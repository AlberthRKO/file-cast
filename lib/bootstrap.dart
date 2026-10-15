import 'dart:async';
import 'dart:developer';

import 'package:file_cast/data/services/evidence_background_sync_service.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  await EvidenceBackgroundSyncService.initializeDispatcher();
  VideoPlayerMediaKit.ensureInitialized(android: true);

  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  // Add cross-flavor configuration here

  runApp(await builder());
}
