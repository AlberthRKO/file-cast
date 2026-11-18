import 'dart:async';

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
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
  StreamSubscription<String>? _evidenceChangesSubscription;
  RequisitionDetail? _detail;
  Future<void>? _evidenceRefreshInFlight;
  bool _evidenceRefreshQueued = false;
  Timer? _evidenceStatusTimer;
  Timer? _messageTimer;
  bool _showEvidence = false;
  bool get showEvidence => _showEvidence;
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
  final Set<String> _restartingSourceIds = {};
  final Map<String, AcquisitionRecordingPhase> _recordingPhases = {};
  final Map<String, DateTime> _recordingStartedAt = {};
  Timer? _recordingTimer;
  String? _message;
  String? get message => _message;
  String? _messageSourceId;
  String? get messageSourceId => _messageSourceId;
  bool _messageIsError = false;
  bool get messageIsError => _messageIsError;
  String _diagnosticLog = '';
  String get diagnosticLog => _diagnosticLog;
  bool _showDiagnostics = false;
  bool get showDiagnostics => _showDiagnostics;
  String? _overviewControlSourceId;
  String? get overviewControlSourceId => _overviewControlSourceId;

  List<RequisitionEvidence> get recentEvidence {
    final items = [...?_detail?.evidence]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(12).toList(growable: false);
  }

  int get totalEvidence => _detail?.evidence.length ?? 0;
  int get pendingEvidenceCount =>
      _detail?.evidence.where((evidence) {
        final status = evidence.uploadStatus?.toUpperCase();
        return status == 'PENDING_UPLOAD' || status == 'UPLOADING';
      }).length ??
      0;

  bool isOverviewControlEnabled(String sourceId) =>
      _overviewControlSourceId == sourceId;

  AcquisitionRecordingPhase recordingPhase(String sourceId) =>
      _recordingPhases[sourceId] ?? AcquisitionRecordingPhase.idle;

  bool isRecording(String sourceId) =>
      recordingPhase(sourceId) == AcquisitionRecordingPhase.recording;

  bool isRestarting(String sourceId) => _restartingSourceIds.contains(sourceId);

  Future<void> load() async {
    _evidenceChangesSubscription ??= _repository.evidenceChanges.listen((
      changedId,
    ) {
      if (changedId != requisitionId || _disposed) return;
      unawaited(_refreshEvidenceDetail());
    });
    _deviceSubscription ??= _repository.deviceChanges.listen((_) {
      unawaited(_refreshSources());
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
    await _refreshSources();
  }

  Future<void> _refreshEvidenceDetail() async {
    final inFlight = _evidenceRefreshInFlight;
    if (inFlight != null) {
      _evidenceRefreshQueued = true;
      return inFlight;
    }
    final refresh = () async {
      do {
        _evidenceRefreshQueued = false;
        try {
          final detail = await _repository.getCachedRequisitionDetail(
            requisitionId,
          );
          if (_disposed) return;
          _detail = detail;
          _safeNotify();
        } on Object {
          // Se conserva el último snapshot visible y se atiende cualquier
          // evento nuevo que haya quedado en cola.
        }
      } while (_evidenceRefreshQueued && !_disposed);
    }();
    _evidenceRefreshInFlight = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_evidenceRefreshInFlight, refresh)) {
        _evidenceRefreshInFlight = null;
      }
    }
  }

  void _updateEvidenceStatusPolling() {
    final hasUnresolved =
        _detail?.evidence.any((evidence) {
          final status = evidence.uploadStatus?.toUpperCase();
          return status == 'PENDING_UPLOAD' ||
              status == 'UPLOADING' ||
              status == 'ERROR';
        }) ??
        false;
    if (!hasUnresolved) {
      _evidenceStatusTimer?.cancel();
      _evidenceStatusTimer = null;
      return;
    }
    _evidenceStatusTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshEvidenceDetail()),
    );
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

  void toggleEvidence() {
    _showEvidence = !_showEvidence;
    _safeNotify();
  }

  void hideEvidence() {
    if (!_showEvidence) return;
    _showEvidence = false;
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
    if (sourceId == null || _isCapturing || isRestarting(sourceId)) return;
    _isCapturing = true;
    _clearMessage();
    _safeNotify();
    try {
      final sourceName =
          focusedSource?.deviceName ?? 'dispositivo seleccionado';
      _detail = await _repository.captureScreenshotForSource(
        sourceSessionId: sourceId,
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      _showMessage(
        'Captura de $sourceName guardada.',
        sourceSessionId: sourceId,
      );
    } catch (error) {
      _showMessage(
        _friendlyError(error),
        isError: true,
        sourceSessionId: sourceId,
      );
    } finally {
      _isCapturing = false;
      _safeNotify();
    }
  }

  Future<void> restartSource(String sourceId) async {
    if (isRestarting(sourceId) ||
        _isCapturing ||
        recordingPhase(sourceId) != AcquisitionRecordingPhase.idle) {
      return;
    }
    MultiMirrorSourceArgs? current;
    for (final source in _sources) {
      if (source.sourceSessionId == sourceId) {
        current = source;
        break;
      }
    }
    if (current == null) return;
    final currentSource = current;

    _restartingSourceIds.add(sourceId);
    _showMessage(
      'Recargando el mirror de ${currentSource.deviceName}…',
      duration: const Duration(seconds: 30),
      sourceSessionId: sourceId,
    );
    _safeNotify();
    try {
      final restarted = await _repository.restartMultiMirrorSource(sourceId);
      if (_disposed) return;
      final index = _sources.indexWhere(
        (source) => source.sourceSessionId == sourceId,
      );
      if (index >= 0) {
        final updated = List<MultiMirrorSourceArgs>.of(_sources);
        updated[index] = MultiMirrorSourceArgs(
          sourceSessionId: restarted.sourceSessionId,
          textureId: restarted.textureId,
          videoSize: Size(
            restarted.videoWidth.toDouble(),
            restarted.videoHeight.toDouble(),
          ),
          deviceName: restarted.deviceName,
        );
        _sources = updated;
      }
      _showMessage(
        'Mirror de ${restarted.deviceName} restablecido.',
        sourceSessionId: sourceId,
      );
    } catch (error) {
      if (_disposed) return;
      _showMessage(
        'No se pudo recargar ${currentSource.deviceName}: ${_friendlyError(error)}',
        isError: true,
        sourceSessionId: sourceId,
      );
    } finally {
      if (!_disposed) {
        _restartingSourceIds.remove(sourceId);
        _safeNotify();
      }
    }
  }

  Future<String?> renameEvidence(
    RequisitionEvidence evidence,
    String displayName,
  ) async {
    try {
      _detail = await _repository.renameEvidence(
        requisitionId: requisitionId,
        evidence: evidence,
        displayName: displayName,
      );
      _safeNotify();
      return null;
    } catch (error) {
      return _friendlyError(error);
    }
  }

  Future<void> toggleRecording() async {
    final sourceId = focusedSourceId;
    if (sourceId == null || isRestarting(sourceId)) return;
    final sourceName = focusedSource?.deviceName ?? 'dispositivo seleccionado';
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
        _detail = await _repository.stopRecordingForSource(
          sourceSessionId: sourceId,
          requisitionId: requisitionId,
          sessionId: sessionId,
        );
        _recordingPhases[sourceId] = AcquisitionRecordingPhase.idle;
        _recordingStartedAt.remove(sourceId);
        _showMessage(
          'Video de $sourceName guardado.',
          sourceSessionId: sourceId,
        );
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
        _showMessage(
          'Grabación de $sourceName iniciada.',
          sourceSessionId: sourceId,
        );
      }
    } catch (error) {
      _recordingPhases[sourceId] = previousPhase;
      _showMessage(
        _friendlyError(error),
        isError: true,
        sourceSessionId: sourceId,
      );
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
    MultiMirrorLayoutMode.focused =>
      sourceId == focusedSourceId && !isRestarting(sourceId),
    MultiMirrorLayoutMode.overview =>
      sourceId == _overviewControlSourceId && !isRestarting(sourceId),
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

  void _showMessage(
    String value, {
    bool isError = false,
    Duration? duration,
    String? sourceSessionId,
  }) {
    _messageTimer?.cancel();
    _message = value;
    _messageIsError = isError;
    _messageSourceId = sourceSessionId;
    _messageTimer = Timer(
      duration ?? Duration(seconds: isError ? 4 : 2),
      _clearMessage,
    );
  }

  void _clearMessage() {
    _messageTimer?.cancel();
    _messageTimer = null;
    if (_message == null) return;
    _message = null;
    _messageIsError = false;
    _messageSourceId = null;
    _safeNotify();
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');

  void _safeNotify() {
    if (_disposed) return;
    _updateEvidenceStatusPolling();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _deviceSubscription?.cancel();
    _evidenceChangesSubscription?.cancel();
    _recordingTimer?.cancel();
    _messageTimer?.cancel();
    _evidenceStatusTimer?.cancel();
    unawaited(close());
    super.dispose();
  }
}
