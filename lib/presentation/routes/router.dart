import 'package:file_cast/presentation/pages/home/home.dart';
import 'package:file_cast/presentation/pages/offline/offline.dart';
import 'package:file_cast/presentation/pages/presentation/mirror/usb_device_list_page.dart';
import 'package:file_cast/presentation/pages/settings/settings.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      name: 'home',
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      name: 'offline',
      path: '/offline',
      builder: (context, state) => const Offline(),
    ),
    GoRoute(
      name: 'settings',
      path: '/settings',
      builder: (context, state) => const Settings(),
    ),
    GoRoute(
      name: 'usb-devices',
      path: '/usb-devices',
      builder: (context, state) => const UsbDeviceListPage(),
    ),
  ],
);
