import 'package:file_cast/presentation/pages/login/login.dart';
import 'package:file_cast/presentation/pages/offline/offline.dart';
import 'package:file_cast/presentation/pages/presentation/mirror/mirror_page.dart';
import 'package:file_cast/presentation/pages/presentation/mirror/usb_device_list_page.dart';
import 'package:file_cast/presentation/pages/settings/settings.dart';
import 'package:file_cast/presentation/pages/started/started.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/navigation/app_route_error_view.dart';
import 'package:file_cast/ui/core/navigation/route_args/mirror_route_args.dart';
import 'package:file_cast/ui/features/requisitions/list/views/requisition_list_view.dart';
import 'package:go_router/go_router.dart';

/// Central router for the application.
///
/// Legacy pages remain under `presentation/` while each feature is migrated
/// independently to `ui/features/`.
final appRouter = GoRouter(
  initialLocation: AppRoutePath.started,
  errorBuilder: (context, state) => AppRouteErrorView(
    message: state.error?.toString() ?? 'La ruta solicitada no existe.',
  ),
  routes: [
    GoRoute(
      path: AppRoutePath.root,
      redirect: (_, _) => AppRoutePath.requisitions,
    ),
    GoRoute(
      name: AppRouteName.started,
      path: AppRoutePath.started,
      builder: (context, state) => const StartedPage(),
    ),
    GoRoute(
      name: AppRouteName.login,
      path: AppRoutePath.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      name: AppRouteName.requisitions,
      path: AppRoutePath.requisitions,
      builder: (context, state) => const RequisitionListRoute(),
    ),
    GoRoute(
      name: AppRouteName.offline,
      path: AppRoutePath.offline,
      builder: (context, state) => const Offline(),
    ),
    GoRoute(
      name: AppRouteName.settings,
      path: AppRoutePath.settings,
      builder: (context, state) => const Settings(),
    ),
    GoRoute(
      name: AppRouteName.usbDevices,
      path: AppRoutePath.usbDevices,
      builder: (context, state) => const UsbDeviceListPage(),
    ),
    GoRoute(
      name: AppRouteName.mirror,
      path: AppRoutePath.mirror,
      builder: (context, state) {
        final args = state.extra;
        if (args is! MirrorRouteArgs) {
          return const AppRouteErrorView(
            message: 'La sesión de espejo no está disponible.',
          );
        }

        return MirrorPage(
          textureId: args.textureId,
          videoWidth: args.videoSize.width.round(),
          videoHeight: args.videoSize.height.round(),
          controlLocalId: args.controlLocalId,
          deviceName: args.deviceName,
        );
      },
    ),
  ],
);
