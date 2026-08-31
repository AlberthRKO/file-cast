abstract final class AppRouteName {
  static const started = 'started';
  static const login = 'login';
  static const requisitions = 'requisitions';
  static const offline = 'offline';
  static const settings = 'settings';
  static const usbDevices = 'usb-devices';
  static const mirror = 'mirror';
}

abstract final class AppRoutePath {
  static const root = '/';
  static const started = '/started';
  static const login = '/login';
  static const requisitions = '/requisitions';
  static const offline = '/offline';
  static const settings = '/settings';
  static const usbDevices = '/usb-devices';
  static const mirror = '/mirror';
}

/// Compatibility names for Views that have not been migrated to `lib/ui` yet.
@Deprecated('Use AppRouteName from lib/ui/core/navigation/app_route.dart.')
abstract final class Routes {
  static const String started = AppRouteName.started;
  static const String login = AppRouteName.login;
  static const String home = AppRouteName.requisitions;
  static const String offline = AppRouteName.offline;
  static const String settings = AppRouteName.settings;
  static const String usbDevices = AppRouteName.usbDevices;
  static const String mirror = AppRouteName.mirror;
}
