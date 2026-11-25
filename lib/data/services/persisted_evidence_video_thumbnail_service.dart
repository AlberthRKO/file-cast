import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';
import 'package:flutter/foundation.dart';

/// Conserva los JPEG por cuenta en SQLCipher y reconstruye el archivo temporal
/// cuando Android o iOS limpian su caché. El archivo original no se conserva.
final class PersistedEvidenceVideoThumbnailService
    implements EvidenceVideoThumbnailService {
  PersistedEvidenceVideoThumbnailService({
    required EvidenceVideoThumbnailService platformService,
    required LocalEvidenceDatabaseService database,
  }) : _platformService = platformService,
       _database = database;

  final EvidenceVideoThumbnailService _platformService;
  final LocalEvidenceDatabaseService _database;
  final Map<String, Future<String>> _inFlight = {};

  String _scopedKey(String accountId, String cacheKey) =>
      sha256.convert(utf8.encode('$accountId\u0000$cacheKey')).toString();

  File _displayFile(String scopedKey) => File(
    '${Directory.systemTemp.path}/evidence_video_thumbnails/persisted_$scopedKey.jpg',
  );

  Future<String?> _existingPath(File file) async =>
      await file.exists() && await file.length() > 0 ? file.path : null;

  @override
  Future<String?> findCachedThumbnail({required String cacheKey}) async {
    String accountId;
    try {
      accountId = await _database.currentAccountId();
    } on Object {
      return _platformService.findCachedThumbnail(cacheKey: cacheKey);
    }
    final scopedKey = _scopedKey(accountId, cacheKey);
    final display = _displayFile(scopedKey);
    final existing = await _existingPath(display);
    if (existing != null) return existing;

    try {
      final bytes = await _database.readVideoThumbnail(
        accountId: accountId,
        cacheKey: scopedKey,
      );
      if (bytes != null && _isJpeg(bytes)) {
        final platformPath = await _platformService.findCachedThumbnail(
          cacheKey: scopedKey,
        );
        if (platformPath != null && await File(platformPath).exists()) {
          return platformPath;
        }
        await _writeDisplay(display, bytes);
        return display.path;
      }
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Video thumbnail cache read: $error');
    }

    final platformPath = await _platformService.findCachedThumbnail(
      cacheKey: scopedKey,
    );
    if (platformPath == null) return null;
    return _persist(
      path: platformPath,
      accountId: accountId,
      scopedKey: scopedKey,
    );
  }

  @override
  Future<String> createThumbnail({
    required String videoPath,
    required String cacheKey,
  }) async {
    String accountId;
    try {
      accountId = await _database.currentAccountId();
    } on Object {
      return _platformService.createThumbnail(
        videoPath: videoPath,
        cacheKey: cacheKey,
      );
    }
    final scopedKey = _scopedKey(accountId, cacheKey);
    final pending = _inFlight[scopedKey];
    if (pending != null) return pending;
    final extraction = _createScoped(
      videoPath: videoPath,
      accountId: accountId,
      scopedKey: scopedKey,
    );
    _inFlight[scopedKey] = extraction;
    try {
      return await extraction;
    } finally {
      if (identical(_inFlight[scopedKey], extraction)) {
        _inFlight.remove(scopedKey);
      }
    }
  }

  Future<String> _createScoped({
    required String videoPath,
    required String accountId,
    required String scopedKey,
  }) async {
    final display = _displayFile(scopedKey);
    final existing = await _existingPath(display);
    if (existing != null) return existing;
    final platformPath = await _platformService.createThumbnail(
      videoPath: videoPath,
      cacheKey: scopedKey,
    );
    return _persist(
      path: platformPath,
      accountId: accountId,
      scopedKey: scopedKey,
    );
  }

  Future<String> _persist({
    required String path,
    required String accountId,
    required String scopedKey,
  }) async {
    try {
      final source = File(path);
      if (await source.length() > 8 * 1024 * 1024) return path;
      final bytes = await source.readAsBytes();
      if (!_isJpeg(bytes)) return path;
      try {
        await _database.saveVideoThumbnail(
          accountId: accountId,
          cacheKey: scopedKey,
          bytes: bytes,
        );
      } on Object catch (error) {
        if (kDebugMode) debugPrint('Video thumbnail cache write: $error');
      }
      return path;
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Video thumbnail cache: $error');
      return path;
    }
  }

  bool _isJpeg(Uint8List bytes) =>
      bytes.lengthInBytes >= 4 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[bytes.lengthInBytes - 2] == 0xff &&
      bytes[bytes.lengthInBytes - 1] == 0xd9;

  Future<void> _writeDisplay(File display, Uint8List bytes) async {
    await display.parent.create(recursive: true);
    final temporary = File(
      '${display.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(display.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
