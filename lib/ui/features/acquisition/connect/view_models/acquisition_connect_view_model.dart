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
  String _diagnosticLog = '';
  AcquisitionMirrorSession? _navigationSession;
  AcquisitionMultiMirrorSession? _navigationMultiSession;
  AcquisitionConnectionSession? _transferConnection;
  final Set<String> _selectedDeviceIds = <String>{};
  final Set<String> _authorizedDeviceIds = <String>{};
  bool _disposed = false;
  int _refreshGeneration = 0;

  AcquisitionAvailability get availability => _availability;
  AcquisitionConnectionPhase get phase => _phase;
  List<AcquisitionDevice> get devices => _devices;
  String? get selectedDeviceId => _selectedDeviceId;
  String? get message => _message;
  String get diagnosticLog => _diagnosticLog;
  bool get hasDiagnostics => _diagnosticLog.trim().isNotEmpty;
  bool get isBusy => switch (_phase) {
    AcquisitionConnectionPhase.requestingPermission ||
    AcquisitionConnectionPhase.connecting ||
    AcquisitionConnectionPhase.preparingMirror => true,
    _ => false,
  };
  AcquisitionMirrorSession? get navigationSession => _navigationSession;
  AcquisitionMultiMirrorSession? get navigationMultiSession =>
      _navigationMultiSession;
  AcquisitionConnectionSession? get transferConnection => _transferConnection;
  bool get isMultiMirror => destination == AcquisitionDestination.multiMirror;
  Set<String> get selectedDeviceIds => Set.unmodifiable(_selectedDeviceIds);
  Set<String> get authorizedDeviceIds => Set.unmodifiable(
    _authorizedDeviceIds,
  );
  int get usbDeviceCount => _devices.length;
  int get adbDeviceCount =>
      _devices.where((device) => device.supportsAdb).length;

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
    if (await _recoverActiveSession()) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (isBusy && _phase != AcquisitionConnectionPhase.requestingPermission) {
      return;
    }
    final generation = ++_refreshGeneration;
    var devices = await _repository.getDevices();
    if (devices.isEmpty || !devices.any(_isSelectable)) {
      for (final delay in const [
        Duration(milliseconds: 400),
        Duration(milliseconds: 800),
      ]) {
        await Future<void>.delayed(delay);
        if (_disposed || generation != _refreshGeneration) return;
        devices = await _repository.getDevices();
        if (devices.any(_isSelectable)) break;
      }
    }
    if (_disposed || generation != _refreshGeneration) return;
    _devices = devices;
    final availableIds = devices
        .where(_isSelectable)
        .map((device) => device.id)
        .toSet();
    _selectedDeviceIds.retainWhere(availableIds.contains);
    _authorizedDeviceIds.retainWhere(availableIds.contains);
    if (_selectedDeviceId != null &&
        !availableIds.contains(_selectedDeviceId)) {
      _selectedDeviceId = null;
    }
    if (_pendingPermissionDeviceId != null &&
        !availableIds.contains(_pendingPermissionDeviceId)) {
      _pendingPermissionDeviceId = null;
    }
    _phase = AcquisitionConnectionPhase.ready;
    _safeNotify();
    final pendingId = _pendingPermissionDeviceId;
    if (pendingId == null) return;
    final permitted = _devices.where(
      (device) => device.id == pendingId && device.hasPermission,
    );
    if (permitted.isNotEmpty) {
      _pendingPermissionDeviceId = null;
      if (isMultiMirror) {
        // A multi-session may need to authorize several targets. Continue the
        // permission queue instead of starting ADB with only the first one.
        await connectSelected();
      } else {
        await connect(permitted.first);
      }
    }
  }

  Future<void> selectDevice(AcquisitionDevice device) async {
    if (isBusy) return;
    if (!_isSelectable(device)) {
      _selectedDeviceId = null;
      _message = _nonAdbMessage(device);
      _phase = AcquisitionConnectionPhase.error;
      _safeNotify();
      return;
    }
    if (isMultiMirror) {
      if (_selectedDeviceIds.contains(device.id)) {
        _selectedDeviceIds.remove(device.id);
      } else {
        _selectedDeviceIds.add(device.id);
      }
      _selectedDeviceId = device.id;
      _message = null;
      _safeNotify();
      return;
    }
    _selectedDeviceId = device.id;
    _message = null;
    _safeNotify();
    if (await _recoverActiveSession()) return;
    if (device.hasPermission) {
      await connect(device);
      return;
    }
    _phase = AcquisitionConnectionPhase.requestingPermission;
    _pendingPermissionDeviceId = device.id;
    _message = device.supportsMtp && !device.supportsAdb
        ? 'Concede a File Cast el permiso USB y permite el acceso en el iPad.'
        : 'En el inspector, concede a File Cast el acceso USB. La autorización RSA aparecerá después en el objetivo.';
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
    if (!_isSelectable(device)) {
      _phase = AcquisitionConnectionPhase.error;
      _message = _nonAdbMessage(device);
      _safeNotify();
      return;
    }
    _selectedDeviceId = device.id;
    final wasAuthorized = _authorizedDeviceIds.contains(device.id);
    _diagnosticLog = '';
    _phase = AcquisitionConnectionPhase.connecting;
    _message = device.supportsMtp && !device.supportsAdb
        ? 'Desbloquea el iPad y permite el acceso a sus archivos. Esperando las carpetas…'
        : 'Autorizando la conexión ADB…';
    _safeNotify();
    try {
      if (isMultiMirror) {
        final selected = _devices
            .where((candidate) => _selectedDeviceIds.contains(candidate.id))
            .toList(growable: false);
        if (selected.isEmpty) {
          _phase = AcquisitionConnectionPhase.error;
          _message = 'Selecciona al menos un dispositivo ADB.';
          _safeNotify();
          return;
        }
        _phase = AcquisitionConnectionPhase.preparingMirror;
        _message =
            'Preparando ${selected.length} mirror${selected.length == 1 ? '' : 's'}…';
        _safeNotify();
        _navigationMultiSession = await _repository.connectAndStartMulti(
          devices: selected,
          requisitionId: requisitionId,
          sessionId: sessionId,
        );
        _authorizedDeviceIds.addAll(
          selected.map((candidate) => candidate.id),
        );
        _phase = AcquisitionConnectionPhase.connected;
        _message = 'Mirrors conectados.';
        _safeNotify();
        return;
      }
      if (destination == AcquisitionDestination.transfer) {
        _message = device.supportsMtp && !device.supportsAdb
            ? 'Esperando que el iPad autorice el acceso a sus carpetas…'
            : 'Preparando el acceso seguro a los archivos…';
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
      _authorizedDeviceIds.add(device.id);
      _phase = AcquisitionConnectionPhase.connected;
      _message = 'Dispositivo conectado.';
    } on TimeoutException {
      await _captureConnectionDiagnostics(
        device.supportsMtp && !device.supportsAdb
            ? 'Timeout esperando la respuesta MTP/PTP.'
            : 'Timeout esperando la respuesta del transporte ADB.',
        device: device,
      );
      if (!isMultiMirror) _selectedDeviceId = null;
      _phase = AcquisitionConnectionPhase.error;
      _message = device.supportsMtp && !device.supportsAdb
          ? 'El iPad no respondió por MTP/PTP. Desbloquéalo, permite el acceso y reconecta el cable.'
          : wasAuthorized
          ? 'El dispositivo no respondió durante la reconexión. La identidad RSA guardada se conserva; revisa el diagnóstico.'
          : 'El dispositivo no respondió. Confirma la depuración USB y acepta su huella RSA.';
      if (isMultiMirror) {
        await _repository.disconnectMulti();
      } else {
        await _repository.disconnect();
      }
    } catch (error) {
      await _captureConnectionDiagnostics(error.toString(), device: device);
      if (!isMultiMirror) _selectedDeviceId = null;
      _phase = AcquisitionConnectionPhase.error;
      _message = device.supportsMtp && !device.supportsAdb
          ? 'No se pudo abrir el acceso MTP/PTP: $error'
          : _friendlyError(error, wasAuthorized: wasAuthorized);
      if (isMultiMirror) {
        await _repository.disconnectMulti();
      } else {
        await _repository.disconnect();
      }
    }
    _safeNotify();
  }

  bool _isSelectable(AcquisitionDevice device) =>
      device.supportsAdb ||
      (destination == AcquisitionDestination.transfer && device.supportsMtp);

  Future<void> connectSelected() async {
    if (!isMultiMirror || _selectedDeviceIds.isEmpty || isBusy) return;
    final selected = _devices
        .where(
          (device) =>
              device.supportsAdb && _selectedDeviceIds.contains(device.id),
        )
        .toList(growable: false);
    if (selected.isEmpty) {
      _phase = AcquisitionConnectionPhase.error;
      _message =
          'Los dispositivos seleccionados ya no están conectados al hub.';
      _safeNotify();
      return;
    }
    for (final device in selected.where((device) => !device.hasPermission)) {
      _phase = AcquisitionConnectionPhase.requestingPermission;
      _pendingPermissionDeviceId = device.id;
      _message =
          'En el inspector, concede el permiso USB para ${device.connectionLabel}. '
          'Luego acepta la huella RSA en ese objetivo…';
      _safeNotify();
      final granted = await _repository.requestPermission(device.id);
      if (granted != true) {
        _pendingPermissionDeviceId = granted == null ? device.id : null;
        _phase = AcquisitionConnectionPhase.error;
        _message = granted == null
            ? 'Autoriza el permiso USB para ${device.name} y continúa.'
            : 'Autoriza el permiso USB para continuar.';
        if (granted == null) {
          _phase = AcquisitionConnectionPhase.requestingPermission;
        }
        _safeNotify();
        return;
      }
    }
    await connect(selected.first);
  }

  void markNavigationHandled() {
    _navigationSession = null;
    _navigationMultiSession = null;
    _transferConnection = null;
    _phase = AcquisitionConnectionPhase.ready;
    _message = null;
    _safeNotify();
  }

  Future<void> retry() async {
    _message = null;
    _diagnosticLog = '';
    await refresh();
  }

  Future<bool> _recoverActiveSession() async {
    if (destination == AcquisitionDestination.multiMirror) return false;

    if (destination == AcquisitionDestination.transfer) {
      final reusable = await _repository.activeConnection(
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      if (reusable == null) return false;
      _rememberAuthorizedDevice(reusable.usbDeviceId);
      _transferConnection = reusable;
    } else {
      final reusable = await _repository.activeSession(
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      if (reusable == null) return false;
      _rememberAuthorizedDevice(reusable.usbDeviceId);
      _navigationSession = reusable;
    }

    _phase = AcquisitionConnectionPhase.connected;
    _message = 'Sesión activa recuperada.';
    _safeNotify();
    return true;
  }

  void _rememberAuthorizedDevice(String? deviceId) {
    if (deviceId != null && deviceId.isNotEmpty) {
      _authorizedDeviceIds.add(deviceId);
    }
  }

  Future<void> _captureConnectionDiagnostics(
    String fallback, {
    required AcquisitionDevice device,
  }) async {
    final header = StringBuffer()
      ..writeln(
        '=== FILE CAST · DIAGNÓSTICO ${device.supportsMtp && !device.supportsAdb ? 'MTP/PTP' : 'ADB'} ===',
      )
      ..writeln('Error: $fallback')
      ..writeln('Dispositivo: ${device.name}')
      ..writeln(
        'USB: ${device.connectionLabel} · '
        'VID ${device.vendorId.toRadixString(16).toUpperCase()} · '
        'PID ${device.productId.toRadixString(16).toUpperCase()}',
      )
      ..writeln('Interfaces: ${device.interfaceSummary}')
      ..writeln('Permiso USB: ${device.hasPermission ? 'sí' : 'no'}');
    try {
      final log = await _repository.getConnectionDiagnostics();
      _diagnosticLog = log.trim().isEmpty
          ? header.toString().trim()
          : '${header.toString().trim()}\n\n${log.trim()}';
    } catch (_) {
      _diagnosticLog = header.toString().trim();
    }
  }

  String _friendlyError(Object error, {required bool wasAuthorized}) {
    final raw = error.toString();
    final normalized = raw.toUpperCase();
    if (normalized.contains('NO_ADB_INTERFACE')) {
      return 'No se encontró una interfaz ADB. Activa la depuración USB en el dispositivo objetivo.';
    }
    if (normalized.contains('NO_PERMISSION')) {
      return 'No existe permiso para usar el dispositivo USB.';
    }
    if (normalized.contains('MULTI_ADB_ERROR')) {
      return 'No se completó la autorización ADB de uno de los objetivos. '
          'Manténlo desbloqueado mientras se reconecta después de aceptar RSA. $raw';
    }
    if (normalized.contains('HANDSHAKE')) {
      if (wasAuthorized) {
        return 'No se completó la reconexión ADB. La identidad RSA guardada se conserva; revisa el diagnóstico.';
      }
      return 'No se completó la autorización ADB. Acepta la huella RSA en el dispositivo objetivo.';
    }
    return destination == AcquisitionDestination.transfer
        ? 'No se pudo preparar la transferencia. $raw'
        : 'No se pudo iniciar la captura. $raw';
  }

  String _nonAdbMessage(
    AcquisitionDevice device,
  ) => switch (device.deviceType) {
    'mtp' =>
      device.vendorId == 0x05ac
          ? 'El iPad expone una interfaz MTP/PTP para archivos, pero no ADB para mirror. '
                'Usa Transferencia de archivos para explorar lo que publique. '
                'Interfaces: ${device.interfaceSummary}.'
          : 'El dispositivo expone MTP/PTP, pero no ADB para mirror. '
                'Interfaces: ${device.interfaceSummary}.',
    'hub' =>
      'El hub fue detectado, pero todavía no aparece ningún objetivo con ADB. '
          'Usa un puerto USB-A de datos y confirma Depuración USB en el objetivo.',
    'hid' => 'Se detectó un periférico HID, no un objetivo Android con ADB.',
    'video' =>
      'Se detectó una capturadora UVC. Esta entrada corresponde a Capturadora, '
          'no al mirror Android por ADB.',
    _ =>
      'Android enumeró este periférico USB, pero no publica una interfaz ADB. '
          'Interfaces (clase/subclase/protocolo): ${device.interfaceSummary}.',
  };

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
