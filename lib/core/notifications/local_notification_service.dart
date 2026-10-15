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
        'operation':
            operation.name == 'offlineSync' ? 'OFFLINE_SYNC' : 'UPLOAD',
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
  static const notificationType = 'evidence_sync';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<LocalNotificationPayload> _clicks =
      StreamController<LocalNotificationPayload>.broadcast();
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

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
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
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final darwin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
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
  }) {
    return _showProgress(
      operation: EvidenceJobOperation.offlineSync,
      requisitionId: requisitionId,
      total: total,
      processed: processed,
      active: active,
      hasFailures: hasFailures,
    );
  }

  Future<void> _showProgress({
    required EvidenceJobOperation operation,
    required String requisitionId,
    required int total,
    required int processed,
    required bool active,
    required bool hasFailures,
  }) async {
    if (kIsWeb) return;
    await initialize(requestPermissions: false);
    final jobId =
        '${operation == EvidenceJobOperation.upload ? 'UPLOAD' : 'OFFLINE_SYNC'}:$requisitionId';
    final progress = total <= 0
        ? 0
        : (((processed / total) * 1000).round().clamp(0, 1000)).toInt();
    final isComplete = !active && !hasFailures;
    final title = !active && hasFailures
        ? 'Sincronización con errores'
        : operation == EvidenceJobOperation.upload
            ? (isComplete ? 'Sincronización completada' : 'Subiendo evidencias')
            : (isComplete
                ? 'Evidencias listas para uso offline'
                : 'Preparando evidencias para uso offline');
    final body = active
        ? operation == EvidenceJobOperation.upload
            ? 'Subiendo $processed de $total archivos'
            : 'Guardando $processed de $total archivos'
        : hasFailures
            ? 'Algunas evidencias requieren reintento'
            : operation == EvidenceJobOperation.upload
                ? 'Todas las evidencias pendientes fueron procesadas'
                : 'La copia cifrada está disponible en este dispositivo';
    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: active,
      autoCancel: !active,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showProgress: active && total > 0,
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
    final prefix =
        operation == EvidenceJobOperation.upload ? 'UPLOAD' : 'OFFLINE_SYNC';
    await _plugin.cancel(stableId('$prefix:$requisitionId'));
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
