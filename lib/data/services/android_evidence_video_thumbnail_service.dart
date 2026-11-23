import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

final class AndroidEvidenceVideoThumbnailService
    implements EvidenceVideoThumbnailService {
  AndroidEvidenceVideoThumbnailService({required AdbClient adbClient})
    : _adbClient = adbClient;

  final AdbClient _adbClient;
  Future<void> _lastExtraction = Future<void>.value();

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
    final extraction = _lastExtraction.then(
      (_) => _createThumbnail(videoPath, cacheKey),
    );
    _lastExtraction = extraction.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return extraction;
  }

  Future<String> _createThumbnail(String videoPath, String cacheKey) async {
    try {
      return await _adbClient
          .createVideoThumbnail(path: videoPath, cacheKey: cacheKey)
          .timeout(const Duration(seconds: 45));
    } on Object catch (error) {
      if (error is! PlatformException && error is! TimeoutException) rethrow;
      // Algunos extractores OEM no pueden leer cuadros que libmpv sí reproduce.
      return _extractWithSoftwareDecoder(videoPath, cacheKey);
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
    String cacheKey,
  ) async {
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
    final temporary = File('${cached.path}.part');
    try {
      final videoReady = player.stream.videoParams.firstWhere(
        (params) =>
            (params.dw ?? params.w ?? 0) > 0 &&
            (params.dh ?? params.h ?? 0) > 0,
      );
      await controller.platform.future.timeout(const Duration(seconds: 15));
      await player
          .open(Media(videoPath), play: false)
          .timeout(const Duration(seconds: 15));
      await videoReady.timeout(const Duration(seconds: 15));

      final duration = player.state.duration;
      final frameTime = duration > Duration.zero
          ? Duration(
              milliseconds: (duration.inMilliseconds ~/ 4)
                  .clamp(0, 1000)
                  .toInt(),
            )
          : Duration.zero;
      await player.seek(frameTime);
      await player.play();
      await controller.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 15),
      );
      await player.pause();

      final jpeg = await player
          .screenshot(format: 'image/jpeg')
          .timeout(const Duration(seconds: 15));
      if (jpeg == null || jpeg.isEmpty) {
        throw StateError('No se pudo extraer un cuadro del video.');
      }

      await cached.parent.create(recursive: true);
      await temporary.writeAsBytes(jpeg, flush: true);
      await temporary.rename(cached.path);
      return cached.path;
    } finally {
      await player.dispose();
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
