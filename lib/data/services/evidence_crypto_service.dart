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
  static const _encryptionDeviceIdName = StorageKeys.encryptionDeviceId;
  static const _encryptionPrivateKeyName = StorageKeys.encryptionPrivateKey;
  static const _aadPrefix = 'file-cast/evidence/v1';
  static const _magic = <int>[0x46, 0x43, 0x45, 0x01];
  static const _nonceLength = 12;
  static const _macLength = 16;

  final SecureStorageService _storage;
  final AesGcm _aes = AesGcm.with256bits();
  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Random _random = Random.secure();

  Future<String> get deviceId async {
    final existing = await _storage.read(_deviceIdName);
    if (existing != null && existing.isNotEmpty) return existing;
    final value = _base64Url(_randomBytes(24));
    await _storage.write(_deviceIdName, value);
    return value;
  }

  static const deviceKeyAlgorithm = 'X25519-HKDF-SHA256-AES-256-GCM';
  static const localKeyWrapAlgorithm = 'AES-256-GCM-LOCAL-VAULT';

  Future<String> get encryptionDeviceId async {
    final existing = await _storage.read(_encryptionDeviceIdName);
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = _randomBytes(16);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final value =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _storage.write(_encryptionDeviceIdName, value);
    return value;
  }

  Future<String> encryptionPublicKey() async {
    final keyPair = await _encryptionKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return _base64Url(publicKey.bytes);
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
    String? wrapAlgorithm,
  }) async {
    final source = await File(encryptedPath).open();
    final targetPath =
        outputPath ??
        '${encryptedPath.substring(0, encryptedPath.length - 4)}.preview-'
            '${DateTime.now().microsecondsSinceEpoch}';
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

      final dataKey = wrapAlgorithm == deviceKeyAlgorithm
          ? await _unwrapDeviceDataKey(wrappedKey, evidenceId)
          : await _unwrapDataKey(wrappedKey);
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

      // El hash autenticado por bloques y el hash del contenido original son
      // las verificaciones de integridad fuertes. Algunas evidencias creadas
      // antes de que el backend distinguiera `byteLength` (FCE) de
      // `plaintextByteLength` conservaron el tamaño cifrado en el segundo
      // campo. No debemos rechazar un archivo íntegro por ese metadato
      // histórico; sí debemos rechazarlo cuando el hash tampoco coincide.
      final hashMatches =
          expectedPlaintextSha256 == null ||
          expectedPlaintextSha256.toLowerCase() == plaintextSha256;
      if (!hashMatches) {
        throw StateError('El hash de la evidencia descifrada no coincide.');
      }
      if (expectedPlaintextByteLength != null &&
          expectedPlaintextByteLength != plaintextLength &&
          expectedPlaintextByteLength != await source.length() &&
          expectedPlaintextSha256 == null) {
        throw StateError(
          'El tamaño de la evidencia descifrada no coincide '
          '(descifrado: $plaintextLength, esperado: '
          '$expectedPlaintextByteLength).',
        );
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

  Future<String> wrapLocalDataKeyForDevice({
    required String wrappedKey,
    required String evidenceId,
    required String recipientPublicKey,
  }) async {
    final localDataKey = await _unwrapDataKey(wrappedKey);
    final dataKeyBytes = await localDataKey.extractBytes();
    final ephemeral = await _x25519.newKeyPair();
    final recipientBytes = _decodeBase64Bytes(
      recipientPublicKey,
      fieldName: 'La clave pública del destinatario',
    );
    if (recipientBytes.length != 32) {
      throw StateError(
        'La clave pública del destinatario X25519 no tiene 32 bytes.',
      );
    }
    final remotePublicKey = SimplePublicKey(
      recipientBytes,
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: remotePublicKey,
    );
    final salt = _randomBytes(16);
    final wrappingKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: salt,
      info: utf8.encode('file-cast/evidence-key/$evidenceId/$formatVersion'),
    );
    final nonce = _randomBytes(_nonceLength);
    final box = await _aes.encrypt(
      dataKeyBytes,
      secretKey: wrappingKey,
      nonce: nonce,
      aad: _keyEnvelopeAad(evidenceId),
    );
    final ephemeralPublicKey = await ephemeral.extractPublicKey();
    ephemeral.destroy();
    return _base64Url(
      utf8.encode(
        jsonEncode({
          'version': formatVersion,
          'ephemeralPublicKey': _base64Url(ephemeralPublicKey.bytes),
          'salt': _base64Url(salt),
          'nonce': _base64Url(nonce),
          'ciphertext': _base64Url(box.cipherText),
          'mac': _base64Url(box.mac.bytes),
        }),
      ),
    );
  }

  Future<String> wrapLocalDataKeyForRecovery({
    required String wrappedKey,
    required String evidenceId,
    required String recoveryPublicKey,
  }) {
    return wrapLocalDataKeyForDevice(
      wrappedKey: wrappedKey,
      evidenceId: evidenceId,
      recipientPublicKey: recoveryPublicKey,
    );
  }

  Future<SecretKey> _unwrapDeviceDataKey(
    String wrappedKey,
    String evidenceId,
  ) async {
    final envelope = _decodeEnvelope(wrappedKey);
    final ephemeralBytes = _decodeBase64Bytes(
      envelope['ephemeralPublicKey'] as String,
      fieldName: 'La clave efímera de la envoltura',
    );
    if (ephemeralBytes.length != 32) {
      throw StateError('La clave efímera X25519 no tiene 32 bytes.');
    }
    final ephemeralPublicKey = SimplePublicKey(
      ephemeralBytes,
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: await _encryptionKeyPair(),
      remotePublicKey: ephemeralPublicKey,
    );
    final wrappingKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: _decodeBase64Bytes(envelope['salt'] as String, fieldName: 'salt'),
      info: utf8.encode('file-cast/evidence-key/$evidenceId/$formatVersion'),
    );
    final dataKey = await _aes.decrypt(
      SecretBox(
        _decodeBase64Bytes(
          envelope['ciphertext'] as String,
          fieldName: 'ciphertext',
        ),
        nonce: _decodeBase64Bytes(
          envelope['nonce'] as String,
          fieldName: 'nonce',
        ),
        mac: Mac(
          _decodeBase64Bytes(envelope['mac'] as String, fieldName: 'mac'),
        ),
      ),
      secretKey: wrappingKey,
      aad: _keyEnvelopeAad(evidenceId),
    );
    return SecretKeyData(dataKey);
  }

  Map<String, dynamic> _decodeEnvelope(String wrappedKey) {
    final decoded = jsonDecode(
      utf8.decode(_decodeBase64Bytes(wrappedKey, fieldName: 'envoltura')),
    );
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != formatVersion) {
      throw StateError('Envoltura de clave no compatible.');
    }
    return decoded;
  }

  List<int> _keyEnvelopeAad(String evidenceId) =>
      utf8.encode('file-cast/evidence-key/$evidenceId/$formatVersion');

  Future<SimpleKeyPair> _encryptionKeyPair() async {
    final stored = await _storage.read(_encryptionPrivateKeyName);
    final seed = stored == null || stored.isEmpty
        ? _randomBytes(32)
        : _decodeBase64Bytes(
            stored,
            fieldName: 'clave privada del dispositivo',
          );
    if (seed.length != 32) {
      throw StateError(
        'La clave privada X25519 del dispositivo no tiene 32 bytes.',
      );
    }
    if (stored == null || stored.isEmpty) {
      await _storage.write(_encryptionPrivateKeyName, _base64Url(seed));
    }
    return _x25519.newKeyPairFromSeed(seed);
  }

  Future<SecretKey> _unwrapDataKey(String wrappedKey) async {
    final decoded = _decodeEnvelope(wrappedKey);
    final box = SecretBox(
      _decodeBase64Bytes(
        decoded['ciphertext'] as String,
        fieldName: 'ciphertext',
      ),
      nonce: _decodeBase64Bytes(
        decoded['nonce'] as String,
        fieldName: 'nonce',
      ),
      mac: Mac(
        _decodeBase64Bytes(decoded['mac'] as String, fieldName: 'mac'),
      ),
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
    final bytes = <int>[];
    while (bytes.length < length) {
      final chunk = await file.read(length - bytes.length);
      if (chunk.isEmpty) throw StateError('Archivo FCE truncado.');
      bytes.addAll(chunk);
    }
    return bytes;
  }

  Future<List<int>?> _readMaybe(RandomAccessFile file, int length) async {
    final first = await file.read(length);
    if (first.isEmpty) return null;
    if (first.length == length) return first;

    final bytes = <int>[...first];
    while (bytes.length < length) {
      final chunk = await file.read(length - bytes.length);
      if (chunk.isEmpty) throw StateError('Archivo FCE truncado.');
      bytes.addAll(chunk);
    }
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

  List<int> _decodeBase64Bytes(
    String value, {
    required String fieldName,
  }) {
    try {
      // El backend publica claves base64url sin padding, mientras que algunos
      // registros antiguos pueden conservar el alfabeto base64 estándar.
      final normalized = base64Url.normalize(
        value.replaceAll('+', '-').replaceAll('/', '_'),
      );
      return base64Url.decode(normalized);
    } on FormatException {
      throw StateError('El campo $fieldName no contiene base64 válido.');
    }
  }

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
