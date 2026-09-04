abstract final class AppRouteName {
  static const started = 'started';
  static const login = 'login';
  static const requisitions = 'requisitions';
  static const createRequisition = 'create-requisition';
  static const requisitionDetail = 'requisition-detail';
  static const fileTransfer = 'file-transfer';
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
  static const createRequisition = '/requisitions/new';
  static const requisitionDetail = '/requisitions/:requisitionId';
  static const fileTransfer = '/requisitions/:requisitionId/file-transfer';
  static const offline = '/offline';
  static const settings = '/settings';
  static const acquisitionConnect =
      '/requisitions/:requisitionId/acquisitions/:sessionId/connect';
  static const mirror =
      '/requisitions/:requisitionId/acquisitions/:sessionId/mirror';
}
