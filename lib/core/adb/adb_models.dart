class UsbDeviceInfo {
  const UsbDeviceInfo({
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.deviceClass,
    required this.deviceSubclass,
    required this.deviceProtocol,
    required this.hasPermission,
    this.manufacturerName,
    this.productName,
    this.serialNumber,
  });

  factory UsbDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return UsbDeviceInfo(
      deviceName: map['deviceName'] as String? ?? '',
      vendorId: map['vendorId'] as int? ?? 0,
      productId: map['productId'] as int? ?? 0,
      manufacturerName: map['manufacturerName'] as String?,
      productName: map['productName'] as String?,
      serialNumber: map['serialNumber'] as String?,
      deviceClass: map['deviceClass'] as int? ?? 0,
      deviceSubclass: map['deviceSubclass'] as int? ?? 0,
      deviceProtocol: map['deviceProtocol'] as int? ?? 0,
      hasPermission: map['hasPermission'] as bool? ?? false,
    );
  }

  final String deviceName;
  final int vendorId;
  final int productId;
  final String? manufacturerName;
  final String? productName;
  final String? serialNumber;
  final int deviceClass;
  final int deviceSubclass;
  final int deviceProtocol;
  final bool hasPermission;

  String get displayName {
    if (manufacturerName != null && productName != null) {
      return '$manufacturerName $productName';
    }
    if (manufacturerName != null) {
      return '$manufacturerName (0x${vendorId.toRadixString(16).toUpperCase()})';
    }
    return 'USB Device (0x${vendorId.toRadixString(16).toUpperCase()})';
  }

  String get vendorIdHex => '0x${vendorId.toRadixString(16).toUpperCase()}';
  String get productIdHex => '0x${productId.toRadixString(16).toUpperCase()}';

  @override
  String toString() =>
      'UsbDeviceInfo($displayName, vendorId: $vendorIdHex, productId: $productIdHex)';
}

enum UsbEventType {
  initialDevices,
  deviceAttached,
  deviceDetached,
  deviceConnected,
  permissionDenied,
  adbState,
}

class UsbEvent {
  UsbEvent({
    required this.type,
    dynamic data,
  }) : _data = data;

  factory UsbEvent.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type'] as String?;
    final rawData = map['data'];

    final type = UsbEventType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () {
        // Map snake_case strings from Kotlin to camelCase enum values
        switch (typeStr) {
          case 'initial_devices':
            return UsbEventType.initialDevices;
          case 'device_attached':
            return UsbEventType.deviceAttached;
          case 'device_detached':
            return UsbEventType.deviceDetached;
          case 'device_connected':
            return UsbEventType.deviceConnected;
          case 'permission_denied':
            return UsbEventType.permissionDenied;
          case 'adb_state':
            return UsbEventType.adbState;
          default:
            return UsbEventType.deviceAttached;
        }
      },
    );

    return UsbEvent(type: type, data: rawData);
  }

  final UsbEventType type;
  final dynamic _data;

  List<UsbDeviceInfo> get devices {
    final raw = _data;
    if (raw is List) {
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(UsbDeviceInfo.fromMap)
          .toList();
    }
    if (raw is Map<dynamic, dynamic>) {
      return [UsbDeviceInfo.fromMap(raw)];
    }
    return [];
  }

  /// Get ADB state info (state + message + log)
  Map<String, dynamic>? get adbStateInfo {
    final raw = _data;
    if (raw is Map) {
      return {
        'state': raw['state'] as String? ?? 'unknown',
        'message': raw['message'] as String?,
        'log': raw['log'] as String? ?? '',
      };
    }
    return null;
  }
}
