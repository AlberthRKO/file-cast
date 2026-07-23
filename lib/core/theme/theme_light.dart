import 'package:file_cast/core/theme/app_dimensions.dart';
import 'package:file_cast/core/theme/app_text_styles.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:flutter/material.dart';

ThemeData get light => ThemeData(
      fontFamily: 'Montserrat',
      brightness: Brightness.light,
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
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: primary),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.grey),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
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
      textTheme: AppTextStyles.lightTextTheme,
    );
