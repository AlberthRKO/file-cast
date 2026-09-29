import 'dart:io';

import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'cifra por bloques, elimina el plano y permite descifrar con verificación',
      () async {
    final storage = _MemorySecureStorage();
    final service = EvidenceCryptoService(storage: storage);
    final directory =
        await Directory.systemTemp.createTemp('file_cast_crypto_test_');
    final input = File('${directory.path}/captura.png');
    final original = List<int>.generate(
      EvidenceCryptoService.chunkSize + 137,
      (index) => index % 251,
    );
    await input.writeAsBytes(original, flush: true);

    try {
      final encrypted = await service.encryptEvidence(
        evidenceId: '11111111-1111-4111-8111-111111111111',
        inputPath: input.path,
        originalName: 'captura.png',
        mimeType: 'image/png',
      );

      expect(await input.exists(), isFalse);
      expect(await File(encrypted.localPath).exists(), isTrue);
      expect(encrypted.plaintextByteLength, original.length);
      expect(encrypted.plaintextSha256, hasLength(64));
      expect(encrypted.sha256, hasLength(64));

      final decryptedPath = await service.decryptToTemporaryFile(
        evidenceId: '11111111-1111-4111-8111-111111111111',
        encryptedPath: encrypted.localPath,
        wrappedKey: encrypted.wrappedKey,
        expectedPlaintextSha256: encrypted.plaintextSha256,
        expectedPlaintextByteLength: encrypted.plaintextByteLength,
      );
      expect(await File(decryptedPath).readAsBytes(), original);
      await File(decryptedPath).delete();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

final class _MemorySecureStorage extends SecureStorageService {
  _MemorySecureStorage() : super(const FlutterSecureStorage());

  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
