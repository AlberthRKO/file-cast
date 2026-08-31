import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:file_cast/data/repositories/in_memory_requisition_repository.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/ui/core/navigation/app_router.dart';
import 'package:file_cast/ui/core/theme/theme_controller.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class DependencyInjection {
  static List<SingleChildWidget> providers() {
    return [
      Provider<FlutterSecureStorage>(
        create: (_) => const FlutterSecureStorage(),
      ),
      ProxyProvider<FlutterSecureStorage, SecureStorageService>(
        update: (_, storage, _) => SecureStorageService(storage),
      ),
      Provider<Http>(
        create: (_) => Http(
          client: http.Client(),
          baseUrl: Config.baseUrl,
          userAgent: 'FileCast',
          ip: '',
        ),
      ),
      Provider<RequisitionRepository>(
        create: (_) => const InMemoryRequisitionRepository(),
      ),
      Provider<AdbClient>(create: (_) => AdbClient()),
      ChangeNotifierProvider<AuthSessionController>(
        create: (_) => AuthSessionController(),
      ),
      ProxyProvider<AuthSessionController, GoRouter>(
        update: (_, sessionController, previousRouter) =>
            previousRouter ??
            createAppRouter(authSessionController: sessionController),
      ),
      ChangeNotifierProxyProvider<SecureStorageService, ThemeController>(
        create: (context) => ThemeController(
          storage: context.read<SecureStorageService>(),
          initialDarkMode: true,
        )..loadTheme(),
        update: (_, storage, controller) =>
            controller ??
            (ThemeController(storage: storage, initialDarkMode: true)
              ..loadTheme()),
      ),
    ];
  }
}
