import 'package:flutter/widgets.dart';

@immutable
class MirrorRouteArgs {
  const MirrorRouteArgs({
    required this.textureId,
    required this.controlLocalId,
    required this.videoSize,
    required this.deviceName,
  });

  final int textureId;
  final int controlLocalId;
  final Size videoSize;
  final String deviceName;
}
