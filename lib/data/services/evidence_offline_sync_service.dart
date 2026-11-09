import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/core/notifications/local_notification_service.dart';
import 'package:file_cast/data/services/evidence_background_sync_service.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/evidence_key_exchange_service.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/domain/models/evidence_offline_sync.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';

/// Recupera los FCE disponibles en el servidor y reconstruye la copia local.
///
/// Esta cola no sube evidencias. El resultado se guarda directamente como
/// SINCRONIZADA en la base local, sin crear una operación de outbox pendiente.
class EvidenceOfflineSyncService {
  EvidenceOfflineSyncService({
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
  final StreamController<EvidenceOfflineSyncProgress> _progressController =
      StreamController<EvidenceOfflineSyncProgress>.broadcast();
  final Map<String, Future<EvidenceOfflineSyncResult>> _activeRuns = {};

  Stream<EvidenceOfflineSyncProgress> get progress =>
      _progressController.stream;

  Future<EvidenceOfflineSyncResult> syncRequisition({
    required String requisitionId,
    required List<RequisitionEvidence> evidence,
    bool scheduleBackgroundOnFailure = true,
  }) async {
    final active = _activeRuns[requisitionId];
    if (active != null) return await active;

    // Una ejecución manual toma el control de la requisa. Si el intento
    // anterior registró un worker de WorkManager, cancelarlo evita que ambos
    // engines descarguen y abran la misma base cifrada al mismo tiempo.
    if (scheduleBackgroundOnFailure) {
      await _cancelScheduledBackgroundSync(requisitionId);
    }
    // Elimina un aviso foreground que pudo quedar de un worker detenido antes
    // de publicar su estado final. La nueva ejecución volverá a mostrar el
    // progreso con el mismo ID estable.
    try {
      await _notifications?.cancelJobId('OFFLINE_SYNC:$requisitionId');
    } on Object {
      // La sincronización manual no depende de limpiar la notificación.
    }

    final run = _syncRequisitionSafely(
      requisitionId: requisitionId,
      evidence: evidence,
    );
    _activeRuns[requisitionId] = run;
    run.then<void>(
      (result) {
        if (identical(_activeRuns[requisitionId], run)) {
          _activeRuns.remove(requisitionId);
        }
        if (scheduleBackgroundOnFailure && _hasRetryableFailures(result)) {
          unawaited(_scheduleBackgroundSync(requisitionId));
        }
      },
      onError: (Object _, StackTrace _) {
        if (identical(_activeRuns[requisitionId], run)) {
          _activeRuns.remove(requisitionId);
        }
        if (scheduleBackgroundOnFailure) {
          unawaited(_scheduleBackgroundSync(requisitionId));
        }
      },
    );
    return await run;
  }

  Future<EvidenceOfflineSyncResult> _syncRequisitionSafely({
    required String requisitionId,
    required List<RequisitionEvidence> evidence,
  }) async {
    try {
      return await _syncRequisition(
        requisitionId: requisitionId,
        evidence: evidence,
      );
    } catch (error) {
      // La recuperación offline hace red, descifrado y escritura de archivos.
      // No debe conservar el lock global durante todo ese trabajo. Si una
      // operación local falla antes de publicar su estado final, cerramos la
      // notificación como error para que no quede permanente en Android.
      final candidates = evidence
          .where(
            (item) =>
                item.encrypted &&
                item.uploadStatus?.toUpperCase() == 'AVAILABLE' &&
                (item.contentUrl?.isNotEmpty ?? false),
          )
          .length;
      if (candidates > 0) {
        _emit(
          requisitionId: requisitionId,
          total: candidates,
          completed: 0,
          skipped: 0,
          failed: candidates,
          stage: EvidenceOfflineSyncStage.error,
          isActive: false,
          errorMessage: _safeMessage(error),
          errors: [_safeMessage(error)],
        );
      }
      rethrow;
    }
  }

  Future<void> _cancelScheduledBackgroundSync(String requisitionId) async {
    try {
      await _backgroundScheduler?.cancelOfflineSync(requisitionId);
    } on Object {
      // La sincronización iniciada por la UI sigue siendo válida aunque el
      // sistema no permita cancelar un worker anterior en ese momento.
    }
  }

  Future<void> _scheduleBackgroundSync(String requisitionId) async {
    try {
      await _backgroundScheduler?.scheduleOfflineSync(requisitionId);
    } on Object {
      // La ejecución iniciada por la UI sigue siendo válida aunque el sistema
      // no permita registrar un worker en esta plataforma.
    }
  }

  bool _hasRetryableFailures(EvidenceOfflineSyncResult result) {
    return result.errors.any((error) {
      final normalized = error.toLowerCase();
      return !normalized.contains('no encontrado en la nas tras migr') &&
          !normalized.contains('no encontrado en la nas');
    });
  }

  Future<EvidenceOfflineSyncResult> _syncRequisition({
    required String requisitionId,
    required List<RequisitionEvidence> evidence,
  }) async {
    final candidates = evidence
        .where(
          (item) =>
              item.encrypted &&
              item.uploadStatus?.toUpperCase() == 'AVAILABLE' &&
              (item.contentUrl?.isNotEmpty ?? false),
        )
        .toList(growable: false);
    final local = await _database.forRequisition(requisitionId);
    final localById = {for (final item in local) item.id: item};
    final total = candidates.length;
    var completed = 0;
    var skipped = 0;
    var failed = 0;
    final errors = <String>[];

    _emit(
      requisitionId: requisitionId,
      total: total,
      completed: completed,
      skipped: skipped,
      failed: failed,
      stage: total == 0
          ? EvidenceOfflineSyncStage.completed
          : EvidenceOfflineSyncStage.preparing,
      isActive: total > 0,
    );

    for (final item in candidates) {
      _emit(
        requisitionId: requisitionId,
        total: total,
        completed: completed,
        skipped: skipped,
        failed: failed,
        stage: EvidenceOfflineSyncStage.downloading,
        isActive: true,
        currentFileName: item.name,
      );
      try {
        final persisted = localById[item.id];
        if (await _isUsableLocalCopy(persisted, item)) {
          skipped += 1;
          continue;
        }

        await _recoverEvidence(item);
        completed += 1;
      } catch (error) {
        failed += 1;
        errors.add('${item.name}: ${_safeMessage(error)}');
      }
    }

    final hasFailures = failed > 0;
    _emit(
      requisitionId: requisitionId,
      total: total,
      completed: completed,
      skipped: skipped,
      failed: failed,
      stage: hasFailures
          ? EvidenceOfflineSyncStage.error
          : EvidenceOfflineSyncStage.completed,
      isActive: false,
      errorMessage: errors.isEmpty ? null : errors.first,
      errors: List.unmodifiable(errors),
    );
    return EvidenceOfflineSyncResult(
      total: total,
      completed: completed,
      skipped: skipped,
      failed: failed,
      errors: List.unmodifiable(errors),
    );
  }

  Future<bool> _isUsableLocalCopy(
    LocalEvidenceRecord? local,
    RequisitionEvidence remote,
  ) async {
    if (local == null || local.state != 'SINCRONIZADA') return false;
    if (local.ciphertextByteLength != remote.byteLength ||
        (remote.sha256 != null &&
            local.ciphertextSha256.toLowerCase() !=
                remote.sha256!.toLowerCase())) {
      return false;
    }
    final file = File(local.encryptedPath);
    if (!await file.exists()) return false;
    if (await file.length() != remote.byteLength) return false;
    final expectedHash = (remote.sha256 ?? local.ciphertextSha256)
        .toLowerCase();
    final actualHash = await crypto.sha256.bind(file.openRead()).first;
    return actualHash.toString().toLowerCase() == expectedHash;
  }

  Future<void> _recoverEvidence(RequisitionEvidence evidence) async {
    final url = evidence.contentUrl;
    if (url == null || url.isEmpty) {
      throw StateError('La evidencia no tiene una ruta de contenido.');
    }
    final remoteEnvelope = await _keyExchange.getEnvelope(
      requisitionId: evidence.requisitionId!,
      evidenceId: evidence.id,
    );
    if (remoteEnvelope == null) {
      throw StateError(
        'No existe una envoltura de clave para esta evidencia.',
      );
    }

    final result = await _http.request<List<int>>(
      url,
      isFileV2: true,
      onSucces: (body) => body is List<int>
          ? body
          : throw StateError('La respuesta de la evidencia no es un archivo.'),
    );
    final bytes = switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo descargar la evidencia.',
      ),
      Right(rightValue: final body) => body,
      Either() => throw StateError(
        'Respuesta inesperada al descargar la evidencia.',
      ),
    };
    if (evidence.byteLength <= 0 || bytes.length != evidence.byteLength) {
      throw StateError(
        'El tamaño de la evidencia descargada no coincide.',
      );
    }
    final ciphertextSha256 = crypto.sha256.convert(bytes).toString();
    if (evidence.sha256 != null &&
        ciphertextSha256 != evidence.sha256!.toLowerCase()) {
      throw StateError('El hash de la evidencia descargada no coincide.');
    }
    if (evidence.plaintextByteLength == null ||
        evidence.plaintextSha256 == null) {
      throw StateError('La evidencia no tiene metadatos de descifrado.');
    }

    final localWrappedKey = await _crypto.rewrapRequisitionDataKeyForLocalVault(
      wrappedKey: remoteEnvelope.wrappedKey,
      evidenceId: evidence.id,
      requisitionId: evidence.requisitionId!,
      requisitionKeyId: remoteEnvelope.requisitionKeyId,
      requisitionKeyVersion: remoteEnvelope.requisitionKeyVersion,
    );
    final targetPath = await _database.persistentEncryptedPath(evidence.id);
    final temporaryPath = '$targetPath.part';
    final temporaryFile = File(temporaryPath);
    final targetFile = File(targetPath);
    var targetInstalled = false;
    try {
      await temporaryFile.writeAsBytes(bytes, flush: true);
      if (await temporaryFile.length() != evidence.byteLength) {
        throw StateError('No se pudo guardar completa la evidencia local.');
      }
      if (await targetFile.exists()) await targetFile.delete();
      await temporaryFile.rename(targetPath);
      targetInstalled = true;

      // Verifica el contenedor completo antes de marcarlo como disponible.
      // Esto autentica cada bloque FCE y valida el hash/tamaño del contenido
      // plano sin conservar una copia descifrada permanente.
      final verificationPath = await _crypto.decryptToTemporaryFile(
        evidenceId: evidence.id,
        encryptedPath: targetPath,
        wrappedKey: localWrappedKey,
        expectedPlaintextSha256: evidence.plaintextSha256,
        expectedPlaintextByteLength: evidence.plaintextByteLength,
      );
      await _crypto.deletePlaintext(verificationPath);

      await _database.saveRecoveredEvidence(
        LocalEvidenceRecord(
          id: evidence.id,
          requisitionId: evidence.requisitionId!,
          sessionId: evidence.sessionId ?? '',
          originalName: evidence.name,
          mimeType: evidence.mimeType ?? 'application/octet-stream',
          type: _backendKind(evidence.type),
          acquisitionMethod: 'RECOVERED_OFFLINE',
          encryptedPath: targetPath,
          plaintextByteLength: evidence.plaintextByteLength!,
          ciphertextByteLength: evidence.byteLength,
          plaintextSha256: evidence.plaintextSha256!,
          ciphertextSha256: ciphertextSha256,
          encryptionAlgorithm:
              evidence.encryptionAlgorithm ??
              EvidenceCryptoService.algorithmName,
          encryptionVersion:
              evidence.encryptionVersion ?? EvidenceCryptoService.formatVersion,
          aadHash: _crypto.aadHashForEvidence(evidence.id),
          wrappedKey: localWrappedKey,
          keyVersion: EvidenceCryptoService.formatVersion,
          state: 'SINCRONIZADA',
          clientOperationId: 'offline-${evidence.id}',
          createdAt: evidence.createdAt,
          sourcePath: evidence.sourcePath,
        ),
      );
    } catch (_) {
      // Un archivo que no pasó la autenticación FCE o cuya metadata no pudo
      // guardarse no debe quedar como una copia aparentemente disponible.
      if (targetInstalled && await targetFile.exists()) {
        await targetFile.delete();
      }
      rethrow;
    } finally {
      if (await temporaryFile.exists()) await temporaryFile.delete();
    }
  }

