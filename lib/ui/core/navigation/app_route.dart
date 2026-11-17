abstract final class AppRouteName {
  static const started = 'started';
  static const login = 'login';
  static const requisitions = 'requisitions';
  static const createRequisition = 'create-requisition';
  static const requisitionDetail = 'requisition-detail';
  static const fileTransfer = 'file-transfer';
  static const offline = 'offline';
  static const acquisitionConnect = 'acquisition-connect';
  static const mirror = 'mirror';
  static const multiMirror = 'multi-mirror';
  static const multiMirrorConnect = 'multi-mirror-connect';
}

abstract final class AppRoutePath {
  static const root = '/';
  static const started = '/started';
  static const login = '/login';
  static const requisitions = '/requisitions';
  static const createRequisition = '/requisitions/new';
  static const requisitionDetail = '/requisitions/:requisitionId';
  static const fileTransfer =
      '/requisitions/:requisitionId/acquisitions/:sessionId/transfer';
  static const offline = '/offline';
  static const acquisitionConnect =
      '/requisitions/:requisitionId/acquisitions/:sessionId/connect';
  static const mirror =
      '/requisitions/:requisitionId/acquisitions/:sessionId/mirror';
  static const multiMirror =
      '/requisitions/:requisitionId/acquisitions/:sessionId/mirrors/live';
  static const multiMirrorConnect =
      '/requisitions/:requisitionId/acquisitions/:sessionId/mirrors/connect';
}
