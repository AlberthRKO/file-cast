import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/ui/core/theme/app_text_theme.dart';
import 'package:file_cast/ui/core/theme/brand_theme.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';

ThemeData get light => ThemeData(
  fontFamily: 'Montserrat',
  brightness: Brightness.light,
  extensions: const [
    BrandTheme(
      headerGradientStart: Color(0xFF312C69),
      onDark: textWhite,
      folderFront: folder1,
      folderMiddle: folder2,
      folderBack: folder3,
      folderHighlight: folder4,
      actionGradientStart: Color(0xFF1E50A5),
      actionGradientEnd: Color(0xFF2662DE),
      actionSurface: textWhite,
      onActionSurface: textColor,
    ),
  ],
  datePickerTheme: DatePickerThemeData(
    backgroundColor: fondoColor,
    headerBackgroundColor: fondoWhite,
    headerForegroundColor: textColor,
    rangeSelectionBackgroundColor: primary.withOpacity(0.2),
  ),
  dropdownMenuTheme: const DropdownMenuThemeData(
    textStyle: TextStyle(
      fontFamily: 'Montserrat',
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: primary,
  ),
  inputDecorationTheme: InputDecorationTheme(
    enabledBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: primary),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: primary),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    disabledBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: Colors.grey),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    errorBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: Colors.red),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    focusedErrorBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: Colors.red),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    border: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: fondoWhite,
    contentTextStyle: TextStyle(color: grey),
  ),
  colorScheme: const ColorScheme.light(primary: primary)
      .copyWith(surface: fondoColor)
      .copyWith(
        error: const Color(0xFFE84D4F),
      )
      .copyWith(surface: Colors.white)
      .copyWith(surface: fondoColor),
  cardColor: fondoWhite,
  scaffoldBackgroundColor: fondoColor,
  primaryColor: primary,
  hintColor: grey,
  canvasColor: violet,
  textTheme: AppTextTheme.light,
);
