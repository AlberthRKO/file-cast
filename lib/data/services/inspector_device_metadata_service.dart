import 'dart:io';

import 'package:flutter/services.dart';

/// Identidad descriptiva del equipo que ejecuta File Cast.
class InspectorDeviceMetadataService {
  static const _android = MethodChannel('com.fiscalia.file_cast/usb');
  static const _ios = MethodChannel(
    'com.fiscalia.file_cast/evidence_photo_library',
  );

  Future<String?> deviceName() async {
    try {
      final channel = Platform.isAndroid
          ? _android
          : Platform.isIOS
          ? _ios
          : null;
      final name = await channel?.invokeMethod<String>(
        'getInspectorDeviceName',
      );
      return name?.trim().isNotEmpty == true ? name!.trim() : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
