import 'dart:async';

import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';
import 'package:file_cast/ui/core/adaptive/adaptive_layout.dart';
import 'package:file_cast/ui/core/feedback/app_feedback.dart';
import 'package:file_cast/ui/features/auth/login/view_models/login_state.dart';
import 'package:file_cast/ui/features/auth/login/view_models/login_view_model.dart';
import 'package:file_cast/ui/features/auth/login/widgets/login_layout.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginRoute extends StatelessWidget {
  const LoginRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginViewModel(
        authRepository: context.read<AuthRepository>(),
        sessionController: context.read<AuthSessionController>(),
      ),
      child: Consumer<LoginViewModel>(
        builder: (context, viewModel, _) => LoginView(viewModel: viewModel),
      ),
    );
  }
}

class LoginView extends StatefulWidget {
  const LoginView({
    required this.viewModel,
    super.key,
  });

  final LoginViewModel viewModel;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final TextEditingController _documentController;
  late final TextEditingController _passwordController;
  final _formKey = GlobalKey<FormState>();

  LoginViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _documentController = TextEditingController(
      text: _viewModel.state.documentNumber,
    );
    _passwordController = TextEditingController(
      text: _viewModel.state.password,
    );
    _viewModel.addListener(_handleViewModelChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChange);
    _documentController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _presentedError;
  bool _successFeedbackScheduled = false;

  void _handleViewModelChange() {
    final state = _viewModel.state;
    if (state.errorMessage == null) {
      _presentedError = null;
    } else if (_presentedError != state.errorMessage) {
      _presentedError = state.errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(showAppErrorBottomSheet(context, state.errorMessage!));
      });
    }

    if (state.phase != LoginPhase.success) {
      _successFeedbackScheduled = false;
      return;
    }
    if (_successFeedbackScheduled) return;

    _successFeedbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showLoginSuccess());
    });
  }

  Future<void> _showLoginSuccess() async {
    await showAppSuccessBottomSheet(
      context,
      'Tu sesión fue iniciada correctamente.',
    );
    if (mounted) _viewModel.completeAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AdaptiveLayout(
        builder: (context, window) {
          return LoginLayout(
            appName: Config.appName,
            window: window,
            state: _viewModel.state,
            documentController: _documentController,
            passwordController: _passwordController,
            formKey: _formKey,
            onDocumentChanged: _viewModel.updateDocument,
            onPasswordChanged: _viewModel.updatePassword,
            validateDocument: _viewModel.validateDocument,
            validatePassword: _viewModel.validatePassword,
            onSubmit: _submit,
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    _formKey.currentState?.validate();
    await _viewModel.submit();
  }
}
