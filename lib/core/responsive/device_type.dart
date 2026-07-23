import 'package:flutter/material.dart';

enum DeviceType { mobile, tablet, desktop }

class DeviceInfo {
  const DeviceInfo({
    required this.type,
    required this.orientation,
    required this.size,
  });

  factory DeviceInfo.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;

    DeviceType deviceType;
    if (width < 600) {
      deviceType = DeviceType.mobile;
    } else if (width < 1200) {
      deviceType = DeviceType.tablet;
    } else {
      deviceType = DeviceType.desktop;
    }

    return DeviceInfo(
      type: deviceType,
      orientation: mq.orientation,
      size: mq.size,
    );
  }

  final DeviceType type;
  final Orientation orientation;
  final Size size;

  bool get isMobile => type == DeviceType.mobile;
  bool get isTablet => type == DeviceType.tablet;
  bool get isDesktop => type == DeviceType.desktop;
  bool get isLandscape => orientation == Orientation.landscape;
}
