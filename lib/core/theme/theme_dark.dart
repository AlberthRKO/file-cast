import 'package:file_cast/core/theme/app_dimensions.dart';
import 'package:file_cast/core/theme/app_text_styles.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:flutter/material.dart';

ThemeData get dark => ThemeData(
      fontFamily: 'Montserrat',
      brightness: Brightness.dark,
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
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: primaryDark),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.grey),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: deleteColor),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: deleteColor),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
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
      textTheme: AppTextStyles.darkTextTheme,
    );