  void _emit({
    required String requisitionId,
    required int total,
    required int completed,
    required int skipped,
    required int failed,
    required EvidenceOfflineSyncStage stage,
    required bool isActive,
    String? currentFileName,
    String? errorMessage,
    List<String> errors = const [],
  }) {
    if (!_progressController.isClosed) {
      _progressController.add(
        EvidenceOfflineSyncProgress(
          requisitionId: requisitionId,
          total: total,
          completed: completed,
          skipped: skipped,
          failed: failed,
          stage: stage,
          isActive: isActive,
          currentFileName: currentFileName,
          errorMessage: errorMessage,
          errors: errors,
        ),
      );
    }
    final notifications = _notifications;
    if (notifications != null) {
      unawaited(
        notifications
            .showOfflineProgress(
              requisitionId: requisitionId,
              total: total,
              processed: completed + skipped + failed,
              active: isActive,
              hasFailures: failed > 0,
              completed: completed,
              skipped: skipped,
              failed: failed,
            )
            .catchError((_) {}),
      );
    }
  }

  String _backendKind(RequisitionEvidenceType type) => switch (type) {
    RequisitionEvidenceType.image => 'IMAGE',
    RequisitionEvidenceType.video => 'VIDEO',
    RequisitionEvidenceType.audio => 'AUDIO',
    RequisitionEvidenceType.document => 'DOCUMENT',
    RequisitionEvidenceType.other => 'OTHER',
  };

  String _safeMessage(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    final normalized = message.toLowerCase();
    if (normalized.contains('timeout') ||
        normalized.contains('bloqueo de sincronización local')) {
      return 'La sincronización local está ocupada. Vuelve a intentarlo en unos segundos.';
    }
    return message.length > 256 ? message.substring(0, 256) : message;
  }
}
