import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppActionButton extends StatelessWidget {
  const AppActionButton({
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    super.key,
    this.backgroundColor,
    this.gradient,
    this.leadingAsset,
    this.isLoading = false,
    this.maxWidth = double.infinity,
    this.elevation = 0,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.l,
      vertical: AppSpace.m,
    ),
  }) : assert(
         backgroundColor != null || gradient != null,
         'A backgroundColor or gradient is required.',
       );

  final String label;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final String? leadingAsset;
  final bool isLoading;
  final double maxWidth;
  final double elevation;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: AppSize.minTouchTarget,
        maxWidth: maxWidth,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          elevation: elevation,
          borderRadius: BorderRadius.circular(AppRadius.l),
          child: Ink(
            decoration: BoxDecoration(
              color: gradient == null ? backgroundColor : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppRadius.l),
            ),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(AppRadius.l),
              child: Padding(
                padding: padding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      SizedBox.square(
                        dimension: AppSize.iconL,
                        child: CircularProgressIndicator(
                          color: foregroundColor,
                          strokeWidth: 2,
                        ),
                      )
                    else if (leadingAsset != null)
                      SvgPicture.asset(
                        leadingAsset!,
                        width: AppSize.iconL,
                        colorFilter: ColorFilter.mode(
                          foregroundColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    if (isLoading || leadingAsset != null)
                      const SizedBox(width: AppSpace.s),
                    Flexible(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
