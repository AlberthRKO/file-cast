import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/data/models/error_model.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';

/// Coordina el registro de la clave pública del dispositivo y la entrega de
/// envolturas de DEK. El contenido sigue cifrado en ms-files-v2; la recuperación
/// institucional solo reenvuelve la DEK en el backend/KMS autorizado.
class EvidenceKeyExchangeService {
  EvidenceKeyExchangeService({
    required Http http,
    required EvidenceCryptoService crypto,
  }) : _http = http,
       _crypto = crypto;

  final Http _http;
  final EvidenceCryptoService _crypto;
  final Set<String> _registeredForRequisitions = <String>{};
  final Map<String, String> _roleByRequisition = <String, String>{};
  final Map<String, EvidenceRecoveryKey> _recoveryKeyByRequisition =
      <String, EvidenceRecoveryKey>{};

  Future<String> get deviceId => _crypto.encryptionDeviceId;

  Future<void> ensureRegistered(String requisitionId) async {
    if (_registeredForRequisitions.contains(requisitionId)) return;
    final deviceId = await _crypto.encryptionDeviceId;
    final result = await _http.request<dynamic>(
      '/api/v1/requisitions/$requisitionId/encryption/devices',
      method: HttpMethod.post,
      headers: {'Idempotency-Key': deviceId},
      body: {
        'deviceId': deviceId,
        'platform': _platform,
        'encryptionPublicKey': await _crypto.encryptionPublicKey(),
        'encryptionKeyAlgorithm': EvidenceCryptoService.deviceKeyAlgorithm,
        'encryptionKeyVersion': EvidenceCryptoService.formatVersion,
      },
      onSucces: (body) => body,
    );
    final response = _successBody(
      result,
      'No se pudo registrar el dispositivo de cifrado.',
    );
    final data = _asMap(_asMap(response)['response'])['data'];
    final role = _asMap(data)['role'];
    if (role is String) _roleByRequisition[requisitionId] = role;
    final recovery = _asMap(_asMap(data)['recoveryKey']);
    final recoveryKey = EvidenceRecoveryKey.fromMap(recovery);
    if (recoveryKey != null) {
      _recoveryKeyByRequisition[requisitionId] = recoveryKey;
    }
    _registeredForRequisitions.add(requisitionId);
  }

  bool canShareKeys(String requisitionId) =>
      _roleByRequisition[requisitionId] == 'OWNER' ||
      _roleByRequisition[requisitionId] == 'EDITOR';

  Future<EvidenceRecoveryKey?> recoveryKey(String requisitionId) async {
    await ensureRegistered(requisitionId);
    return _recoveryKeyByRequisition[requisitionId];
  }

