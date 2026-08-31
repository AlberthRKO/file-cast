import 'dart:async';

import 'package:file_cast/core/adb/adb_client.dart';
import 'package:flutter/foundation.dart';

class MirrorViewModel extends ChangeNotifier {
  MirrorViewModel({
    required AdbClient adbClient,
    required this.videoWidth,
    required this.videoHeight,
  }) : _adbClient = adbClient {
    _refreshLogs();
    _logTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshLogs(),
    );
  }

  final AdbClient _adbClient;
  final int videoWidth;
  final int videoHeight;
  Timer? _logTimer;

  String _log = '';
  bool _showControls = false;
  bool _showLogs = false;
  bool _disposed = false;

  String get log => _log;
  bool get showControls => _showControls;
  bool get showLogs => _showLogs;

  void toggleControls() {
    _showControls = !_showControls;
    notifyListeners();
  }

  void toggleLogs() {
    _showLogs = !_showLogs;
    notifyListeners();
  }

  Future<void> _refreshLogs() async {
    final mirrorLog = await _adbClient.getMirrorLog();
    final serverLog = await _adbClient.getServerLog();
    if (_disposed) return;

    final buffer = StringBuffer(mirrorLog);
    if (serverLog.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer
        ..writeln('--- SERVER LOG ---')
        ..write(serverLog);
    }
    _log = buffer.toString();
    notifyListeners();
  }

  void sendTouch(int action, int x, int y) {
    _adbClient.sendTouch(action, x, y, videoWidth, videoHeight);
  }

  Future<void> sendBack() => _adbClient.sendBack();
  Future<void> sendHome() => _adbClient.sendHome();
  Future<void> sendAppSwitch() => _adbClient.sendAppSwitch();
  Future<void> sendVolumeUp() => _adbClient.sendVolumeUp();
  Future<void> sendVolumeDown() => _adbClient.sendVolumeDown();
  Future<void> sendPower() => _adbClient.sendPower();

  @override
  void dispose() {
    _disposed = true;
    _logTimer?.cancel();
    super.dispose();
  }
}
