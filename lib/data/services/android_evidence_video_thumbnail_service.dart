import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';

final class AndroidEvidenceVideoThumbnailService
    implements EvidenceVideoThumbnailService {
  const AndroidEvidenceVideoThumbnailService({required AdbClient adbClient})
    : _adbClient = adbClient;

  final AdbClient _adbClient;

  @override
  Future<String?> findCachedThumbnail({required String cacheKey}) =>
      _adbClient.getCachedVideoThumbnail(cacheKey: cacheKey);

  @override
  Future<String> createThumbnail({
    required String videoPath,
    required String cacheKey,
  }) => _adbClient.createVideoThumbnail(path: videoPath, cacheKey: cacheKey);
}
