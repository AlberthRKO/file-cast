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
  final Map<int, List<int>> _readRemainders = {};

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
  Future<int> startPersistentShell(
    String command, {
    int timeoutMs = 10000,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'startPersistentShell',
        {
          'command': command,
          'timeoutMs': timeoutMs,
        },
      );
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

  Future<List<Map<String, dynamic>>> listRemoteFiles(
    String remotePath, {
    int timeoutMs = 30000,
  }) async {
    final result = await _methodChannel.invokeMethod<List>('listRemoteFiles', {
      'remotePath': remotePath,
      'timeoutMs': timeoutMs,
    });
    if (result == null) return const [];
    return result
        .whereType<Map>()
        .map(
          (entry) => entry.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> statRemoteFile(
    String remotePath, {
    int timeoutMs = 30000,
  }) async {
    final result = await _methodChannel.invokeMethod<Map>('statRemoteFile', {
      'remotePath': remotePath,
      'timeoutMs': timeoutMs,
    });
    if (result == null) throw StateError('statRemoteFile returned null');
    return result.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<Map<String, dynamic>> pullRemoteFiles({
    required String requisitionId,
    required String sessionId,
    required String transferId,
    required List<String> remotePaths,
    bool previewOnly = false,
    int timeoutMs = 30000,
  }) async {
    final result = await _methodChannel.invokeMethod<Map>('pullRemoteFiles', {
      'requisitionId': requisitionId,
      'sessionId': sessionId,
      'transferId': transferId,
      'remotePaths': remotePaths,
      'previewOnly': previewOnly,
      'timeoutMs': timeoutMs,
    });
    if (result == null) throw StateError('pullRemoteFiles returned null');
    return result.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> discardRemoteFilePreview({
    required String requisitionId,
    required String sessionId,
  }) async {
    await _methodChannel.invokeMethod<void>('discardRemoteFilePreview', {
      'requisitionId': requisitionId,
      'sessionId': sessionId,
    });
  }

  Future<void> cancelFileTransfer() async {
    await _methodChannel.invokeMethod<void>('cancelFileTransfer');
  }

  /// Open an ADB stream (A_OPEN + wait for A_OKAY).
  /// Returns stream info with localId and remoteId.
  Future<Map<String, dynamic>> openStream(
    String service, {
    int timeoutMs = 10000,
  }) async {
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
  Future<Map<String, dynamic>> readStream(
    int localId, {
    int timeoutMs = 10000,
  }) async {
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
    _readRemainders.remove(localId);
    try {
      await _methodChannel.invokeMethod('closeStream', {'localId': localId});
    } on PlatformException catch (e) {
      print('AdbClient: closeStream error: ${e.code} - ${e.message}');
    }
  }

  /// Read exactly [n] bytes from a stream, accumulating across multiple WRTE packets.
  Future<List<int>> _readExact(
    int localId,
    int n, {
    int timeoutMs = 5000,
  }) async {
    final buffer = <int>[...?_readRemainders.remove(localId)];
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
    if (buffer.length > n) {
      _readRemainders[localId] = buffer.sublist(n);
    }
    return buffer.sublist(0, n);
  }

  /// Connect to scrcpy server socket and read device info header.
  /// v2.7 protocol: 1B dummy + 64B name + 4B codec_id + 4B width + 4B height (all BE)
  /// Total header: 77 bytes. Stream stays open for video frames (Phase 6).
  /// Also opens control stream (second connection to same socket).
  /// IMPORTANT: With control=true, server waits for BOTH connections before sending header.
  Future<Map<String, dynamic>> connectScrcpySockets() async {
    final logBuffer = StringBuffer();

    try {
      final socketName = 'localabstract:scrcpy';

      // Open video stream (first connection)
      logBuffer.writeln('[1] Opening video socket ($socketName)...');
      final streamInfo = await openStream(socketName, timeoutMs: 10000);
      final localId = streamInfo['localId'] as int;
      logBuffer.writeln('  Video stream opened: localId=$localId');

      // Open control stream (second connection) — MUST be done before reading header
      // because with control=true, server waits for both connections
      logBuffer.writeln('[2] Opening control socket ($socketName)...');
      final controlInfo = await openStream(socketName, timeoutMs: 10000);
      final controlLocalId = controlInfo['localId'] as int;
      logBuffer.writeln('  Control stream opened: localId=$controlLocalId');

      // Now server sends the video header on the first stream
      logBuffer.writeln('[3] Reading dummy byte...');
      final dummy = await _readExact(localId, 1);
      logBuffer.writeln('  Dummy byte: 0x${dummy[0].toRadixString(16)}');

      logBuffer.writeln('[4] Reading device name (64 bytes)...');
      final nameBytes = await _readExact(localId, 64);
      final nameEnd = nameBytes.indexWhere((b) => b == 0);
      final deviceName = String.fromCharCodes(
        nameBytes.sublist(0, nameEnd > 0 ? nameEnd : 64),
      );
      logBuffer.writeln('  Device: $deviceName');

      logBuffer.writeln('[5] Reading video codec metadata (12 bytes)...');
      final codecMeta = await _readExact(localId, 12);
      final hexBytes = codecMeta
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      logBuffer.writeln('  Raw bytes: $hexBytes');
      final codecId =
          (codecMeta[0] << 24) |
          (codecMeta[1] << 16) |
          (codecMeta[2] << 8) |
          codecMeta[3];
      final width =
          (codecMeta[4] << 24) |
          (codecMeta[5] << 16) |
          (codecMeta[6] << 8) |
          codecMeta[7];
      final height =
          (codecMeta[8] << 24) |
          (codecMeta[9] << 16) |
          (codecMeta[10] << 8) |
          codecMeta[11];
      final codecFourcc = String.fromCharCodes(codecMeta.sublist(0, 4));

      logBuffer.writeln(
        '  Codec: $codecFourcc (id=0x${codecId.toRadixString(16)})',
      );
      logBuffer.writeln('  Screen: ${width}x$height');
      logBuffer.writeln(
        '  (bytes[4..7] width raw: ${codecMeta[4]},${codecMeta[5]},${codecMeta[6]},${codecMeta[7]})',
      );
      logBuffer.writeln(
        '  (bytes[8..11] height raw: ${codecMeta[8]},${codecMeta[9]},${codecMeta[10]},${codecMeta[11]})',
      );
      logBuffer.writeln('\n--- Phase 5 SUCCESS: Server connected! ---');

      return {
        'deviceName': deviceName,
        'width': width,
        'height': height,
        'codec': codecFourcc,
        'localId': localId,
        'controlLocalId': controlLocalId,
        'log': logBuffer.toString(),
      };
    } catch (e) {
      logBuffer.writeln('ERROR: $e');
      throw Exception('${logBuffer.toString()}\n$e');
    }
  }

  /// Create a Flutter Texture backed by a SurfaceTexture.
  /// Returns the textureId to use with the Texture widget.
  Future<int> createMirrorTexture() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'createMirrorTexture',
      );
      if (result == null) throw Exception('createMirrorTexture returned null');
      return result['textureId'] as int;
    } on PlatformException catch (e) {
      print('AdbClient: createMirrorTexture error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Start video mirror decoding to the created texture.
  /// Connects MediaCodec to the Surface and starts the native video read loop.
  Future<void> startMirror(
    int width,
    int height, {
    required int videoStreamLocalId,
  }) async {
    try {
      await _methodChannel.invokeMethod('startMirror', {
        'width': width,
        'height': height,
        'videoStreamLocalId': videoStreamLocalId,
      });
    } on PlatformException catch (e) {
      print('AdbClient: startMirror error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Stop video mirror and release decoder + texture.
  Future<void> stopMirror() async {
    try {
      await _methodChannel.invokeMethod('stopMirror');
    } on PlatformException catch (e) {
      print('AdbClient: stopMirror error: ${e.code} - ${e.message}');
    }
  }

  /// Captures the target screen directly through ADB and stores the PNG in the
  /// app-private staging area. Only metadata crosses the platform channel.
  Future<Map<String, dynamic>> captureScreenshot({
    required String requisitionId,
    required String sessionId,
  }) async {
    final result = await _methodChannel.invokeMethod<Map>('captureScreenshot', {
      'requisitionId': requisitionId,
      'sessionId': sessionId,
    });
    if (result == null) throw StateError('captureScreenshot returned null');
    return Map<String, dynamic>.from(result);
  }

  /// Starts recording the already active scrcpy H.264 stream to an MP4 file.
  Future<Map<String, dynamic>> startScreenRecording({
    required String requisitionId,
    required String sessionId,
  }) async {
    final result = await _methodChannel.invokeMethod<Map>(
      'startScreenRecording',
      {'requisitionId': requisitionId, 'sessionId': sessionId},
    );
    if (result == null) throw StateError('startScreenRecording returned null');
    return Map<String, dynamic>.from(result);
  }

  /// Finalizes the current MP4 and returns its local evidence metadata.
  Future<Map<String, dynamic>> stopScreenRecording() async {
    final result = await _methodChannel.invokeMethod<Map>(
      'stopScreenRecording',
    );
    if (result == null) throw StateError('stopScreenRecording returned null');
    return Map<String, dynamic>.from(result);
  }

  /// Get mirror decoder + transport logs for debugging.
  Future<String> getMirrorLog() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getMirrorLog');
      if (result == null) return '';
      return result['log'] as String? ?? '';
    } on PlatformException catch (e) {
      print('AdbClient: getMirrorLog error: ${e.code} - ${e.message}');
      return '';
    }
  }

  Future<Map<String, dynamic>> getMirrorDiagnostics() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getMirrorLog');
      if (result == null) return const {};
      return result.map((key, value) => MapEntry(key.toString(), value));
    } on PlatformException catch (e) {
      print('AdbClient: getMirrorDiagnostics error: ${e.code} - ${e.message}');
      return const {};
    }
  }

  /// Get scrcpy-server stdout/stderr log (drains accumulated output from server shell stream).
  Future<String> getServerLog() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getServerLog');
      if (result == null) return '';
      return result['log'] as String? ?? '';
    } on PlatformException catch (e) {
      print('AdbClient: getServerLog error: ${e.code} - ${e.message}');
      return '';
    }
  }

  /// Get the actual device screen size via `wm size`.
  /// Returns (width, height) in pixels.
  Future<(int, int)?> getDeviceScreenSize() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'getDeviceScreenSize',
      );
      if (result == null) return null;
      final w = result['width'] as int?;
      final h = result['height'] as int?;
      if (w != null && h != null) return (w, h);
      return null;
    } on PlatformException catch (e) {
      print('AdbClient: getDeviceScreenSize error: ${e.code} - ${e.message}');
      return null;
    }
  }

  /// Send a touch event to the target device via control stream.
  /// [action]: 0=down, 1=up, 2=move
  /// [pointerId]: stable Flutter pointer identifier for the gesture
  /// [x], [y]: touch coordinates in device screen space
  Future<void> sendTouch(
    int action,
    int pointerId,
    int x,
    int y,
    int screenWidth,
    int screenHeight, {
    int pressure = 0xFFFF,
  }) async {
    try {
      await _methodChannel.invokeMethod('sendTouch', {
        'action': action,
        'pointerId': pointerId,
        'x': x,
        'y': y,
        'screenWidth': screenWidth,
        'screenHeight': screenHeight,
        'pressure': pressure,
      });
    } on PlatformException catch (e) {
      print('AdbClient: sendTouch error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Send a key event to the target device via control stream.
  /// [action]: 0=down, 1=up
  /// [keycode]: Android keycode (e.g., 3=HOME, 4=BACK, 26=POWER)
  Future<void> sendKey(int action, int keycode) async {
    try {
      await _methodChannel.invokeMethod('sendKey', {
        'action': action,
        'keycode': keycode,
      });
    } on PlatformException catch (e) {
      print('AdbClient: sendKey error: ${e.code} - ${e.message}');
    }
  }

  /// Send a scroll event to the target device via control stream.
  /// [scrollY]: vertical scroll amount (positive=up, negative=down)
  Future<void> sendScroll(
    int x,
    int y,
    int scrollX,
    int scrollY,
    int screenWidth,
    int screenHeight,
  ) async {
    try {
      await _methodChannel.invokeMethod('sendScroll', {
        'x': x,
        'y': y,
        'scrollX': scrollX,
        'scrollY': scrollY,
        'screenWidth': screenWidth,
        'screenHeight': screenHeight,
      });
    } on PlatformException catch (e) {
      print('AdbClient: sendScroll error: ${e.code} - ${e.message}');
    }
  }

  /// Send a back key press (down + up) to the target device.
  Future<void> sendBack() async {
    await sendKey(0, 4); // ACTION_DOWN, AKEYCODE_BACK
    await sendKey(1, 4); // ACTION_UP, AKEYCODE_BACK
  }

  /// Send a home key press (down + up) to the target device.
  Future<void> sendHome() async {
    await sendKey(0, 3); // ACTION_DOWN, AKEYCODE_HOME
    await sendKey(1, 3); // ACTION_UP, AKEYCODE_HOME
  }

  /// Send a power key press (down + up) to the target device.
  Future<void> sendPower() async {
    await sendKey(0, 26); // ACTION_DOWN, AKEYCODE_POWER
    await sendKey(1, 26); // ACTION_UP, AKEYCODE_POWER
  }

  /// Send volume up key press.
  Future<void> sendVolumeUp() async {
    await sendKey(0, 24); // ACTION_DOWN, AKEYCODE_VOLUME_UP
    await sendKey(1, 24); // ACTION_UP, AKEYCODE_VOLUME_UP
  }

  /// Send volume down key press.
  Future<void> sendVolumeDown() async {
    await sendKey(0, 25); // ACTION_DOWN, AKEYCODE_VOLUME_DOWN
    await sendKey(1, 25); // ACTION_UP, AKEYCODE_VOLUME_DOWN
  }

  /// Send app switch (recent apps) key press.
  Future<void> sendAppSwitch() async {
    await sendKey(0, 187); // ACTION_DOWN, AKEYCODE_APP_SWITCH
    await sendKey(1, 187); // ACTION_UP, AKEYCODE_APP_SWITCH
  }

  /// Set the control stream localId and device screen dimensions on the native side.
  /// Returns wm size info for debugging.
  Future<Map<String, dynamic>> setControlStream(
    int controlLocalId,
    int screenWidth,
    int screenHeight,
  ) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'setControlStream',
        {
          'controlLocalId': controlLocalId,
          'screenWidth': screenWidth,
          'screenHeight': screenHeight,
        },
      );
      if (result != null) {
        final map = result.map((key, value) => MapEntry(key.toString(), value));
        final streamOpen = map['streamOpen'] as bool? ?? false;
        final wmWidth = map['wmSizeWidth'] as int? ?? 0;
        final wmHeight = map['wmSizeHeight'] as int? ?? 0;
        final wmRaw = map['wmSizeRaw'] as String? ?? '';
        print(
          'AdbClient: setControlStream: controlId=${map['controlId']} streamOpen=$streamOpen',
        );
        print('  header: ${map['headerWidth']}x${map['headerHeight']}');
        print('  wm size: ${wmWidth}x${wmHeight} raw="$wmRaw"');
        if (!streamOpen) {
          print(
            'AdbClient: WARNING - control stream $controlLocalId is NOT open!',
          );
        }
        return map;
      }
      return {};
    } on PlatformException catch (e) {
      print('AdbClient: setControlStream error: ${e.code} - ${e.message}');
      return {};
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
