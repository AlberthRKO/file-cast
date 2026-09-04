import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/ui/core/adaptive/adaptive_layout.dart';
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
        initialMode: initialMode,
      ),
      child: Builder(
        builder: (context) {
          final vm = context.read<CreateRequisitionViewModel>();
          return ListenableBuilder(
            listenable: vm,
            builder: (context, _) {
              final result = vm.state.createdResult;
              if (result != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) onCompleted(result);
                });
              }
              return _SheetSurface(viewModel: vm, onClose: onClose);
            },
          );
        },
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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CreateRequisitionViewModel>();
    final result = viewModel.state.createdResult;

    if (!_navigated && result != null) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.goNamed(
          AppRouteName.requisitionDetail,
          pathParameters: {
            'requisitionId': result.requisitionId,
          },
        );
      });
    }

    return CreateRequisitionView(
      viewModel: viewModel,
      onCancel: () => context.goNamed(AppRouteName.requisitions),
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
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 860),
        child: Material(
          color: Theme.of(context).cardColor,
          child: CreateRequisitionForm(
            viewModel: viewModel,
            compact: compact,
            onCancel: onClose,
          ),
        ),
      ),
    );
  }
}
