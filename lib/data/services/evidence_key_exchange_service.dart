import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/data/models/error_model.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';

/// Registra la clave pública del dispositivo y prepara una única clave
/// simétrica por requisa. Cada evidencia solo envuelve su DEK con esa clave,
/// por lo que el costo de subir no crece con la cantidad de dispositivos.
class EvidenceKeyExchangeService {
  EvidenceKeyExchangeService({
    required Http http,
    required EvidenceCryptoService crypto,
  }) : _http = http,
       _crypto = crypto;

  final Http _http;
  final EvidenceCryptoService _crypto;
  final Set<String> _registeredForRequisitions = <String>{};
  final Map<String, RequisitionKeyEnvelope> _keysByRequisition =
      <String, RequisitionKeyEnvelope>{};
  final Map<String, Future<RequisitionKeyEnvelope>> _keyRequests =
      <String, Future<RequisitionKeyEnvelope>>{};

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
        'platform': 'FLUTTER',
        'encryptionPublicKey': await _crypto.encryptionPublicKey(),
        'encryptionKeyAlgorithm': EvidenceCryptoService.deviceKeyAlgorithm,
        'encryptionKeyVersion': EvidenceCryptoService.formatVersion,
      },
      onSucces: (body) => body,
    );
    _successBody(result, 'No se pudo registrar el dispositivo de cifrado.');
    _registeredForRequisitions.add(requisitionId);
  }

  Future<RequisitionKeyEnvelope> requisitionKey(String requisitionId) async {
    final cached = _keysByRequisition[requisitionId];
    if (cached != null) return cached;
    final inFlight = _keyRequests[requisitionId];
    if (inFlight != null) return inFlight;
    final request = _loadRequisitionKey(requisitionId);
    _keyRequests[requisitionId] = request;
    try {
      return await request;
    } finally {
      if (identical(_keyRequests[requisitionId], request)) {
        _keyRequests.remove(requisitionId);
      }
    }
  }

  Future<RequisitionKeyEnvelope> _loadRequisitionKey(
    String requisitionId,
  ) async {
    await ensureRegistered(requisitionId);
    final deviceId = await _crypto.encryptionDeviceId;
    final result = await _http.request<dynamic>(
      '/api/v1/requisitions/$requisitionId/encryption/requisition-key',
      queryParameters: {'deviceId': deviceId},
      onSucces: (body) => body,
    );
    final response = _successBody(
      result,
      'No se pudo obtener la clave de la requisa.',
    );
    final envelope = RequisitionKeyEnvelope.fromMap(_responseData(response));
    if (envelope.recipientId != deviceId) {
      throw const FormatException(
        'La clave de requisa no corresponde al dispositivo actual.',
      );
    }
    await _crypto.cacheRequisitionKey(
      requisitionId: requisitionId,
      keyId: envelope.keyId,
      keyVersion: envelope.keyVersion,
      wrappedKey: envelope.wrappedKey,
    );
    _keysByRequisition[requisitionId] = envelope;
    return envelope;
  }

  Future<EvidenceKeyEnvelope?> getEnvelope({
    required String requisitionId,
    required String evidenceId,
  }) async {
    final requisitionEnvelope = await requisitionKey(requisitionId);
    final deviceId = await _crypto.encryptionDeviceId;
    final result = await _http.request<dynamic>(
      '/api/v1/requisitions/$requisitionId/evidences/$evidenceId/key-envelope',
      queryParameters: {'deviceId': deviceId},
      onSucces: (body) => body,
    );
    final response = _successBody(
      result,
      'No se pudo obtener la clave de la evidencia.',
    );
    final data = _responseData(response);
    if (data.isEmpty) return null;
    final envelope = EvidenceKeyEnvelope.fromMap(data);
    if (envelope.requisitionKeyId != requisitionEnvelope.keyId ||
        envelope.requisitionKeyVersion != requisitionEnvelope.keyVersion) {
      throw StateError(
        'La evidencia usa una versión de clave de requisa no disponible.',
      );
    }
    return envelope;
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

  Map<String, dynamic> _responseData(Object? body) {
    final response = _asMap(_asMap(body)['response']);
    return _asMap(response['data']);
  }

  Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}

final class RequisitionKeyEnvelope {
  const RequisitionKeyEnvelope({
    required this.keyId,
    required this.keyVersion,
    required this.algorithm,
    required this.recipientId,
    required this.wrappedKey,
  });

  final String keyId;
  final int keyVersion;
  final String algorithm;
  final String recipientId;
  final String wrappedKey;

  factory RequisitionKeyEnvelope.fromMap(Map value) {
    final keyId = value['requisitionKeyId']?.toString() ?? '';
    final keyVersion =
        int.tryParse(value['requisitionKeyVersion']?.toString() ?? '') ?? 0;
    final algorithm = value['requisitionKeyAlgorithm']?.toString() ?? '';
    final recipientType = value['recipientType']?.toString() ?? '';
    final recipientId = value['recipientId']?.toString() ?? '';
    final wrapAlgorithm = value['wrapAlgorithm']?.toString() ?? '';
    final wrappedKey = value['wrappedKey']?.toString() ?? '';
    if (keyId.isEmpty ||
        keyVersion <= 0 ||
        algorithm != EvidenceCryptoService.requisitionKeyAlgorithm ||
        recipientType != 'DEVICE' ||
        recipientId.isEmpty ||
        wrapAlgorithm != EvidenceCryptoService.deviceKeyAlgorithm ||
        wrappedKey.isEmpty) {
      throw const FormatException(
        'La API devolvió una clave de requisa incompleta.',
      );
    }
    return RequisitionKeyEnvelope(
      keyId: keyId,
      keyVersion: keyVersion,
      algorithm: algorithm,
      recipientId: recipientId,
      wrappedKey: wrappedKey,
    );
  }
}

final class EvidenceKeyEnvelope {
  const EvidenceKeyEnvelope({
    required this.requisitionKeyId,
    required this.requisitionKeyVersion,
    required this.wrapAlgorithm,
    required this.wrappedKey,
  });

  final String requisitionKeyId;
  final int requisitionKeyVersion;
  final String wrapAlgorithm;
  final String wrappedKey;

  factory EvidenceKeyEnvelope.fromMap(Map value) {
    final keyId = value['recipientId']?.toString() ?? '';
    final keyVersion = int.tryParse(value['keyVersion']?.toString() ?? '') ?? 0;
    final wrapAlgorithm = value['wrapAlgorithm']?.toString() ?? '';
    final wrappedKey = value['wrappedKey']?.toString() ?? '';
    if (keyId.isEmpty ||
        keyVersion <= 0 ||
        wrapAlgorithm != EvidenceCryptoService.requisitionKeyWrapAlgorithm ||
        wrappedKey.isEmpty) {
      throw const FormatException(
        'La API devolvió una envoltura de evidencia incompleta.',
      );
    }
    return EvidenceKeyEnvelope(
      requisitionKeyId: keyId,
      requisitionKeyVersion: keyVersion,
      wrapAlgorithm: wrapAlgorithm,
      wrappedKey: wrappedKey,
    );
  }
}
