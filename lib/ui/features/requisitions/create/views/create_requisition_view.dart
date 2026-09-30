import 'dart:async';

import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/data/services/location_service.dart';
import 'package:file_cast/ui/core/adaptive/adaptive_layout.dart';
import 'package:file_cast/ui/core/feedback/app_feedback.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/requisitions/create/view_models/create_requisition_view_model.dart';
import 'package:file_cast/ui/features/requisitions/create/widgets/create_requisition_form.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class CreateRequisitionRoute extends StatelessWidget {
  const CreateRequisitionRoute({
    required this.initialMode,
    super.key,
  });

  final RequisitionRegistrationMode initialMode;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CreateRequisitionViewModel(
        repository: context.read<RequisitionCreationRepository>(),
        locationService: context.read<LocationService>(),
        initialMode: initialMode,
      ),
      child: const _CreateRequisitionConnector(),
    );
  }
}

/// Contenido reutilizable del formulario cuando se presenta como bottom sheet.
class CreateRequisitionSheet extends StatelessWidget {
  const CreateRequisitionSheet({
    required this.initialMode,
    required this.onCompleted,
    required this.onClose,
    super.key,
  });

  final RequisitionRegistrationMode initialMode;
  final ValueChanged<CreateRequisitionResult> onCompleted;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CreateRequisitionViewModel(
        repository: context.read<RequisitionCreationRepository>(),
        locationService: context.read<LocationService>(),
        initialMode: initialMode,
      ),
      child: _CreateRequisitionSheetContent(
        onCompleted: onCompleted,
        onClose: onClose,
      ),
    );
  }
}

class _CreateRequisitionSheetContent extends StatefulWidget {
  const _CreateRequisitionSheetContent({
    required this.onCompleted,
    required this.onClose,
  });

  final ValueChanged<CreateRequisitionResult> onCompleted;
  final VoidCallback onClose;

  @override
  State<_CreateRequisitionSheetContent> createState() =>
      _CreateRequisitionSheetContentState();
}

class _CreateRequisitionSheetContentState
    extends State<_CreateRequisitionSheetContent> {
  late final CreateRequisitionViewModel _viewModel;
  bool _completionHandled = false;
  String? _presentedError;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<CreateRequisitionViewModel>();
    _viewModel.addListener(_handleViewModelChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChange);
    super.dispose();
  }

  void _handleViewModelChange() {
    final state = _viewModel.state;
    final result = state.createdResult;
    if (result != null && !_completionHandled) {
      _completionHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_showCreationSuccess(result));
      });
    }

    final errorMessage = state.errorMessage;
    if (errorMessage == null) {
      _presentedError = null;
    } else if (_presentedError != errorMessage) {
      _presentedError = errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(showAppErrorBottomSheet(context, errorMessage));
      });
    }
  }

  Future<void> _showCreationSuccess(CreateRequisitionResult result) async {
    await showAppSuccessBottomSheet(
      context,
      'La requisa fue registrada correctamente.',
    );
    if (mounted) widget.onCompleted(result);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _SheetSurface(
        viewModel: _viewModel,
        onClose: widget.onClose,
      ),
    );
  }
}

class _CreateRequisitionConnector extends StatefulWidget {
  const _CreateRequisitionConnector();

  @override
  State<_CreateRequisitionConnector> createState() =>
      _CreateRequisitionConnectorState();
}

class _CreateRequisitionConnectorState
    extends State<_CreateRequisitionConnector> {
  bool _navigated = false;
  String? _presentedError;
  late final CreateRequisitionViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<CreateRequisitionViewModel>();
    _viewModel.addListener(_handleViewModelChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChange);
    super.dispose();
  }

  void _handleViewModelChange() {
    final result = _viewModel.state.createdResult;
    if (!_navigated && result != null) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_showCreationSuccessAndNavigate(result));
      });
    }

    final errorMessage = _viewModel.state.errorMessage;
    if (errorMessage == null) {
      _presentedError = null;
    } else if (_presentedError != errorMessage) {
      _presentedError = errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(showAppErrorBottomSheet(context, errorMessage));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => CreateRequisitionView(
        viewModel: _viewModel,
        onCancel: () => context.goNamed(AppRouteName.requisitions),
      ),
    );
  }

  Future<void> _showCreationSuccessAndNavigate(
    CreateRequisitionResult result,
  ) async {
    await showAppSuccessBottomSheet(
      context,
      'La requisa fue registrada correctamente.',
    );
    if (!mounted) return;
    context.goNamed(
      AppRouteName.requisitionDetail,
      pathParameters: {'requisitionId': result.requisitionId},
    );
  }
}

class CreateRequisitionView extends StatelessWidget {
  const CreateRequisitionView({
    required this.viewModel,
    required this.onCancel,
    super.key,
  });

  final CreateRequisitionViewModel viewModel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.94),
      body: SafeArea(
        child: AdaptiveLayout(
          builder: (context, window) {
            final compact = window.isCompact || window.hasCompactHeight;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: compact ? double.infinity : AppSize.formMaxWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.all(compact ? AppSpace.s : AppSpace.m),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(
                        compact ? AppRadius.m : AppRadius.l,
                      ),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.18,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        compact ? AppRadius.m : AppRadius.l,
                      ),
                      child: CreateRequisitionForm(
                        viewModel: viewModel,
                        compact: compact,
                        onCancel: onCancel,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.viewModel, required this.onClose});
  final CreateRequisitionViewModel viewModel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      top: true,
      bottom: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 860),
        child: Material(
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: CreateRequisitionForm(
              viewModel: viewModel,
              compact: compact,
              onCancel: onClose,
            ),
          ),
        ),
      ),
    );
  }
}