  Future<List<EvidenceEncryptionRecipient>> recipients(
    String requisitionId,
  ) async {
    await ensureRegistered(requisitionId);
    final result = await _http.request<dynamic>(
      '/api/v1/requisitions/$requisitionId/encryption/recipients',
      onSucces: (body) => body,
    );
    final body = _successBody(
      result,
      'No se pudieron obtener los dispositivos autorizados.',
    );
    final data = _asMap(_asMap(body)['response'])['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => EvidenceEncryptionRecipient.fromMap(item))
        .where((item) => item.deviceId.isNotEmpty && item.publicKey.isNotEmpty)
        .toList(growable: false);
  }

  Future<String?> getEnvelope({
    required String requisitionId,
    required String evidenceId,
  }) async {
    await ensureRegistered(requisitionId);
    final deviceId = await _crypto.encryptionDeviceId;
    final result = await _http.request<dynamic>(
      '/api/v1/requisitions/$requisitionId/evidences/$evidenceId/key-envelope',
      queryParameters: {'deviceId': deviceId},
      onSucces: (body) => body,
    );
    final body = _successBody(
      result,
      'No se pudo obtener la clave de la evidencia.',
    );
    final data = _asMap(_asMap(body)['response'])['data'];
    final envelope = _asMap(data);
    final wrappedKey = envelope['wrappedKey'];
    return wrappedKey is String && wrappedKey.isNotEmpty ? wrappedKey : null;
  }

  Future<void> addEnvelope({
    required String requisitionId,
    required String evidenceId,
    required String recipientId,
    required String wrappedKey,
    int keyVersion = EvidenceCryptoService.formatVersion,
  }) async {
    final result = await _http.request<dynamic>(
      '/api/v1/requisitions/$requisitionId/evidences/$evidenceId/key-envelopes',
      method: HttpMethod.post,
      headers: {
        'Idempotency-Key': _envelopeIdempotencyKey(
          evidenceId: evidenceId,
          recipientId: recipientId,
          wrappedKey: wrappedKey,
        ),
      },
      body: {
        'recipientType': 'DEVICE',
        'recipientId': recipientId,
        'wrapAlgorithm': EvidenceCryptoService.deviceKeyAlgorithm,
        'keyVersion': keyVersion,
        'wrappedKey': wrappedKey,
      },
      onSucces: (body) => body,
    );
    _throwIfError(result, 'No se pudo compartir la clave de la evidencia.');
  }

  Future<void> addRecoveryEnvelope({
    required String requisitionId,
    required String evidenceId,
    required EvidenceRecoveryKey recoveryKey,
    required String wrappedKey,
  }) async {
    final result = await _http.request<dynamic>(
      '/api/v1/requisitions/$requisitionId/evidences/$evidenceId/key-envelopes',
      method: HttpMethod.post,
      headers: {
        'Idempotency-Key': _envelopeIdempotencyKey(
          evidenceId: evidenceId,
          recipientId: recoveryKey.keyId,
          wrappedKey: wrappedKey,
        ),
      },
      body: {
        'recipientType': 'RECOVERY',
        'recipientId': recoveryKey.keyId,
        'wrapAlgorithm': recoveryKey.algorithm,
        'keyVersion': recoveryKey.version,
        'wrappedKey': wrappedKey,
      },
      onSucces: (body) => body,
    );
    _throwIfError(result, 'No se pudo guardar la clave de recuperación.');
  }

  Object? _successBody(Either<ErrorModel, dynamic> result, String message) {
    return switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? message,
      ),
      Right(rightValue: final body) => body,
      Either() => throw StateError(message),
    };
  }

  void _throwIfError(Either<ErrorModel, dynamic> result, String message) {
    _successBody(result, message);
  }

  String _envelopeIdempotencyKey({
    required String evidenceId,
    required String recipientId,
    required String wrappedKey,
  }) {
    final fingerprint = crypto.sha256
        .convert(utf8.encode(wrappedKey))
        .toString()
        .substring(0, 24);
    return '$evidenceId-$recipientId-$fingerprint';
  }

  Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  String get _platform {
    // El backend usa este campo para diagnóstico; la clave criptográfica no
    // depende de la plataforma.
    return 'FLUTTER';
  }
}

final class EvidenceEncryptionRecipient {
  const EvidenceEncryptionRecipient({
    required this.actorId,
    required this.deviceId,
    required this.publicKey,
    required this.keyVersion,
  });

  final String actorId;
  final String deviceId;
  final String publicKey;
  final int keyVersion;

  factory EvidenceEncryptionRecipient.fromMap(Map value) {
    return EvidenceEncryptionRecipient(
      actorId: value['actorId']?.toString() ?? '',
      deviceId: value['deviceId']?.toString() ?? '',
      publicKey: value['encryptionPublicKey']?.toString() ?? '',
      keyVersion:
          int.tryParse(value['encryptionKeyVersion']?.toString() ?? '') ?? 1,
    );
  }
}

final class EvidenceRecoveryKey {
  const EvidenceRecoveryKey({
    required this.keyId,
    required this.publicKey,
    required this.algorithm,
    required this.version,
  });

  final String keyId;
  final String publicKey;
  final String algorithm;
  final int version;

  static EvidenceRecoveryKey? fromMap(Map value) {
    final keyId = value['keyId']?.toString() ?? '';
    final publicKey = value['publicKey']?.toString() ?? '';
    final algorithm = value['algorithm']?.toString() ?? '';
    final version = int.tryParse(value['version']?.toString() ?? '');
    if (keyId.isEmpty ||
        publicKey.isEmpty ||
        algorithm.isEmpty ||
        version == null) {
      return null;
    }
    return EvidenceRecoveryKey(
      keyId: keyId,
      publicKey: publicKey,
      algorithm: algorithm,
      version: version,
    );
  }
}
