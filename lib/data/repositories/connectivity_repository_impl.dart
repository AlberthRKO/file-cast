import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_cast/data/datasources/remote/internet_checker.dart';
import 'package:file_cast/domain/repositories/connectivity_repository.dart';

class ConnectivityRepositoryImpl implements ConnectivityRepository {
  ConnectivityRepositoryImpl({
    required Connectivity connectivity,
    required InternetChecker internetChecker,
  }) : _connectivity = connectivity,
       _internetChecker = internetChecker;

  static const _changeDebounce = Duration(milliseconds: 450);
  static const _probeInterval = Duration(seconds: 30);

  final Connectivity _connectivity;
  final InternetChecker _internetChecker;
  final StreamController<ConnectivityStatus> _changesController =
      StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounce;
  Timer? _probeTimer;
  ConnectivityStatus _currentStatus = ConnectivityStatus.checking;
  Future<ConnectivityStatus>? _refreshInFlight;

  @override
  ConnectivityStatus get currentStatus => _currentStatus;

  @override
  Stream<ConnectivityStatus> get changes => _changesController.stream;

  @override
  Future<void> start() async {
    _subscription ??= _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    _probeTimer ??= Timer.periodic(_probeInterval, (_) {
      unawaited(refresh());
    });
    await refresh();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _debounce?.cancel();
    if (_hasNoLink(results)) {
      _emit(ConnectivityStatus.offline);
      return;
    }
    _debounce = Timer(_changeDebounce, () {
      unawaited(refresh());
    });
  }

  @override
  Future<ConnectivityStatus> refresh() {
    final active = _refreshInFlight;
    if (active != null) return active;
    final operation = _refresh();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
  }

  Future<ConnectivityStatus> _refresh() async {
    late final List<ConnectivityResult> connections;
    try {
      connections = await _connectivity.checkConnectivity();
    } on Object {
      _emit(ConnectivityStatus.offline);
      return _currentStatus;
    }
    if (_hasNoLink(connections)) {
      _emit(ConnectivityStatus.offline);
      return _currentStatus;
    }

    final reachability = await _internetChecker.checkBackend();
    _emit(
      switch (reachability) {
        BackendReachability.reachable => ConnectivityStatus.online,
        BackendReachability.degraded => ConnectivityStatus.limited,
        BackendReachability.unreachable => ConnectivityStatus.offline,
      },
    );
    return _currentStatus;
  }

  bool _hasNoLink(List<ConnectivityResult> results) =>
      results.isEmpty ||
      results.every((result) => result == ConnectivityResult.none);

  void _emit(ConnectivityStatus status) {
    if (_currentStatus == status) return;
    _currentStatus = status;
    if (!_changesController.isClosed) _changesController.add(status);
  }

  @override
  Future<void> dispose() async {
    _debounce?.cancel();
    _probeTimer?.cancel();
    await _subscription?.cancel();
    await _changesController.close();
  }
}
