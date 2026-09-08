import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';

/// Shared themed surface for borderless cards used across product features.
class AppCardSurface extends StatelessWidget {
  const AppCardSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpace.m),
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.l)),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).cardColor,
      borderRadius: borderRadius,
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 15,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}
