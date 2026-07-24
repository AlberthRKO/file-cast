import 'package:file_cast/core/responsive/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FontTokens {
  FontTokens._();

  static double caption(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 14.sp : 12.sp;
  }

  static double body(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 16.sp : 14.sp;
  }

  static double title(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 20.sp : 24.sp;
  }
}
