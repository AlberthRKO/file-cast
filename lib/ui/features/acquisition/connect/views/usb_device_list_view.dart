import 'dart:async';
import 'dart:io';

import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/core/adb/adb_models.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/navigation/route_args/mirror_route_args.dart';
import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class UsbDeviceListRoute extends StatelessWidget {
  const UsbDeviceListRoute({
    required this.requisitionId,
    required this.sessionId,
    super.key,
  });

  final String requisitionId;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return UsbDeviceListView(
      adbClient: context.read<AdbClient>(),
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
  }
}

class UsbDeviceListView extends StatefulWidget {
  const UsbDeviceListView({
    required this.adbClient,
    required this.requisitionId,
    required this.sessionId,
    super.key,
  });

  final AdbClient adbClient;
  final String requisitionId;
  final String sessionId;

  @override
  State<UsbDeviceListView> createState() => _UsbDeviceListViewState();
}

class _UsbDeviceListViewState extends State<UsbDeviceListView> {
  AdbClient get _adbClient => widget.adbClient;
  List<UsbDeviceInfo> _devices = [];
  bool _isOtgSupported = false;
  bool _isLoading = true;
  StreamSubscription<UsbEvent>? _usbSubscription;

  // ADB connection state
  String _adbState = 'disconnected';
  String? _adbMessage;
  String? _connectingDeviceName;
  String _adbLog = '';

  // Shell command state
  String _shellOutput = '';
  bool _shellRunning = false;
  String _shellCommand = 'echo hola';
  final TextEditingController _shellCommandController = TextEditingController(
    text: 'echo hola',
  );

  // Phase 4 - scrcpy push/execute state
  String _scrcpyOutput = '';
  bool _scrcpyRunning = false;

  // Phase 6 - mirror state
  int? _mirrorTextureId;
  bool _mirrorStarted = false;
  int? _videoStreamLocalId;
  int? _controlLocalId;
  int? _videoWidth;
  int? _videoHeight;
  String _mirrorLog = '';
  Timer? _mirrorLogTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // iOS no registra el canal USB/ADB nativo: evitar invocarlo y mostrar una
    // capacidad honesta en vez de tratarlo como fallo de OTG.
    if (Platform.isIOS) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _isOtgSupported = await _adbClient.isOtgSupported();
    _devices = await _adbClient.getConnectedDevices();
    if (!mounted) return;

    _usbSubscription = _adbClient.onUsbEvent.listen((event) {
      if (!mounted) return;
      setState(() {
        switch (event.type) {
          case UsbEventType.initialDevices:
          case UsbEventType.deviceAttached:
          case UsbEventType.deviceConnected:
            _devices = event.devices;
          case UsbEventType.deviceDetached:
            final detachedDevices = event.devices;
            _devices = _devices
                .where(
                  (d) => !detachedDevices.any(
                    (dd) => dd.deviceName == d.deviceName,
                  ),
                )
                .toList();
          case UsbEventType.permissionDenied:
            break;
          case UsbEventType.adbState:
            final stateInfo = event.adbStateInfo;
            if (stateInfo != null) {
              _adbState = stateInfo['state'] as String? ?? 'unknown';
              _adbMessage = stateInfo['message'] as String?;
              _adbLog = stateInfo['log'] as String? ?? '';
            }
          case UsbEventType.mirrorState:
            final mirrorInfo = event.adbStateInfo;
            if (mirrorInfo != null) {
              final state = mirrorInfo['state'] as String?;
              final msg = mirrorInfo['message'] as String?;
              if (state == 'error') {
                _scrcpyOutput += '\nMIRROR ERROR: $msg\n';
              }
            }
        }
      });
    });

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _usbSubscription?.cancel();
    _mirrorLogTimer?.cancel();
    unawaited(_adbClient.stopMirror());
    unawaited(_adbClient.disconnectAdb());
    _shellCommandController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission(UsbDeviceInfo device) async {
    if (device.hasPermission) {
      _connectToDevice(device);
      return;
    }

    final result = await _adbClient.requestPermission(device.deviceName);
    if ((result ?? false) && mounted) {
      setState(() {});
      _connectToDevice(device);
    }
  }

