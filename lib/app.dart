import 'dart:async';

import 'package:file_cast/core/notifications/local_notification_service.dart';
import 'package:file_cast/core/theme/theme_dark.dart';
import 'package:file_cast/core/theme/theme_light.dart';
import 'package:file_cast/ui/core/theme/theme_controller.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  StreamSubscription<LocalNotificationPayload>? _notificationSubscription;
  LocalNotificationPayload? _pendingPayload;

  @override
  void initState() {
    super.initState();
    final notifications = context.read<LocalNotificationService>();
    final session = context.read<AuthSessionController>();
    session.addListener(_tryOpenPendingPayload);
    _notificationSubscription = notifications.clicks.listen((payload) {
      _pendingPayload = payload;
      _tryOpenPendingPayload();
    });
    unawaited(_initializeNotifications(notifications));
  }

  Future<void> _initializeNotifications(
    LocalNotificationService notifications,
  ) async {
    await notifications.initialize();
    if (!mounted) return;
    _pendingPayload ??= notifications.takePendingLaunchPayload();
    _tryOpenPendingPayload();
  }

  void _tryOpenPendingPayload() {
    final payload = _pendingPayload;
    if (!mounted || payload == null) return;
    if (!context.read<AuthSessionController>().isAuthenticated) return;
    _pendingPayload = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/requisitions/${Uri.encodeComponent(payload.requisitionId)}');
    });
  }

  @override
  void dispose() {
    context
        .read<AuthSessionController>()
        .removeListener(_tryOpenPendingPayload);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final router = context.watch<GoRouter>();

    return MaterialApp.router(
      title: 'File Cast',
      theme: light,
      darkTheme: dark,
      themeMode: themeController.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: theme.scaffoldBackgroundColor,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
