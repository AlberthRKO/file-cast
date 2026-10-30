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
  final Map<String, List<EvidenceEncryptionRecipient>>
  _recipientsByRequisition = <String, List<EvidenceEncryptionRecipient>>{};
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
      await syncPending(includeNonRetryable: false);
    } catch (_) {
      // La evidencia permanece en la outbox para el siguiente intento.
    }
  }

  Future<int> syncPending({
    int limit = 50,
    bool includeNonRetryable = true,
  }) {
    final activeRun = _activeRun;
    if (activeRun != null) {
      // La sincronización inicial puede estar consultando la outbox mientras
      // el usuario termina de cifrar una nueva selección. No descartamos esa
      // solicitud: ejecutamos otro ciclo al liberar el actual.
      _runAgainWhenIdle = true;
      return activeRun;
    }
    final run = _database.withSyncLock(
      () => _syncAllPending(
        limit: limit,
        includeNonRetryable: includeNonRetryable,
      ),
    );
    _activeRun = run;
    run.then<void>(
      (_) {
        _recipientsByRequisition.clear();
        if (identical(_activeRun, run)) {
          _activeRun = null;
          _startQueuedRunIfNeeded();
        }
        unawaited(_scheduleIfPending());
      },
      onError: (Object _, StackTrace __) {
        _recipientsByRequisition.clear();
        if (identical(_activeRun, run)) {
          _activeRun = null;
          _startQueuedRunIfNeeded();
        }
        unawaited(_scheduleIfPending());
      },
    );
    return run;
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

  void _startQueuedRunIfNeeded() {
    if (!_runAgainWhenIdle) return;
    _runAgainWhenIdle = false;
    unawaited(_triggerSync());
  }

  Future<int> _syncAllPending({
    required int limit,
    required bool includeNonRetryable,
  }) async {
    var synchronized = 0;
    final attempted = <String>{};
    while (true) {
      final pending =
          (await _database.pending(
                limit: limit,
                automaticOnly: !includeNonRetryable,
              ))
              .where((evidence) => !attempted.contains(evidence.id))
              .toList(growable: false);
      if (pending.isEmpty) return synchronized;
      attempted.addAll(pending.map((evidence) => evidence.id));
      final processed = await _syncPending(pending: pending);
      synchronized += processed;
    }
  }

  Future<int> _syncPending({required List<LocalEvidenceRecord> pending}) async {
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
    final errors = <String, String>{};
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
        errorMessage: errors[requisitionId],
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

  Future<String> _syncOne(LocalEvidenceRecord evidence) async {
    await _keyExchange.ensureRegistered(evidence.requisitionId);
    final recipients = await _recipientsFor(evidence.requisitionId);
    final currentDeviceId = await _crypto.encryptionDeviceId;
    final shareableRecipients = recipients
        .where((recipient) => recipient.publicKey.isNotEmpty)
        .toList(growable: false);
    final recoveryKey = await _keyExchange.recoveryKey(evidence.requisitionId);
    if (recoveryKey == null) {
      throw StateError(
        'La recuperación institucional no está configurada. La evidencia queda pendiente para evitar una pérdida de acceso.',
      );
    }
    final wrappedKeys = await _crypto.wrapLocalDataKeyForRecipients(
      wrappedKey: evidence.wrappedKey,
      evidenceId: evidence.id,
      recipientPublicKeys: [
        ...shareableRecipients.map((recipient) => recipient.publicKey),
        recoveryKey.publicKey,
      ],
    );
    final keyEnvelopes = <Map<String, dynamic>>[];
    for (var index = 0; index < shareableRecipients.length; index++) {
      final wrappedKey = wrappedKeys[index];
      if (wrappedKey == null) continue;
      final recipient = shareableRecipients[index];
      keyEnvelopes.add({
        'recipientType': 'DEVICE',
        'recipientId': recipient.deviceId,
        'wrapAlgorithm': EvidenceCryptoService.deviceKeyAlgorithm,
        'keyVersion': recipient.keyVersion,
        'wrappedKey': wrappedKey,
      });
    }
    final recoveryWrappedKey = wrappedKeys[shareableRecipients.length];
    if (recoveryWrappedKey == null) {
      throw StateError(
        'No se pudo preparar la envoltura de recuperación institucional.',
      );
    }
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
        if (keyEnvelopes.isNotEmpty)
          'keyEnvelopes': keyEnvelopes
        else
          'keyEnvelope': {
            'recipientType': 'DEVICE',
            'recipientId': currentDeviceId,
            'wrapAlgorithm': EvidenceCryptoService.localKeyWrapAlgorithm,
            'keyVersion': evidence.keyVersion,
            'wrappedKey': evidence.wrappedKey,
          },
        if (recoveryKey != null && recoveryWrappedKey != null)
          'recoveryEnvelope': {
            'recipientType': 'RECOVERY',
            'recipientId': recoveryKey.keyId,
            'wrapAlgorithm': recoveryKey.algorithm,
            'keyVersion': recoveryKey.version,
            'wrappedKey': recoveryWrappedKey,
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

  Future<List<EvidenceEncryptionRecipient>> _recipientsFor(
    String requisitionId,
  ) async {
    final cached = _recipientsByRequisition[requisitionId];
    if (cached != null) return cached;
    final recipients = await _keyExchange.recipients(requisitionId);
    _recipientsByRequisition[requisitionId] = recipients;
    return recipients;
  }

  /// Las envolturas X25519 se generan con aleatoriedad. Si se reutiliza la
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
