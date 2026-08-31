import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/ui/core/theme/app_text_theme.dart';
import 'package:file_cast/ui/core/theme/brand_theme.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';

ThemeData get dark => ThemeData(
  fontFamily: 'Montserrat',
  brightness: Brightness.dark,
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
  timePickerTheme: const TimePickerThemeData(
    backgroundColor: fondoColorDark,
    hourMinuteColor: colorCardDark,
    dialBackgroundColor: colorCardDark,
    dayPeriodColor: textDark,
    helpTextStyle: TextStyle(color: Colors.white),
    hourMinuteTextColor: textDark,
  ),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: fondoColorDark,
    headerBackgroundColor: colorCardDark,
    headerForegroundColor: Colors.white,
    rangeSelectionBackgroundColor: primaryDark.withOpacity(0.2),
  ),
  dropdownMenuTheme: const DropdownMenuThemeData(
    textStyle: TextStyle(
      fontFamily: 'Montserrat',
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: primaryDark,
  ),
  inputDecorationTheme: InputDecorationTheme(
    enabledBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: primaryDark),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: primaryDark),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    disabledBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: Colors.grey),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    errorBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: deleteColor),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    focusedErrorBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: deleteColor),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    border: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: colorCardDark,
    contentTextStyle: TextStyle(color: greyDark),
  ),
  colorScheme: const ColorScheme.dark(primary: primaryDark)
      .copyWith(surface: violet)
      .copyWith(
        error: const Color(0xFFE84D4F),
      )
      .copyWith(surface: violet)
      .copyWith(surface: violet),
  cardColor: colorCardDark,
  scaffoldBackgroundColor: fondoColorDark,
  primaryColor: textDarkBold,
  canvasColor: greyDark,
  hintColor: greyDark,
  textTheme: AppTextTheme.dark,
);
