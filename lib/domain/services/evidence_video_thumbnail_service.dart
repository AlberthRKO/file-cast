abstract interface class EvidenceVideoThumbnailService {
  Future<String?> findCachedThumbnail({required String cacheKey});

  Future<String> createThumbnail({
    required String videoPath,
    required String cacheKey,
  });
}
