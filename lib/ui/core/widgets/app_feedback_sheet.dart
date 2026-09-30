import 'dart:async';

import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

enum AppFeedbackType { error, success }

class AppFeedbackSheet extends StatefulWidget {
  const AppFeedbackSheet({
    required this.type,
    required this.message,
    required this.duration,
    this.title,
    super.key,
  });

  final AppFeedbackType type;
  final String message;
  final String? title;
  final Duration duration;

  @override
  State<AppFeedbackSheet> createState() => _AppFeedbackSheetState();
}

class _AppFeedbackSheetState extends State<AppFeedbackSheet> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;

    final route = ModalRoute.of(context);
    if (route == null || !route.isActive || !route.isCurrent) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSuccess = widget.type == AppFeedbackType.success;
    final accent = isSuccess ? scheme.primary : scheme.error;
    final title =
        widget.title ?? (isSuccess ? 'Operación exitosa' : 'Ocurrió un error');

    return PopScope(
      canPop: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          final maxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight * 0.75
              : 420.0;
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 0.0;
          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: isWide ? 0 : availableWidth,
                maxWidth: isWide ? AppSize.messageMaxWidth : double.infinity,
                maxHeight: maxHeight,
              ),
              child: Material(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.l),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? AppSpace.xl : AppSpace.l,
                      AppSpace.l,
                      isWide ? AppSpace.xl : AppSpace.l,
                      AppSpace.m + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FeedbackVisual(
                          type: widget.type,
                          accent: accent,
                        ),
                        const SizedBox(height: AppSpace.s),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppSize.messageMaxWidth,
                          ),
                          child: Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedbackVisual extends StatelessWidget {
  const _FeedbackVisual({required this.type, required this.accent});

  final AppFeedbackType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (type == AppFeedbackType.success) {
      return SizedBox(
        height: 132,
        child: Lottie.asset(
          'assets/images/illustrations/check.json',
          repeat: false,
          fit: BoxFit.contain,
        ),
      );
    }

    return SizedBox.square(
      dimension: 64,
      child: SvgPicture.asset(
        'assets/images/icons/alertNew.svg',
        colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
      ),
    );
  }
}
