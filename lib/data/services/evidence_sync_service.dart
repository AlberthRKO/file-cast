import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/domain/models/evidence_upload_progress.dart';
import 'package:http/http.dart' as http;

/// Consume la outbox local cuando existe conectividad.
/// Si no hay red, deja el registro pendiente para el siguiente intento.
class EvidenceSyncService {
  EvidenceSyncService({
    required Http http,
    required LocalEvidenceDatabaseService database,
    required EvidenceCryptoService crypto,
  }) : _http = http,
       _database = database,
       _crypto = crypto;

  final Http _http;
  final LocalEvidenceDatabaseService _database;
  final EvidenceCryptoService _crypto;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<String> _changesController =
      StreamController<String>.broadcast();
  final StreamController<EvidenceUploadProgress> _progressController =
      StreamController<EvidenceUploadProgress>.broadcast();
  Future<int>? _activeRun;

  Stream<String> get changes => _changesController.stream;
  Stream<EvidenceUploadProgress> get progress => _progressController.stream;

  void start() {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(_triggerSync());
      }
    });
    unawaited(_triggerSync());
  }

  Future<void> _triggerSync() async {
    try {
      await syncPending();
    } catch (_) {
      // La evidencia permanece en la outbox para el siguiente intento.
    }
  }

  Future<int> syncPending({int limit = 50}) {
    final activeRun = _activeRun;
    if (activeRun != null) return activeRun;
    final run = _syncPending(limit: limit);
    _activeRun = run;
    run.then<void>(
      (_) {
        if (identical(_activeRun, run)) _activeRun = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(_activeRun, run)) _activeRun = null;
      },
    );
    return run;
  }

  Future<int> _syncPending({required int limit}) async {
    final pending = await _database.pending(limit: limit);
    if (pending.isEmpty) return 0;

    final totals = <String, int>{};
    for (final evidence in pending) {
      totals.update(
        evidence.requisitionId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final completed = <String, int>{};
    final failed = <String, int>{};
    var synchronized = 0;
    for (final evidence in pending) {
      _emitProgress(
        requisitionId: evidence.requisitionId,
        total: totals[evidence.requisitionId]!,
        completed: completed[evidence.requisitionId] ?? 0,
        failed: failed[evidence.requisitionId] ?? 0,
        stage: EvidenceUploadStage.uploading,
        isActive: true,
        currentFileName: evidence.originalName,
      );
      try {
        final remoteId = await _syncOne(evidence);
        await _database.markUploaded(evidence.id, remoteId);
        completed.update(
          evidence.requisitionId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        synchronized += 1;
      } catch (error) {
        await _database.markError(evidence.id, _safeMessage(error));
        failed.update(
          evidence.requisitionId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    for (final requisitionId in totals.keys) {
      final total = totals[requisitionId]!;
      final completedCount = completed[requisitionId] ?? 0;
      final failedCount = failed[requisitionId] ?? 0;
      _emitProgress(
        requisitionId: requisitionId,
        total: total,
        completed: completedCount,
        failed: failedCount,
        stage: failedCount == total
            ? EvidenceUploadStage.error
            : EvidenceUploadStage.completed,
        isActive: false,
      );
      if (!_changesController.isClosed) {
        _changesController.add(requisitionId);
      }
    }
    return synchronized;
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _changesController.close();
    await _progressController.close();
  }

  void _emitProgress({
    required String requisitionId,
    required int total,
    required int completed,
    required int failed,
    required EvidenceUploadStage stage,
    required bool isActive,
    String? currentFileName,
  }) {
    if (_progressController.isClosed) return;
    _progressController.add(
      EvidenceUploadProgress(
        requisitionId: requisitionId,
        total: total,
        completed: completed,
        failed: failed,
        stage: stage,
        isActive: isActive,
        currentFileName: currentFileName,
      ),
    );
  }

  Future<String> _syncOne(LocalEvidenceRecord evidence) async {
    final intent = await _http.request<dynamic>(
      '/api/v1/requisitions/${evidence.requisitionId}/evidence-intents',
      method: HttpMethod.post,
      headers: {'Idempotency-Key': evidence.clientOperationId},
      body: {
        'id': evidence.id,
        'sessionId': evidence.sessionId,
        'originalName': evidence.originalName,
        'mimeType': evidence.mimeType,
        'extension': 'fce',
        'byteLength': evidence.ciphertextByteLength,
        'sha256': evidence.ciphertextSha256,
        'encrypted': true,
        'encryptionAlgorithm': evidence.encryptionAlgorithm,
        'encryptionVersion': evidence.encryptionVersion,
        'plaintextByteLength': evidence.plaintextByteLength,
        'plaintextSha256': evidence.plaintextSha256,
        'ciphertextSha256': evidence.ciphertextSha256,
        'aadHash': evidence.aadHash,
        'keyEnvelope': {
          'recipientType': 'DEVICE',
          'recipientId': await _crypto.deviceId,
          'wrapAlgorithm': 'AES-256-GCM-LOCAL-VAULT',
          'keyVersion': evidence.keyVersion,
          'wrappedKey': evidence.wrappedKey,
        },
        'kind': evidence.type,
        'acquisitionMethod': evidence.acquisitionMethod,
        'sourcePath': evidence.sourcePath,
        'capturedAt': evidence.createdAt.toUtc().toIso8601String(),
        'isOriginal': true,
      },
      onSucces: (body) => body,
    );
    final intentBody = switch (intent) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo registrar la evidencia.',
      ),
      Right(rightValue: final body) => body,
      Either() => throw StateError(
        'Respuesta inesperada al registrar la evidencia.',
      ),
    };
    if (intentBody == null)
      throw StateError('La API no devolvió una intención.');

    final upload = await _http.multipartRequest<dynamic>(
      '/api/v1/requisitions/${evidence.requisitionId}/evidences/upload',
      headers: {'Idempotency-Key': evidence.clientOperationId},
      queryParameters: {
        'evidenceId': evidence.id,
        'sessionId': evidence.sessionId,
        'kind': evidence.type,
        'acquisitionMethod': evidence.acquisitionMethod,
      },
      files: await Http.multipartFileFromPath(
        field: 'file',
        filePath: evidence.encryptedPath,
        filename: '${evidence.originalName}.fce',
        contentType: http.MediaType('application', 'vnd.file-cast.encrypted'),
      ),
      onSuccess: (body) => body,
    );
    final uploadBody = switch (upload) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo subir la evidencia.',
      ),
      Right(rightValue: final body) => body,
      Either() => throw StateError(
        'Respuesta inesperada al subir la evidencia.',
      ),
    };
    final remoteId = _findString(uploadBody, const [
      'msFileId',
      'fileId',
      'id',
      '_id',
    ]);
    if (remoteId == null) throw StateError('La API no devolvió el msFileId.');
    return remoteId;
  }

  String? _findString(Object? value, List<String> keys) {
    if (value is String && value.isNotEmpty) return value;
    if (value is List) {
      for (final item in value) {
        final found = _findString(item, keys);
        if (found != null) return found;
      }
    }
    if (value is Map) {
      for (final key in keys) {
        final direct = value[key];
        if (direct is String && direct.isNotEmpty) return direct;
      }
      for (final key in const ['response', 'data']) {
        final found = _findString(value[key], keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  String _safeMessage(Object error) {
    final message = error.toString();
    return message.length > 512 ? message.substring(0, 512) : message;
  }
}