  Future<void> _connectToDevice(UsbDeviceInfo device) async {
    setState(() {
      _adbState = 'connecting';
      _connectingDeviceName = device.displayName;
      _adbMessage = null;
      _adbLog = ''; // Clear old log for new attempt
    });

    try {
      final result = await _adbClient
          .connectAdb(device.deviceName)
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () =>
                throw TimeoutException('Timeout de conexion ADB (45s)'),
          );
      if (result == null && mounted) {
        setState(() {
          _adbState = 'error';
          _adbMessage = 'No se pudo conectar';
        });
      }
    } on TimeoutException catch (e) {
      print('=== ADB CONNECTION TIMEOUT ===');
      print('Error: $e');
      print('=============================');
      if (mounted) {
        setState(() {
          _adbState = 'error';
          _adbMessage =
              'Timeout: el dispositivo no respondio. Verifica que Depuracion USB este activada.';
        });
      }
    } on PlatformException catch (e) {
      print('=== ADB CONNECTION ERROR ===');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
      print('===========================');
      if (mounted) {
        String friendlyMessage;
        switch (e.code) {
          case 'HANDSHAKE_TIMEOUT':
            friendlyMessage =
                'Timeout: el dispositivo no respondio en 20 segundos.';
          case 'NO_ADB_INTERFACE':
            friendlyMessage = 'No se encontro interfaz ADB en el dispositivo.';
          case 'HANDSHAKE_FAILED':
            friendlyMessage =
                'Handshake ADB fallido. Verifica que Depuracion USB este activada.';
          case 'OPEN_FAILED':
            friendlyMessage = 'No se pudo abrir el dispositivo USB.';
          case 'NO_PERMISSION':
            friendlyMessage = 'Sin permiso para acceder al dispositivo USB.';
          default:
            friendlyMessage = '${e.code}: ${e.message ?? "Error desconocido"}';
        }
        setState(() {
          _adbState = 'error';
          _adbMessage = friendlyMessage;
        });
      }
    } catch (e) {
      print('=== ADB CONNECTION EXCEPTION ===');
      print('Error: $e');
      print('================================');
      if (mounted) {
        setState(() {
          _adbState = 'error';
          _adbMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _runShellCommand() async {
    final command = _shellCommandController.text.trim();
    if (command.isEmpty) return;

    setState(() {
      _shellRunning = true;
      _shellOutput = 'Running: $command\n';
    });

    try {
      final output = await _adbClient.shellCommand(command);
      if (mounted) {
        setState(() {
          _shellOutput = 'Command: $command\n---\n$output';
          _shellRunning = false;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _shellOutput = 'Error: ${e.code}\n${e.message}';
          _shellRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shellOutput = 'Error: $e';
          _shellRunning = false;
        });
      }
    }
  }

  Future<void> _pushAndExecuteScrcpy() async {
    setState(() {
      _scrcpyRunning = true;
      _scrcpyOutput = 'Starting Phase 4: Push & Execute scrcpy-server...\n';
    });

    try {
      setState(
        () => _scrcpyOutput += '[1/4] Reading scrcpy-server from assets...\n',
      );
      final assetBytes = await _adbClient.readAsset(
        'assets/scrcpy/scrcpy-server-v2.7.jar',
      );
      if (assetBytes.isEmpty) {
        setState(() {
          _scrcpyOutput += 'ERROR: Asset is empty!\n';
          _scrcpyRunning = false;
        });
        return;
      }
      setState(() => _scrcpyOutput += '  Read ${assetBytes.length} bytes\n');

      setState(() => _scrcpyOutput += '[2/4] Writing to temp file...\n');
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/scrcpy-server.jar');
      await tempFile.writeAsBytes(assetBytes);
      setState(() => _scrcpyOutput += '  Temp: ${tempFile.path}\n');

      setState(
        () => _scrcpyOutput +=
            '[3/4] Pushing to /data/local/tmp/scrcpy-server.jar...\n',
      );
      final pushResult = await _adbClient.pushFile(
        tempFile.path,
        '/data/local/tmp/scrcpy-server.jar',
      );
      setState(() => _scrcpyOutput += '  Push success: $pushResult\n');

      if (!pushResult) {
        setState(() {
          _scrcpyOutput += 'ERROR: Push failed!\n';
          _scrcpyRunning = false;
        });
        return;
      }

      setState(
        () => _scrcpyOutput += '[4/7] Killing previous scrcpy-server...\n',
      );
      try {
        await _adbClient.shellCommand(
          'pkill -f scrcpy.Server 2>/dev/null; sleep 0.5',
        );
        setState(() => _scrcpyOutput += '  Previous server killed\n');
      } catch (_) {
        setState(() => _scrcpyOutput += '  No previous server (ok)\n');
      }

      setState(() => _scrcpyOutput += '[5/7] Executing scrcpy-server...\n');
      // startPersistentShell keeps the shell stream OPEN → server process stays alive
      // tunnel_forward=true: server creates LocalServerSocket and listens, we connect as client
      // audio=false, control=false: only open video socket for now
      final shellLocalId = await _adbClient.startPersistentShell(
        'CLASSPATH=/data/local/tmp/scrcpy-server.jar app_process / com.genymobile.scrcpy.Server 2.7 tunnel_forward=true audio=false control=true log_level=debug',
      );
      setState(
        () => _scrcpyOutput += '  Server shell stream: localId=$shellLocalId\n',
      );

      // Give server time to initialize + create LocalServerSocket + start accept()
      await Future.delayed(const Duration(milliseconds: 3000));

      setState(() => _scrcpyOutput += '[6/7] Connecting to video socket...\n');
      final videoInfo = await _adbClient.connectScrcpySockets();
      _videoStreamLocalId = videoInfo['localId'] as int;
      final controlLocalId = videoInfo['controlLocalId'] as int;
      _controlLocalId = controlLocalId;
      _videoWidth = videoInfo['width'] as int;
      _videoHeight = videoInfo['height'] as int;
      setState(() {
        _scrcpyOutput += '  Device: ${videoInfo['deviceName']}\n';
        _scrcpyOutput += '  Screen: ${_videoWidth}x$_videoHeight\n';
        _scrcpyOutput += '  Codec: ${videoInfo['codec']}\n';
        _scrcpyOutput += '  Control stream: localId=$controlLocalId\n';
        _scrcpyOutput += '\n--- Phase 5 SUCCESS ---\n';
      });

      // Set control stream on native side
      final controlResult = await _adbClient.setControlStream(
        controlLocalId,
        _videoWidth!,
        _videoHeight!,
      );
      final wmWidth = controlResult['wmSizeWidth'] as int? ?? 0;
      final wmHeight = controlResult['wmSizeHeight'] as int? ?? 0;
      final wmRaw = controlResult['wmSizeRaw'] as String? ?? '';
      setState(() {
        _scrcpyOutput += '  Header size: ${_videoWidth}x$_videoHeight\n';
        if (wmWidth > 0) {
          _scrcpyOutput += '  wm size: ${wmWidth}x$wmHeight\n';
          if (wmWidth != _videoWidth || wmHeight != _videoHeight) {
            _scrcpyOutput += '  *** MISMATCH: header vs wm size ***\n';
            _scrcpyOutput += '  Touch will use wm size dimensions\n';
          }
        } else if (wmRaw.isNotEmpty) {
          _scrcpyOutput += '  wm size raw: $wmRaw\n';
        }
      });

      // Phase 6: Create texture and start mirror
      setState(() => _scrcpyOutput += '\nStarting Phase 6: Mirror...\n');
      setState(() => _scrcpyOutput += '[7/9] Creating mirror texture...\n');
      final textureId = await _adbClient.createMirrorTexture();
      _mirrorTextureId = textureId;
      setState(() => _scrcpyOutput += '  Texture id=$textureId\n');

      setState(() => _scrcpyOutput += '[8/9] Starting mirror decoder...\n');
      await _adbClient.startMirror(
        _videoWidth!,
        _videoHeight!,
        videoStreamLocalId: _videoStreamLocalId!,
      );
      _mirrorStarted = true;
      setState(() {
        _scrcpyOutput += '  Mirror started!\n';
        _scrcpyOutput += '\n=== PHASE 6 SUCCESS: MIRROR ACTIVE ===\n';
        _scrcpyRunning = false;
      });

      if (mounted) {
        _openMirror(
          controlLocalId: videoInfo['controlLocalId'] as int,
          deviceName: videoInfo['deviceName'] as String,
        );
      }

      // Start periodic log refresh to show decoder status (5s to avoid overhead)
      _mirrorLogTimer?.cancel();
      _mirrorLogTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted || !_mirrorStarted) return;
        final log = await _adbClient.getMirrorLog();
        if (mounted) setState(() => _mirrorLog = log);
      });
    } catch (e) {
      String adbLog = '';
      try {
        adbLog = await _adbClient.getAdbLog();
      } catch (_) {}
      setState(() {
        _scrcpyOutput += 'ERROR: $e\n\n--- ADB TRANSPORT LOG ---\n$adbLog';
        _scrcpyRunning = false;
      });
    }
  }

  Future<void> _disconnect() async {
    _mirrorLogTimer?.cancel();
    await _adbClient.stopMirror();
    await _adbClient.disconnectAdb();
    setState(() {
      _adbState = 'disconnected';
      _adbMessage = null;
      _mirrorStarted = false;
      _mirrorTextureId = null;
      _mirrorLog = '';
      _videoStreamLocalId = null;
      _controlLocalId = null;
      _videoWidth = null;
      _videoHeight = null;
      // Keep _adbLog so user can copy the full log
      _connectingDeviceName = null;
    });
  }

  void _openMirror({
    required int controlLocalId,
    required String deviceName,
  }) {
    final textureId = _mirrorTextureId;
    final videoWidth = _videoWidth;
    final videoHeight = _videoHeight;
    if (textureId == null || videoWidth == null || videoHeight == null) return;

    context.pushNamed(
      AppRouteName.mirror,
      pathParameters: {
        'requisitionId': widget.requisitionId,
        'sessionId': widget.sessionId,
      },
      extra: MirrorRouteArgs(
        textureId: textureId,
        controlLocalId: controlLocalId,
        videoSize: Size(videoWidth.toDouble(), videoHeight.toDouble()),
        deviceName: deviceName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Dispositivos USB'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_adbState == 'connecting')
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                await _adbClient.disconnectAdb();
                if (mounted) {
                  setState(() {
                    _adbState = 'disconnected';
                    _adbMessage = null;
                    _connectingDeviceName = null;
                  });
                }
              },
              tooltip: 'Cancelar',
            ),
          if (_adbState == 'connected')
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: _disconnect,
              tooltip: 'Desconectar',
            ),
          if (_adbState == 'error' && _connectingDeviceName != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final device = _devices.firstWhere(
                  (d) => d.displayName == _connectingDeviceName,
                  orElse: () => _devices.first,
                );
                _connectToDevice(device);
              },
              tooltip: 'Reintentar',
            ),
        ],
      ),
      body: SafeArea(
        child: ConstrainedContent(
          padding: EdgeInsets.zero,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatusBar(),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    if (_adbState == 'disconnected') return const SizedBox.shrink();

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_adbState) {
      case 'connecting':
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Conectando a $_connectingDeviceName...';
      case 'authorizing':
        statusColor = Colors.blue;
        statusIcon = Icons.phonelink_lock;
        statusText = _adbMessage ?? 'Revisa tu dispositivo objetivo';
      case 'connected':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Conectado a $_connectingDeviceName';
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = _adbMessage ?? 'Error de conexion';
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = 'Estado desconocido';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpace.l,
            vertical: AppSpace.m,
          ),
          color: statusColor.withOpacity(0.1),
          child: Row(
            children: [
              if (_adbState == 'connecting')
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                )
              else
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 32,
                ),
              SizedBox(width: AppSpace.m),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_adbState == 'connected') _buildShellPanel(),
        if (_adbState == 'connected') _buildScrcpyPanel(),
        if (_mirrorStarted && _mirrorTextureId != null) _buildMirrorPanel(),
        if (_adbState == 'error' ||
            _adbState == 'authorizing' ||
            _adbState == 'connecting')
          _buildLogPanel(),
      ],
    );
  }

  Widget _buildShellPanel() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      padding: EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Shell Command (Phase 3 Test)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: AppSpace.s),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _shellCommandController,
                  decoration: InputDecoration(
                    hintText: 'echo hola',
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpace.s,
                      vertical: AppSpace.s,
                    ),
                  ),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  onSubmitted: (_) => _runShellCommand(),
                ),
              ),
              SizedBox(width: AppSpace.s),
              ElevatedButton.icon(
                onPressed: _shellRunning ? null : _runShellCommand,
                icon: _shellRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_shellRunning ? 'Running...' : 'Run'),
              ),
            ],
          ),
          if (_shellOutput.isNotEmpty) ...[
            SizedBox(height: AppSpace.s),
            Container(
              constraints: BoxConstraints(
                maxHeight: 260,
              ),
              padding: EdgeInsets.all(AppSpace.s),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _shellOutput,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.green.shade300,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrcpyPanel() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      padding: EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_android,
                color: Colors.purple,
                size: AppSpace.l,
              ),
              SizedBox(width: AppSpace.s),
              Expanded(
                child: Text(
                  'Phase 4 - Push & Execute scrcpy-server',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpace.s),
          ElevatedButton.icon(
            onPressed: _scrcpyRunning ? null : _pushAndExecuteScrcpy,
            icon: _scrcpyRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rocket_launch),
            label: Text(
              _scrcpyRunning ? 'Running...' : 'Push & Execute Server',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
          if (_scrcpyOutput.isNotEmpty) ...[
            SizedBox(height: AppSpace.s),
            Container(
              constraints: BoxConstraints(
                maxHeight: 400,
              ),
              padding: EdgeInsets.all(AppSpace.s),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _scrcpyOutput,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.green.shade300,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMirrorPanel() {
    // Get last 30 lines of transport log for mirror debug
    final logLines = _adbLog.split('\n');
    final transportLog = logLines
        .where(
          (l) =>
              l.contains('VideoReader') ||
              l.contains('ScrcpyDecoder') ||
              l.contains('WRTE') && l.contains('stream ${_videoStreamLocalId}'),
        )
        .join('\n');
    // Merge transport log with decoder log from getMirrorLog()
    final mirrorLog = [
      transportLog,
      _mirrorLog,
    ].where((l) => l.isNotEmpty).join('\n');

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      padding: EdgeInsets.all(AppSpace.s),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.screen_share,
                color: Colors.green,
                size: AppSpace.l,
              ),
              SizedBox(width: AppSpace.s),
              Expanded(
                child: Text(
                  'Phase 6 - Mirror Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, color: Colors.blue),
                onPressed: _mirrorTextureId != null
                    ? () {
                        _openMirror(
                          controlLocalId: _controlLocalId!,
                          deviceName: _connectingDeviceName ?? 'Device',
                        );
                      }
                    : null,
                tooltip: 'Abrir Mirror',
              ),
              IconButton(
                icon: const Icon(Icons.stop_circle, color: Colors.red),
                onPressed: () async {
                  _mirrorLogTimer?.cancel();
                  await _adbClient.stopMirror();
                  setState(() {
                    _mirrorStarted = false;
                    _mirrorTextureId = null;
                    _mirrorLog = '';
                  });
                },
                tooltip: 'Stop Mirror',
              ),
            ],
          ),
          SizedBox(height: AppSpace.s),
          AspectRatio(
            aspectRatio:
                (_videoWidth?.toDouble() ?? 9) /
                (_videoHeight?.toDouble() ?? 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Texture(textureId: _mirrorTextureId!),
            ),
          ),
          SizedBox(height: AppSpace.xs),
          Text(
            '${_videoWidth}x$_videoHeight - ${_videoStreamLocalId != null ? "Stream #$_videoStreamLocalId" : "No stream"}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (mirrorLog.isNotEmpty) ...[
            SizedBox(height: AppSpace.s),
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              padding: EdgeInsets.all(AppSpace.s),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  mirrorLog,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.green.shade300,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    final isEmpty = _adbLog.isEmpty;
    final headerColor = _adbState == 'error'
        ? Colors.red.shade300
        : _adbState == 'authorizing'
        ? Colors.blue.shade300
        : Colors.orange.shade300;

    return Container(
      constraints: BoxConstraints(maxHeight: 400),
      margin: EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: headerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpace.m,
              vertical: AppSpace.s,
            ),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bug_report,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: AppSpace.s),
                Expanded(
                  child: Text(
                    _adbState == 'connecting'
                        ? 'Debug - Copia esto y enviamelo'
                        : _adbState == 'authorizing'
                        ? 'Debug - Copia esto y enviamelo'
                        : 'Detalle del error (copia esto)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!isEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                    onPressed: () {
                      final data = ClipboardData(text: _adbLog);
                      Clipboard.setData(data);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Log copiado al portapapeles'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copiar log',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpace.m),
              child: SelectableText(
                isEmpty
                    ? 'Esperando logs del dispositivo...\n\nSi ves esto por mas de 5 segundos,\nsignifica que el handshake no esta\nenviando eventos a la UI.'
                    : _adbLog,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: isEmpty
                      ? Colors.yellow.shade300
                      : Colors.green.shade300,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (Platform.isIOS) {
      return _buildIosCapabilityState();
    }
    if (!_isOtgSupported) {
      return _buildNoOtgSupport();
    }

    if (_devices.isEmpty) {
      return _buildNoDevices();
    }

    return _buildDeviceList();
  }

  Widget _buildIosCapabilityState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_iphone_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpace.m),
            Text('Conexión iOS', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.s),
            Text(
              'La captura ADB/OTG solo está disponible para Android. Para iPhone o iPad usa Importar archivos desde el detalle de la requisa.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.m),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Volver al detalle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOtgSupport() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.usb_off,
              size: 96,
              color: Colors.red.shade300,
            ),
            SizedBox(height: AppSpace.l),
            Text(
              'OTG No Soportado',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppSpace.s),
            Text(
              'Tu dispositivo no soporta USB Host (OTG). '
              'No es posible conectar dispositivos USB.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSpace.m,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDevices() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.usb,
              size: 96,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: AppSpace.l),
            Text(
              'Sin Dispositivos',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppSpace.s),
            Text(
              'Conecta un dispositivo Android al puerto USB '
              'con depuración USB activada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSpace.m,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: AppSpace.xl),
            _buildInstructionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(AppSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pasos para conectar:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppSpace.s),
            _buildStep(
              '1',
              'Activa Opciones de desarrollador en el dispositivo objetivo',
            ),
            _buildStep('2', 'Activa Depuración USB'),
            _buildStep('3', 'Conecta el cable USB con soporte OTG'),
            _buildStep('4', 'Acepta el permiso en esta app'),
            _buildStep(
              '5',
              'Acepta "Depuración USB" en el dispositivo objetivo',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpace.s),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpace.m),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _devices.length,
      itemBuilder: (context, index) => _buildDeviceCard(_devices[index]),
    );
  }

  Widget _buildDeviceCard(UsbDeviceInfo device) {
    final isConnecting =
        _adbState == 'connecting' &&
        _connectingDeviceName == device.displayName;
    final isConnected =
        _adbState == 'connected' && _connectingDeviceName == device.displayName;
    final hasError = _adbState == 'error';

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: AppSpace.s),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isConnecting ? null : () => _requestPermission(device),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(AppSpace.l),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.green.shade50
                      : device.hasPermission
                      ? Colors.blue.shade50
                      : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConnected ? Icons.check_circle : Icons.phone_android,
                  color: isConnected
                      ? Colors.green
                      : device.hasPermission
                      ? Colors.blue
                      : Colors.orange,
                  size: AppSpace.xl,
                ),
              ),
              SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppSpace.xxs),
                    Text(
                      'VID: ${device.vendorIdHex}  PID: ${device.productIdHex}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (device.serialNumber != null) ...[
                      SizedBox(height: AppSpace.xxs),
                      Text(
                        'S/N: ${device.serialNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isConnecting)
                SizedBox(
                  width: AppSpace.xl,
                  height: AppSpace.xl,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isConnected)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpace.s,
                    vertical: AppSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Conectado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpace.s,
                    vertical: AppSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: device.hasPermission ? Colors.blue : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    device.hasPermission ? 'Conectar' : 'Permitir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
