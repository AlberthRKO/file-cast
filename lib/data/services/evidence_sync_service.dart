import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/core/notifications/local_notification_service.dart';
import 'package:file_cast/data/services/evidence_background_sync_service.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/evidence_key_exchange_service.dart';
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
    required EvidenceKeyExchangeService keyExchange,
    LocalNotificationService? notifications,
    EvidenceBackgroundSyncService? backgroundScheduler,
  }) : _http = http,
       _database = database,
       _crypto = crypto,
       _keyExchange = keyExchange,
       _notifications = notifications,
       _backgroundScheduler = backgroundScheduler;

  final Http _http;
  final LocalEvidenceDatabaseService _database;
  final EvidenceCryptoService _crypto;
  final EvidenceKeyExchangeService _keyExchange;
  final LocalNotificationService? _notifications;
  final EvidenceBackgroundSyncService? _backgroundScheduler;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<String> _changesController =
      StreamController<String>.broadcast();
  final StreamController<EvidenceUploadProgress> _progressController =
      StreamController<EvidenceUploadProgress>.broadcast();
  final Random _random = Random.secure();
  final Map<String, int> _activeUploadTotals = <String, int>{};
  final Map<String, String> _activeEvidenceRequisitions = <String, String>{};
  final Set<String> _cancelledRequisitions = <String>{};
  Future<int>? _activeRun;
  bool _runAgainWhenIdle = false;

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
    unawaited(_scheduleAndTriggerInitialSync());
  }

  Future<void> _scheduleAndTriggerInitialSync() async {
    await _triggerSync();
    await scheduleBackgroundSync();
  }

  /// Registra el trabajo persistente después de crear una evidencia. El
  /// registro es idempotente y `keep` evita duplicar workers para la outbox.
  Future<void> scheduleBackgroundSync() async {
    try {
      if ((await _database.pending(limit: 1, automaticOnly: true)).isEmpty) {
        await _notifications?.cancelJobId('UPLOAD');
        return;
      }
      await _backgroundScheduler?.scheduleUpload();
    } on Object {
      // La outbox y el listener de conectividad siguen siendo el fallback
      // cuando el scheduler no está disponible en el dispositivo.
    }
  }

  Future<void> _triggerSync() async {
    try {
      // Los errores permanentes (por ejemplo HTTP 413) solo se reintentan
      // cuando el usuario pulsa la acción explícita de reintento.
      await syncPendingInForeground();
    } catch (_) {
      // La evidencia permanece en la outbox para el siguiente intento.
    }
  }

  /// El isolate visible toma propiedad de la outbox antes de iniciar. Si ya
  /// había un worker programado, se cancela para que no existan dos motores
  /// subiendo archivos distintos y publicando estados contradictorios.
  Future<int> syncPendingInForeground({
    String? requisitionId,
    String? evidenceId,
  }) async {
    try {
      await _backgroundScheduler?.cancelUpload();
    } on Object {
      // La outbox sigue protegida por claim atómico si la plataforma no puede
      // cancelar un worker que ya estaba finalizando.
    }
    try {
      await _notifications?.cancelJobId('UPLOAD');
    } on Object {
      // Limpiar el aviso no condiciona el intento de subida.
    }
    return syncPending(
      includeNonRetryable: false,
      requisitionId: requisitionId,
      evidenceId: evidenceId,
    );
  }

  Future<int> syncPending({
    int limit = 1,
    bool includeNonRetryable = false,
    String? requisitionId,
    String? evidenceId,
  }) {
    final activeRun = _activeRun;
    if (activeRun != null) {
      // La sincronización inicial puede estar consultando la outbox mientras
      // el usuario termina de cifrar una nueva selección. No descartamos esa
      // solicitud: ejecutamos otro ciclo al liberar el actual.
      _runAgainWhenIdle = true;
      return activeRun;
    }
    final run = _syncPendingSafely(
      limit: limit,
      includeNonRetryable: includeNonRetryable,
      requisitionId: requisitionId,
      evidenceId: evidenceId,
    );
    _activeRun = run;
    run.then<void>(
      (_) {
        var queuedRunStarted = false;
        if (identical(_activeRun, run)) {
          _activeRun = null;
          _cancelledRequisitions.clear();
          queuedRunStarted = _startQueuedRunIfNeeded();
        }
        if (!queuedRunStarted) unawaited(_scheduleIfPending());
      },
      onError: (Object _, StackTrace __) {
        var queuedRunStarted = false;
        if (identical(_activeRun, run)) {
          _activeRun = null;
          _cancelledRequisitions.clear();
          queuedRunStarted = _startQueuedRunIfNeeded();
        }
        if (!queuedRunStarted) unawaited(_scheduleIfPending());
      },
    );
    return run;
  }

  Future<void> cancelPendingEvidence({required String requisitionId}) async {
    final normalizedId = requisitionId.trim();
    if (normalizedId.isEmpty) return;
    _cancelledRequisitions.add(normalizedId);
    _runAgainWhenIdle = false;
    try {
      await _backgroundScheduler?.cancelUpload();
      await _notifications?.cancelJobId('UPLOAD');
      await _notifications?.cancelJob(
        operation: EvidenceJobOperation.upload,
        requisitionId: normalizedId,
      );
      await _database.pausePendingForRequisition(normalizedId);
      _publishChanges([normalizedId]);
    } finally {
      if (_activeRun == null) _cancelledRequisitions.remove(normalizedId);
    }
  }

  Future<int> retryPendingEvidence({required String requisitionId}) async {
    final normalizedId = requisitionId.trim();
    if (normalizedId.isEmpty) return 0;
    _cancelledRequisitions.remove(normalizedId);
    await _database.resumePendingForRequisition(normalizedId);
    _publishChanges([normalizedId]);
    return syncPendingInForeground(requisitionId: normalizedId);
  }

  /// Reintenta una sola evidencia. Si existía una carga global, la pausa de
  /// forma segura, espera la confirmación HTTP que ya estuviera en curso y
  /// conserva pausados los demás archivos de la requisa.
  Future<bool> retryEvidence({
    required String requisitionId,
    required String evidenceId,
  }) async {
    final normalizedRequisitionId = requisitionId.trim();
    final normalizedEvidenceId = evidenceId.trim();
    if (normalizedRequisitionId.isEmpty || normalizedEvidenceId.isEmpty) {
      return false;
    }

    await cancelPendingEvidence(requisitionId: normalizedRequisitionId);
    final running = _activeRun;
    if (running != null) {
      try {
        await running;
      } on Object {
        // La fila conserva el error y se reactiva explícitamente debajo.
      }
      await Future<void>.delayed(Duration.zero);
    }

    _cancelledRequisitions.remove(normalizedRequisitionId);
    await _database.resumeEvidenceForUpload(
      requisitionId: normalizedRequisitionId,
      evidenceId: normalizedEvidenceId,
    );
    _publishChanges([normalizedRequisitionId]);
    final synchronized = await syncPendingInForeground(
      requisitionId: normalizedRequisitionId,
      evidenceId: normalizedEvidenceId,
    );
    if (synchronized > 0) return true;

    final records = await _database.forRequisition(normalizedRequisitionId);
    return records.any(
      (record) =>
          record.id == normalizedEvidenceId &&
          record.state.toUpperCase() == 'SINCRONIZADA',
    );
  }

  Future<int> _syncPendingSafely({
    required int limit,
    required bool includeNonRetryable,
    String? requisitionId,
    String? evidenceId,
  }) async {
    try {
      return await _syncAllPending(
        limit: limit,
        includeNonRetryable: includeNonRetryable,
        requisitionId: requisitionId,
        evidenceId: evidenceId,
      );
    } catch (error) {
      await _releaseActiveClaims(error);
      // Un fallo al reservar el lote (por ejemplo, una base local que estaba
      // cerrándose) no debe dejar una notificación `ongoing` sin un estado
      // final. Publicamos el error y luego conservamos la excepción para que
      // el worker pueda reintentar según su política.
      await _emitTerminalFailure(error, automaticOnly: !includeNonRetryable);
      rethrow;
    }
  }

  Future<void> _releaseActiveClaims(Object error) async {
    if (_activeEvidenceRequisitions.isEmpty) return;
    final message = _safeMessage(error);
    final claimed = Map<String, String>.from(_activeEvidenceRequisitions);
    for (final evidenceId in claimed.keys) {
      try {
        await _database.markError(
          evidenceId,
          message,
          retryable: _isRetryableError(message),
        );
      } on Object {
        // Si la base también está ocupada, la reclamación caduca y el próximo
        // ciclo la recupera como ERROR. Nunca se deja un estado SUBIENDO como
        // estado terminal de la aplicación.
      }
    }
    for (final requisitionId in claimed.values.toSet()) {
      if (!_changesController.isClosed) {
        _changesController.add(requisitionId);
      }
    }
    _activeEvidenceRequisitions.clear();
  }

  Future<void> _emitTerminalFailure(
    Object error, {
    required bool automaticOnly,
  }) async {
    final totals = <String, int>{..._activeUploadTotals};
    try {
      final pending = await _database.pending(
        limit: 5000,
        automaticOnly: automaticOnly,
      );
      final pendingByRequisition = <String, int>{};
      for (final evidence in pending) {
        pendingByRequisition.update(
          evidence.requisitionId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      for (final entry in pendingByRequisition.entries) {
        totals.update(
          entry.key,
          (value) => value > entry.value ? value : entry.value,
          ifAbsent: () => entry.value,
        );
      }
    } on Object {
      // El error original es más útil que un segundo fallo de diagnóstico.
    }
    if (totals.isEmpty) return;
    final message = _safeMessage(error);
    for (final entry in totals.entries) {
      _emitProgress(
        requisitionId: entry.key,
        total: entry.value,
        completed: 0,
        failed: entry.value,
        stage: EvidenceUploadStage.error,
        isActive: false,
        errorMessage: message,
      );
      await _notifications?.cancelJob(
        operation: EvidenceJobOperation.upload,
        requisitionId: entry.key,
      );
    }
    _activeUploadTotals.clear();
  }

  Future<void> _scheduleIfPending() async {
    try {
      if ((await _database.pending(limit: 1, automaticOnly: true)).isNotEmpty) {
        await scheduleBackgroundSync();
      }
    } on Object {
      // La sincronización de primer plano ya terminó; la outbox y el listener
      // de conectividad siguen siendo la fuente de reintento.
    }
  }

  bool _startQueuedRunIfNeeded() {
    if (!_runAgainWhenIdle) return false;
    _runAgainWhenIdle = false;
    unawaited(_triggerSync());
    return true;
  }

  Future<int> _syncAllPending({
    required int limit,
    required bool includeNonRetryable,
    String? requisitionId,
    String? evidenceId,
  }) async {
    var synchronized = 0;
    final attempted = <String>{};
    while (true) {
      final pending = await _database.claimPending(
        limit: limit,
        automaticOnly: !includeNonRetryable,
        requisitionId: requisitionId,
        evidenceId: evidenceId,
        excludedEvidenceIds: attempted,
      );
      if (pending.isEmpty) return synchronized;
      attempted.addAll(pending.map((evidence) => evidence.id));
      final cancelledRequisitions = pending
          .map((evidence) => evidence.requisitionId)
          .where(_cancelledRequisitions.contains)
          .toSet();
      for (final requisitionId in cancelledRequisitions) {
        await _database.pausePendingForRequisition(requisitionId);
      }
      final activePending = pending
          .where(
            (evidence) =>
                !_cancelledRequisitions.contains(evidence.requisitionId),
          )
          .toList(growable: false);
      _publishChanges(cancelledRequisitions);
      if (activePending.isEmpty) continue;
      _publishChanges(activePending.map((evidence) => evidence.requisitionId));
      final processed = await _syncPending(pending: activePending);
      synchronized += processed;
    }
  }

  Future<int> _syncPending({required List<LocalEvidenceRecord> pending}) async {
    if (pending.isEmpty) return 0;

    _activeEvidenceRequisitions.addAll({
      for (final evidence in pending) evidence.id: evidence.requisitionId,
    });

    final totals = <String, int>{};
    for (final evidence in pending) {
      totals.update(
        evidence.requisitionId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    _activeUploadTotals
      ..clear()
      ..addAll(totals);
    final completed = <String, int>{};
    final failed = <String, int>{};
    final errors = <String, String>{};
    var synchronized = 0;
    for (final evidence in pending) {
      if (_cancelledRequisitions.contains(evidence.requisitionId)) {
        await _database.pausePendingForRequisition(evidence.requisitionId);
        continue;
      }
      _emitProgress(
        requisitionId: evidence.requisitionId,
        total: totals[evidence.requisitionId]!,
        completed: completed[evidence.requisitionId] ?? 0,
        failed: failed[evidence.requisitionId] ?? 0,
        stage: EvidenceUploadStage.preparing,
        isActive: true,
        currentFileName: evidence.originalName,
      );
      try {
        final remoteId = await _syncOne(
          evidence,
          onReadyToUpload: () {
            _emitProgress(
              requisitionId: evidence.requisitionId,
              total: totals[evidence.requisitionId]!,
              completed: completed[evidence.requisitionId] ?? 0,
              failed: failed[evidence.requisitionId] ?? 0,
              stage: EvidenceUploadStage.uploading,
              isActive: true,
              currentFileName: evidence.originalName,
            );
          },
        );
        // Una petición HTTP en curso no se puede deshacer con seguridad. Si
        // el servidor ya confirmó el archivo, persistimos esa confirmación y
        // pausamos únicamente los siguientes; así un reintento no lo duplica.
        await _database.markUploaded(evidence.id, remoteId);
        completed.update(
          evidence.requisitionId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        synchronized += 1;
        if (_cancelledRequisitions.contains(evidence.requisitionId)) {
          await _database.pausePendingForRequisition(evidence.requisitionId);
        }
      } catch (error) {
        if (_cancelledRequisitions.contains(evidence.requisitionId)) {
          await _database.pausePendingForRequisition(evidence.requisitionId);
          continue;
        }
        final message = _safeMessage(error);
        await _database.markError(
          evidence.id,
          message,
          retryable: _isRetryableError(message),
        );
        errors[evidence.requisitionId] = message;
        failed.update(
          evidence.requisitionId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    for (final requisitionId in totals.keys) {
      if (_cancelledRequisitions.contains(requisitionId)) {
        await _notifications?.cancelJob(
          operation: EvidenceJobOperation.upload,
          requisitionId: requisitionId,
        );
        if (!_changesController.isClosed) {
          _changesController.add(requisitionId);
        }
        continue;
      }
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
            : failedCount > 0
            ? EvidenceUploadStage.error
            : EvidenceUploadStage.completed,
        isActive: false,
        errorMessage: errors[requisitionId],
      );
      // Espera la actualización/cancelación encolada antes de permitir que el
      // isolate de WorkManager finalice. De otro modo Android podía conservar
      // el aviso por requisa aunque el worker global ya hubiera terminado.
      await _notifications?.cancelJob(
        operation: EvidenceJobOperation.upload,
        requisitionId: requisitionId,
      );
      if (!_changesController.isClosed) {
        _changesController.add(requisitionId);
      }
    }
    _activeUploadTotals.clear();
    _activeEvidenceRequisitions.removeWhere(
      (evidenceId, _) => pending.any((evidence) => evidence.id == evidenceId),
    );
    return synchronized;
  }

  void _publishChanges(Iterable<String> requisitionIds) {
    if (_changesController.isClosed) return;
    for (final requisitionId in requisitionIds.toSet()) {
      _changesController.add(requisitionId);
    }
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
    String? errorMessage,
  }) {
    if (!_progressController.isClosed) {
      _progressController.add(
        EvidenceUploadProgress(
          requisitionId: requisitionId,
          total: total,
          completed: completed,
          failed: failed,
          stage: stage,
          isActive: isActive,
          currentFileName: currentFileName,
          errorMessage: errorMessage,
        ),
      );
    }
    final notifications = _notifications;
    if (notifications != null) {
      unawaited(
        notifications
            .showUploadProgress(
              requisitionId: requisitionId,
              total: total,
              processed: completed + failed,
              active: isActive,
              hasFailures: failed > 0,
            )
            .catchError((_) {}),
      );
    }
  }

  Future<String> _syncOne(
    LocalEvidenceRecord evidence, {
    void Function()? onReadyToUpload,
  }) async {
    final requisitionKey = await _keyExchange.requisitionKey(
      evidence.requisitionId,
    );
    final requisitionWrappedKey = await _crypto.wrapLocalDataKeyForRequisition(
      wrappedKey: evidence.wrappedKey,
      evidenceId: evidence.id,
      requisitionId: evidence.requisitionId,
      requisitionKeyId: requisitionKey.keyId,
      requisitionKeyVersion: requisitionKey.keyVersion,
    );
    onReadyToUpload?.call();
    final intent = await _http.request<dynamic>(
      '/api/v1/requisitions/${evidence.requisitionId}/evidence-intents',
      method: HttpMethod.post,
      headers: {'Idempotency-Key': _intentIdempotencyKey(evidence.id)},
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
          'recipientType': 'REQUISITION_KEY',
          'recipientId': requisitionKey.keyId,
          'wrapAlgorithm': EvidenceCryptoService.requisitionKeyWrapAlgorithm,
          'keyVersion': requisitionKey.keyVersion,
          'wrappedKey': requisitionWrappedKey,
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
    // Las envolturas ya se guardaron atómicamente al crear la intención. El
    // endpoint `key-envelopes` queda reservado para reparar o agregar una
    // envoltura después; repetirlo aquí hacía 7 peticiones extra por archivo.
    return remoteId;
  }

  /// Las envolturas AES-GCM se generan con aleatoriedad. Si se reutiliza la
  /// misma clave de idempotencia después de un fallo de upload, el body de la
  /// intención cambia y el backend correctamente lo rechaza como conflicto.
  /// La evidencia se mantiene idempotente por su id y hash en el backend, por
  /// lo que cada intento de registrar una intención usa una clave nueva.
  String _intentIdempotencyKey(String evidenceId) {
    final suffix = _random.nextInt(0x7fffffff).toRadixString(36);
    return 'evidence-intent-$evidenceId-${DateTime.now().microsecondsSinceEpoch}-$suffix';
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
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    final normalized = message.toLowerCase();
    if (normalized.contains('timeout') ||
        normalized.contains('bloqueo de sincronización local')) {
      return 'La sincronización local está ocupada. Se reintentará automáticamente.';
    }
    return message.length > 512 ? message.substring(0, 512) : message;
  }

  bool _isRetryableError(String message) {
    final normalized = message.toLowerCase();
    return !normalized.contains('http 413') &&
        !normalized.contains('límite de carga') &&
        !normalized.contains('tamaño máximo configurado') &&
        !normalized.contains('supera el tamaño permitido');
  }
}
