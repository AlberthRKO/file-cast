import 'dart:async';

import 'package:file_cast/domain/repositories/connectivity_repository.dart';
import 'package:flutter/foundation.dart';

class ConnectivityViewModel extends ChangeNotifier {
  ConnectivityViewModel({required ConnectivityRepository repository})
    : _repository = repository,
      _status = repository.currentStatus;

  final ConnectivityRepository _repository;
  StreamSubscription<ConnectivityStatus>? _subscription;
  ConnectivityStatus _status;
  bool _disposed = false;

  ConnectivityStatus get status => _status;
  bool get showsOfflineIndicator =>
      _status == ConnectivityStatus.offline ||
      _status == ConnectivityStatus.limited;

  Future<void> initialize() async {
    _subscription ??= _repository.changes.listen((status) {
      _status = status;
      if (!_disposed) notifyListeners();
    });
    try {
      await _repository.start();
      _status = _repository.currentStatus;
    } on Object {
      _status = ConnectivityStatus.offline;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> retry() async {
    _status = ConnectivityStatus.checking;
    if (!_disposed) notifyListeners();
    try {
      _status = await _repository.refresh();
    } on Object {
      _status = ConnectivityStatus.offline;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
