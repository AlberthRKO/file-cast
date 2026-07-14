import 'dart:async';
import 'dart:io';

import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UsbDeviceListPage extends StatefulWidget {
  const UsbDeviceListPage({super.key});

  @override
  State<UsbDeviceListPage> createState() => _UsbDeviceListPageState();
}

class _UsbDeviceListPageState extends State<UsbDeviceListPage> {
  final AdbClient _adbClient = AdbClient();
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _isOtgSupported = await _adbClient.isOtgSupported();
    _devices = await _adbClient.getConnectedDevices();

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
        }
      });
    });

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _usbSubscription?.cancel();
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
      setState(() => _scrcpyOutput += '[1/4] Reading scrcpy-server from assets...\n');
      final assetBytes = await _adbClient.readAsset(
        'assets/scrcpy/scrcpy-server-v3.3.4.jar',
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

      setState(() => _scrcpyOutput += '[3/4] Pushing to /data/local/tmp/scrcpy-server.jar...\n');
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

      setState(() => _scrcpyOutput += '[4/5] Executing scrcpy-server...\n');
      // startPersistentShell keeps the shell stream OPEN → server process stays alive
      // tunnel_forward=true: server creates LocalServerSocket and listens, we connect as client
      // no_audio=true, no_control=true: only open video socket for now
      final shellLocalId = await _adbClient.startPersistentShell(
        'CLASSPATH=/data/local/tmp/scrcpy-server.jar app_process / com.genymobile.scrcpy.Server 3.3.4 tunnel_forward=true no_audio=true no_control=true log_level=debug',
        timeoutMs: 10000,
      );
      setState(() => _scrcpyOutput += '  Server shell stream: localId=$shellLocalId\n');

      // Give server time to initialize + create LocalServerSocket + start accept()
      await Future.delayed(const Duration(milliseconds: 3000));

      setState(() => _scrcpyOutput += '[5/5] Connecting to video socket...\n');
      final videoInfo = await _adbClient.connectScrcpySockets();
      setState(() {
        _scrcpyOutput += '  Device: ${videoInfo['deviceName']}\n';
        _scrcpyOutput += '  Screen: ${videoInfo['width']}x${videoInfo['height']}\n';
        _scrcpyOutput += '  Codec: ${videoInfo['codec']}\n';
        _scrcpyRunning = false;
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
    await _adbClient.disconnectAdb();
    setState(() {
      _adbState = 'disconnected';
      _adbMessage = null;
      // Keep _adbLog so user can copy the full log
      _connectingDeviceName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

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
      body: _buildBody(responsive),
    );
  }

  Widget _buildBody(Responsive responsive) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildStatusBar(responsive),
        Expanded(
          child: _buildContent(responsive),
        ),
      ],
    );
  }

  Widget _buildStatusBar(Responsive responsive) {
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
            horizontal: responsive.widthPercent(4),
            vertical: responsive.heightPercent(1.5),
          ),
          color: statusColor.withOpacity(0.1),
          child: Row(
            children: [
              if (_adbState == 'connecting')
                SizedBox(
                  width: responsive.heightPercent(2.5),
                  height: responsive.heightPercent(2.5),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                )
              else
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: responsive.heightPercent(2.5),
                ),
              SizedBox(width: responsive.widthPercent(3)),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: responsive.heightPercent(1.4),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_adbState == 'connected') _buildShellPanel(responsive),
        if (_adbState == 'connected') _buildScrcpyPanel(responsive),
        if (_adbState == 'error' ||
            _adbState == 'authorizing' ||
            _adbState == 'connecting')
          _buildLogPanel(responsive),
      ],
    );
  }

  Widget _buildShellPanel(Responsive responsive) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: responsive.widthPercent(3),
        vertical: responsive.heightPercent(1),
      ),
      padding: EdgeInsets.all(responsive.widthPercent(3)),
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
              fontSize: responsive.heightPercent(1.4),
            ),
          ),
          SizedBox(height: responsive.heightPercent(1)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _shellCommandController,
                  decoration: InputDecoration(
                    hintText: 'echo hola',
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: responsive.widthPercent(2),
                      vertical: responsive.heightPercent(0.8),
                    ),
                  ),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: responsive.heightPercent(1.2),
                  ),
                  onSubmitted: (_) => _runShellCommand(),
                ),
              ),
              SizedBox(width: responsive.widthPercent(2)),
              ElevatedButton.icon(
                onPressed: _shellRunning ? null : _runShellCommand,
                icon: _shellRunning
                    ? SizedBox(
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
            SizedBox(height: responsive.heightPercent(1)),
            Container(
              constraints: BoxConstraints(maxHeight: responsive.heightPercent(25)),
              padding: EdgeInsets.all(responsive.widthPercent(2)),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _shellOutput,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: responsive.heightPercent(1.1),
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

  Widget _buildScrcpyPanel(Responsive responsive) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: responsive.widthPercent(3),
        vertical: responsive.heightPercent(1),
      ),
      padding: EdgeInsets.all(responsive.widthPercent(3)),
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
              Icon(Icons.phone_android, color: Colors.purple, size: responsive.heightPercent(2)),
              SizedBox(width: responsive.widthPercent(2)),
              Expanded(
                child: Text(
                  'Phase 4 - Push & Execute scrcpy-server',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: responsive.heightPercent(1.4),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.heightPercent(1)),
          ElevatedButton.icon(
            onPressed: _scrcpyRunning ? null : _pushAndExecuteScrcpy,
            icon: _scrcpyRunning
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rocket_launch),
            label: Text(_scrcpyRunning ? 'Running...' : 'Push & Execute Server'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
          if (_scrcpyOutput.isNotEmpty) ...[
            SizedBox(height: responsive.heightPercent(1)),
            Container(
              constraints: BoxConstraints(maxHeight: responsive.heightPercent(50)),
              padding: EdgeInsets.all(responsive.widthPercent(2)),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _scrcpyOutput,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: responsive.heightPercent(1.1),
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

  Widget _buildLogPanel(Responsive responsive) {
    final isEmpty = _adbLog.isEmpty;
    final headerColor = _adbState == 'error'
        ? Colors.red.shade300
        : _adbState == 'authorizing'
        ? Colors.blue.shade300
        : Colors.orange.shade300;

    return Container(
      constraints: BoxConstraints(maxHeight: responsive.heightPercent(50)),
      margin: EdgeInsets.symmetric(
        horizontal: responsive.widthPercent(3),
        vertical: responsive.heightPercent(1),
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
              horizontal: responsive.widthPercent(3),
              vertical: responsive.heightPercent(0.8),
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
                  size: responsive.heightPercent(1.8),
                ),
                SizedBox(width: responsive.widthPercent(2)),
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
                      fontSize: responsive.heightPercent(1.3),
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
              padding: EdgeInsets.all(responsive.widthPercent(3)),
              child: SelectableText(
                isEmpty
                    ? 'Esperando logs del dispositivo...\n\nSi ves esto por mas de 5 segundos,\nsignifica que el handshake no esta\nenviando eventos a la UI.'
                    : _adbLog,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: responsive.heightPercent(1.1),
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

  Widget _buildContent(Responsive responsive) {
    if (!_isOtgSupported) {
      return _buildNoOtgSupport(responsive);
    }

    if (_devices.isEmpty) {
      return _buildNoDevices(responsive);
    }

    return _buildDeviceList(responsive);
  }

  Widget _buildNoOtgSupport(Responsive responsive) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(responsive.widthPercent(5)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.usb_off,
              size: responsive.heightPercent(10),
              color: Colors.red.shade300,
            ),
            SizedBox(height: responsive.heightPercent(2)),
            Text(
              'OTG No Soportado',
              style: TextStyle(
                fontSize: responsive.heightPercent(2.5),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: responsive.heightPercent(1)),
            Text(
              'Tu dispositivo no soporta USB Host (OTG). '
              'No es posible conectar dispositivos USB.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.heightPercent(1.5),
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDevices(Responsive responsive) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(responsive.widthPercent(5)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.usb,
              size: responsive.heightPercent(10),
              color: Colors.grey.shade400,
            ),
            SizedBox(height: responsive.heightPercent(2)),
            Text(
              'Sin Dispositivos',
              style: TextStyle(
                fontSize: responsive.heightPercent(2.5),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: responsive.heightPercent(1)),
            Text(
              'Conecta un dispositivo Android al puerto USB '
              'con depuración USB activada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.heightPercent(1.5),
                color: Colors.grey,
              ),
            ),
            SizedBox(height: responsive.heightPercent(3)),
            _buildInstructionsCard(responsive),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard(Responsive responsive) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(responsive.widthPercent(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pasos para conectar:',
              style: TextStyle(
                fontSize: responsive.heightPercent(1.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: responsive.heightPercent(1)),
            _buildStep(
              responsive,
              '1',
              'Activa Opciones de desarrollador en el dispositivo objetivo',
            ),
            _buildStep(responsive, '2', 'Activa Depuración USB'),
            _buildStep(responsive, '3', 'Conecta el cable USB con soporte OTG'),
            _buildStep(responsive, '4', 'Acepta el permiso en esta app'),
            _buildStep(
              responsive,
              '5',
              'Acepta "Depuración USB" en el dispositivo objetivo',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(Responsive responsive, String number, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.heightPercent(0.5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: responsive.heightPercent(2.5),
            height: responsive.heightPercent(2.5),
            decoration: const BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.heightPercent(1.2),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: responsive.widthPercent(2)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: responsive.heightPercent(1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(Responsive responsive) {
    return RefreshIndicator(
      onRefresh: () async {
        _devices = await _adbClient.getConnectedDevices();
        setState(() {});
      },
      child: ListView.builder(
        padding: EdgeInsets.all(responsive.widthPercent(3)),
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return _buildDeviceCard(device, responsive);
        },
      ),
    );
  }

  Widget _buildDeviceCard(UsbDeviceInfo device, Responsive responsive) {
    final isConnecting =
        _adbState == 'connecting' &&
        _connectingDeviceName == device.displayName;
    final isConnected =
        _adbState == 'connected' && _connectingDeviceName == device.displayName;
    final hasError = _adbState == 'error';

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: responsive.heightPercent(0.8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isConnecting ? null : () => _requestPermission(device),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(responsive.widthPercent(4)),
          child: Row(
            children: [
              Container(
                width: responsive.heightPercent(6),
                height: responsive.heightPercent(6),
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
                  size: responsive.heightPercent(3),
                ),
              ),
              SizedBox(width: responsive.widthPercent(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: TextStyle(
                        fontSize: responsive.heightPercent(1.8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: responsive.heightPercent(0.3)),
                    Text(
                      'VID: ${device.vendorIdHex}  PID: ${device.productIdHex}',
                      style: TextStyle(
                        fontSize: responsive.heightPercent(1.2),
                        color: Colors.grey,
                      ),
                    ),
                    if (device.serialNumber != null) ...[
                      SizedBox(height: responsive.heightPercent(0.3)),
                      Text(
                        'S/N: ${device.serialNumber}',
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.2),
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isConnecting)
                SizedBox(
                  width: responsive.heightPercent(3),
                  height: responsive.heightPercent(3),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isConnected)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.widthPercent(2),
                    vertical: responsive.heightPercent(0.5),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Conectado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.heightPercent(1.2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.widthPercent(2),
                    vertical: responsive.heightPercent(0.5),
                  ),
                  decoration: BoxDecoration(
                    color: device.hasPermission ? Colors.blue : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    device.hasPermission ? 'Conectar' : 'Permitir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.heightPercent(1.2),
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
