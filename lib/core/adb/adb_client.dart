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
