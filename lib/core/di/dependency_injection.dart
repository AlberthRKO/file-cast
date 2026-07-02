import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/core/storage/local_storage_service.dart';
import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:file_cast/presentation/providers/theme_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DependencyInjection {
  static List<SingleChildWidget> providers() {
    return [
      Provider<FlutterSecureStorage>(
        create: (_) => const FlutterSecureStorage(),
      ),
      FutureProvider<SharedPreferences?>(
        create: (_) async => SharedPreferences.getInstance(),
        lazy: false,
        initialData: null,
      ),
      ProxyProvider<FlutterSecureStorage, SecureStorageService>(
        update: (_, storage, _) => SecureStorageService(storage),
      ),
      ProxyProvider<SharedPreferences?, LocalStorageService>(
        update: (_, prefs, _) => LocalStorageService(prefs!),
      ),
      Provider<Http>(
        create: (_) => Http(
          client: http.Client(),
          baseUrl: Config.baseUrl,
          userAgent: 'FileCast',
          ip: '',
        ),
      ),
      ChangeNotifierProvider<ThemeController>(
        create: (_) => ThemeController(false),
      ),
    ];
  }
}
