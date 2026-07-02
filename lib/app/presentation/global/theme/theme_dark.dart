import 'package:flutter/material.dart';
import 'package:file_cast/app/presentation/global/theme/colors.dart';

ThemeData dark = ThemeData(
  fontFamily: 'Poppins',
  brightness: Brightness.dark,
  timePickerTheme: const TimePickerThemeData(
    backgroundColor: fondoColorDark,
    hourMinuteColor: colorCardDark,
    dialBackgroundColor: colorCardDark,
    dayPeriodColor: textDark,
    helpTextStyle: TextStyle(color: Colors.white), // Texto superior
    hourMinuteTextColor: textDark, // Texto de hora y minutos
  ),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: fondoColorDark,
    headerBackgroundColor: colorCardDark,
    headerForegroundColor: Colors.white,
    rangeSelectionBackgroundColor: primaryDark.withOpacity(0.2),
  ),
  dropdownMenuTheme: const DropdownMenuThemeData(
    textStyle: TextStyle(
      fontFamily: 'Poppins',
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: primaryDark,
  ),
  inputDecorationTheme: InputDecorationTheme(
    enabledBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: primaryDark),
      borderRadius: BorderRadius.circular(15),
    ),
    // Define el borde cuando el campo está enfocado
    focusedBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: primaryDark),
      borderRadius: BorderRadius.circular(15),
    ),
    // Define el borde cuando el campo está deshabilitado
    disabledBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: Colors.grey),
      borderRadius: BorderRadius.circular(15),
    ),
    // Define el borde para el error
    errorBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: deleteColor),
      borderRadius: BorderRadius.circular(15),
    ),
    // Define el borde cuando el campo tiene error y está enfocado
    focusedErrorBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: deleteColor),
      borderRadius: BorderRadius.circular(15),
    ),

    border: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(15),
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
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: textDark,
    ),
    bodyMedium: TextStyle(
      color: textDark,
    ),
    bodySmall: TextStyle(
      color: textDark,
    ),
    labelSmall: TextStyle(
      color: greyDark,
    ),
  ),
);
