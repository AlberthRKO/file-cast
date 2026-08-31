import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/adaptive/window_size_class.dart';
import 'package:file_cast/ui/core/theme/brand_theme.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/folder_background.dart';
import 'package:file_cast/ui/features/auth/login/view_models/login_state.dart';
import 'package:file_cast/ui/features/auth/login/widgets/login_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginLayout extends StatelessWidget {
  const LoginLayout({
    required this.appName,
    required this.window,
    required this.state,
    required this.documentController,
    required this.passwordController,
    required this.formKey,
    required this.onDocumentChanged,
    required this.onPasswordChanged,
    required this.validateDocument,
    required this.validatePassword,
    required this.onSubmit,
    super.key,
  });

  final String appName;
  final AppWindowSize window;
  final LoginState state;
  final TextEditingController documentController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final ValueChanged<String> onDocumentChanged;
  final ValueChanged<String> onPasswordChanged;
  final FormFieldValidator<String> validateDocument;
  final FormFieldValidator<String> validatePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
        final compactHeight = constraints.maxHeight < 480 || keyboardOpen;
        final useTwoPanes = constraints.maxWidth >= 720 && !keyboardOpen;

        if (useTwoPanes) {
          final brand = BrandTheme.of(context);
          final theme = Theme.of(context);

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  brand.headerGradientStart,
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: _LoginBrandPane(
                    appName: appName,
                    compact: compactHeight || window.isMedium,
                    showGradient: false,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _LoginFormPane(
                    state: state,
                    documentController: documentController,
                    passwordController: passwordController,
                    formKey: formKey,
                    onDocumentChanged: onDocumentChanged,
                    onPasswordChanged: onPasswordChanged,
                    validateDocument: validateDocument,
                    validatePassword: validatePassword,
                    onSubmit: onSubmit,
                    compactHeight: compactHeight,
                    showFolder: true,
                    maxWidth: 500,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (!compactHeight)
              SizedBox(
                width: double.infinity,
                height: (constraints.maxHeight * 0.27)
                    .clamp(210.0, 260.0)
                    .toDouble(),
                child: _LoginBrandPane(
                  appName: appName,
                  compact: window.isCompact,
                ),
              ),
            Expanded(
              child: _LoginFormPane(
                state: state,
                documentController: documentController,
                passwordController: passwordController,
                formKey: formKey,
                onDocumentChanged: onDocumentChanged,
                onPasswordChanged: onPasswordChanged,
                validateDocument: validateDocument,
                validatePassword: validatePassword,
                onSubmit: onSubmit,
                compactHeight: compactHeight,
                showFolder: !keyboardOpen,
                maxWidth: window.isCompact ? double.infinity : 560,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoginBrandPane extends StatelessWidget {
  const _LoginBrandPane({
    required this.appName,
    required this.compact,
    this.showGradient = true,
    super.key,
  });

  final String appName;
  final bool compact;
  final bool showGradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);

    final child = SizedBox.expand(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpace.m : AppSpace.xl,
            vertical: compact ? AppSpace.s : AppSpace.xl,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SvgPicture.asset(
                  'assets/images/illustrations/fileCast.svg',
                  width: compact ? 180 : 280,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: compact ? AppSpace.s : AppSpace.m),
              Text(
                appName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: brand.onDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!showGradient) {
      return child;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [brand.headerGradientStart, theme.scaffoldBackgroundColor],
        ),
      ),
      child: child,
    );
  }
}

class _LoginFormPane extends StatelessWidget {
  const _LoginFormPane({
    required this.state,
    required this.documentController,
    required this.passwordController,
    required this.formKey,
    required this.onDocumentChanged,
    required this.onPasswordChanged,
    required this.validateDocument,
    required this.validatePassword,
    required this.onSubmit,
    required this.compactHeight,
    required this.showFolder,
    required this.maxWidth,
  });

  final LoginState state;
  final TextEditingController documentController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final ValueChanged<String> onDocumentChanged;
  final ValueChanged<String> onPasswordChanged;
  final FormFieldValidator<String> validateDocument;
  final FormFieldValidator<String> validatePassword;
  final VoidCallback onSubmit;
  final bool compactHeight;
  final bool showFolder;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final brand = BrandTheme.of(context);

    return LayoutBuilder(
      builder: (context, paneConstraints) {
        final folderTabHeight = paneConstraints.maxWidth * (100 / 667);
        final topPadding = compactHeight && showFolder
            ? folderTabHeight + AppSpace.s
            : compactHeight
            ? AppSpace.m
            : AppSpace.xl;

        return FolderBackground.panel(
          frontColor: brand.folderFront,
          showDecoration: showFolder,
          child: SafeArea(
            top: compactHeight,
            child: ConstrainedContent(
              maxWidth: maxWidth,
              padding: EdgeInsets.fromLTRB(
                AppSpace.l,
                topPadding,
                AppSpace.l,
                AppSpace.l + bottomInset,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Align(
                        alignment: compactHeight
                            ? Alignment.topCenter
                            : Alignment.center,
                        child: LoginForm(
                          state: state,
                          documentController: documentController,
                          passwordController: passwordController,
                          formKey: formKey,
                          onDocumentChanged: onDocumentChanged,
                          onPasswordChanged: onPasswordChanged,
                          validateDocument: validateDocument,
                          validatePassword: validatePassword,
                          onSubmit: onSubmit,
                          compactHeight: compactHeight,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
