abstract final class AppRouteName {
  static const started = 'started';
  static const login = 'login';
  static const requisitions = 'requisitions';
  static const offline = 'offline';
  static const settings = 'settings';
  static const acquisitionConnect = 'acquisition-connect';
  static const mirror = 'mirror';
}

abstract final class AppRoutePath {
  static const root = '/';
  static const started = '/started';
  static const login = '/login';
  static const requisitions = '/requisitions';
  static const offline = '/offline';
  static const settings = '/settings';
  static const acquisitionConnect =
      '/requisitions/:requisitionId/acquisitions/:sessionId/connect';
  static const mirror =
      '/requisitions/:requisitionId/acquisitions/:sessionId/mirror';
}
