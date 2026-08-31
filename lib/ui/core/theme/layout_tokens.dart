/// Stable spacing values in Flutter logical pixels.
///
/// These tokens keep the visual rhythm consistent; they do not scale with the
/// screen. Responsive composition is decided from local constraints in
/// `ui/core/adaptive`.
abstract final class AppSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const pill = 999.0;
}

/// Shared accessibility sizes and readable content limits.
abstract final class AppSize {
  static const minTouchTarget = 48.0;
  static const iconS = 16.0;
  static const iconM = 20.0;
  static const iconL = 24.0;
  static const formMaxWidth = 640.0;
  static const messageMaxWidth = 480.0;
  static const actionMaxWidth = 240.0;
  static const contentMaxWidth = 1200.0;
  static const supportingPaneWidth = 360.0;
}
