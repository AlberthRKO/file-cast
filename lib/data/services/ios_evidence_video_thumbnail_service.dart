import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';
import 'package:flutter/services.dart';

final class IosEvidenceVideoThumbnailService
    implements EvidenceVideoThumbnailService {
  IosEvidenceVideoThumbnailService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.fiscalia.file_cast/evidence_video_thumbnail';

  final MethodChannel _channel;

  String _nativeCacheKey(String cacheKey) =>
      sha256.convert(utf8.encode(cacheKey)).toString();

  @override
  Future<String?> findCachedThumbnail({required String cacheKey}) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'findCachedThumbnail',
      {'cacheKey': _nativeCacheKey(cacheKey)},
    );
    final path = result?['path'] as String?;
    return path?.isNotEmpty == true ? path : null;
  }

  @override
  Future<String> createThumbnail({
    required String videoPath,
    required String cacheKey,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'createThumbnail',
      {
        'path': videoPath,
        'cacheKey': _nativeCacheKey(cacheKey),
      },
    );
    final path = result?['path'] as String?;
    if (path == null || path.isEmpty) {
      throw StateError('createThumbnail returned no path');
    }
    return path;
  }
}
