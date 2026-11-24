import 'dart:typed_data';

abstract interface class EvidenceImageThumbnailService {
  Uint8List? findCachedThumbnail({
    required String evidenceId,
    required String encryptedPath,
    String? plaintextSha256,
    int? plaintextByteLength,
  });

  Future<Uint8List?> loadThumbnail({
    required String evidenceId,
    required String encryptedPath,
    required String wrappedKey,
    String? plaintextSha256,
    int? plaintextByteLength,
  });

  Future<String> decryptForFallback({
    required String evidenceId,
    required String encryptedPath,
    required String wrappedKey,
    String? plaintextSha256,
    int? plaintextByteLength,
  });

  Future<void> deleteFallback(String path);
}
