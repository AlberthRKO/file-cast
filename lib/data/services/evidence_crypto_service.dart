import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:file_cast/core/constants/storage_keys.dart';
import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:file_cast/domain/services/evidence_decryption_service.dart';

/// Cifra evidencias localmente antes de que entren a la cola de sincronización.
///
/// El formato FCE es deliberadamente opaco para ms-files-v2. Usa una DEK
/// aleatoria por evidencia, AES-256-GCM por bloques y una clave de bóveda
/// protegida por flutter_secure_storage para envolver la DEK.
class EvidenceCryptoService implements EvidenceDecryptionService {
  EvidenceCryptoService({required SecureStorageService storage})
    : _storage = storage;

  static const algorithmName = 'AES-256-GCM-CHUNKED';
  static const formatVersion = 1;
  static const chunkSize = 1024 * 1024;
  static const _vaultKeyName = 'file_cast_evidence_vault_key_v1';
  static const _deviceIdName = StorageKeys.deviceId;
  static const _aadPrefix = 'file-cast/evidence/v1';
  static const _magic = <int>[0x46, 0x43, 0x45, 0x01];
  static const _nonceLength = 12;
  static const _macLength = 16;

  final SecureStorageService _storage;
  final AesGcm _aes = AesGcm.with256bits();
  final Random _random = Random.secure();

  Future<String> get deviceId async {
    final existing = await _storage.read(_deviceIdName);
    if (existing != null && existing.isNotEmpty) return existing;
    final value = _base64Url(_randomBytes(24));
    await _storage.write(_deviceIdName, value);
    return value;
  }

  Future<EncryptedEvidenceLocal> encryptEvidence({
    required String evidenceId,
    required String inputPath,
    required String originalName,
    required String mimeType,
  }) async {
    final input = File(inputPath);
    if (!await input.exists()) {
      throw StateError(
        'No existe el archivo de evidencia que se desea cifrar.',
      );
    }
    if (await input.length() == 0) {
      throw StateError('No se puede cifrar una evidencia vacía.');
    }

    final outputPath = '$inputPath.fce';
    final output = File(outputPath);
    final dataKeyBytes = _randomBytes(32);
    final dataKey = SecretKeyData(dataKeyBytes);
    final aadHash = _sha256(utf8.encode('$_aadPrefix/$evidenceId'));
    final plaintextHasher = _StreamingSha256();
    final ciphertextHasher = _StreamingSha256();
    var plaintextLength = 0;
    var chunkIndex = 0;

    try {
      final source = await input.open();
      final sink = output.openWrite();
      try {
        final header = <int>[..._magic, ..._u32(chunkSize)];
        sink.add(header);
        ciphertextHasher.add(header);

        while (true) {
          final chunk = await source.read(chunkSize);
          if (chunk.isEmpty) break;

          plaintextLength += chunk.length;
          plaintextHasher.add(chunk);
          final nonce = _randomBytes(_nonceLength);
          final secretBox = await _aes.encrypt(
            chunk,
            secretKey: dataKey,
            nonce: nonce,
            aad: _aad(evidenceId, chunkIndex),
          );
          final record = <int>[
            ..._u32(chunk.length),
            ...nonce,
            ..._u32(secretBox.cipherText.length),
            ...secretBox.cipherText,
            ...secretBox.mac.bytes,
          ];
          sink.add(record);
          ciphertextHasher.add(record);
          chunkIndex += 1;
        }
      } finally {
        await source.close();
        await sink.flush();
        await sink.close();
      }

      final wrappedKey = await _wrapDataKey(dataKeyBytes);
      final plaintextSha256 = plaintextHasher.close();
      final ciphertextSha256 = ciphertextHasher.close();
      final ciphertextLength = await output.length();
      await input.delete();

      return EncryptedEvidenceLocal(
        name: originalName,
        localPath: outputPath,
        byteLength: ciphertextLength,
        sha256: ciphertextSha256,
        plaintextByteLength: plaintextLength,
        plaintextSha256: plaintextSha256,
        encrypted: true,
        encryptionAlgorithm: algorithmName,
        encryptionVersion: formatVersion,
        aadHash: aadHash,
        wrappedKey: wrappedKey,
        keyVersion: formatVersion,
        mimeType: mimeType,
      );
    } catch (_) {
      if (await output.exists()) await output.delete();
      rethrow;
    }
  }

