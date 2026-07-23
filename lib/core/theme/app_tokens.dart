import 'package:file_cast/core/responsive/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTokens {
  AppTokens._();

  // Spacing
  static double spaceXs(BuildContext context) => 4.w;
  static double spaceSm(BuildContext context) => 8.w;
  static double spaceMd(BuildContext context) => 16.w;
  static double spaceLg(BuildContext context) => 24.w;
  static double spaceXl(BuildContext context) => 32.w;

  // Font sizes (ajuste por tipo de dispositivo)
  static double fontCaption(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 14.sp : 12.sp;
  }

  static double fontBody(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 16.sp : 14.sp;
  }

  static double fontTitle(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 20.sp : 24.sp;
  }

  // Icons
  static double iconSm(BuildContext context) => 16.r;
  static double iconMd(BuildContext context) => 20.r;
  static double iconLg(BuildContext context) => 28.r;

  // Component heights
  static double buttonHeightMd(BuildContext context) {
    final device = DeviceInfo.of(context);
    return device.isTablet ? 56.h : 48.h;
  }
}
