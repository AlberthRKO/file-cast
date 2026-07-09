import 'dart:async';

import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/core/adb/adb_models.dart';
import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';

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
            break;
          case UsbEventType.deviceDetached:
            final detachedDevices = event.devices;
            _devices = _devices
                .where((d) => !detachedDevices
                    .any((dd) => dd.deviceName == d.deviceName))
                .toList();
            break;
          case UsbEventType.permissionDenied:
            break;
        }
      });
    });

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _usbSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermission(UsbDeviceInfo device) async {
    if (device.hasPermission) {
      _connectToDevice(device);
      return;
    }

    final result = await _adbClient.requestPermission(device.deviceName);
    if (result == true && mounted) {
      setState(() {});
      _connectToDevice(device);
    }
  }

  void _connectToDevice(UsbDeviceInfo device) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conectado a ${device.displayName}'),
        backgroundColor: Colors.green,
      ),
    );
    // TODO: Fase 2 - navegar a handshake ADB
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
      ),
      body: _buildBody(responsive),
    );
  }

  Widget _buildBody(Responsive responsive) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
            _buildStep(responsive, '1', 'Activa Opciones de desarrollador en el dispositivo objetivo'),
            _buildStep(responsive, '2', 'Activa Depuración USB'),
            _buildStep(responsive, '3', 'Conecta el cable USB con soporte OTG'),
            _buildStep(responsive, '4', 'Acepta el permiso en esta app'),
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
            decoration: BoxDecoration(
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
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: responsive.heightPercent(0.8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _requestPermission(device),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(responsive.widthPercent(4)),
          child: Row(
            children: [
              Container(
                width: responsive.heightPercent(6),
                height: responsive.heightPercent(6),
                decoration: BoxDecoration(
                  color: device.hasPermission ? Colors.green.shade50 : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone_android,
                  color: device.hasPermission ? Colors.green : Colors.orange,
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
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.widthPercent(2),
                  vertical: responsive.heightPercent(0.5),
                ),
                decoration: BoxDecoration(
                  color: device.hasPermission ? Colors.green : Colors.orange,
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