  /// Materializa un archivo temporal solo para una vista previa local.
  /// El caller debe eliminar el resultado al cerrar la vista.
  @override
  Future<String> decryptToTemporaryFile({
    required String evidenceId,
    required String encryptedPath,
    required String wrappedKey,
    String? outputPath,
    String? expectedPlaintextSha256,
    int? expectedPlaintextByteLength,
  }) async {
    final source = await File(encryptedPath).open();
    final targetPath =
        outputPath ??
        '${encryptedPath.substring(0, encryptedPath.length - 4)}.preview';
    final target = File(targetPath);
    final plaintextHasher = _StreamingSha256();
    var plaintextLength = 0;

    try {
      final magic = await _readExactly(source, _magic.length);
      if (!_sameBytes(magic, _magic))
        throw StateError('Formato FCE no reconocido.');
      final version = _readU32(await _readExactly(source, 4));
      if (version != chunkSize)
        throw StateError('Tamaño de bloque FCE no soportado.');

      final dataKey = await _unwrapDataKey(wrappedKey);
      final sink = target.openWrite();
      try {
        var chunkIndex = 0;
        while (true) {
          final plaintextLengthInRecord = await _readMaybe(source, 4);
          if (plaintextLengthInRecord == null) break;
          final recordPlaintextLength = _readU32(plaintextLengthInRecord);
          final nonce = await _readExactly(source, _nonceLength);
          final ciphertextLength = _readU32(await _readExactly(source, 4));
          if (ciphertextLength == 0 ||
              ciphertextLength > chunkSize ||
              recordPlaintextLength > chunkSize) {
            throw StateError('Registro FCE inválido.');
          }
          final ciphertext = await _readExactly(source, ciphertextLength);
          final mac = await _readExactly(source, _macLength);
          final plaintext = await _aes.decrypt(
            SecretBox(
              ciphertext,
              nonce: nonce,
              mac: Mac(mac),
            ),
            secretKey: dataKey,
            aad: _aad(evidenceId, chunkIndex),
          );
          if (plaintext.length != recordPlaintextLength) {
            throw StateError('La longitud de un bloque FCE no coincide.');
          }
          sink.add(plaintext);
          plaintextHasher.add(plaintext);
          plaintextLength += plaintext.length;
          chunkIndex += 1;
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      final plaintextSha256 = plaintextHasher.close();
      if (expectedPlaintextByteLength != null &&
          expectedPlaintextByteLength != plaintextLength) {
        throw StateError('El tamaño de la evidencia descifrada no coincide.');
      }
      if (expectedPlaintextSha256 != null &&
          expectedPlaintextSha256.toLowerCase() != plaintextSha256) {
        throw StateError('El hash de la evidencia descifrada no coincide.');
      }
      return targetPath;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    } finally {
      await source.close();
    }
  }

  Future<void> deletePlaintext(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  List<int> _aad(String evidenceId, int chunkIndex) =>
      utf8.encode('$_aadPrefix/$evidenceId/$chunkIndex');

  Future<SecretKey> _getVaultKey() async {
    final stored = await _storage.read(_vaultKeyName);
    if (stored != null && stored.isNotEmpty) {
      return SecretKeyData(base64Url.decode(stored));
    }
    final bytes = _randomBytes(32);
    await _storage.write(_vaultKeyName, _base64Url(bytes));
    return SecretKeyData(bytes);
  }

  Future<String> _wrapDataKey(List<int> dataKeyBytes) async {
    final nonce = _randomBytes(_nonceLength);
    final box = await _aes.encrypt(
      dataKeyBytes,
      secretKey: await _getVaultKey(),
      nonce: nonce,
      aad: utf8.encode('$_aadPrefix/dek/$formatVersion'),
    );
    final envelope = jsonEncode({
      'version': formatVersion,
      'nonce': _base64Url(nonce),
      'ciphertext': _base64Url(box.cipherText),
      'mac': _base64Url(box.mac.bytes),
    });
    return _base64Url(utf8.encode(envelope));
  }

  Future<SecretKey> _unwrapDataKey(String wrappedKey) async {
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(wrappedKey)),
    );
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != formatVersion) {
      throw StateError('Envoltura de clave no compatible.');
    }
    final box = SecretBox(
      base64Url.decode(decoded['ciphertext'] as String),
      nonce: base64Url.decode(decoded['nonce'] as String),
      mac: Mac(base64Url.decode(decoded['mac'] as String)),
    );
    return SecretKeyData(
      await _aes.decrypt(
        box,
        secretKey: await _getVaultKey(),
        aad: utf8.encode('$_aadPrefix/dek/$formatVersion'),
      ),
    );
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256), growable: false);

  List<int> _u32(int value) => [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];

  int _readU32(List<int> bytes) =>
      (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];

  Future<List<int>> _readExactly(RandomAccessFile file, int length) async {
    final bytes = await file.read(length);
    if (bytes.length != length) throw StateError('Archivo FCE truncado.');
    return bytes;
  }

  Future<List<int>?> _readMaybe(RandomAccessFile file, int length) async {
    final bytes = await file.read(length);
    if (bytes.isEmpty) return null;
    if (bytes.length != length) throw StateError('Archivo FCE truncado.');
    return bytes;
  }

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  String _base64Url(List<int> bytes) => base64UrlEncode(bytes);

  String _sha256(List<int> bytes) => crypto.sha256.convert(bytes).toString();
}

final class EncryptedEvidenceLocal {
  const EncryptedEvidenceLocal({
    required this.name,
    required this.localPath,
    required this.byteLength,
    required this.sha256,
    required this.plaintextByteLength,
    required this.plaintextSha256,
    required this.encrypted,
    required this.encryptionAlgorithm,
    required this.encryptionVersion,
    required this.aadHash,
    required this.wrappedKey,
    required this.keyVersion,
    required this.mimeType,
  });

  final String name;
  final String localPath;
  final int byteLength;
  final String sha256;
  final int plaintextByteLength;
  final String plaintextSha256;
  final bool encrypted;
  final String encryptionAlgorithm;
  final int encryptionVersion;
  final String aadHash;
  final String wrappedKey;
  final int keyVersion;
  final String mimeType;
}

final class _StreamingSha256 {
  final _DigestSink _output = _DigestSink();
  late final ByteConversionSink _input = crypto.sha256.startChunkedConversion(
    _output,
  );

  void add(List<int> bytes) => _input.add(Uint8List.fromList(bytes));

  String close() {
    _input.close();
    return _output.value.toString();
  }
}

final class _DigestSink implements Sink<crypto.Digest> {
  crypto.Digest? _digest;

  crypto.Digest get value => _digest!;

  @override
  void add(crypto.Digest digest) {
    if (_digest != null) {
      throw StateError('El hash solo puede cerrarse una vez.');
    }
    _digest = digest;
  }

  @override
  void close() {
    if (_digest == null) {
      throw StateError('El hash no produjo ningún resultado.');
    }
  }
}
