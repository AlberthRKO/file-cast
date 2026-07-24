import 'package:file_cast/core/responsive/device_type.dart';
import 'package:file_cast/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

class ComponentTokens {
  ComponentTokens._();

  static double buttonHeight(BuildContext context) {
    final device = DeviceInfo.of(context);

    if (device.isTablet) {
      return device.isLandscape
          ? AppDimensions.buttonHeightS
          : AppDimensions.buttonHeightL;
    }
    return device.isLandscape
        ? AppDimensions.buttonHeightS
        : AppDimensions.buttonHeightM;
  }

  static double inputHeight(BuildContext context) => AppDimensions.inputHeight;
}
