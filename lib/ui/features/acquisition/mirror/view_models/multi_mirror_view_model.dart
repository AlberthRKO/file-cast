import 'dart:async';

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/ui/core/navigation/route_args/multi_mirror_route_args.dart';
import 'package:flutter/widgets.dart';

enum MultiMirrorLayoutMode { overview, focused }

class MultiMirrorViewModel extends ChangeNotifier {
  MultiMirrorViewModel({
    required AcquisitionRepository repository,
    required this.requisitionId,
    required this.sessionId,
    required List<MultiMirrorSourceArgs> sources,
  }) : _repository = repository,
       _sources = List.of(sources);

  final AcquisitionRepository _repository;
  final String requisitionId;
  final String sessionId;
  List<MultiMirrorSourceArgs> _sources;
  List<MultiMirrorSourceArgs> get sources => List.unmodifiable(_sources);
  StreamSubscription<void>? _deviceSubscription;
  String? _focusedSourceId;
  String? get focusedSourceId =>
      _focusedSourceId ??
      (_sources.isEmpty ? null : _sources.first.sourceSessionId);
  MultiMirrorSourceArgs? get focusedSource {
    final sourceId = focusedSourceId;
    if (sourceId == null) return null;
    for (final source in _sources) {
      if (source.sourceSessionId == sourceId) return source;
    }
    return null;
  }

  MultiMirrorLayoutMode _layoutMode = MultiMirrorLayoutMode.overview;
  MultiMirrorLayoutMode get layoutMode => _layoutMode;
  bool _disposed = false;
  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;
  final Map<String, AcquisitionRecordingPhase> _recordingPhases = {};
  final Map<String, DateTime> _recordingStartedAt = {};
  Timer? _recordingTimer;
  String? _message;
  String? get message => _message;
  bool _messageIsError = false;
  bool get messageIsError => _messageIsError;
  String _diagnosticLog = '';
  String get diagnosticLog => _diagnosticLog;
  bool _showDiagnostics = false;
  bool get showDiagnostics => _showDiagnostics;
  String? _overviewControlSourceId;
  String? get overviewControlSourceId => _overviewControlSourceId;

  bool isOverviewControlEnabled(String sourceId) =>
      _overviewControlSourceId == sourceId;

  AcquisitionRecordingPhase recordingPhase(String sourceId) =>
      _recordingPhases[sourceId] ?? AcquisitionRecordingPhase.idle;

  bool isRecording(String sourceId) =>
      recordingPhase(sourceId) == AcquisitionRecordingPhase.recording;

  Future<void> load() async {
    _deviceSubscription ??= _repository.deviceChanges.listen((_) {
      unawaited(_refreshSources());
    });
    await _refreshSources();
  }

