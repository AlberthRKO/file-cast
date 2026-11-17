class UsbDeviceInfo {
  const UsbDeviceInfo({
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.deviceClass,
    required this.deviceSubclass,
    required this.deviceProtocol,
    required this.hasPermission,
    required this.hasAdbInterface,
    required this.deviceType,
    this.interfaceDescriptors = const [],
    this.manufacturerName,
    this.productName,
    this.adbProductModel,
    this.serialNumber,
  });

  factory UsbDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return UsbDeviceInfo(
      deviceName: map['deviceName'] as String? ?? '',
      vendorId: map['vendorId'] as int? ?? 0,
      productId: map['productId'] as int? ?? 0,
      manufacturerName: map['manufacturerName'] as String?,
      productName: map['productName'] as String?,
      adbProductModel: map['adbProductModel'] as String?,
      serialNumber: map['serialNumber'] as String?,
      deviceClass: map['deviceClass'] as int? ?? 0,
      deviceSubclass: map['deviceSubclass'] as int? ?? 0,
      deviceProtocol: map['deviceProtocol'] as int? ?? 0,
      hasPermission: map['hasPermission'] as bool? ?? false,
      hasAdbInterface: map['hasAdbInterface'] as bool? ?? false,
      deviceType: map['deviceType'] as String? ?? 'other',
      interfaceDescriptors: (map['interfaces'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (interface) =>
                '${interface['class'] ?? '?'} / '
                '${interface['subclass'] ?? '?'} / '
                '${interface['protocol'] ?? '?'}',
          )
          .toList(growable: false),
    );
  }

  final String deviceName;
  final int vendorId;
  final int productId;
  final String? manufacturerName;
  final String? productName;
  final String? adbProductModel;
  final String? serialNumber;
  final int deviceClass;
  final int deviceSubclass;
  final int deviceProtocol;
  final bool hasPermission;
  final bool hasAdbInterface;
  final String deviceType;
  final List<String> interfaceDescriptors;

  String get interfaceSummary => interfaceDescriptors.isEmpty
      ? 'Sin descriptores de interfaz'
      : interfaceDescriptors.join(', ');

  String get displayName {
    final manufacturer = manufacturerName?.trim();
    final resolvedAdbModel = adbProductModel?.trim();
    final usbProduct = productName?.trim();
    final product = resolvedAdbModel?.isNotEmpty == true
        ? resolvedAdbModel
        : _isGenericAndroidProduct(usbProduct)
        ? null
        : usbProduct;
    if (manufacturer != null &&
        manufacturer.isNotEmpty &&
        product != null &&
        product.isNotEmpty) {
      if (product.toLowerCase().startsWith(manufacturer.toLowerCase())) {
        return product;
      }
      return '$manufacturer $product';
    }
    if (product != null && product.isNotEmpty) return product;
    if (manufacturer != null && manufacturer.isNotEmpty) {
      if (hasAdbInterface) return '$manufacturer · modelo pendiente';
      return '$manufacturer (0x${vendorId.toRadixString(16).toUpperCase()})';
    }
    return 'USB Device (0x${vendorId.toRadixString(16).toUpperCase()})';
  }

  bool _isGenericAndroidProduct(String? value) {
    if (value == null || value.isEmpty) return true;
    final normalized = value.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalized == 'android' ||
        normalized == 'androidadb' ||
        normalized == 'samsungandroid';
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
  mirrorState,
  fileTransfer,
  multiAdbState,
  multiMirrorState,
  multiSessionState,
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
          case 'mirror_state':
            return UsbEventType.mirrorState;
          case 'file_transfer':
            return UsbEventType.fileTransfer;
          case 'multi_adb_state':
            return UsbEventType.multiAdbState;
          case 'multi_mirror_state':
            return UsbEventType.multiMirrorState;
          case 'multi_session_state':
            return UsbEventType.multiSessionState;
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

  Map<String, dynamic>? get mirrorStateInfo {
    final raw = _data;
    if (type != UsbEventType.mirrorState || raw is! Map) return null;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic>? get fileTransferInfo {
    final raw = _data;
    if (type != UsbEventType.fileTransfer || raw is! Map) return null;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic>? get multiSessionInfo {
    final raw = _data;
    if (raw is! Map) return null;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
}
