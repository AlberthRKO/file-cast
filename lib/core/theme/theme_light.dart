import 'package:file_cast/core/theme/colors.dart';
import 'package:flutter/material.dart';

ThemeData light = ThemeData(
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
      borderRadius: BorderRadius.circular(15),
    ),
    // Define el borde cuando el campo está enfocado
    focusedBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: primary),
      borderRadius: BorderRadius.circular(15),
    ),
    // Define el borde cuando el campo está deshabilitado
    disabledBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: Colors.grey),
      borderRadius: BorderRadius.circular(15),
    ),
    // Define el borde para el error
    errorBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: Colors.red),
      borderRadius: BorderRadius.circular(15),
    ),
    // Define el borde cuando el campo tiene error y está enfocado
    focusedErrorBorder: UnderlineInputBorder(
      borderSide: const BorderSide(width: .8, color: Colors.red),
      borderRadius: BorderRadius.circular(15),
    ),

    border: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(15),
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
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: textBlack,
    ),
    bodyMedium: TextStyle(
      color: textBlack,
    ),
    bodySmall: TextStyle(
      color: textBlack,
    ),
    labelSmall: TextStyle(
      color: grey,
    ),
  ),
);
