import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/widgets.dart';

class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    required this.child,
    this.maxWidth = AppSize.contentMaxWidth,
    this.padding = const EdgeInsets.all(AppSpace.m),
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(
            width: double.infinity,
            child: child,
          ),
        ),
      ),
    );
  }
}
