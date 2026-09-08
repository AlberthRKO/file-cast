import 'dart:async';

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:flutter/foundation.dart';

class AcquisitionConnectViewModel extends ChangeNotifier {
  AcquisitionConnectViewModel({
    required AcquisitionRepository repository,
    required this.requisitionId,
    required this.sessionId,
    this.destination = AcquisitionDestination.mirror,
  }) : _repository = repository;

  final AcquisitionRepository _repository;
  final String requisitionId;
  final String sessionId;
  final AcquisitionDestination destination;
  StreamSubscription<void>? _deviceSubscription;
  AcquisitionAvailability _availability = AcquisitionAvailability.checking;
  AcquisitionConnectionPhase _phase = AcquisitionConnectionPhase.loading;
  List<AcquisitionDevice> _devices = const [];
  String? _selectedDeviceId;
  String? _pendingPermissionDeviceId;
  String? _message;
  AcquisitionMirrorSession? _navigationSession;
  AcquisitionConnectionSession? _transferConnection;
  bool _disposed = false;
  int _refreshGeneration = 0;

  AcquisitionAvailability get availability => _availability;
  AcquisitionConnectionPhase get phase => _phase;
  List<AcquisitionDevice> get devices => _devices;
  String? get selectedDeviceId => _selectedDeviceId;
  String? get message => _message;
  bool get isBusy => switch (_phase) {
    AcquisitionConnectionPhase.requestingPermission ||
    AcquisitionConnectionPhase.connecting ||
    AcquisitionConnectionPhase.preparingMirror => true,
    _ => false,
  };
  AcquisitionMirrorSession? get navigationSession => _navigationSession;
  AcquisitionConnectionSession? get transferConnection => _transferConnection;

  Future<void> initialize() async {
    _availability = await _repository.getAvailability();
    if (_availability == AcquisitionAvailability.unsupported) {
      _phase = AcquisitionConnectionPhase.ready;
      _message =
          'La captura por USB/ADB está disponible únicamente en Android con soporte OTG.';
      _safeNotify();
      return;
    }
    _deviceSubscription = _repository.deviceChanges.listen((_) => refresh());
    final reusable = destination == AcquisitionDestination.transfer
        ? await _repository.activeConnection(
            requisitionId: requisitionId,
            sessionId: sessionId,
          )
        : await _repository.activeSession(
            requisitionId: requisitionId,
            sessionId: sessionId,
          );
    if (reusable != null) {
      if (reusable is AcquisitionMirrorSession) {
        _navigationSession = reusable;
      } else if (reusable is AcquisitionConnectionSession) {
        _transferConnection = reusable;
      }
      _phase = AcquisitionConnectionPhase.connected;
      _message = 'Sesión activa recuperada.';
      _safeNotify();
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (isBusy && _phase != AcquisitionConnectionPhase.requestingPermission) {
      return;
    }
    final generation = ++_refreshGeneration;
    var devices = await _repository.getDevices();
    if (devices.isEmpty && _devices.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (_disposed || generation != _refreshGeneration) return;
      devices = await _repository.getDevices();
    }
    if (_disposed || generation != _refreshGeneration) return;
    _devices = devices;
    _phase = AcquisitionConnectionPhase.ready;
    _safeNotify();
    final pendingId = _pendingPermissionDeviceId;
    if (pendingId == null) return;
    final permitted = _devices.where(
      (device) => device.id == pendingId && device.hasPermission,
    );
    if (permitted.isNotEmpty) {
      _pendingPermissionDeviceId = null;
      await connect(permitted.first);
    }
  }

  Future<void> selectDevice(AcquisitionDevice device) async {
    if (isBusy) return;
    _selectedDeviceId = device.id;
    _message = null;
    _safeNotify();
    final reusable = destination == AcquisitionDestination.transfer
        ? await _repository.activeConnection(
            requisitionId: requisitionId,
            sessionId: sessionId,
          )
        : await _repository.activeSession(
            requisitionId: requisitionId,
            sessionId: sessionId,
          );
    if (reusable != null) {
      if (reusable is AcquisitionMirrorSession) {
        _navigationSession = reusable;
      } else if (reusable is AcquisitionConnectionSession) {
        _transferConnection = reusable;
      }
      _phase = AcquisitionConnectionPhase.connected;
      _message = 'Sesión activa recuperada.';
      _safeNotify();
      return;
    }
    if (device.hasPermission) {
      await connect(device);
      return;
    }
    _phase = AcquisitionConnectionPhase.requestingPermission;
    _pendingPermissionDeviceId = device.id;
    _safeNotify();
    final granted = await _repository.requestPermission(device.id);
    if (granted == true) {
      _pendingPermissionDeviceId = null;
      await connect(device);
    } else if (granted == false) {
      _phase = AcquisitionConnectionPhase.error;
      _message = 'El permiso USB fue rechazado en este dispositivo.';
      _safeNotify();
    }
  }

  Future<void> connect(AcquisitionDevice device) async {
    if (_phase == AcquisitionConnectionPhase.connecting ||
        _phase == AcquisitionConnectionPhase.preparingMirror) {
      return;
    }
    _selectedDeviceId = device.id;
    _phase = AcquisitionConnectionPhase.connecting;
    _message = 'Autorizando la conexión ADB…';
    _safeNotify();
    try {
      if (destination == AcquisitionDestination.transfer) {
        _message = 'Preparando el acceso seguro a los archivos…';
        _safeNotify();
        _transferConnection = await _repository.connectForTransfer(
          device: device,
          requisitionId: requisitionId,
          sessionId: sessionId,
        );
      } else {
        _phase = AcquisitionConnectionPhase.preparingMirror;
        _message = 'Preparando la captura segura de pantalla…';
        _safeNotify();
        _navigationSession = await _repository.connectAndStart(
          device: device,
          requisitionId: requisitionId,
          sessionId: sessionId,
        );
      }
      _phase = AcquisitionConnectionPhase.connected;
      _message = 'Dispositivo conectado.';
    } on TimeoutException {
      _phase = AcquisitionConnectionPhase.error;
      _message =
          'El dispositivo no respondió. Confirma la depuración USB y acepta su huella RSA.';
    } catch (error) {
      _phase = AcquisitionConnectionPhase.error;
      _message = _friendlyError(error);
      await _repository.disconnect();
    }
    _safeNotify();
  }

  void markNavigationHandled() {
    _navigationSession = null;
    _transferConnection = null;
  }

  Future<void> retry() async {
    _message = null;
    await refresh();
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('NO_ADB_INTERFACE')) {
      return 'No se encontró una interfaz ADB. Activa la depuración USB en el dispositivo objetivo.';
    }
    if (raw.contains('NO_PERMISSION')) {
      return 'No existe permiso para usar el dispositivo USB.';
    }
    if (raw.contains('HANDSHAKE')) {
      return 'No se completó la autorización ADB. Acepta la huella RSA en el dispositivo objetivo.';
    }
    return destination == AcquisitionDestination.transfer
        ? 'No se pudo preparar la transferencia. $raw'
        : 'No se pudo iniciar la captura. $raw';
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _deviceSubscription?.cancel();
    super.dispose();
  }
}
