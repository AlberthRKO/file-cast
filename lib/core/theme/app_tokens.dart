import 'package:file_cast/core/theme/tokens/component_tokens.dart';
import 'package:file_cast/core/theme/tokens/font_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTokens {
  AppTokens._();

  // Spacing - primitivos puros, sin context
  static double spaceXs(BuildContext context) => 4.w;
  static double spaceSm(BuildContext context) => 8.w;
  static double spaceMd(BuildContext context) => 16.w;
  static double spaceLg(BuildContext context) => 24.w;
  static double spaceXl(BuildContext context) => 32.w;

  // Font sizes - delegados a FontTokens
  static double fontCaption(BuildContext context) => FontTokens.caption(context);
  static double fontBody(BuildContext context) => FontTokens.body(context);
  static double fontTitle(BuildContext context) => FontTokens.title(context);

  // Icons - primitivos puros
  static double iconSm(BuildContext context) => 16.r;
  static double iconMd(BuildContext context) => 20.r;
  static double iconLg(BuildContext context) => 28.r;

  // Component heights - delegado a ComponentTokens
  static double buttonHeightMd(BuildContext context) => ComponentTokens.buttonHeight(context);
}
