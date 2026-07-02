import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeController extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _darkMode;

  ThemeController(this._darkMode);

  bool get darkMode => _darkMode;

  // Clave para guardar el estado del tema en el almacenamiento
  static const String _themeKey = 'dark_mode';

  Future<void> loadTheme() async {
    // Recuperar el valor del tema desde el almacenamiento
    final storedTheme = await _storage.read(key: _themeKey);
    if (storedTheme != null) {
      _darkMode = storedTheme == 'true';
      notifyListeners();
    }
  }

  void onChange(bool darkMode) async {
    _darkMode = darkMode;

    // Guardar la selección del tema en el almacenamiento seguro
    await _storage.write(key: _themeKey, value: darkMode.toString());
    final storedTheme = await _storage.read(key: _themeKey);
    print("Dato guardado: $storedTheme");
    // Cambiar el estilo del sistema
    if (darkMode) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    } else {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    }

    notifyListeners();
  }
}
