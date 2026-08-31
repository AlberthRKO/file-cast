import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({
    required SecureStorageService storage,
    required bool initialDarkMode,
  }) : _storage = storage,
       _darkMode = initialDarkMode;

  static const _themeKey = 'dark_mode';
  final SecureStorageService _storage;
  bool _darkMode;

  bool get darkMode => _darkMode;

  Future<void> loadTheme() async {
    final storedTheme = await _storage.read(_themeKey);
    if (storedTheme == null) return;

    _darkMode = storedTheme == 'true';
    notifyListeners();
  }

  Future<void> onChange(bool value) async {
    if (_darkMode == value) return;

    _darkMode = value;
    await _storage.write(_themeKey, value.toString());
    SystemChrome.setSystemUIOverlayStyle(
      value ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    notifyListeners();
  }
}
