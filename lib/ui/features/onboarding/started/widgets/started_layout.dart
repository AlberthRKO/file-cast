import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/theme/brand_theme.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_action_button.dart';
import 'package:file_cast/ui/core/widgets/app_section_heading.dart';
import 'package:file_cast/ui/features/onboarding/started/view_models/started_view_model.dart';
import 'package:flutter/material.dart';

class StartedLayout extends StatelessWidget {
  const StartedLayout({
    required this.content,
    required this.onStart,
    required this.useWideComposition,
    required this.compactHeight,
    required this.maxWidth,
    super.key,
  });

  final StartedContent content;
  final VoidCallback onStart;
  final bool useWideComposition;
  final bool compactHeight;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedContent(
      maxWidth: maxWidth,
      padding: EdgeInsets.symmetric(
        horizontal: compactHeight ? AppSpace.m : AppSpace.l,
        vertical: compactHeight ? AppSpace.s : AppSpace.l,
      ),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: useWideComposition
                    ? _WideStartedContent(
                        content: content,
                        onStart: onStart,
                        compactHeight: compactHeight,
                      )
                    : _CompactStartedContent(
                        content: content,
                        onStart: onStart,
                        compactHeight: compactHeight,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompactStartedContent extends StatelessWidget {
  const _CompactStartedContent({
    required this.content,
    required this.onStart,
    required this.compactHeight,
  });

  final StartedContent content;
  final VoidCallback onStart;
  final bool compactHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppName(name: content.appName),
        if (compactHeight)
          const SizedBox(height: AppSpace.xl)
        else
          const Spacer(),
        _StartedMessage(content: content),
        SizedBox(height: compactHeight ? AppSpace.m : AppSpace.l),
        Align(
          alignment: Alignment.centerRight,
          child: _StartedAction(
            label: content.actionLabel,
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}

class _WideStartedContent extends StatelessWidget {
  const _WideStartedContent({
    required this.content,
    required this.onStart,
    required this.compactHeight,
  });

  final StartedContent content;
  final VoidCallback onStart;
  final bool compactHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AppName(name: content.appName),
              SizedBox(height: compactHeight ? AppSpace.s : AppSpace.m),
              _StartedMessage(content: content),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.xxl),
        Flexible(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: _StartedAction(
              label: content.actionLabel,
              onPressed: onStart,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppName extends StatelessWidget {
  const _AppName({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: Theme.of(
        context,
      ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _StartedMessage extends StatelessWidget {
  const _StartedMessage({required this.content});

  final StartedContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);

    return AppSectionHeading(
      title: content.title,
      subtitle: content.subtitle,
      titleStyle: theme.textTheme.headlineLarge?.copyWith(
        color: brand.onDark,
        fontWeight: FontWeight.w700,
      ),
      subtitleStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.hintColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StartedAction extends StatelessWidget {
  const _StartedAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = BrandTheme.of(context);

    return AppActionButton(
      label: label,
      onPressed: onPressed,
      foregroundColor: brand.onActionSurface,
      backgroundColor: brand.actionSurface,
      leadingAsset: 'assets/images/icons/paper.svg',
      maxWidth: AppSize.actionMaxWidth,
    );
  }
}
