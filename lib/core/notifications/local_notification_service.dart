import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum EvidenceJobOperation { upload, offlineSync }

final class LocalNotificationPayload {
  const LocalNotificationPayload({
    required this.type,
    required this.operation,
    required this.requisitionId,
    required this.jobId,
  });

  final String type;
  final EvidenceJobOperation operation;
  final String requisitionId;
  final String jobId;

  String toJson() => jsonEncode({
    'type': type,
    'operation': operation.name == 'offlineSync' ? 'OFFLINE_SYNC' : 'UPLOAD',
    'requisitionId': requisitionId,
    'jobId': jobId,
  });

  static LocalNotificationPayload? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final map = decoded.map(
        (key, item) => MapEntry(key.toString(), item),
      );
      final operation = switch ((map['operation'] as String?)?.toUpperCase()) {
        'OFFLINE_SYNC' => EvidenceJobOperation.offlineSync,
        'UPLOAD' => EvidenceJobOperation.upload,
        _ => null,
      };
      final requisitionId = map['requisitionId'] as String?;
      final jobId = map['jobId'] as String?;
      final type = map['type'] as String?;
      if (operation == null ||
          requisitionId == null ||
          requisitionId.isEmpty ||
          jobId == null ||
          jobId.isEmpty ||
          type == null ||
          type.isEmpty) {
        return null;
      }
      return LocalNotificationPayload(
        type: type,
        operation: operation,
        requisitionId: requisitionId,
        jobId: jobId,
      );
    } on Object {
      return null;
    }
  }
}

