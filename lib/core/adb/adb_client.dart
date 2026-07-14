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

  /// Read exactly [n] bytes from a stream, accumulating across multiple WRTE packets.
  Future<List<int>> _readExact(int localId, int n, {int timeoutMs = 5000}) async {
    final buffer = <int>[];
    while (buffer.length < n) {
      final result = await readStream(localId, timeoutMs: timeoutMs);
      final data = result['data'];
      if (data == null) {
        throw Exception(
          'Stream closed while reading (got ${buffer.length}/$n bytes, closed=${result['closed']})',
        );
      }
      buffer.addAll((data as List).cast<int>());
    }
    return buffer;
  }

  /// Connect to scrcpy server socket and read device info header.
  /// v2.7 protocol: 1B dummy + 64B name + 4B codec_id + 4B width + 4B height (all BE)
  /// Total header: 77 bytes. Stream stays open for video frames (Phase 6).
  Future<Map<String, dynamic>> connectScrcpySockets() async {
    final logBuffer = StringBuffer();

    try {
      final socketName = 'localabstract:scrcpy';
      logBuffer.writeln('[1] Opening video socket ($socketName)...');
      final streamInfo = await openStream(socketName, timeoutMs: 10000);
      final localId = streamInfo['localId'] as int;
      logBuffer.writeln('  Stream opened: localId=$localId');

      logBuffer.writeln('[2] Reading dummy byte...');
      final dummy = await _readExact(localId, 1);
      logBuffer.writeln('  Dummy byte: 0x${dummy[0].toRadixString(16)}');

      logBuffer.writeln('[3] Reading device name (64 bytes)...');
      final nameBytes = await _readExact(localId, 64);
      final nameEnd = nameBytes.indexWhere((b) => b == 0);
      final deviceName = String.fromCharCodes(
        nameBytes.sublist(0, nameEnd > 0 ? nameEnd : 64),
      );
      logBuffer.writeln('  Device: $deviceName');

      logBuffer.writeln('[4] Reading video codec metadata (12 bytes)...');
      final codecMeta = await _readExact(localId, 12);
      final codecId = (codecMeta[0] << 24) | (codecMeta[1] << 16) | (codecMeta[2] << 8) | codecMeta[3];
      final width = (codecMeta[4] << 24) | (codecMeta[5] << 16) | (codecMeta[6] << 8) | codecMeta[7];
      final height = (codecMeta[8] << 24) | (codecMeta[9] << 16) | (codecMeta[10] << 8) | codecMeta[11];
      final codecFourcc = String.fromCharCodes(codecMeta.sublist(0, 4));

      logBuffer.writeln('  Codec: $codecFourcc (0x${codecId.toRadixString(16)})');
      logBuffer.writeln('  Screen: ${width}x$height');
      logBuffer.writeln('\n--- Phase 5 SUCCESS: Server connected! ---');

      return {
        'deviceName': deviceName,
        'width': width,
        'height': height,
        'codec': codecFourcc,
        'localId': localId,
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
