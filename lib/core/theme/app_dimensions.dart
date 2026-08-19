import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppDimensions {
  AppDimensions._();
  // Spacing
  static double get spaceXXS => 2.w;
  static double get spaceXS => 4.w;
  static double get spaceS => 8.w;
  static double get spaceM => 16.w;
  static double get spaceL => 24.w;
  static double get spaceXL => 32.w;
  static double get spaceXXL => 48.w;

  // Border Radius
  static double get radiusXS => 4.r;
  static double get radiusS => 8.r;
  static double get radiusM => 12.r;
  static double get radiusL => 16.r;
  static double get radiusXL => 20.r;
  static double get radiusFull => 999.r;

  // Icon Sizes
  static double get iconXS => 12.r;
  static double get iconS => 16.r;
  static double get iconM => 20.r;
  static double get iconL => 24.r;
  static double get iconXL => 32.r;

  // Button Heights
  static double get buttonHeightS => 36.h;
  static double get buttonHeightM => 48.h;
  static double get buttonHeightL => 56.h;

  // Input
  static double get inputHeight => 50.h;
  static double get inputBorderWidth => 0.8;
}
