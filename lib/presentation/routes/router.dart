import 'package:file_cast/presentation/pages/home/home.dart';
import 'package:file_cast/presentation/pages/login/login.dart';
import 'package:file_cast/presentation/pages/offline/offline.dart';
import 'package:file_cast/presentation/pages/presentation/mirror/mirror_page.dart';
import 'package:file_cast/presentation/pages/presentation/mirror/usb_device_list_page.dart';
import 'package:file_cast/presentation/pages/settings/settings.dart';
import 'package:file_cast/presentation/pages/started/started.dart';
import 'package:file_cast/presentation/routes/routes.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/started',
  routes: [
    GoRoute(
      name: Routes.started,
      path: '/started',
      builder: (context, state) => const StartedPage(),
    ),
    GoRoute(
      name: Routes.login,
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      name: Routes.home,
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      name: Routes.offline,
      path: '/offline',
      builder: (context, state) => const Offline(),
    ),
    GoRoute(
      name: Routes.settings,
      path: '/settings',
      builder: (context, state) => const Settings(),
    ),
    GoRoute(
      name: Routes.usbDevices,
      path: '/usb-devices',
      builder: (context, state) => const UsbDeviceListPage(),
    ),
    GoRoute(
      name: Routes.mirror,
      path: '/mirror',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra == null || extra['controlLocalId'] == null) {
          throw Exception('MirrorPage requires extra with controlLocalId');
        }
        return MirrorPage(
          textureId: extra['textureId'] as int? ?? 0,
          videoWidth: extra['videoWidth'] as int? ?? 1200,
          videoHeight: extra['videoHeight'] as int? ?? 2000,
          controlLocalId: extra['controlLocalId'] as int,
          deviceName: extra['deviceName'] as String? ?? 'Device',
        );
      },
    ),
  ],
);
