import 'package:flutter/widgets.dart';

@immutable
class MultiMirrorSourceArgs {
  const MultiMirrorSourceArgs({
    required this.sourceSessionId,
    required this.textureId,
    required this.videoSize,
    required this.deviceName,
  });

  final String sourceSessionId;
  final int textureId;
  final Size videoSize;
  final String deviceName;
}

@immutable
class MultiMirrorRouteArgs {
  const MultiMirrorRouteArgs({required this.sources});

  final List<MultiMirrorSourceArgs> sources;
}
