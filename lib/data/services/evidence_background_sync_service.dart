import 'dart:ui';

import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/core/network/debug_http_overrides.dart';
import 'package:file_cast/core/network/http.dart' as file_cast_http;
import 'package:file_cast/core/notifications/local_notification_service.dart';
import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:file_cast/data/services/auth_session_service.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/evidence_key_exchange_service.dart';
import 'package:file_cast/data/services/evidence_offline_sync_service.dart';
import 'package:file_cast/data/services/evidence_sync_service.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/data/services/requisition_detail_service.dart';
import 'package:file_cast/domain/models/evidence_offline_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

const _evidenceTaskName = 'file_cast_evidence_sync';
const _uploadUniqueName = 'file_cast_evidence_upload';
const _offlineUniquePrefix = 'file_cast_evidence_offline_';

String _offlineTag(String requisitionId) =>
    '$_offlineUniquePrefix${requisitionId}_tag';

String _offlineUniqueName(
  String requisitionId,
  List<String> evidenceIds,
) {
  if (evidenceIds.isEmpty) return '$_offlineUniquePrefix$requisitionId';
  final normalized = [...evidenceIds]..sort();
  final scope = LocalNotificationService.stableId(normalized.join(','));
  return '$_offlineUniquePrefix${requisitionId}_$scope';
}

/// Programa trabajos que sobreviven al cierre normal y al reinicio del
/// proceso. El sistema operativo sigue decidiendo cuándo ejecutarlos; no se
/// promete ejecución durante un force-stop explícito del usuario.
class EvidenceBackgroundSyncService {
  EvidenceBackgroundSyncService({
    required this.baseUrl,
    required this.authBaseUrl,
  });

  final String baseUrl;
  final String authBaseUrl;
  static Future<void>? _initialization;

  static Future<void> initializeDispatcher() {
    final current = _initialization;
    if (current != null) return current;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return Future<void>.value();
    }
    final operation = Workmanager().initialize(
      evidenceBackgroundCallbackDispatcher,
    );
    _initialization = operation;
    return operation;
  }

  Future<void> scheduleUpload() async {
    await initializeDispatcher();
    if (!_supportsBackgroundTasks) return;
    await Workmanager().registerOneOffTask(
      _uploadUniqueName,
      _evidenceTaskName,
      inputData: {
        'operation': 'UPLOAD',
        'jobId': 'UPLOAD',
        'baseUrl': baseUrl,
        'authBaseUrl': authBaseUrl,
      },
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 10),
      foregroundServiceConfig: _foregroundServiceConfig(
        notificationId: LocalNotificationService.stableId('UPLOAD'),
        notificationText: 'Sincronizando evidencias',
      ),
    );
  }

  Future<void> scheduleOfflineSync(
    String requisitionId, {
    List<String> evidenceIds = const [],
  }) async {
    if (requisitionId.trim().isEmpty) return;
    await initializeDispatcher();
    if (!_supportsBackgroundTasks) return;
    await Workmanager().registerOneOffTask(
      _offlineUniqueName(requisitionId, evidenceIds),
      _evidenceTaskName,
      inputData: {
        'operation': 'OFFLINE_SYNC',
        'jobId': 'OFFLINE_SYNC:$requisitionId',
        'requisitionId': requisitionId,
        if (evidenceIds.isNotEmpty)
          'evidenceIds': ([...evidenceIds]..sort()).join(','),
        'baseUrl': baseUrl,
        'authBaseUrl': authBaseUrl,
      },
      tag: _offlineTag(requisitionId),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 10),
      foregroundServiceConfig: _foregroundServiceConfig(
        notificationId: LocalNotificationService.stableId(
          'OFFLINE_SYNC:$requisitionId',
        ),
        notificationText: 'Preparando evidencias para uso offline',
      ),
    );
  }

  Future<void> cancelOfflineSync(
    String requisitionId, {
    List<String> evidenceIds = const [],
  }) async {
    await initializeDispatcher();
    if (!_supportsBackgroundTasks) return;
    if (evidenceIds.isEmpty) {
      await Workmanager().cancelByTag(_offlineTag(requisitionId));
      // Compatibilidad con trabajos registrados antes de que existiera el
      // tag por requisa. El nombre general se conserva en el flujo nuevo.
      await Workmanager().cancelByUniqueName(
        '$_offlineUniquePrefix$requisitionId',
      );
      return;
    }
    await Workmanager().cancelByUniqueName(
      _offlineUniqueName(requisitionId, evidenceIds),
    );
  }

  Future<void> cancelUpload() async {
    await initializeDispatcher();
    if (!_supportsBackgroundTasks) return;
    await Workmanager().cancelByUniqueName(_uploadUniqueName);
  }

  bool get _supportsBackgroundTasks =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  ForegroundServiceConfig? _foregroundServiceConfig({
    required int notificationId,
    required String notificationText,
  }) {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    return ForegroundServiceConfig(
      notificationTitle: 'File Cast',
      notificationText: notificationText,
      notificationChannelId: LocalNotificationService.channelId,
      notificationChannelName: LocalNotificationService.channelName,
      notificationId: notificationId,
    );
  }
}

