import 'package:file_cast/ui/core/theme/brand_theme.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_action_button.dart';
import 'package:file_cast/ui/core/widgets/app_section_heading.dart';
import 'package:file_cast/ui/features/auth/login/view_models/login_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({
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
    super.key,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    final isSubmitting = state.phase == LoginPhase.submitting;

    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeading(
              title: 'Iniciar Sesión',
              subtitle: 'Ingresa tus credenciales para continuar',
              titleStyle: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: brand.onDark,
              ),
              subtitleStyle: theme.textTheme.bodyMedium?.copyWith(
                color: brand.onDark.withOpacity(0.7),
              ),
            ),
            SizedBox(height: compactHeight ? AppSpace.l : AppSpace.xl),
            _LoginTextField(
              controller: documentController,
              icon: 'cardEmployee.svg',
              labelText: 'Número de Documento',
              onChanged: onDocumentChanged,
              validator: validateDocument,
              enabled: !isSubmitting,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpace.m),
            _LoginTextField(
              controller: passwordController,
              icon: 'lock.svg',
              labelText: 'Contraseña',
              isPassword: true,
              onChanged: onPasswordChanged,
              validator: validatePassword,
              enabled: !isSubmitting,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: AppSpace.m),
              Text(
                state.errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            AppActionButton(
              label: 'Iniciar Sesión',
              onPressed: onSubmit,
              isLoading: isSubmitting,
              leadingAsset: 'assets/images/icons/paper.svg',
              foregroundColor: brand.onDark,
              gradient: LinearGradient(
                colors: [
                  brand.actionGradientStart,
                  brand.actionGradientEnd,
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.l,
                vertical: AppSpace.s,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginTextField extends StatefulWidget {
  const _LoginTextField({
    required this.controller,
    required this.icon,
    required this.labelText,
    required this.onChanged,
    required this.enabled,
    required this.autofillHints,
    required this.textInputAction,
    this.validator,
    this.isPassword = false,
    this.inputFormatters,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String icon;
  final String labelText;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;
  final bool isPassword;
  final bool enabled;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<_LoginTextField> createState() => _LoginTextFieldState();
}

class _LoginTextFieldState extends State<_LoginTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.isPassword && _obscureText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      style: theme.textTheme.bodyLarge,
      cursorColor: theme.textTheme.bodyLarge?.color,
      decoration: InputDecoration(
        prefixIcon: SizedBox.square(
          dimension: AppSize.minTouchTarget,
          child: Center(
            child: SvgPicture.asset(
              'assets/images/icons/${widget.icon}',
              height: AppSize.iconM,
              colorFilter: ColorFilter.mode(
                theme.colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscureText
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                onPressed: widget.enabled
                    ? () => setState(() => _obscureText = !_obscureText)
                    : null,
                icon: SvgPicture.asset(
                  _obscureText
                      ? 'assets/images/icons/eye.svg'
                      : 'assets/images/icons/eyeClose.svg',
                  height: AppSize.iconM,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.primary.withOpacity(.7),
                    BlendMode.srcIn,
                  ),
                ),
              )
            : null,
        labelText: widget.labelText,
        labelStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.primary.withOpacity(0.5),
          height: 1,
        ),
        errorMaxLines: 2,
      ),
    );
  }
}
