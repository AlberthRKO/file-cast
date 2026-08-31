import 'package:flutter/widgets.dart';

enum WindowWidthClass { compact, medium, expanded, large }

enum WindowHeightClass { compact, regular }

@immutable
class AppWindowSize {
  const AppWindowSize({
    required this.width,
    required this.height,
  });

  factory AppWindowSize.fromConstraints(BoxConstraints constraints) {
    return AppWindowSize(
      width: switch (constraints.maxWidth) {
        < 600 => WindowWidthClass.compact,
        < 840 => WindowWidthClass.medium,
        < 1200 => WindowWidthClass.expanded,
        _ => WindowWidthClass.large,
      },
      height: constraints.maxHeight < 480
          ? WindowHeightClass.compact
          : WindowHeightClass.regular,
    );
  }

  final WindowWidthClass width;
  final WindowHeightClass height;

  bool get isCompact => width == WindowWidthClass.compact;

  bool get isMedium => width == WindowWidthClass.medium;

  bool get isExpanded => width == WindowWidthClass.expanded;

  bool get isLarge => width == WindowWidthClass.large;

  bool get hasCompactHeight => height == WindowHeightClass.compact;

  bool get canShowSupportingPane =>
      (isExpanded || isLarge) && !hasCompactHeight;
}
