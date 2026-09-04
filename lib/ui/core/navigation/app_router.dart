import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/navigation/app_route_error_view.dart';
import 'package:file_cast/ui/core/navigation/route_args/mirror_route_args.dart';
import 'package:file_cast/ui/features/acquisition/connect/views/usb_device_list_view.dart';
import 'package:file_cast/ui/features/acquisition/mirror/views/mirror_view.dart';
import 'package:file_cast/ui/features/auth/login/views/login_view.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:file_cast/ui/features/connectivity/offline/views/offline_view.dart';
import 'package:file_cast/ui/features/onboarding/started/views/started_view.dart';
import 'package:file_cast/ui/features/requisitions/create/views/create_requisition_view.dart';
import 'package:file_cast/ui/features/requisitions/detail/views/file_transfer_placeholder_view.dart';
import 'package:file_cast/ui/features/requisitions/detail/views/requisition_detail_view.dart';
import 'package:file_cast/ui/features/requisitions/list/views/requisition_list_view.dart';
import 'package:file_cast/ui/features/settings/views/settings_view.dart';
import 'package:go_router/go_router.dart';

/// Central router for the application.
///
GoRouter createAppRouter({
  required AuthSessionController authSessionController,
}) {
  return GoRouter(
    initialLocation: AppRoutePath.started,
    refreshListenable: authSessionController,
    redirect: (context, state) {
      final location = state.uri.path;
      final isAuthRoute =
          location == AppRoutePath.started || location == AppRoutePath.login;
      final isPublicRoute = isAuthRoute || location == AppRoutePath.offline;

      if (authSessionController.isAuthenticated && isAuthRoute) {
        return AppRoutePath.requisitions;
      }

      if (!authSessionController.isAuthenticated &&
          location == AppRoutePath.root) {
        return AppRoutePath.started;
      }

      if (!authSessionController.isAuthenticated && !isPublicRoute) {
        return AppRoutePath.login;
      }

      return null;
    },
    errorBuilder: (context, state) => AppRouteErrorView(
      message: state.error?.toString() ?? 'La ruta solicitada no existe.',
    ),
    routes: [
      GoRoute(
        path: AppRoutePath.root,
        redirect: (_, _) => authSessionController.isAuthenticated
            ? AppRoutePath.requisitions
            : AppRoutePath.started,
      ),
      GoRoute(
        name: AppRouteName.started,
        path: AppRoutePath.started,
        builder: (context, state) => const StartedRoute(),
      ),
      GoRoute(
        name: AppRouteName.login,
        path: AppRoutePath.login,
        builder: (context, state) => const LoginRoute(),
      ),
      GoRoute(
        name: AppRouteName.requisitions,
        path: AppRoutePath.requisitions,
        builder: (context, state) => const RequisitionListRoute(),
      ),
      GoRoute(
        name: AppRouteName.createRequisition,
        path: AppRoutePath.createRequisition,
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return CreateRequisitionRoute(
            initialMode: mode == 'person'
                ? RequisitionRegistrationMode.withoutCud
                : RequisitionRegistrationMode.existingCud,
          );
        },
      ),
      GoRoute(
        name: AppRouteName.requisitionDetail,
        path: AppRoutePath.requisitionDetail,
        builder: (context, state) => RequisitionDetailRoute(
          requisitionId: state.pathParameters['requisitionId']!,
        ),
      ),
      GoRoute(
        name: AppRouteName.fileTransfer,
        path: AppRoutePath.fileTransfer,
        builder: (context, state) => FileTransferPlaceholderView(
          requisitionId: state.pathParameters['requisitionId']!,
        ),
      ),
      GoRoute(
        name: AppRouteName.offline,
        path: AppRoutePath.offline,
        builder: (context, state) => const OfflineView(),
      ),
      GoRoute(
        name: AppRouteName.settings,
        path: AppRoutePath.settings,
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        name: AppRouteName.acquisitionConnect,
        path: AppRoutePath.acquisitionConnect,
        builder: (context, state) => UsbDeviceListRoute(
          requisitionId: state.pathParameters['requisitionId']!,
          sessionId: state.pathParameters['sessionId']!,
        ),
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

          return MirrorRoute(
            args: args,
            requisitionId: state.pathParameters['requisitionId']!,
            sessionId: state.pathParameters['sessionId']!,
          );
        },
      ),
    ],
  );
}
