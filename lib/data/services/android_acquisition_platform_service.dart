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
  AcquisitionConnectionSession? _activeConnection;
  int? _latestVideoWidth;
  int? _latestVideoHeight;
  Future<AcquisitionMirrorSession>? _connectOperation;
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
    return await _adbClient.isOtgSupported()
        ? AcquisitionAvailability.available
        : AcquisitionAvailability.unsupported;
  }

  Future<List<AcquisitionDevice>> getDevices() async {
    if (!Platform.isAndroid) return const [];
    final devices = await _adbClient.getConnectedDevices();
    return devices.map(_toDomain).toList(growable: false);
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
    final reusable = await activeSession(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    if (reusable != null) return reusable;

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

    await _adbClient.startPersistentShell(
      'CLASSPATH=$_serverRemotePath app_process / '
      'com.genymobile.scrcpy.Server 2.7 tunnel_forward=true '
      'audio=false control=true log_level=debug max_fps=30 video_bit_rate=8000000',
    );
    await Future<void>.delayed(const Duration(seconds: 2));

    final video = await _adbClient.connectScrcpySockets();
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

    final effectiveWidth = _latestVideoWidth ?? width;
    final effectiveHeight = _latestVideoHeight ?? height;

    final session = AcquisitionMirrorSession(
      requisitionId: requisitionId,
      sessionId: sessionId,
      deviceName: video['deviceName'] as String? ?? device.name,
      textureId: textureId,
      controlStreamId: controlStreamId,
      videoWidth: effectiveWidth,
      videoHeight: effectiveHeight,
    );
    _activeSession = session;
    return session;
  }

  Future<AcquisitionConnectionSession> connectForTransfer({
    required AcquisitionDevice device,
    required String requisitionId,
    required String sessionId,
  }) async {
    final reusable = await activeConnection(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    if (reusable != null) return reusable;

    _activeSession = null;
    _activeConnection = null;
    await _resetNativeSession();
    final connection = await _adbClient
        .connectAdb(device.id)
        .timeout(const Duration(seconds: 45));
    if (connection == null) {
      throw StateError('ADB no confirmó la conexión con el dispositivo.');
    }
    final session = AcquisitionConnectionSession(
      requisitionId: requisitionId,
      sessionId: sessionId,
      deviceName: device.name,
    );
    _activeConnection = session;
    return session;
  }

  Future<AcquisitionConnectionSession?> activeConnection({
    required String requisitionId,
    required String sessionId,
  }) async {
    final current = _activeConnection;
    if (current?.requisitionId != requisitionId ||
        current?.sessionId != sessionId) {
      return null;
    }
    final state = await _adbClient.getAdbState();
    if (state?['connected'] == true) return current;
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

  Future<void> disconnect() async {
    _activeSession = null;
    _activeConnection = null;
    await _resetNativeSession();
  }

  Future<List<RemoteFileEntry>> listRemoteFiles(String remotePath) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'La transferencia ADB solo está disponible en Android.',
      );
    }
    final entries = await _adbClient.listRemoteFiles(remotePath);
    return entries.map(_mapRemoteFile).toList(growable: false);
  }

  Future<FileTransferResult> transferRemoteFiles({
    required String requisitionId,
    required String sessionId,
    required List<RemoteFileEntry> files,
  }) async {
    final transferId = 'transfer_${DateTime.now().microsecondsSinceEpoch}';
    final result = await _adbClient.pullRemoteFiles(
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
    final result = await _adbClient.pullRemoteFiles(
      requisitionId: requisitionId,
      sessionId: sessionId,
      transferId: 'preview_${DateTime.now().microsecondsSinceEpoch}',
      remotePaths: [file.path],
      previewOnly: true,
      timeoutMs: 120000,
    );
    final rawFiles = result['files'];
    if (rawFiles is! List || rawFiles.isEmpty || rawFiles.first is! Map) {
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

  Future<void> cancelFileTransfer() => _adbClient.cancelFileTransfer();

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
    if (const {'mp4', 'mkv', 'mov', 'avi', 'webm', '3gp'}.contains(extension)) {
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
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'txt',
      'csv',
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
    if (event.type == UsbEventType.deviceDetached ||
        (event.type == UsbEventType.mirrorState &&
            mirrorState?['state'] == 'error')) {
      _activeSession = null;
      _activeConnection = null;
      unawaited(_resetNativeSession());
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
    final serverLog = await _adbClient.getServerLog();
    if (serverLog.trim().isNotEmpty &&
        serverLog != '(server shell not started)' &&
        serverLog != '(stream closed)') {
      _serverLogHistory += serverLog;
      if (!serverLog.endsWith('\n')) _serverLogHistory += '\n';
      if (_serverLogHistory.length > 16000) {
        _serverLogHistory = _serverLogHistory.substring(
          _serverLogHistory.length - 16000,
        );
      }
    }
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

  AcquisitionDevice _toDomain(UsbDeviceInfo device) => AcquisitionDevice(
    id: device.deviceName,
    name: device.displayName,
    hasPermission: device.hasPermission,
    vendorId: device.vendorId,
    productId: device.productId,
  );
}
