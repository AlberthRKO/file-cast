enum ConnectivityStatus { checking, online, offline, limited }

abstract interface class ConnectivityRepository {
  ConnectivityStatus get currentStatus;

  Stream<ConnectivityStatus> get changes;

  Future<void> start();

  Future<ConnectivityStatus> refresh();

  Future<void> dispose();
}
