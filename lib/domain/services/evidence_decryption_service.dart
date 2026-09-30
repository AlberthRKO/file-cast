abstract interface class EvidenceDecryptionService {
  Future<String> decryptToTemporaryFile({
    required String evidenceId,
    required String encryptedPath,
    required String wrappedKey,
    String? outputPath,
    String? expectedPlaintextSha256,
    int? expectedPlaintextByteLength,
  });
}