/// Encapsula las notificaciones de progreso de trabajos de evidencias.
///
/// El mismo ID se actualiza durante todo el trabajo. No incluye nombres de
/// archivos, CUD ni datos personales en el texto visible de la notificación.
class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'file_cast_evidence_sync';
  static const channelName = 'Sincronización de evidencias';
  static const channelDescription =
      'Progreso de subida y preparación offline de evidencias.';
  static const resultChannelId = 'file_cast_evidence_results';
  static const resultChannelName = 'Resultados de evidencias';
  static const resultChannelDescription =
      'Confirma cuando una sincronización de evidencias termina.';
  static const notificationType = 'evidence_sync';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<LocalNotificationPayload> _clicks =
      StreamController<LocalNotificationPayload>.broadcast();
  final Map<String, Future<void>> _progressUpdates = <String, Future<void>>{};
  Future<void>? _initialization;
  bool _permissionsRequested = false;
  LocalNotificationPayload? _pendingLaunchPayload;

  Stream<LocalNotificationPayload> get clicks => _clicks.stream;
  LocalNotificationPayload? takePendingLaunchPayload() {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return payload;
  }

  Future<void> initialize({bool requestPermissions = true}) {
    if (kIsWeb) return Future<void>.value();
    final operation = _initialization ??= _initialize();
    return operation.then((_) async {
      if (requestPermissions && !_permissionsRequested) {
        await _requestPermissions();
      }
    });
  }

  Future<void> _initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = LocalNotificationPayload.tryParse(response.payload);
        if (payload != null && !_clicks.isClosed) _clicks.add(payload);
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        resultChannelId,
        resultChannelName,
        description: resultChannelDescription,
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
        showBadge: true,
      ),
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingLaunchPayload = LocalNotificationPayload.tryParse(
        launchDetails?.notificationResponse?.payload,
      );
    }
  }

  Future<void> _requestPermissions() async {
    _permissionsRequested = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final darwin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await darwin?.requestPermissions(
        alert: true,
        badge: true,
        sound: false,
      );
    }
  }

  Future<void> showUploadProgress({
    required String requisitionId,
    required int total,
    required int processed,
    required bool active,
    required bool hasFailures,
  }) {
    return _showProgress(
      operation: EvidenceJobOperation.upload,
      requisitionId: requisitionId,
      total: total,
      processed: processed,
      active: active,
      hasFailures: hasFailures,
    );
  }

  Future<void> showOfflineProgress({
    required String requisitionId,
    required int total,
    required int processed,
    required bool active,
    required bool hasFailures,
    int completed = 0,
    int skipped = 0,
    int failed = 0,
  }) {
    return _showProgress(
      operation: EvidenceJobOperation.offlineSync,
      requisitionId: requisitionId,
      total: total,
      processed: processed,
      active: active,
      hasFailures: hasFailures,
      completed: completed,
      skipped: skipped,
      failed: failed,
    );
  }

  Future<void> showOfflineCompletion({
    required String requisitionId,
    required int total,
    required int available,
    required bool selectedEvidenceOnly,
  }) async {
    if (kIsWeb || total <= 0) return;
    await initialize(requestPermissions: false);
    final title = selectedEvidenceOnly
        ? 'Evidencia disponible offline'
        : 'Sincronización offline completada';
    final body = selectedEvidenceOnly
        ? 'La evidencia solicitada ya puede abrirse sin conexión.'
        : '$available de $total evidencias quedaron disponibles sin conexión.';
    final jobId = 'OFFLINE_SYNC:$requisitionId';
    final payload = LocalNotificationPayload(
      type: notificationType,
      operation: EvidenceJobOperation.offlineSync,
      requisitionId: requisitionId,
      jobId: jobId,
    );
    await _plugin.show(
      stableId('OFFLINE_SYNC_RESULT:$requisitionId'),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          resultChannelId,
          resultChannelName,
          channelDescription: resultChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
          playSound: false,
          enableVibration: false,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.status,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: false,
        ),
      ),
      payload: payload.toJson(),
    );
  }

  Future<void> _showProgress({
    required EvidenceJobOperation operation,
    required String requisitionId,
    required int total,
    required int processed,
    required bool active,
    required bool hasFailures,
    int completed = 0,
    int skipped = 0,
    int failed = 0,
  }) {
    final jobId =
        '${operation == EvidenceJobOperation.upload ? 'UPLOAD' : 'OFFLINE_SYNC'}:$requisitionId';
    final previous = _progressUpdates[jobId];

    Future<void> update() async {
      if (previous != null) {
        try {
          await previous;
        } on Object {
          // Una actualización fallida no debe bloquear el estado siguiente.
        }
      }
      await _showProgressNow(
        operation: operation,
        requisitionId: requisitionId,
        total: total,
        processed: processed,
        active: active,
        hasFailures: hasFailures,
        completed: completed,
        skipped: skipped,
        failed: failed,
      );
    }

    final current = update();
    _progressUpdates[jobId] = current;
    unawaited(
      current.then<void>(
        (_) {
          if (identical(_progressUpdates[jobId], current)) {
            _progressUpdates.remove(jobId);
          }
        },
        onError: (Object _, StackTrace __) {
          if (identical(_progressUpdates[jobId], current)) {
            _progressUpdates.remove(jobId);
          }
        },
      ),
    );
    return current;
  }

  Future<void> _showProgressNow({
    required EvidenceJobOperation operation,
    required String requisitionId,
    required int total,
    required int processed,
    required bool active,
    required bool hasFailures,
    int completed = 0,
    int skipped = 0,
    int failed = 0,
  }) async {
    if (kIsWeb) return;
    await initialize(requestPermissions: false);
    final jobId =
        '${operation == EvidenceJobOperation.upload ? 'UPLOAD' : 'OFFLINE_SYNC'}:$requisitionId';
    // La pantalla conserva el resultado final. La notificación del sistema
    // representa únicamente trabajo activo y debe desaparecer siempre que el
    // flujo termina, falla o es pausado; así nunca queda un aviso `ongoing`
    // huérfano después de cerrar un worker.
    if (!active) {
      await _plugin.cancel(stableId(jobId));
      return;
    }
    final progress = total <= 0
        ? 0
        : (((processed / total) * 1000).round().clamp(0, 1000)).toInt();
    final title = operation == EvidenceJobOperation.upload
        ? 'Subiendo evidencias'
        : 'Preparando evidencias para uso offline';
    final body = operation == EvidenceJobOperation.upload
        ? 'Subiendo $processed de $total archivos'
        : 'Guardando $processed de $total archivos';
    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showProgress: total > 0,
      maxProgress: 1000,
      progress: progress,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.progress,
    );
    final payload = LocalNotificationPayload(
      type: notificationType,
      operation: operation,
      requisitionId: requisitionId,
      jobId: jobId,
    );
    await _plugin.show(
      stableId(jobId),
      title,
      body,
      NotificationDetails(
        android: details,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: payload.toJson(),
    );
  }

  Future<void> cancelJob({
    required EvidenceJobOperation operation,
    required String requisitionId,
  }) async {
    if (kIsWeb) return;
    await initialize(requestPermissions: false);
    final prefix = operation == EvidenceJobOperation.upload
        ? 'UPLOAD'
        : 'OFFLINE_SYNC';
    await cancelJobId('$prefix:$requisitionId');
  }

  /// Cancela el aviso de foreground que crea WorkManager. Ese aviso usa un
  /// ID global para la outbox de subida y no el ID por requisa de la UI.
  Future<void> cancelJobId(String jobId) async {
    if (kIsWeb) return;
    await initialize(requestPermissions: false);
    final pending = _progressUpdates[jobId];
    if (pending != null) {
      try {
        await pending;
      } on Object {
        // La cancelación sigue siendo válida aunque el update haya fallado.
      }
    }
    await _plugin.cancel(stableId(jobId));
  }

  Future<void> dispose() async {
    await _clicks.close();
  }

  static int stableId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
