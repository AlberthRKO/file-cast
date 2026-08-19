import 'package:file_cast/core/responsive/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FontTokens {
  FontTokens._();

  static double captionS(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 4.sp : 8.sp;
  }

  static double caption(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 6.sp : 10.sp;
  }

  static double body(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 10.sp : 14.sp;
  }

  static double title(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 18.sp : 24.sp;
  }
}