  Future<void> _refreshSources() async {
    try {
      final active = await _repository.activeMultiSessions(
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      if (_disposed) return;
      _sources = active
          .map(
            (source) => MultiMirrorSourceArgs(
              sourceSessionId: source.sourceSessionId,
              textureId: source.textureId,
              videoSize: Size(
                source.videoWidth.toDouble(),
                source.videoHeight.toDouble(),
              ),
              deviceName: source.deviceName,
            ),
          )
          .toList(growable: false);
      final activeSourceIds = _sources
          .map((source) => source.sourceSessionId)
          .toSet();
      _recordingPhases.removeWhere(
        (sourceId, _) => !activeSourceIds.contains(sourceId),
      );
      _recordingStartedAt.removeWhere(
        (sourceId, _) => !activeSourceIds.contains(sourceId),
      );
      if (_recordingStartedAt.isEmpty) {
        _recordingTimer?.cancel();
        _recordingTimer = null;
      }
      if (_focusedSourceId != null &&
          !_sources.any(
            (source) => source.sourceSessionId == _focusedSourceId,
          )) {
        _focusedSourceId = null;
      }
      if (_overviewControlSourceId != null &&
          !activeSourceIds.contains(_overviewControlSourceId)) {
        _overviewControlSourceId = null;
      }
      if (_sources.length <= 1) {
        _layoutMode = MultiMirrorLayoutMode.focused;
      }
      if (_sources.isEmpty) {
        _showMessage(
          'Los dispositivos objetivo fueron desconectados.',
          isError: true,
        );
      }
      _safeNotify();
    } catch (error) {
      if (_disposed) return;
      _showMessage(_friendlyError(error), isError: true);
      _safeNotify();
    }
  }

  String recordingDurationLabel(String sourceId) {
    final startedAt = _recordingStartedAt[sourceId];
    if (startedAt == null) return '00:00';
    final elapsed = DateTime.now().difference(startedAt);
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void focus(String sourceId) {
    _focusedSourceId = sourceId;
    _safeNotify();
  }

  void showOverview() {
    if (_sources.length <= 1) return;
    _layoutMode = MultiMirrorLayoutMode.overview;
    _overviewControlSourceId = null;
    _safeNotify();
  }

  void showFocused(String sourceId) {
    _focusedSourceId = sourceId;
    _layoutMode = MultiMirrorLayoutMode.focused;
    _overviewControlSourceId = null;
    _safeNotify();
  }

  void setLayoutMode(MultiMirrorLayoutMode mode) {
    if (mode == MultiMirrorLayoutMode.overview && _sources.length <= 1) return;
    _layoutMode = mode;
    _overviewControlSourceId = null;
    _safeNotify();
  }

  void toggleOverviewControl(String sourceId) {
    if (_layoutMode != MultiMirrorLayoutMode.overview) return;
    _focusedSourceId = sourceId;
    _overviewControlSourceId = _overviewControlSourceId == sourceId
        ? null
        : sourceId;
    _safeNotify();
  }

  Future<void> captureScreenshot() async {
    final sourceId = focusedSourceId;
    if (sourceId == null || _isCapturing) return;
    _isCapturing = true;
    _clearMessage();
    _safeNotify();
    try {
      await _repository.captureScreenshotForSource(
        sourceSessionId: sourceId,
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      _showMessage('Captura guardada.');
    } catch (error) {
      _showMessage(_friendlyError(error), isError: true);
    } finally {
      _isCapturing = false;
      _safeNotify();
    }
  }

  Future<void> toggleRecording() async {
    final sourceId = focusedSourceId;
    if (sourceId == null) return;
    final previousPhase = recordingPhase(sourceId);
    if (previousPhase == AcquisitionRecordingPhase.starting ||
        previousPhase == AcquisitionRecordingPhase.saving) {
      return;
    }
    _clearMessage();
    try {
      if (previousPhase == AcquisitionRecordingPhase.recording) {
        _recordingPhases[sourceId] = AcquisitionRecordingPhase.saving;
        _safeNotify();
        await _repository.stopRecordingForSource(
          sourceSessionId: sourceId,
          requisitionId: requisitionId,
          sessionId: sessionId,
        );
        _recordingPhases[sourceId] = AcquisitionRecordingPhase.idle;
        _recordingStartedAt.remove(sourceId);
        _showMessage('Video guardado.');
      } else {
        _recordingPhases[sourceId] = AcquisitionRecordingPhase.starting;
        _safeNotify();
        await _repository.startRecordingForSource(
          sourceSessionId: sourceId,
          requisitionId: requisitionId,
          sessionId: sessionId,
        );
        _recordingPhases[sourceId] = AcquisitionRecordingPhase.recording;
        _recordingStartedAt[sourceId] = DateTime.now();
        _recordingTimer ??= Timer.periodic(
          const Duration(seconds: 1),
          (_) => _safeNotify(),
        );
        _showMessage('Grabación iniciada.');
      }
    } catch (error) {
      _recordingPhases[sourceId] = previousPhase;
      _showMessage(_friendlyError(error), isError: true);
    }
    if (_recordingStartedAt.isEmpty) {
      _recordingTimer?.cancel();
      _recordingTimer = null;
    }
    _safeNotify();
  }

  void sendTouch(String sourceId, int action, int pointerId, int x, int y) {
    if (!_canControlSource(sourceId)) return;
    unawaited(
      _repository
          .sendTouchToSource(sourceId, action, pointerId, x, y)
          .catchError((_) {}),
    );
  }

  void sendScroll(String sourceId, int x, int y, int deltaY) {
    if (!_canControlSource(sourceId)) return;
    unawaited(
      _repository.sendScrollToSource(sourceId, x, y, deltaY).catchError((_) {}),
    );
  }

  bool _canControlSource(String sourceId) => switch (_layoutMode) {
    MultiMirrorLayoutMode.focused => sourceId == focusedSourceId,
    MultiMirrorLayoutMode.overview => sourceId == _overviewControlSourceId,
  };

  void sendKey(String sourceId, int keycode) {
    unawaited(
      _repository.sendKeyToSource(sourceId, keycode).catchError((_) {}),
    );
  }

  void toggleDiagnostics() {
    _showDiagnostics = !_showDiagnostics;
    if (_showDiagnostics) unawaited(refreshDiagnostics());
    _safeNotify();
  }

  Future<void> refreshDiagnostics() async {
    final sourceId = focusedSourceId;
    if (sourceId == null) return;
    try {
      _diagnosticLog = await _repository.getMultiControlDiagnostics(sourceId);
      _safeNotify();
    } catch (error) {
      _diagnosticLog = _friendlyError(error);
      _safeNotify();
    }
  }

  Future<void> close() => _repository.disconnectMulti();

  void _showMessage(String value, {bool isError = false}) {
    _message = value;
    _messageIsError = isError;
  }

  void _clearMessage() {
    _message = null;
    _messageIsError = false;
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _deviceSubscription?.cancel();
    _recordingTimer?.cancel();
    unawaited(close());
    super.dispose();
  }
}
