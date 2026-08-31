import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';

class AppSectionHeading extends StatelessWidget {
  const AppSectionHeading({
    required this.title,
    required this.subtitle,
    super.key,
    this.titleStyle,
    this.subtitleStyle,
    this.maxWidth = AppSize.messageMaxWidth,
    this.textAlign = TextAlign.start,
  });

  final String title;
  final String subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double maxWidth;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment = textAlign == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(title, style: titleStyle, textAlign: textAlign),
          const SizedBox(height: AppSpace.s),
          Text(subtitle, style: subtitleStyle, textAlign: textAlign),
        ],
      ),
    );
  }
}
