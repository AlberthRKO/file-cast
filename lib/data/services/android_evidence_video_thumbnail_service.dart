import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

final class AndroidEvidenceVideoThumbnailService
    implements EvidenceVideoThumbnailService {
  AndroidEvidenceVideoThumbnailService({required AdbClient adbClient})
    : _adbClient = adbClient;

  final AdbClient _adbClient;
  Future<void> _lastExtraction = Future<void>.value();
  DateTime? _nativeUnavailableUntil;
  final Set<String> _nativeUnsupportedKeys = {};

  @override
  Future<String?> findCachedThumbnail({required String cacheKey}) async {
    final native = await _adbClient.getCachedVideoThumbnail(cacheKey: cacheKey);
    if (native != null) return native;
    final softwareFile = _softwareCacheFile(cacheKey);
    return await softwareFile.exists() && await softwareFile.length() > 0
        ? softwareFile.path
        : null;
  }

  @override
  Future<String> createThumbnail({
    required String videoPath,
    required String cacheKey,
  }) {
    final ready = Completer<String>();
    _lastExtraction = _lastExtraction.then((_) async {
      try {
        final path = await _createThumbnail(
          videoPath,
          cacheKey,
          onReady: (path) {
            if (!ready.isCompleted) ready.complete(path);
          },
        );
        if (!ready.isCompleted) ready.complete(path);
      } on Object catch (error, stackTrace) {
        if (!ready.isCompleted) ready.completeError(error, stackTrace);
      }
    });
    return ready.future;
  }

  Future<String> _createThumbnail(
    String videoPath,
    String cacheKey, {
    required void Function(String) onReady,
  }) async {
    final cached = _softwareCacheFile(cacheKey);
    if (await cached.exists() && await cached.length() > 0) {
      return cached.path;
    }
    // Algunos MOV sí son compatibles con el extractor nativo y se resuelven
    // mucho más rápido. Solo omitirlo si ya falló para esta evidencia.
    if (_nativeUnsupportedKeys.contains(cacheKey)) {
      return _extractWithSoftwareDecoder(videoPath, cacheKey, onReady: onReady);
    }
    final nativeUnavailableUntil = _nativeUnavailableUntil;
    if (nativeUnavailableUntil != null &&
        DateTime.now().isBefore(nativeUnavailableUntil)) {
      return _extractWithSoftwareDecoder(videoPath, cacheKey, onReady: onReady);
    }
    try {
      return await _adbClient
          .createVideoThumbnail(path: videoPath, cacheKey: cacheKey)
          .timeout(const Duration(seconds: 45));
    } on Object catch (error) {
      if (error is! PlatformException && error is! TimeoutException) rethrow;
      if (error is PlatformException &&
          error.message?.contains('No se pudo extraer un cuadro') == true) {
        _nativeUnsupportedKeys.add(cacheKey);
      }
      if (error is TimeoutException) {
        // El hilo nativo puede seguir ocupado aunque Dart haya agotado el
        // tiempo. No encolar más extractores OEM mientras se recupera.
        _nativeUnavailableUntil = DateTime.now().add(
          const Duration(minutes: 2),
        );
      }
      // Algunos extractores OEM no pueden leer cuadros que libmpv sí reproduce.
      return _extractWithSoftwareDecoder(videoPath, cacheKey, onReady: onReady);
    }
  }

  File _softwareCacheFile(String cacheKey) {
    final digest = sha256.convert(utf8.encode(cacheKey));
    return File(
      '${Directory.systemTemp.path}/evidence_video_thumbnails/$digest.jpg',
    );
  }

  Future<String> _extractWithSoftwareDecoder(
    String videoPath,
    String cacheKey, {
    required void Function(String) onReady,
  }) async {
    final cached = _softwareCacheFile(cacheKey);
    if (await cached.exists() && await cached.length() > 0) {
      return cached.path;
    }
    final video = File(videoPath);
    if (!await video.exists() || await video.length() == 0) {
      throw StateError('El video no está disponible para crear la miniatura.');
    }

    final player = Player(
      configuration: const PlayerConfiguration(muted: true),
    );
    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'no'),
    );
    // Cada intento usa un temporal distinto antes de instalar el JPEG en caché.
    final temporary = File(
      '${cached.path}.${DateTime.now().microsecondsSinceEpoch}.part.jpg',
    );
    try {
      await controller.platform.future.timeout(const Duration(seconds: 15));
      await player
          .open(Media(videoPath), play: true)
          .timeout(const Duration(seconds: 20));
      if (player.state.position < const Duration(milliseconds: 250)) {
        try {
          await player.stream.position
              .firstWhere(
                (position) => position >= const Duration(milliseconds: 250),
              )
              .timeout(const Duration(seconds: 30));
        } on Object catch (error) {
          // Algunos contenedores no publican posición antes del primer frame.
          if (kDebugMode) debugPrint('MediaKit thumbnail progress: $error');
        }
      }
      await cached.parent.create(recursive: true);
      Uint8List? jpeg;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          jpeg = await player
              .screenshot(format: 'image/jpeg')
              .timeout(const Duration(seconds: 25));
        } on TimeoutException {
          // La captura original puede seguir ejecutándose: no lanzar otra.
          rethrow;
        } on Object catch (error) {
          if (kDebugMode) debugPrint('MediaKit thumbnail: $error');
        }
        if (jpeg != null && jpeg.isNotEmpty) break;
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      if (jpeg == null || jpeg.isEmpty) {
        throw StateError('MediaKit no entregó un cuadro del video.');
      }

      await temporary.writeAsBytes(jpeg, flush: true);
      await temporary.rename(cached.path);
      // La tarjeta ya puede mostrar el JPEG. El servicio conserva la cola
      // mientras MediaKit libera el decoder y la textura en finally.
      onReady(cached.path);
      return cached.path;
    } finally {
      try {
        await player.dispose().timeout(const Duration(seconds: 10));
      } on Object catch (error) {
        if (kDebugMode) debugPrint('MediaKit thumbnail dispose: $error');
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }
}
