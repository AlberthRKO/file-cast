import 'dart:async';
import 'dart:io';

import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/core/adb/adb_models.dart';
import 'package:file_cast/domain/models/acquisition.dart';
import 'package:flutter/services.dart';

class AndroidAcquisitionPlatformService {
  AndroidAcquisitionPlatformService({required AdbClient adbClient})
    : _adbClient = adbClient {
    if (Platform.isAndroid) {
      _usbSubscription = _adbClient.onUsbEvent.listen(_handleUsbEvent);
    }
  }

  static const _serverAsset = 'assets/scrcpy/scrcpy-server-v2.7.jar';
  static const _serverRemotePath = '/data/local/tmp/scrcpy-server.jar';
  final AdbClient _adbClient;
  AcquisitionMirrorSession? _activeSession;
  AcquisitionMirrorSession? _restartableSingleSession;
  AcquisitionConnectionSession? _activeConnection;
  final Map<String, AcquisitionMirrorSession> _multiSessions = {};
  int? _latestVideoWidth;
  int? _latestVideoHeight;
  Future<AcquisitionMirrorSession>? _connectOperation;
  Future<void>? _disconnectOperation;
  Future<void> _multiLifecycleTail = Future<void>.value();
  StreamSubscription<UsbEvent>? _usbSubscription;
  String _serverLogHistory = '';
  final StreamController<void> _deviceChangesController =
      StreamController<void>.broadcast();
  final StreamController<FileTransferProgress> _fileTransferController =
      StreamController<FileTransferProgress>.broadcast();

  Stream<void> get deviceChanges => _deviceChangesController.stream;
  Stream<FileTransferProgress> get fileTransferProgress =>
      _fileTransferController.stream;

  Future<AcquisitionAvailability> getAvailability() async {
    if (!Platform.isAndroid) return AcquisitionAvailability.unsupported;
    // The manifest feature is only an OEM capability hint. Real enumeration
    // is authoritative: several devices expose MTP/ADB while omitting the
    // android.hardware.usb.host declaration.
    return AcquisitionAvailability.available;
  }

  Future<List<AcquisitionDevice>> getDevices() async {
    if (!Platform.isAndroid) return const [];
    final devices = await _adbClient.getConnectedDevices();
    final mapped = devices.map(_toDomain).toList();
    mapped.sort(
      (left, right) => left.connectionLabel.compareTo(right.connectionLabel),
    );
    return List.unmodifiable(mapped);
  }

  Future<bool?> requestPermission(String deviceId) {
    return _adbClient.requestPermission(deviceId);
  }

