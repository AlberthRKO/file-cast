import 'dart:async';

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:flutter/foundation.dart';

class MirrorViewModel extends ChangeNotifier {
  MirrorViewModel({
    required AcquisitionRepository repository,
    required this.requisitionId,
    required this.sessionId,
    required int videoWidth,
    required int videoHeight,
  }) : _repository = repository,
       _videoWidth = videoWidth,
       _videoHeight = videoHeight;

  final AcquisitionRepository _repository;
  final String requisitionId;
  final String sessionId;
  int _videoWidth;
  int get videoWidth => _videoWidth;
  int _videoHeight;
  int get videoHeight => _videoHeight;
  RequisitionDetail? _detail;
  RequisitionDetail? get detail => _detail;
  AcquisitionRecordingPhase _recordingPhase = AcquisitionRecordingPhase.idle;
  AcquisitionRecordingPhase get recordingPhase => _recordingPhase;
  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;
  String? _message;
  String? get message => _message;
  bool _messageIsError = false;
  bool get messageIsError => _messageIsError;
  bool _disposed = false;
  StreamSubscription<void>? _deviceSubscription;
  Timer? _recordingTimer;
  Timer? _messageTimer;
  DateTime? _recordingStartedAt;
  bool _touchErrorReported = false;
  bool _showDiagnostics = false;
  bool get showDiagnostics => _showDiagnostics;
  String _diagnosticLog = '';
  String get diagnosticLog => _diagnosticLog;
  Timer? _diagnosticTimer;
  bool _refreshingDiagnostics = false;

  List<RequisitionEvidence> get recentEvidence {
    final items = [...?_detail?.evidence]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(12).toList(growable: false);
  }

  int get totalEvidence => _detail?.evidence.length ?? 0;
  String get recordingDurationLabel {
    final startedAt = _recordingStartedAt;
    if (startedAt == null) return '00:00';
    final elapsed = DateTime.now().difference(startedAt);
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> load() async {
    _deviceSubscription ??= _repository.deviceChanges.listen((_) async {
      final session = await _repository.activeSession(
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      if (session != null) {
        _videoWidth = session.videoWidth;
        _videoHeight = session.videoHeight;
      }
      final devices = await _repository.getDevices();
      if (devices.isEmpty) {
        _showMessage(
          'El dispositivo objetivo fue desconectado.',
          isError: true,
          duration: const Duration(seconds: 4),
        );
      }
      _safeNotify();
    });
    try {
      _detail = await _repository.getRequisitionDetail(requisitionId);
    } catch (_) {
      _showMessage(
        'No se pudo cargar el resumen de la requisa.',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    }
    _safeNotify();
  }

  void toggleDiagnostics() {
    _showDiagnostics = !_showDiagnostics;
    _diagnosticTimer?.cancel();
    if (_showDiagnostics) {
      unawaited(refreshDiagnostics());
      _diagnosticTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(refreshDiagnostics()),
      );
    }
    _safeNotify();
  }

  Future<void> refreshDiagnostics() async {
    if (_refreshingDiagnostics) return;
    _refreshingDiagnostics = true;
    try {
      final log = await _repository.getControlDiagnostics();
      if (_disposed) return;
      _diagnosticLog = log;
      _safeNotify();
    } finally {
      _refreshingDiagnostics = false;
    }
  }

  Future<void> captureScreenshot() async {
    if (_isCapturing) return;
    _isCapturing = true;
    _clearMessage(notify: false);
    _safeNotify();
    try {
      _detail = await _repository.captureScreenshot(
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      _showMessage('Captura guardada.', notify: false);
    } catch (error) {
      _showMessage(
        'No se pudo capturar la pantalla: $error',
        isError: true,
        duration: const Duration(seconds: 4),
        notify: false,
      );
    }
    _isCapturing = false;
    _safeNotify();
  }

  Future<void> toggleRecording() async {
    if (_recordingPhase == AcquisitionRecordingPhase.saving) return;
    _clearMessage(notify: false);
    if (_recordingPhase == AcquisitionRecordingPhase.idle) {
      try {
        await _repository.startRecording(
          requisitionId: requisitionId,
          sessionId: sessionId,
        );
        _recordingPhase = AcquisitionRecordingPhase.recording;
        _recordingStartedAt = DateTime.now();
        _recordingTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _safeNotify(),
        );
        _showMessage('Grabación iniciada.', notify: false);
      } catch (error) {
        _showMessage(
          'No se pudo iniciar la grabación: $error',
          isError: true,
          duration: const Duration(seconds: 4),
          notify: false,
        );
      }
      _safeNotify();
      return;
    }
    _recordingPhase = AcquisitionRecordingPhase.saving;
    _recordingTimer?.cancel();
    _safeNotify();
    try {
      _detail = await _repository.stopRecording(
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      _showMessage('Video guardado.', notify: false);
    } catch (error) {
      _showMessage(
        'No se pudo guardar la grabación: $error',
        isError: true,
        duration: const Duration(seconds: 4),
        notify: false,
      );
    }
    _recordingPhase = AcquisitionRecordingPhase.idle;
    _recordingStartedAt = null;
    _safeNotify();
  }

  void sendTouch(int action, int pointerId, int x, int y) {
    unawaited(_sendTouch(action, pointerId, x, y));
  }

  Future<void> _sendTouch(int action, int pointerId, int x, int y) async {
    try {
      await _repository.sendTouch(action, pointerId, x, y);
    } catch (_) {
      if (_touchErrorReported) return;
      _touchErrorReported = true;
      _showMessage(
        'El canal táctil no respondió. Verifica “Depuración USB (ajustes de seguridad)” en el dispositivo objetivo.',
        isError: true,
        duration: const Duration(seconds: 4),
        notify: false,
      );
      _safeNotify();
    } finally {
      if (action == 1 && _showDiagnostics) {
        unawaited(refreshDiagnostics());
      }
    }
  }

  void sendScroll(int x, int y, int deltaY) {
    unawaited(_sendScroll(x, y, deltaY));
  }

  Future<void> _sendScroll(int x, int y, int deltaY) async {
    try {
      await _repository.sendScroll(x, y, deltaY);
    } catch (_) {
      if (_touchErrorReported) return;
      _touchErrorReported = true;
      _showMessage(
        'El canal de control táctil no respondió.',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> sendBack() => _repository.sendBack();
  Future<void> sendHome() => _repository.sendHome();
  Future<void> sendAppSwitch() => _repository.sendAppSwitch();

  void _showMessage(
    String value, {
    bool isError = false,
    Duration duration = const Duration(seconds: 1),
    bool notify = true,
  }) {
    _messageTimer?.cancel();
    _message = value;
    _messageIsError = isError;
    _messageTimer = Timer(duration, () => _clearMessage());
    if (notify) _safeNotify();
  }

  void _clearMessage({bool notify = true}) {
    _messageTimer?.cancel();
    _messageTimer = null;
    if (_message == null) return;
    _message = null;
    _messageIsError = false;
    if (notify) _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _deviceSubscription?.cancel();
    _recordingTimer?.cancel();
    _messageTimer?.cancel();
    _diagnosticTimer?.cancel();
    if (_recordingPhase == AcquisitionRecordingPhase.recording) {
      unawaited(
        _repository.stopRecording(
          requisitionId: requisitionId,
          sessionId: sessionId,
        ),
      );
    }
    super.dispose();
  }
}