@pragma('vm:entry-point')
void evidenceBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final operation = (inputData?['operation'] as String?)?.toUpperCase();
    if (taskName != _evidenceTaskName && operation == null) return true;
    DartPluginRegistrant.ensureInitialized();
    configureDebugHttpOverrides();

    final baseUrl = inputData?['baseUrl'] as String?;
    if (baseUrl == null || baseUrl.trim().isEmpty) return false;
    final authBaseUrl =
        inputData?['authBaseUrl'] as String? ?? Config.baseUrlAuth;
    if (authBaseUrl.trim().isEmpty) return false;

    final notifications = LocalNotificationService();
    await notifications.initialize(requestPermissions: false);
    final requisitionId = inputData?['requisitionId'] as String?;
    final requestedEvidenceIds = (inputData?['evidenceIds'] as String?)
        ?.split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final secureStorage = SecureStorageService(const FlutterSecureStorage());
    final auth = AuthSessionService(
      client: http.Client(),
      storage: secureStorage,
      baseUrl: authBaseUrl,
    );
    if (!await auth.hasStoredSession()) {
      try {
        await notifications.cancelJobId(
          operation == 'OFFLINE_SYNC'
              ? 'OFFLINE_SYNC:${requisitionId ?? ''}'
              : 'UPLOAD',
        );
      } on Object {
        // La ausencia de sesión no debe dejar el engine sin finalizar.
      }
      await notifications.dispose();
      return true;
    }

    final client = file_cast_http.Http(
      client: http.Client(),
      baseUrl: baseUrl,
      userAgent: 'FileCast',
      ip: '',
      tokenProvider: auth.getValidAccessToken,
      onUnauthorized: auth.refreshTokenIfNeeded,
    );
    final database = LocalEvidenceDatabaseService(storage: secureStorage);
    final crypto = EvidenceCryptoService(storage: secureStorage);
    final keyExchange = EvidenceKeyExchangeService(
      http: client,
      crypto: crypto,
    );
    try {
      if (operation == 'OFFLINE_SYNC') {
        if (requisitionId == null || requisitionId.isEmpty) return false;
        final detail = await RequisitionDetailService(http: client).getDetail(
          requisitionId,
        );
        final selectedEvidence =
            requestedEvidenceIds == null || requestedEvidenceIds.isEmpty
            ? detail.evidence
            : detail.evidence
                  .where((item) => requestedEvidenceIds.contains(item.id))
                  .toList(growable: false);
        final selectedEvidenceOnly =
            requestedEvidenceIds != null && requestedEvidenceIds.isNotEmpty;
        final offline = EvidenceOfflineSyncService(
          http: client,
          database: database,
          crypto: crypto,
          keyExchange: keyExchange,
          notifications: notifications,
        );
        final result = await offline.syncRequisition(
          requisitionId: requisitionId,
          evidence: selectedEvidence,
          scheduleBackgroundOnFailure: false,
          scope: selectedEvidenceOnly
              ? EvidenceOfflineSyncScope.selectedEvidence
              : EvidenceOfflineSyncScope.requisition,
        );
        if (!result.hasFailures && result.total > 0) {
          await notifications.showOfflineCompletion(
            requisitionId: requisitionId,
            total: result.total,
            available: result.available,
            selectedEvidenceOnly: selectedEvidenceOnly,
          );
        }
        return !result.hasFailures;
      }

      final upload = EvidenceSyncService(
        http: client,
        database: database,
        crypto: crypto,
        keyExchange: keyExchange,
        notifications: notifications,
      );
      await upload.syncPending(includeNonRetryable: false);
      return (await database.pending(limit: 1, automaticOnly: true)).isEmpty;
    } on Object {
      return false;
    } finally {
      // WorkManager usa un aviso foreground separado de los avisos de
      // progreso por requisa. No lo dejamos permanente después de que el
      // worker terminó, incluso si terminó por error y será reintentado.
      try {
        await notifications.cancelJobId(
          operation == 'OFFLINE_SYNC'
              ? 'OFFLINE_SYNC:${requisitionId ?? ''}'
              : 'UPLOAD',
        );
      } on Object {
        // El resultado del worker no depende de limpiar la notificación.
      }
      // No cerrar explícitamente esta conexión desde el engine de
      // WorkManager. El worker puede ejecutarse en un engine Flutter distinto
      // al de la interfaz, pero ambos apuntan al mismo archivo SQLite/SQLCipher.
      // Durante una subida grande el engine principal puede estar guardando o
      // marcando una evidencia; cerrar aquí dejaba su conexión en estado
      // `database_close` y hacía fallar fotos o videos posteriores.
      await notifications.dispose();
    }
  });
}
