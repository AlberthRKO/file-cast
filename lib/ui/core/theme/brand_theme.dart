import 'package:flutter/material.dart';

@immutable
final class BrandTheme extends ThemeExtension<BrandTheme> {
  const BrandTheme({
    required this.headerGradientStart,
    required this.onDark,
    required this.folderFront,
    required this.folderMiddle,
    required this.folderBack,
    required this.folderHighlight,
    required this.actionGradientStart,
    required this.actionGradientEnd,
    required this.actionSurface,
    required this.onActionSurface,
  });

  final Color headerGradientStart;
  final Color onDark;
  final Color folderFront;
  final Color folderMiddle;
  final Color folderBack;
  final Color folderHighlight;
  final Color actionGradientStart;
  final Color actionGradientEnd;
  final Color actionSurface;
  final Color onActionSurface;

  static BrandTheme of(BuildContext context) {
    final brand = Theme.of(context).extension<BrandTheme>();
    assert(brand != null, 'BrandTheme is not registered in ThemeData.');
    return brand!;
  }

  @override
  BrandTheme copyWith({
    Color? headerGradientStart,
    Color? onDark,
    Color? folderFront,
    Color? folderMiddle,
    Color? folderBack,
    Color? folderHighlight,
    Color? actionGradientStart,
    Color? actionGradientEnd,
    Color? actionSurface,
    Color? onActionSurface,
  }) {
    return BrandTheme(
      headerGradientStart: headerGradientStart ?? this.headerGradientStart,
      onDark: onDark ?? this.onDark,
      folderFront: folderFront ?? this.folderFront,
      folderMiddle: folderMiddle ?? this.folderMiddle,
      folderBack: folderBack ?? this.folderBack,
      folderHighlight: folderHighlight ?? this.folderHighlight,
      actionGradientStart: actionGradientStart ?? this.actionGradientStart,
      actionGradientEnd: actionGradientEnd ?? this.actionGradientEnd,
      actionSurface: actionSurface ?? this.actionSurface,
      onActionSurface: onActionSurface ?? this.onActionSurface,
    );
  }

  @override
  BrandTheme lerp(covariant BrandTheme? other, double t) {
    if (other == null) return this;

    return BrandTheme(
      headerGradientStart: Color.lerp(
        headerGradientStart,
        other.headerGradientStart,
        t,
      )!,
      onDark: Color.lerp(onDark, other.onDark, t)!,
      folderFront: Color.lerp(folderFront, other.folderFront, t)!,
      folderMiddle: Color.lerp(folderMiddle, other.folderMiddle, t)!,
      folderBack: Color.lerp(folderBack, other.folderBack, t)!,
      folderHighlight: Color.lerp(
        folderHighlight,
        other.folderHighlight,
        t,
      )!,
      actionGradientStart: Color.lerp(
        actionGradientStart,
        other.actionGradientStart,
        t,
      )!,
      actionGradientEnd: Color.lerp(
        actionGradientEnd,
        other.actionGradientEnd,
        t,
      )!,
      actionSurface: Color.lerp(actionSurface, other.actionSurface, t)!,
      onActionSurface: Color.lerp(
        onActionSurface,
        other.onActionSurface,
        t,
      )!,
    );
  }
}
