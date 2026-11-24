import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/domain/services/evidence_image_thumbnail_service.dart';

/// Conserva solo PNG pequeños en memoria. El archivo plano usado para generar
/// cada miniatura se elimina inmediatamente, incluso si falla el decoder.
final class EvidenceImageThumbnailServiceImpl
    implements EvidenceImageThumbnailService {
  EvidenceImageThumbnailServiceImpl({
    required EvidenceDecryptionService decryptionService,
    required LocalEvidenceDatabaseService database,
  }) : _decryptionService = decryptionService,
       _database = database;

  static const _thumbnailEdge = 384;
  static const _maximumCachedBytes = 40 * 1024 * 1024;
  static const _maximumCachedItems = 128;

  final EvidenceDecryptionService _decryptionService;
  final LocalEvidenceDatabaseService _database;
  final LinkedHashMap<String, Uint8List> _cached = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _inFlight = {};
  int _cachedBytes = 0;
  String? _ownerId;
  int _ownerGeneration = 0;

  void setOwnerId(String? ownerId) {
    if (_ownerId == ownerId) return;
    _ownerId = ownerId;
    _ownerGeneration++;
    _cached.clear();
    _inFlight.clear();
    _cachedBytes = 0;
  }

  String _key({
    required String evidenceId,
    required String encryptedPath,
    String? plaintextSha256,
    int? plaintextByteLength,
  }) => sha256
      .convert(
        utf8.encode(
          [
            'image-thumb-v1',
            evidenceId,
            encryptedPath,
            plaintextSha256 ?? '',
            plaintextByteLength?.toString() ?? '',
          ].join('\u0000'),
        ),
      )
      .toString();

  @override
  Uint8List? findCachedThumbnail({
    required String evidenceId,
    required String encryptedPath,
    String? plaintextSha256,
    int? plaintextByteLength,
  }) {
    final key = _key(
      evidenceId: evidenceId,
      encryptedPath: encryptedPath,
      plaintextSha256: plaintextSha256,
      plaintextByteLength: plaintextByteLength,
    );
    final cached = _cached.remove(key);
    if (cached != null) _cached[key] = cached;
    return cached;
  }

  @override
  Future<Uint8List?> loadThumbnail({
    required String evidenceId,
    required String encryptedPath,
    required String wrappedKey,
    String? plaintextSha256,
    int? plaintextByteLength,
  }) async {
    final key = _key(
      evidenceId: evidenceId,
      encryptedPath: encryptedPath,
      plaintextSha256: plaintextSha256,
      plaintextByteLength: plaintextByteLength,
    );
    final cached = findCachedThumbnail(
      evidenceId: evidenceId,
      encryptedPath: encryptedPath,
      plaintextSha256: plaintextSha256,
      plaintextByteLength: plaintextByteLength,
    );
    if (cached != null) return cached;
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final generation = _ownerGeneration;
    final generated = () async {
      String? accountId;
      Uint8List? bytes;
      try {
        accountId = await _database.currentAccountId();
        bytes = await _database.readImageThumbnail(
          accountId: accountId,
          cacheKey: key,
        );
      } on Object {
        // La caché es opcional; una lectura fallida no impide el preview.
      }
      if (bytes == null) {
        bytes = await _generate(
          evidenceId: evidenceId,
          encryptedPath: encryptedPath,
          wrappedKey: wrappedKey,
          plaintextSha256: plaintextSha256,
          plaintextByteLength: plaintextByteLength,
        );
        if (generation != _ownerGeneration) {
          throw StateError('La sesión cambió durante la miniatura.');
        }
        if (bytes != null && accountId != null) {
          try {
            await _database.saveImageThumbnail(
              accountId: accountId,
              cacheKey: key,
              bytes: bytes,
            );
          } on Object {
            // El preview continúa aunque la caché persistente no se escriba.
          }
        }
      }
      if (generation != _ownerGeneration) {
        throw StateError('La sesión cambió durante la miniatura.');
      }
      if (bytes != null) _remember(key, bytes);
      return bytes;
    }();
    _inFlight[key] = generated;
    try {
      return await generated;
    } finally {
      if (identical(_inFlight[key], generated)) _inFlight.remove(key);
    }
  }

  Future<Uint8List?> _generate({
    required String evidenceId,
    required String encryptedPath,
    required String wrappedKey,
    String? plaintextSha256,
    int? plaintextByteLength,
  }) async {
    final path = await _decryptionService.decryptToTemporaryFile(
      evidenceId: evidenceId,
      encryptedPath: encryptedPath,
      wrappedKey: wrappedKey,
      expectedPlaintextSha256: plaintextSha256,
      expectedPlaintextByteLength: plaintextByteLength,
    );
    try {
      try {
        return await _decodeSmallPng(path);
      } on Exception {
        // Algunos HEIC se pueden mostrar como archivo aunque el decoder
        // reducido no consiga producir un PNG. La View usa ese fallback.
        return null;
      } on StateError {
        return null;
      }
    } finally {
      await deleteFallback(path);
    }
  }

  Future<Uint8List> _decodeSmallPng(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final landscape = descriptor.width >= descriptor.height;
      try {
        codec = await descriptor.instantiateCodec(
          targetWidth: landscape
              ? math.min(descriptor.width, _thumbnailEdge)
              : null,
          targetHeight: landscape
              ? null
              : math.min(descriptor.height, _thumbnailEdge),
        );
      } on Exception {
        // Algunos decoders HEIC rechazan un tamaño de destino muy pequeño.
        codec = await descriptor.instantiateCodec(
          targetWidth: landscape ? math.min(descriptor.width, 960) : null,
          targetHeight: landscape ? null : math.min(descriptor.height, 960),
        );
      }
      image = (await codec.getNextFrame()).image;
      final longestEdge = math.max(image.width, image.height);
      if (longestEdge > _thumbnailEdge) {
        final width = (image.width * _thumbnailEdge / longestEdge)
            .round()
            .clamp(1, _thumbnailEdge)
            .toInt();
        final height = (image.height * _thumbnailEdge / longestEdge)
            .round()
            .clamp(1, _thumbnailEdge)
            .toInt();
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        try {
          final resized = await picture.toImage(width, height);
          image.dispose();
          image = resized;
        } finally {
          picture.dispose();
        }
      }
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || data.lengthInBytes == 0) {
        throw StateError('No se pudo codificar la miniatura de la imagen.');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  void _remember(String key, Uint8List bytes) {
    if (bytes.lengthInBytes > _maximumCachedBytes) return;
    final previous = _cached.remove(key);
    if (previous != null) _cachedBytes -= previous.lengthInBytes;
    _cached[key] = bytes;
    _cachedBytes += bytes.lengthInBytes;
    while (_cachedBytes > _maximumCachedBytes ||
        _cached.length > _maximumCachedItems) {
      final oldest = _cached.keys.first;
      _cachedBytes -= _cached.remove(oldest)!.lengthInBytes;
    }
  }

  @override
  Future<String> decryptForFallback({
    required String evidenceId,
    required String encryptedPath,
    required String wrappedKey,
    String? plaintextSha256,
    int? plaintextByteLength,
  }) => _decryptionService.decryptToTemporaryFile(
    evidenceId: evidenceId,
    encryptedPath: encryptedPath,
    wrappedKey: wrappedKey,
    expectedPlaintextSha256: plaintextSha256,
    expectedPlaintextByteLength: plaintextByteLength,
  );

  @override
  Future<void> deleteFallback(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Los temporales pueden haber sido retirados por el sistema.
    }
  }
}
