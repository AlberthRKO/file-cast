import 'dart:async';

import 'package:file_cast/core/adb/adb_models.dart';
import 'package:flutter/services.dart';

class AdbClient {
  factory AdbClient() => _instance;
  AdbClient._internal();
  static const _methodChannel = MethodChannel('com.fiscalia.file_cast/usb');
  static const _eventChannel = EventChannel(
    'com.fiscalia.file_cast/usb/events',
  );

  StreamController<UsbEvent>? _eventController;
  Stream<UsbEvent>? _eventStream;

  static final AdbClient _instance = AdbClient._internal();

  /// Check if OTG (USB Host) is supported on this device
  Future<bool> isOtgSupported() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isOtgSupported');
      return result ?? false;
    } on PlatformException catch (e) {
      print('AdbClient: Error checking OTG support: ${e.message}');
      return false;
    }
  }

  /// Get list of currently connected USB devices
  Future<List<UsbDeviceInfo>> getConnectedDevices() async {
    try {
      final result = await _methodChannel.invokeMethod<List>(
        'getConnectedDevices',
      );
      if (result == null) return [];
      return result.map((e) => UsbDeviceInfo.fromMap(e as Map)).toList();
    } on PlatformException catch (e) {
      print('AdbClient: Error getting connected devices: ${e.message}');
      return [];
    }
  }

  /// Check if we have permission for a specific device
  Future<bool> hasPermission(String deviceName) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasPermission', {
        'deviceName': deviceName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('AdbClient: Error checking permission: ${e.message}');
      return false;
    }
  }

  /// Request permission for a USB device
  /// Returns true if granted, null if permission dialog is showing
  Future<bool?> requestPermission(String deviceName) async {
    try {
      final result = await _methodChannel.invokeMethod<bool?>(
        'requestPermission',
        {
          'deviceName': deviceName,
        },
      );
      return result;
    } on PlatformException catch (e) {
      print('AdbClient: Error requesting permission: ${e.message}');
      return false;
    }
  }

  /// Open a USB device and get file descriptor
  Future<Map<String, dynamic>?> openDevice(String deviceName) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('openDevice', {
        'deviceName': deviceName,
      });
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print('AdbClient: Error opening device: ${e.message}');
      return null;
    }
  }

  /// Connect ADB to a device
  Future<Map<String, dynamic>?> connectAdb(String deviceName) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('connectAdb', {
        'deviceName': deviceName,
      });
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print('AdbClient: Error connecting ADB: ${e.code} - ${e.message}');
      rethrow; // Rethrow so UI can catch and display details
    }
  }

  /// Disconnect ADB
  Future<bool> disconnectAdb() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('disconnectAdb');
      return result ?? false;
    } on PlatformException catch (e) {
      print('AdbClient: Error disconnecting ADB: ${e.message}');
      return false;
    }
  }

  /// Get current ADB connection state
  Future<Map<String, dynamic>?> getAdbState() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getAdbState');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print('AdbClient: Error getting ADB state: ${e.message}');
      return null;
    }
  }

  /// Get ADB transport log buffer
  Future<String> getAdbLog() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getAdbLog');
      if (result == null) return '';
      return result['log'] as String? ?? '';
    } on PlatformException catch (e) {
      print('AdbClient: Error getting ADB log: ${e.message}');
      return '';
    }
  }

  /// Execute a shell command on the target device and return the output.
  /// Throws PlatformException if ADB is not connected or command fails.
  Future<String> shellCommand(String command, {int timeoutMs = 15000}) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('shellCommand', {
        'command': command,
        'timeoutMs': timeoutMs,
      });
      if (result == null) return '';
      return result['output'] as String? ?? '';
    } on PlatformException catch (e) {
      print('AdbClient: shellCommand error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Start a long-running shell process that stays alive (stream not closed).
  /// The caller MUST call closeStream(localId) when done to kill the process.
  Future<int> startPersistentShell(String command, {int timeoutMs = 10000}) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('startPersistentShell', {
        'command': command,
        'timeoutMs': timeoutMs,
      });
      if (result == null) throw Exception('startPersistentShell returned null');
      return result['localId'] as int;
    } on PlatformException catch (e) {
      print('AdbClient: startPersistentShell error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Push a file to the target device using ADB sync protocol.
  /// Throws PlatformException on error.
  Future<bool> pushFile(
    String localPath,
    String remotePath, {
    int timeoutMs = 30000,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('pushFile', {
        'localPath': localPath,
        'remotePath': remotePath,
        'timeoutMs': timeoutMs,
      });
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('AdbClient: pushFile error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Open an ADB stream (A_OPEN + wait for A_OKAY).
  /// Returns stream info with localId and remoteId.
  Future<Map<String, dynamic>> openStream(String service, {int timeoutMs = 10000}) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('openStream', {
        'service': service,
        'timeoutMs': timeoutMs,
      });
      if (result == null) throw Exception('openStream returned null');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print('AdbClient: openStream error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Read data from an open ADB stream.
  /// Returns map with 'data' (Uint8List or null) and 'closed' (bool).
  Future<Map<String, dynamic>> readStream(int localId, {int timeoutMs = 10000}) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('readStream', {
        'localId': localId,
        'timeoutMs': timeoutMs,
      });
      if (result == null) throw Exception('readStream returned null');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print('AdbClient: readStream error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Close an ADB stream.
  Future<void> closeStream(int localId) async {
    try {
      await _methodChannel.invokeMethod('closeStream', {'localId': localId});
    } on PlatformException catch (e) {
      print('AdbClient: closeStream error: ${e.code} - ${e.message}');
    }
  }

  /// Connect to scrcpy server sockets and read DeviceInfo.
  /// 1. Opens video stream to "localabstract:scrcpy_00000001" (scid=1)
  /// 2. Reads 68-byte DeviceInfo header (64B name + 2B width + 2B height)
  /// 3. Returns parsed device info.
  Future<Map<String, dynamic>> connectScrcpySockets() async {
    final logBuffer = StringBuffer();

    try {
      // scid=-1 (default) → socket name is just "scrcpy"
      final socketName = 'localabstract:scrcpy';
      logBuffer.writeln('[1] Opening video socket ($socketName)...');
      final streamInfo = await openStream(socketName, timeoutMs: 10000);
      final localId = streamInfo['localId'] as int;
      logBuffer.writeln('  Stream opened: localId=$localId');

      logBuffer.writeln('[2] Reading DeviceInfo header (68 bytes)...');
      final readResult = await readStream(localId, timeoutMs: 5000);
      final data = readResult['data'];
      if (data == null) {
        throw Exception('No DeviceInfo data received (stream closed: ${readResult['closed']})');
      }

      final bytes = (data as List).cast<int>();
      logBuffer.writeln('  Received ${bytes.length} bytes');

      if (bytes.length < 68) {
        throw Exception('DeviceInfo too short: ${bytes.length} bytes (need 68)');
      }

      // Parse DeviceInfo: 64B name (null-padded) + 2B width (BE) + 2B height (BE)
      final nameBytes = bytes.sublist(0, 64);
      final nameEnd = nameBytes.indexWhere((b) => b == 0);
      final deviceName = String.fromCharCodes(
        nameBytes.sublist(0, nameEnd > 0 ? nameEnd : 64),
      );
      final width = (bytes[64] << 8) | bytes[65];
      final height = (bytes[66] << 8) | bytes[67];

      logBuffer.writeln('  Device: $deviceName');
      logBuffer.writeln('  Screen: ${width}x$height');

      await closeStream(localId);

      return {
        'deviceName': deviceName,
        'width': width,
        'height': height,
        'log': logBuffer.toString(),
      };
    } catch (e) {
      logBuffer.writeln('ERROR: $e');
      throw Exception('${logBuffer.toString()}\n$e');
    }
  }

  /// Read a Flutter asset and return its bytes as a list of ints.
  /// Uses rootBundle to load from Flutter asset bundle.
  Future<List<int>> readAsset(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List().toList();
    } catch (e) {
      print('AdbClient: readAsset error: $e');
      rethrow;
    }
  }

  /// Listen to USB events (attach, detach, permission, ADB state)
  Stream<UsbEvent> get onUsbEvent {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return UsbEvent.fromMap(event);
      }
      return UsbEvent(type: UsbEventType.deviceAttached);
    });
    return _eventStream!;
  }
}