  Future<AcquisitionMirrorSession> connectAndStart({
    required AcquisitionDevice device,
    required String requisitionId,
    required String sessionId,
  }) {
    final running = _connectOperation;
    if (running != null) return running;
    final operation = _connectAndStart(
      device: device,
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    _connectOperation = operation;
    return operation.whenComplete(() {
      if (identical(_connectOperation, operation)) _connectOperation = null;
    });
  }

  Future<AcquisitionMirrorSession> _connectAndStart({
    required AcquisitionDevice device,
    required String requisitionId,
    required String sessionId,
  }) async {
    _ensureAdbDevice(device);
    await _awaitPendingDisconnect();
    final reusable = await activeSession(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    if (reusable != null && reusable.usbDeviceId == device.id) return reusable;

    await connectForTransfer(
      device: device,
      requisitionId: requisitionId,
      sessionId: sessionId,
    );

    final serverData = await rootBundle.load(_serverAsset);
    final stagingDirectory = await Directory.systemTemp.createTemp(
      'file_cast_scrcpy_',
    );
    final serverFile = File('${stagingDirectory.path}/scrcpy-server.jar');
    try {
      await serverFile.writeAsBytes(
        serverData.buffer.asUint8List(
          serverData.offsetInBytes,
          serverData.lengthInBytes,
        ),
        flush: true,
      );
      final pushed = await _adbClient.pushFile(
        serverFile.path,
        _serverRemotePath,
      );
      if (!pushed) throw StateError('No se pudo preparar scrcpy en el equipo.');
    } finally {
      try {
        await stagingDirectory.delete(recursive: true);
      } on FileSystemException {
        // El directorio temporal será limpiado por el sistema operativo.
      }
    }

    try {
      await _adbClient.shellCommand(
        'pkill -f scrcpy.Server 2>/dev/null; sleep 0.5',
      );
    } on PlatformException {
      // Es normal cuando no existe una sesión anterior.
    }

    final targetSize = await _adbClient.getDeviceScreenSize();
    final longestTargetEdge = targetSize == null
        ? null
        : targetSize.$1 > targetSize.$2
        ? targetSize.$1
        : targetSize.$2;
    final (video, textureId) = await _startSingleMirrorWithFallback(
      longestTargetEdge: longestTargetEdge,
    );
    final controlStreamId = video['controlLocalId'] as int;
    final width = video['width'] as int;
    final height = video['height'] as int;

    final effectiveWidth = _latestVideoWidth ?? width;
    final effectiveHeight = _latestVideoHeight ?? height;

    final session = AcquisitionMirrorSession(
      requisitionId: requisitionId,
      sessionId: sessionId,
      deviceName: video['deviceName'] as String? ?? device.name,
      usbDeviceId: device.id,
      textureId: textureId,
      controlStreamId: controlStreamId,
      videoWidth: effectiveWidth,
      videoHeight: effectiveHeight,
    );
    _activeSession = session;
    _restartableSingleSession = session;
    return session;
  }

  Future<AcquisitionConnectionSession> connectForTransfer({
    required AcquisitionDevice device,
    required String requisitionId,
    required String sessionId,
  }) async {
    if (!device.supportsAdb && !device.supportsMtp) {
      throw StateError('El dispositivo no expone ADB ni MTP/PTP.');
    }
    await _awaitPendingDisconnect();
    final reusable = await activeConnection(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    if (reusable != null && reusable.usbDeviceId == device.id) return reusable;

    _activeSession = null;
    _restartableSingleSession = null;
    _activeConnection = null;
    await _resetNativeSession();
    if (device.supportsMtp && !device.supportsAdb) {
      await _adbClient
          .connectMtp(device.id)
          .timeout(const Duration(seconds: 95));
    } else {
      final connection = await _adbClient
          .connectAdb(device.id)
          .timeout(const Duration(seconds: 45));
      if (connection == null)
        throw StateError('ADB no confirmó la conexión con el dispositivo.');
    }
    final session = AcquisitionConnectionSession(
      requisitionId: requisitionId,
      sessionId: sessionId,
      deviceName: device.name,
      usbDeviceId: device.id,
      transport: device.supportsMtp && !device.supportsAdb ? 'mtp' : 'adb',
    );
    _activeConnection = session;
    return session;
  }

  Future<AcquisitionMultiMirrorSession> connectAndStartMulti({
    required List<AcquisitionDevice> devices,
    required String requisitionId,
    required String sessionId,
  }) => _serializeMultiLifecycle(
    () => _connectAndStartMulti(
      devices: devices,
      requisitionId: requisitionId,
      sessionId: sessionId,
    ),
  );

  Future<AcquisitionMultiMirrorSession> _connectAndStartMulti({
    required List<AcquisitionDevice> devices,
    required String requisitionId,
    required String sessionId,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'El mirror múltiple solo está disponible en Android.',
      );
    }
    if (devices.isEmpty)
      throw StateError('Selecciona al menos un dispositivo ADB.');
    for (final device in devices) {
      _ensureAdbDevice(device);
    }
    // A retry or a new acquisition session must not leave the previous
    // registry entries, decoders or textures consuming the inspector.
    await _disconnectMulti();
    final started = <AcquisitionMirrorSession>[];
    final startedSourceIds = <String>{};
    try {
      for (var index = 0; index < devices.length; index++) {
        final device = devices[index];
        final sourceSessionId =
            'source_${index}_${device.id.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}';
        await _adbClient
            .multiConnectAdb(
              sourceSessionId: sourceSessionId,
              deviceName: device.id,
            )
            .timeout(const Duration(seconds: 95));
        startedSourceIds.add(sourceSessionId);
        await _prepareMultiServer(sourceSessionId);
        int? longestTargetEdge;
        try {
          longestTargetEdge = _longestEdgeFromWmSize(
            await _adbClient.multiShellCommand(
              sourceSessionId: sourceSessionId,
              command: 'wm size',
            ),
          );
        } on PlatformException {
          // The fallback ladder remains safe when an OEM blocks wm size.
        }
        final (video, textureId) = await _startMultiMirrorWithFallback(
          sourceSessionId: sourceSessionId,
          mirrorCount: devices.length,
          longestTargetEdge: longestTargetEdge,
        );
        final source = AcquisitionMirrorSession(
          requisitionId: requisitionId,
          sessionId: sessionId,
          sourceSessionId: sourceSessionId,
          usbDeviceId: device.id,
          deviceName: video['deviceName'] as String? ?? device.name,
          textureId: textureId,
          controlStreamId: video['controlLocalId'] as int,
          videoWidth: video['width'] as int,
          videoHeight: video['height'] as int,
        );
        _multiSessions[sourceSessionId] = source;
        started.add(source);
      }
      return AcquisitionMultiMirrorSession(
        requisitionId: requisitionId,
        sessionId: sessionId,
        sources: List.unmodifiable(started),
        maxConcurrentMirrors: started.length,
      );
    } catch (_) {
      for (final sourceId in startedSourceIds) {
        await _adbClient.multiDisconnectAdb(sourceId);
        _multiSessions.remove(sourceId);
      }
      rethrow;
    }
  }

  Future<(Map<String, dynamic>, int)> _startSingleMirrorWithFallback({
    required int? longestTargetEdge,
  }) async {
    Object? lastFailure;
    StackTrace? lastFailureStackTrace;
    final candidates = _videoMaxSizeCandidates(
      mirrorCount: 1,
      longestTargetEdge: longestTargetEdge,
    );
    for (var index = 0; index < candidates.length; index++) {
      final maxSize = candidates[index];
      int? serverShellId;
      Map<String, dynamic>? video;
      try {
        serverShellId = await _adbClient.startPersistentShell(
          _scrcpyServerCommand(maxSize: maxSize),
        );
        video = await _connectScrcpySocketsWhenReady(
          _adbClient.connectScrcpySockets,
          collectServerLog: true,
        );
        final videoStreamId = video['localId'] as int;
        final controlStreamId = video['controlLocalId'] as int;
        final width = video['width'] as int;
        final height = video['height'] as int;
        await _adbClient.setControlStream(controlStreamId, width, height);
        final textureId = await _adbClient.createMirrorTexture();
        await _adbClient.startMirror(
          width,
          height,
          videoStreamLocalId: videoStreamId,
        );
        return (video, textureId);
      } catch (error, stackTrace) {
        final retryableFailure = _isRetryableMirrorStartFailure(
          error,
          multi: false,
        );
        await _cleanupFailedSingleMirrorAttempt(
          video: video,
          serverShellId: serverShellId,
        );
        if (!retryableFailure) Error.throwWithStackTrace(error, stackTrace);
        lastFailure = error;
        lastFailureStackTrace = stackTrace;
        _serverLogHistory += _mirrorRetryDiagnostic(error, video);
        if (index < candidates.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
      }
    }
    Error.throwWithStackTrace(lastFailure!, lastFailureStackTrace!);
  }

  Future<void> _cleanupFailedSingleMirrorAttempt({
    required Map<String, dynamic>? video,
    required int? serverShellId,
  }) async {
    await _adbClient.stopMirror();
    final videoStreamId = video?['localId'] as int?;
    final controlStreamId = video?['controlLocalId'] as int?;
    if (videoStreamId != null) await _adbClient.closeStream(videoStreamId);
    if (controlStreamId != null) await _adbClient.closeStream(controlStreamId);
    if (serverShellId != null) await _adbClient.closeStream(serverShellId);
    try {
      await _adbClient.shellCommand(
        "pkill -f '[c]om.genymobile.scrcpy.Server' 2>/dev/null; sleep 1.25",
      );
    } on PlatformException {
      // The failed server may already have exited.
    }
  }

  Future<(Map<String, dynamic>, int)> _startMultiMirrorWithFallback({
    required String sourceSessionId,
    required int mirrorCount,
    required int? longestTargetEdge,
  }) async {
    Object? lastFailure;
    StackTrace? lastFailureStackTrace;
    final candidates = _videoMaxSizeCandidates(
      mirrorCount: mirrorCount,
      longestTargetEdge: longestTargetEdge,
    );
    for (var index = 0; index < candidates.length; index++) {
      try {
        await _adbClient.multiStartPersistentShell(
          sourceSessionId: sourceSessionId,
          command: _scrcpyServerCommand(maxSize: candidates[index]),
        );
        final video = await _connectScrcpySocketsWhenReady(
          () => _adbClient.multiConnectScrcpySockets(sourceSessionId),
        );
        final textureId = await _adbClient.multiCreateMirrorTexture(
          sourceSessionId,
        );
        await _adbClient.multiStartMirror(
          sourceSessionId: sourceSessionId,
          width: video['width'] as int,
          height: video['height'] as int,
          videoStreamLocalId: video['localId'] as int,
        );
        return (video, textureId);
      } catch (error, stackTrace) {
        final retryableFailure = _isRetryableMirrorStartFailure(
          error,
          multi: true,
        );
        await _adbClient.multiStopMirror(sourceSessionId);
        try {
          await _adbClient.multiShellCommand(
            sourceSessionId: sourceSessionId,
            command:
                "pkill -f '[c]om.genymobile.scrcpy.Server' 2>/dev/null; sleep 1.25",
          );
        } on PlatformException {
          // The failed server may already have exited.
        }
        if (!retryableFailure) Error.throwWithStackTrace(error, stackTrace);
        lastFailure = error;
        lastFailureStackTrace = stackTrace;
        if (index < candidates.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
      }
    }
    Error.throwWithStackTrace(lastFailure!, lastFailureStackTrace!);
  }

  bool _isRetryableMirrorStartFailure(Object error, {required bool multi}) {
    if (error is PlatformException) {
      final codecCode = multi ? 'MULTI_CODEC_ERROR' : 'CODEC_ERROR';
      if (error.code == codecCode || error.code == 'STREAM_ERROR') return true;
    }
    final message = error.toString().toLowerCase();
    return message.contains('localabstract:scrcpy') ||
        message.contains('adb stream refused a_open') ||
        message.contains('opening video socket') ||
        message.contains('opening control socket') ||
        message.contains('stream closed while reading');
  }

  String _mirrorRetryDiagnostic(
    Object error,
    Map<String, dynamic>? video,
  ) {
    final isCodecFailure =
        error is PlatformException && error.code == 'CODEC_ERROR';
    if (isCodecFailure) {
      return 'MediaCodec rechazó ${video?['width'] ?? '?'}x${video?['height'] ?? '?'}; '
          'se reintentará con menor resolución.\n';
    }
    return 'El servidor scrcpy terminó antes de publicar o completar sus sockets; '
        'se liberaron encoder, streams y decoder antes de reintentar con menor resolución.\n';
  }

  List<int?> _videoMaxSizeCandidates({
    required int mirrorCount,
    required int? longestTargetEdge,
  }) {
    final initialLimit = switch (mirrorCount) {
      // 1600 keeps portrait streams within the reliable AVC envelope of old
      // tablet decoders and materially reduces latency over phone-to-phone OTG.
      <= 1 => 1600,
      2 => 1280,
      3 => 1024,
      _ => 800,
    };
    final int? first =
        longestTargetEdge != null && longestTargetEdge <= initialLimit
        ? null
        : initialLimit;
    const qualityLadder = <int>[1600, 1280, 1024, 800, 640, 480];
    final raw = <int?>[
      first,
      ...qualityLadder.where(
        (candidate) => first == null || candidate < first,
      ),
    ];
    final candidates = <int?>[];
    for (final candidate in raw) {
      if (candidate != null &&
          longestTargetEdge != null &&
          candidate >= longestTargetEdge) {
        continue;
      }
      if (!candidates.contains(candidate)) candidates.add(candidate);
    }
    return candidates;
  }

  String _scrcpyServerCommand({required int? maxSize}) {
    final bitRate = switch (maxSize) {
      null => 8000000,
      >= 1600 => 5000000,
      >= 1280 => 4000000,
      >= 1024 => 3000000,
      >= 800 => 2500000,
      _ => 1500000,
    };
    final maxSizeArgument = maxSize == null ? '' : ' max_size=$maxSize';
    return 'CLASSPATH=$_serverRemotePath app_process / '
        'com.genymobile.scrcpy.Server 2.7 tunnel_forward=true '
        'audio=false control=true log_level=debug max_fps=30 '
        'video_bit_rate=$bitRate video_codec_options=i-frame-interval=1'
        '$maxSizeArgument';
  }

  int? _longestEdgeFromWmSize(String output) {
    final matches = RegExp(r'(\d+)x(\d+)').allMatches(output).toList();
    if (matches.isEmpty) return null;
    final match = matches.last;
    final width = int.tryParse(match.group(1)!);
    final height = int.tryParse(match.group(2)!);
    if (width == null || height == null) return null;
    return width > height ? width : height;
  }

  Future<void> _prepareMultiServer(String sourceSessionId) async {
    final serverData = await rootBundle.load(_serverAsset);
    final stagingDirectory = await Directory.systemTemp.createTemp(
      'file_cast_multi_scrcpy_',
    );
    final serverFile = File('${stagingDirectory.path}/scrcpy-server.jar');
    try {
      await serverFile.writeAsBytes(
        serverData.buffer.asUint8List(
          serverData.offsetInBytes,
          serverData.lengthInBytes,
        ),
        flush: true,
      );
      final pushed = await _adbClient.multiPushFile(
        sourceSessionId: sourceSessionId,
        localPath: serverFile.path,
        remotePath: _serverRemotePath,
      );
      if (!pushed)
        throw StateError('No se pudo preparar scrcpy en el equipo objetivo.');
    } finally {
      try {
        await stagingDirectory.delete(recursive: true);
      } on FileSystemException {
        // El sistema limpiará el directorio temporal.
      }
    }
    try {
      await _adbClient.multiShellCommand(
        sourceSessionId: sourceSessionId,
        command: 'pkill -f scrcpy.Server 2>/dev/null; sleep 0.5',
      );
    } on PlatformException {
      // Es normal cuando no existe una sesión anterior.
    }
  }

  Future<Map<String, dynamic>> _connectScrcpySocketsWhenReady(
    Future<Map<String, dynamic>> Function() connect, {
    bool collectServerLog = false,
  }) async {
    // The shell A_OPEN only confirms that app_process was launched. Poll early
    // for fast targets, but keep a bounded backoff for slower OEMs until the
    // scrcpy abstract socket is actually published.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    Object? lastError;
    StackTrace? lastStackTrace;
    const retryDelays = [
      Duration(milliseconds: 250),
      Duration(milliseconds: 400),
      Duration(milliseconds: 650),
      Duration(seconds: 1),
      Duration(milliseconds: 1500),
    ];
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      try {
        return await connect();
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (collectServerLog) await _collectServerLog();
        if (attempt == retryDelays.length) break;
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<void> _collectServerLog() async {
    final serverLog = await _adbClient.getServerLog();
    if (serverLog.trim().isEmpty ||
        serverLog == '(server shell not started)' ||
        serverLog == '(stream closed)') {
      return;
    }
    _serverLogHistory += serverLog;
    if (!serverLog.endsWith('\n')) _serverLogHistory += '\n';
    if (_serverLogHistory.length > 16000) {
      _serverLogHistory = _serverLogHistory.substring(
        _serverLogHistory.length - 16000,
      );
    }
  }

  Future<List<AcquisitionMirrorSession>> activeMultiSessions({
    required String requisitionId,
    required String sessionId,
  }) async => _multiSessions.values
      .where(
        (source) =>
            source.requisitionId == requisitionId &&
            source.sessionId == sessionId,
      )
      .toList(growable: false);

  Future<AcquisitionMirrorSession> restartMirror() async {
    final current = _activeSession ?? _restartableSingleSession;
    if (current == null) {
      throw StateError('No existe un mirror individual activo para recargar.');
    }
    final usbDeviceId = current.usbDeviceId;
    if (usbDeviceId == null || usbDeviceId.isEmpty) {
      throw StateError('No se pudo identificar el dispositivo USB activo.');
    }
    AcquisitionDevice? device;
    for (final candidate in await getDevices()) {
      if (candidate.id == usbDeviceId) {
        device = candidate;
        break;
      }
    }
    if (device == null) {
      throw StateError(
        'El dispositivo objetivo ya no está disponible en el puerto USB.',
      );
    }

    _activeSession = null;
    _activeConnection = null;
    try {
      return await _connectAndStart(
        device: device,
        requisitionId: current.requisitionId,
        sessionId: current.sessionId,
      );
    } catch (_) {
      _restartableSingleSession = current;
      rethrow;
    }
  }

  Future<AcquisitionMirrorSession> restartMultiMirrorSource(
    String sourceSessionId,
  ) => _serializeMultiLifecycle(
    () => _restartMultiMirrorSource(sourceSessionId),
  );

  Future<AcquisitionMirrorSession> _restartMultiMirrorSource(
    String sourceSessionId,
  ) async {
    final current = _multiSessions[sourceSessionId];
    if (current == null) {
      throw StateError('El mirror seleccionado ya no está conectado.');
    }

    final usbDeviceId = current.usbDeviceId;
    if (usbDeviceId == null || usbDeviceId.isEmpty) {
      throw StateError(
        'No se pudo identificar el dispositivo USB seleccionado.',
      );
    }

    // A rejected localabstract:scrcpy socket may leave both the native stream
    // registry and the server shell stale. Rebuild only this source transport;
    // the other mirrors remain active and the persistent RSA key is reused.
    await _adbClient.multiDisconnectAdb(sourceSessionId);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _adbClient
        .multiConnectAdb(
          sourceSessionId: sourceSessionId,
          deviceName: usbDeviceId,
        )
        .timeout(const Duration(seconds: 35));
    await _prepareMultiServer(sourceSessionId);

    int? longestTargetEdge;
    try {
      longestTargetEdge = _longestEdgeFromWmSize(
        await _adbClient.multiShellCommand(
          sourceSessionId: sourceSessionId,
          command: 'wm size',
        ),
      );
    } on PlatformException {
      // La escalera de resolución también funciona sin consultar wm size.
    }
    final (video, textureId) = await _startMultiMirrorWithFallback(
      sourceSessionId: sourceSessionId,
      mirrorCount: _multiSessions.length,
      longestTargetEdge: longestTargetEdge,
    );
    final restarted = AcquisitionMirrorSession(
      requisitionId: current.requisitionId,
      sessionId: current.sessionId,
      sourceSessionId: current.sourceSessionId,
      usbDeviceId: current.usbDeviceId,
      deviceName: video['deviceName'] as String? ?? current.deviceName,
      textureId: textureId,
      controlStreamId: video['controlLocalId'] as int,
      videoWidth: video['width'] as int,
      videoHeight: video['height'] as int,
    );
    _multiSessions[sourceSessionId] = restarted;
    _deviceChangesController.add(null);
    return restarted;
  }

  Future<void> disconnectMulti({String? sourceSessionId}) =>
      _serializeMultiLifecycle(
        () => _disconnectMulti(sourceSessionId: sourceSessionId),
      );

  Future<void> _disconnectMulti({String? sourceSessionId}) async {
    final ids = sourceSessionId == null
        ? _multiSessions.keys.toList(growable: false)
        : [sourceSessionId];
    for (final id in ids) {
      try {
        await _adbClient.multiDisconnectAdb(id);
      } finally {
        _multiSessions.remove(id);
      }
    }
  }

  Future<T> _serializeMultiLifecycle<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final scheduled = _multiLifecycleTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _multiLifecycleTail = scheduled;
    return completer.future;
  }

  Future<void> sendTouchToSource(
    String sourceSessionId,
    int action,
    int pointerId,
    int x,
    int y,
  ) => _adbClient.multiSendTouch(
    sourceSessionId: sourceSessionId,
    action: action,
    pointerId: pointerId,
    x: x,
    y: y,
  );

  Future<void> sendScrollToSource(
    String sourceSessionId,
    int x,
    int y,
    int deltaY,
  ) => _adbClient.multiSendScroll(
    sourceSessionId: sourceSessionId,
    x: x,
    y: y,
    deltaY: deltaY,
  );

  Future<void> sendKeyToSource(String sourceSessionId, int keycode) async {
    await _adbClient.multiSendKey(
      sourceSessionId: sourceSessionId,
      action: 0,
      keycode: keycode,
    );
    await _adbClient.multiSendKey(
      sourceSessionId: sourceSessionId,
      action: 1,
      keycode: keycode,
    );
  }

  Future<CapturedEvidence> captureScreenshotForSource({
    required String sourceSessionId,
    required String requisitionId,
    required String sessionId,
  }) async => _mapEvidence(
    await _adbClient.multiCaptureScreenshot(
      sourceSessionId: sourceSessionId,
      requisitionId: requisitionId,
      sessionId: sessionId,
    ),
  );

  Future<CapturedEvidence> startRecordingForSource({
    required String sourceSessionId,
    required String requisitionId,
    required String sessionId,
  }) async => _mapEvidence(
    await _adbClient.multiStartScreenRecording(
      sourceSessionId: sourceSessionId,
      requisitionId: requisitionId,
      sessionId: sessionId,
    ),
  );

  Future<CapturedEvidence> stopRecordingForSource(
    String sourceSessionId,
  ) async =>
      _mapEvidence(await _adbClient.multiStopScreenRecording(sourceSessionId));

  Future<String> getMultiControlDiagnostics(String sourceSessionId) async =>
      (await _adbClient.multiGetMirrorLog(sourceSessionId))['log'] as String? ??
      '';

  Future<AcquisitionConnectionSession?> activeConnection({
    required String requisitionId,
    required String sessionId,
  }) async {
    final current = _activeConnection;
    if (current?.requisitionId != requisitionId ||
        current?.sessionId != sessionId) {
      return null;
    }
    if (current?.transport == 'mtp') {
      if (await _adbClient.isMtpConnected(current!.usbDeviceId ?? ''))
        return current;
    } else {
      final state = await _adbClient.getAdbState();
      if (state?['connected'] == true) return current;
    }
    _activeConnection = null;
    _activeSession = null;
    return null;
  }

  Future<AcquisitionMirrorSession?> activeSession({
    required String requisitionId,
    required String sessionId,
  }) async {
    final current = _activeSession;
    if (current?.requisitionId != requisitionId ||
        current?.sessionId != sessionId) {
      return null;
    }
    final state = await _adbClient.getAdbState();
    if (state?['connected'] == true) return current;
    _activeSession = null;
    return null;
  }

  Future<CapturedEvidence> captureScreenshot({
    required String requisitionId,
    required String sessionId,
  }) async {
    final result = await _adbClient.captureScreenshot(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    return CapturedEvidence(
      name: result['name'] as String,
      localPath: result['path'] as String,
      byteLength: result['byteLength'] as int,
      sha256: result['sha256'] as String,
      createdAt: DateTime.now(),
    );
  }

  Future<CapturedEvidence> startRecording({
    required String requisitionId,
    required String sessionId,
  }) async {
    final result = await _adbClient.startScreenRecording(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    return _mapEvidence(result);
  }

  Future<CapturedEvidence> stopRecording() async {
    return _mapEvidence(await _adbClient.stopScreenRecording());
  }

  CapturedEvidence _mapEvidence(Map<String, dynamic> result) {
    return CapturedEvidence(
      name: result['name'] as String,
      localPath: result['path'] as String,
      byteLength: result['byteLength'] as int? ?? 0,
      sha256: result['sha256'] as String? ?? '',
      createdAt: DateTime.now(),
    );
  }

  Future<void> disconnect() {
    final running = _disconnectOperation;
    if (running != null) return running;
    final operation = _disconnectAndReset();
    _disconnectOperation = operation;
    return operation.whenComplete(() {
      if (identical(_disconnectOperation, operation)) {
        _disconnectOperation = null;
      }
    });
  }

  Future<void> _disconnectAndReset() async {
    _activeSession = null;
    _restartableSingleSession = null;
    _activeConnection = null;
    await _resetNativeSession();
  }

  Future<void> _awaitPendingDisconnect() async {
    final pending = _disconnectOperation;
    if (pending != null) await pending;
  }

  Future<List<RemoteFileEntry>> listRemoteFiles(String remotePath) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'La transferencia ADB solo está disponible en Android.',
      );
    }
    final entries = remotePath.startsWith('mtp:')
        ? await _adbClient.listMtpFiles(remotePath)
        : await _adbClient.listRemoteFiles(remotePath);
    return entries.map(_mapRemoteFile).toList(growable: false);
  }

  Future<FileTransferResult> transferRemoteFiles({
    required String requisitionId,
    required String sessionId,
    required List<RemoteFileEntry> files,
  }) async {
    final transferId = 'transfer_${DateTime.now().microsecondsSinceEpoch}';
    final result = _activeConnection?.transport == 'mtp'
        ? await _adbClient.pullMtpFiles(
            requisitionId: requisitionId,
            sessionId: sessionId,
            transferId: transferId,
            remotePaths: files.map((file) => file.path).toList(growable: false),
          )
        : await _adbClient.pullRemoteFiles(
            requisitionId: requisitionId,
            sessionId: sessionId,
            transferId: transferId,
            remotePaths: files.map((file) => file.path).toList(growable: false),
          );
    final rawFiles = result['files'];
    final captured = rawFiles is List
        ? rawFiles
              .whereType<Map>()
              .map((raw) {
                final map = raw.map(
                  (key, value) => MapEntry(key.toString(), value),
                );
                return CapturedEvidence(
                  name: map['name'] as String? ?? 'archivo',
                  localPath: map['path'] as String? ?? '',
                  byteLength: (map['byteLength'] as num?)?.toInt() ?? 0,
                  sha256: map['sha256'] as String? ?? '',
                  createdAt: DateTime.now(),
                  sourcePath: map['remotePath'] as String?,
                );
              })
              .toList(growable: false)
        : const <CapturedEvidence>[];
    final rawFailures = result['failures'];
    final failures = rawFailures is List
        ? rawFailures
              .whereType<Map>()
              .map((raw) {
                return FileTransferFailure(
                  remotePath: raw['path'] as String? ?? '',
                  message:
                      raw['message'] as String? ?? 'No se pudo transferir.',
                );
              })
              .toList(growable: false)
        : const <FileTransferFailure>[];
    return FileTransferResult(
      files: captured,
      failures: failures,
      cancelled: result['cancelled'] as bool? ?? false,
    );
  }

  Future<String> prepareRemoteFilePreview({
    required String requisitionId,
    required String sessionId,
    required RemoteFileEntry file,
  }) async {
    final result = _activeConnection?.transport == 'mtp'
        ? await _adbClient.pullMtpFiles(
            requisitionId: requisitionId,
            sessionId: sessionId,
            transferId: 'preview_${DateTime.now().microsecondsSinceEpoch}',
            remotePaths: [file.path],
            previewOnly: true,
          )
        : await _adbClient.pullRemoteFiles(
            requisitionId: requisitionId,
            sessionId: sessionId,
            transferId: 'preview_${DateTime.now().microsecondsSinceEpoch}',
            remotePaths: [file.path],
            previewOnly: true,
            timeoutMs: 120000,
          );
    final rawFiles = result['files'];
    if (rawFiles is! List || rawFiles.isEmpty || rawFiles.first is! Map) {
      final failures = result['failures'];
      if (failures is List && failures.isNotEmpty && failures.first is Map) {
        final message = (failures.first as Map)['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          throw StateError(message);
        }
      }
      if (result['cancelled'] == true) {
        throw StateError('Se canceló la copia para la vista previa.');
      }
      throw StateError('No se pudo preparar la vista previa.');
    }
    final fileMap = (rawFiles.first as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final localPath = fileMap['path'] as String?;
    if (localPath == null || localPath.isEmpty) {
      throw StateError('La vista previa no devolvió un archivo local.');
    }
    return localPath;
  }

  Future<void> discardRemoteFilePreview({
    required String requisitionId,
    required String sessionId,
  }) => _adbClient.discardRemoteFilePreview(
    requisitionId: requisitionId,
    sessionId: sessionId,
  );

  Future<void> cancelFileTransfer() => _activeConnection?.transport == 'mtp'
      ? _adbClient.cancelMtpTransfer()
      : _adbClient.cancelFileTransfer();

  RemoteFileEntry _mapRemoteFile(Map<String, dynamic> map) {
    final name = map['name'] as String? ?? '';
    final isDirectory = map['isDirectory'] as bool? ?? false;
    final isRegular = map['isRegularFile'] as bool? ?? false;
    return RemoteFileEntry(
      path: map['path'] as String? ?? '',
      name: name,
      byteLength: (map['byteLength'] as num?)?.toInt() ?? 0,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        ((map['modifiedAtSeconds'] as num?)?.toInt() ?? 0) * 1000,
      ),
      kind: isDirectory ? RemoteFileKind.directory : _kindForName(name),
      isSelectable: isRegular,
    );
  }

  RemoteFileKind _kindForName(String name) {
    final extension = name.toLowerCase().split('.').last;
    if (const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'heic',
      'bmp',
    }.contains(extension)) {
      return RemoteFileKind.image;
    }
    if (const {
      'mp4',
      'mkv',
      'mov',
      'avi',
      'webm',
      '3gp',
      'm4v',
      'ts',
      'mts',
      'm2ts',
      'flv',
      'wmv',
    }.contains(extension)) {
      return RemoteFileKind.video;
    }
    if (const {
      'mp3',
      'wav',
      'aac',
      'm4a',
      'ogg',
      'oga',
      'opus',
      'flac',
      'amr',
    }.contains(extension)) {
      return RemoteFileKind.audio;
    }
    if (const {
      'pdf',
      'doc',
      'docx',
      'docm',
      'xls',
      'xlsx',
      'xlsm',
      'ppt',
      'pptx',
      'pptm',
      'rtf',
      'txt',
      'csv',
      'tsv',
      'json',
      'xml',
      'log',
    }.contains(extension)) {
      return RemoteFileKind.document;
    }
    return RemoteFileKind.other;
  }

  Future<void> _resetNativeSession() async {
    _serverLogHistory = '';
    _latestVideoWidth = null;
    _latestVideoHeight = null;
    await _adbClient.disconnectMtp();
    await _adbClient.stopMirror();
    await _adbClient.disconnectAdb();
  }

  void _handleUsbEvent(UsbEvent event) {
    final transfer = event.fileTransferInfo;
    if (transfer != null) {
      _fileTransferController.add(_mapTransferProgress(transfer));
      return;
    }
    final mirrorState = event.mirrorStateInfo;
    if (mirrorState?['state'] == 'video_size') {
      final width = mirrorState?['width'] as int?;
      final height = mirrorState?['height'] as int?;
      if (width != null && height != null) {
        _latestVideoWidth = width;
        _latestVideoHeight = height;
      }
      final current = _activeSession;
      if (width != null && height != null && current != null) {
        _activeSession = AcquisitionMirrorSession(
          requisitionId: current.requisitionId,
          sessionId: current.sessionId,
          sourceSessionId: current.sourceSessionId,
          usbDeviceId: current.usbDeviceId,
          deviceName: current.deviceName,
          textureId: current.textureId,
          controlStreamId: current.controlStreamId,
          videoWidth: width,
          videoHeight: height,
        );
      }
      _deviceChangesController.add(null);
      return;
    }
    final multiState = event.multiSessionInfo;
    if (event.type == UsbEventType.multiMirrorState && multiState != null) {
      final sourceId = multiState['sourceSessionId'] as String?;
      final width = multiState['width'] as int?;
      final height = multiState['height'] as int?;
      final current = sourceId == null ? null : _multiSessions[sourceId];
      if (sourceId != null &&
          current != null &&
          width != null &&
          height != null) {
        _multiSessions[sourceId] = AcquisitionMirrorSession(
          requisitionId: current.requisitionId,
          sessionId: current.sessionId,
          sourceSessionId: current.sourceSessionId,
          usbDeviceId: current.usbDeviceId,
          deviceName: current.deviceName,
          textureId: current.textureId,
          controlStreamId: current.controlStreamId,
          videoWidth: width,
          videoHeight: height,
        );
      }
      _deviceChangesController.add(null);
      return;
    }
    if (event.type == UsbEventType.multiSessionState) {
      final sourceId = event.multiSessionInfo?['sourceSessionId'] as String?;
      if (sourceId != null) _multiSessions.remove(sourceId);
      _deviceChangesController.add(null);
      return;
    }
    if (event.type == UsbEventType.deviceDetached ||
        (event.type == UsbEventType.mirrorState &&
            mirrorState?['state'] == 'error')) {
      final detachedDevice = event.devices.isEmpty ? null : event.devices.first;
      final matchesActive =
          detachedDevice == null ||
          detachedDevice.deviceName == _activeSession?.usbDeviceId ||
          detachedDevice.deviceName == _activeConnection?.usbDeviceId;
      if (matchesActive) {
        _activeSession = null;
        _restartableSingleSession = null;
        _activeConnection = null;
        unawaited(_resetNativeSession());
      }
    }
    _deviceChangesController.add(null);
  }

  FileTransferProgress _mapTransferProgress(Map<String, dynamic> map) {
    final rawPhase = map['state'] as String? ?? 'idle';
    final phase = FileTransferPhase.values.firstWhere(
      (value) => value.name == rawPhase,
      orElse: () => FileTransferPhase.error,
    );
    int number(String key) => (map[key] as num?)?.toInt() ?? 0;
    return FileTransferProgress(
      transferId: map['transferId'] as String? ?? '',
      phase: phase,
      fileName: map['fileName'] as String?,
      fileIndex: number('fileIndex'),
      fileCount: number('fileCount'),
      fileBytes: number('fileBytes'),
      fileTotalBytes: number('fileTotalBytes'),
      batchBytes: number('batchBytes'),
      batchTotalBytes: number('batchTotalBytes'),
      message: map['message'] as String?,
    );
  }

  Future<void> sendTouch(int action, int pointerId, int x, int y) {
    final session = _activeSession;
    if (session == null) return Future.value();
    return _adbClient.sendTouch(
      action,
      pointerId,
      x,
      y,
      session.videoWidth,
      session.videoHeight,
    );
  }

  Future<void> sendScroll(int x, int y, int deltaY) {
    final session = _activeSession;
    if (session == null || deltaY == 0) return Future.value();
    final fixedPointDelta = deltaY.isNegative ? 0x7FFF : -0x7FFF;
    return _adbClient.sendScroll(
      x,
      y,
      0,
      fixedPointDelta,
      session.videoWidth,
      session.videoHeight,
    );
  }

  Future<String> getControlDiagnostics() async {
    final diagnostics = await _adbClient.getMirrorDiagnostics();
    await _collectServerLog();
    final nativeLog = diagnostics['log'] as String? ?? '';
    final result = StringBuffer(nativeLog);
    if (_serverLogHistory.isNotEmpty) {
      result
        ..writeln('--- SCRCPY SERVER ---')
        ..write(_serverLogHistory);
    }
    return result.toString().trim();
  }

  Future<void> sendBack() => _adbClient.sendBack();
  Future<void> sendHome() => _adbClient.sendHome();
  Future<void> sendAppSwitch() => _adbClient.sendAppSwitch();

  Future<String> getConnectionDiagnostics() => _adbClient.getAdbLog();

  AcquisitionDevice _toDomain(UsbDeviceInfo device) => AcquisitionDevice(
    id: device.deviceName,
    name: device.displayName,
    hasPermission: device.hasPermission,
    vendorId: device.vendorId,
    productId: device.productId,
    deviceType: device.deviceType,
    supportsAdb: device.hasAdbInterface,
    connectionLabel: _usbConnectionLabel(device.deviceName),
    interfaceSummary: device.interfaceSummary,
    serialNumber: device.serialNumber,
  );

  String _usbConnectionLabel(String deviceName) {
    final segments = deviceName
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (segments.length >= 2) {
      return 'USB ${segments[segments.length - 2]}/${segments.last}';
    }
    return deviceName.isEmpty ? 'USB sin dirección' : deviceName;
  }

  void _ensureAdbDevice(AcquisitionDevice device) {
    if (!device.supportsAdb) {
      throw StateError(
        'NO_ADB_INTERFACE: El periférico ${device.name} fue enumerado '
        'como ${device.deviceType}, pero no expone la interfaz ADB.',
      );
    }
  }
}
