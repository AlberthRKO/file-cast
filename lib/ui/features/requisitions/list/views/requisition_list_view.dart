import 'dart:async';

import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/ui/core/adaptive/adaptive_layout.dart';
import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/adaptive/window_size_class.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/feedback/app_feedback.dart';
import 'package:file_cast/ui/core/widgets/app_modal_bottom_sheet.dart';
import 'package:file_cast/ui/features/requisitions/list/view_models/requisition_list_state.dart';
import 'package:file_cast/ui/features/requisitions/list/view_models/requisition_list_view_model.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_card.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_filters.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_list_header.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_table.dart';
import 'package:file_cast/ui/features/requisitions/create/views/create_requisition_view.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class RequisitionListRoute extends StatelessWidget {
  const RequisitionListRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RequisitionListViewModel(
        repository: context.read<RequisitionRepository>(),
      )..load(),
      child: const _RequisitionListConnector(),
    );
  }
}

class _RequisitionListConnector extends StatelessWidget {
  const _RequisitionListConnector();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSessionController>().user;
    final canFinalize =
        user?.permisos?.any(
          (permission) =>
              permission?.trim().toLowerCase() == 'requisitions.finalize',
        ) ??
        false;

    return RequisitionListView(
      viewModel: context.watch<RequisitionListViewModel>(),
      canFinalize: canFinalize,
      identityLabel: _identityLabel(user),
      userName: user?.nombreCompleto?.trim().isNotEmpty == true
          ? user!.nombreCompleto!.trim()
          : 'Usuario',
    );
  }

  String _identityLabel(UserEntity? user) {
    final document = user?.numeroDocumento?.trim();
    final id = user?.id?.toString();
    final documentLabel = document == null || document.isEmpty
        ? 'C.I. —'
        : 'C.I. $document';
    final idLabel = id == null || id.isEmpty ? 'ID —' : 'ID $id';
    return '$documentLabel · $idLabel';
  }
}

class RequisitionListView extends StatefulWidget {
  const RequisitionListView({
    required this.viewModel,
    required this.canFinalize,
    required this.identityLabel,
    required this.userName,
    super.key,
  });

  final RequisitionListViewModel viewModel;
  final bool canFinalize;
  final String identityLabel;
  final String userName;

  @override
  State<RequisitionListView> createState() => _RequisitionListViewState();
}

class _RequisitionListViewState extends State<RequisitionListView> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  bool _fillViewportScheduled = false;

  RequisitionListViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _viewModel.state.query);
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant RequisitionListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != _viewModel.state.query &&
        _viewModel.state.query.isEmpty) {
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final useCompactActions = size.width < 600 || size.height < 480;
    _scheduleFillViewport();

    return Scaffold(
      floatingActionButton: useCompactActions
          ? _CreateRequisitionLauncher(
              onPressed: () => _openCreateRequisition(
                RequisitionRegistrationMode.existingCud,
              ),
            )
          : null,
      body: AdaptiveLayout(
        builder: (context, window) {
          final compact = window.isCompact || window.hasCompactHeight;
          return Column(
            children: [
              RequisitionListHeader(
                compact: compact,
                identityLabel: widget.identityLabel,
                userName: widget.userName,
                searchController: _searchController,
                onQueryChanged: _updateQuery,
                onOpenFilters: () => _openFilters(context),
                onRefresh: _viewModel.refresh,
                onSettings: () => context.pushNamed(AppRouteName.settings),
                isRefreshing: _viewModel.state.isRefreshing,
                filtersActive:
                    _viewModel.state.statusFilter != null ||
                    _viewModel.state.startDate != null ||
                    _viewModel.state.endDate != null,
              ),
              Expanded(
                child: ConstrainedContent(
                  padding: EdgeInsets.all(compact ? AppSpace.s : AppSpace.m),
                  child: Column(
                    children: [
                      if (!compact) ...[
                        _WideActions(
                          state: _viewModel.state,
                          onStatusChanged: _updateStatus,
                          onDatePressed: () => _selectDateRange(context),
                          onClear: _clearFilters,
                          onCreate: () => _openCreateRequisition(
                            RequisitionRegistrationMode.existingCud,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s),
                      ],
                      Expanded(child: _buildResults(context, window)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults(BuildContext context, AppWindowSize window) {
    final state = _viewModel.state;
    return switch (state.phase) {
      RequisitionListPhase.initial || RequisitionListPhase.loading =>
        const Center(child: CircularProgressIndicator()),
      RequisitionListPhase.error => _MessageState(
        icon: Icons.error_outline_rounded,
        title: 'No pudimos cargar las requisas',
        message: state.errorMessage ?? 'Intenta nuevamente.',
        actionLabel: 'Reintentar',
        onAction: _viewModel.load,
      ),
      RequisitionListPhase.empty => _MessageState(
        icon: Icons.search_off_rounded,
        title: 'No hay resultados',
        message: 'Cambia o limpia los filtros para ver otras requisas.',
        actionLabel: 'Limpiar filtros',
        onAction: _clearFilters,
      ),
      RequisitionListPhase.content => _ContentResults(
        items: _viewModel.visibleItems,
        window: window,
        scrollController: _scrollController,
        hasMore: _viewModel.hasMore,
        canFinalize: widget.canFinalize,
        onPressed: _showDetailsPlaceholder,
        onFinalize: _finalizeRequisition,
        onRefresh: _viewModel.refresh,
        isLoadingMore: _viewModel.isLoadingMore,
        loadMoreError: _viewModel.loadMoreError,
        onRetryLoadMore: () => unawaited(_viewModel.loadMore()),
      ),
    };
  }

  Future<void> _openFilters(BuildContext context) async {
    await showAppModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      maxWidth: AppSize.formMaxWidth,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpace.m,
                AppSpace.m,
                AppSpace.m,
                AppSpace.m + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filtrar requisas',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpace.m),
                  RequisitionFilters(
                    status: _viewModel.state.statusFilter,
                    startDate: _viewModel.state.startDate,
                    endDate: _viewModel.state.endDate,
                    onStatusChanged: _updateStatus,
                    onDatePressed: () => _selectDateRange(sheetContext),
                    onClear: _clearFilters,
                    vertical: true,
                  ),
                  const SizedBox(height: AppSpace.s),
                  FilledButton(
                    onPressed: () => sheetContext.pop(),
                    child: const Text('Listo'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final state = _viewModel.state;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: state.startDate != null && state.endDate != null
          ? DateTimeRange(start: state.startDate!, end: state.endDate!)
          : null,
    );
    if (range == null) return;
    _viewModel.updateDateRange(start: range.start, end: range.end);
    _resetScroll();
  }

  void _clearFilters() {
    _searchController.clear();
    _viewModel.clearFilters();
    _resetScroll();
  }

  void _updateQuery(String value) {
    _viewModel.updateQuery(value);
    _resetScroll();
  }

  void _updateStatus(RequisitionStatus? value) {
    _viewModel.updateStatus(value);
    _resetScroll();
  }

  void _resetScroll() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter <= 240) {
      unawaited(_viewModel.loadMore());
    }
  }

  void _scheduleFillViewport() {
    if (_fillViewportScheduled || !_viewModel.hasMore) return;
    _fillViewportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillViewportScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.extentAfter <= 240) {
        unawaited(_viewModel.loadMore());
      }
    });
  }

  Future<void> _openCreateRequisition(RequisitionRegistrationMode mode) async {
    var completionHandled = false;
    await showAppModalBottomSheet<void>(
      context: context,
      expand: true,
      useSafeArea: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      maxWidth: AppSize.formMaxWidth,
      builder: (sheetContext) => CreateRequisitionSheet(
        initialMode: mode,
        onClose: () => Navigator.of(sheetContext).pop(),
        onCompleted: (result) {
          if (completionHandled) return;
          completionHandled = true;
          Navigator.of(sheetContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.pushNamed(
              AppRouteName.requisitionDetail,
              pathParameters: {
                'requisitionId': result.requisitionId,
              },
            );
          });
        },
      ),
    );
  }

  void _showDetailsPlaceholder(Requisition requisition) {
    context.pushNamed(
      AppRouteName.requisitionDetail,
      pathParameters: {'requisitionId': requisition.id},
    );
  }

  Future<void> _finalizeRequisition(Requisition requisition) async {
    final confirmed = await showAppModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      maxWidth: 520,
      builder: (sheetContext) => _ConfirmFinalizeSheet(
        requisition: requisition,
        onCancel: () => Navigator.of(sheetContext).pop(false),
        onConfirm: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await _viewModel.finalizeRequisition(requisition.id);
    if (!mounted) return;
    if (error == null) {
      await showAppSuccessBottomSheet(
        context,
        'La requisa fue finalizada y sellada correctamente.',
      );
    } else {
      await showAppErrorBottomSheet(context, error);
    }
  }
}

class _WideActions extends StatelessWidget {
  const _WideActions({
    required this.state,
    required this.onStatusChanged,
    required this.onDatePressed,
    required this.onClear,
    required this.onCreate,
  });

  final RequisitionListState state;
  final ValueChanged<RequisitionStatus?> onStatusChanged;
  final VoidCallback onDatePressed;
  final VoidCallback onClear;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RequisitionFilters(
          status: state.statusFilter,
          startDate: state.startDate,
          endDate: state.endDate,
          onStatusChanged: onStatusChanged,
          onDatePressed: onDatePressed,
          onClear: onClear,
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Registrar nueva requisa'),
        ),
      ],
    );
  }
}

class _ContentResults extends StatelessWidget {
  const _ContentResults({
    required this.items,
    required this.window,
    required this.scrollController,
    required this.hasMore,
    required this.canFinalize,
    required this.onPressed,
    required this.onFinalize,
    required this.onRefresh,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onRetryLoadMore,
  });

  final List<Requisition> items;
  final AppWindowSize window;
  final ScrollController scrollController;
  final bool hasMore;
  final bool canFinalize;
  final ValueChanged<Requisition> onPressed;
  final ValueChanged<Requisition> onFinalize;
  final Future<void> Function() onRefresh;
  final bool isLoadingMore;
  final String? loadMoreError;
  final VoidCallback onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    if ((window.isExpanded || window.isLarge) && !window.hasCompactHeight) {
      return RequisitionTable(
        items: items,
        onPressed: onPressed,
        scrollController: scrollController,
        hasMore: hasMore,
        canFinalize: canFinalize,
        onFinalize: onFinalize,
        onRefresh: onRefresh,
        isLoadingMore: isLoadingMore,
        loadMoreError: loadMoreError,
        onRetryLoadMore: onRetryLoadMore,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useGrid =
            !window.hasCompactHeight &&
            constraints.maxWidth >= 700 &&
            textScale <= 1.25;

        if (useGrid) {
          return _refreshable(
            context,
            CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 460,
                    crossAxisSpacing: AppSpace.s,
                    mainAxisSpacing: AppSpace.s,
                    mainAxisExtent: 260,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => RequisitionCard(
                      requisition: items[index],
                      onPressed: () => onPressed(items[index]),
                      canFinalize: canFinalize,
                      onFinalize: () => onFinalize(items[index]),
                    ),
                    childCount: items.length,
                  ),
                ),
                _InfiniteScrollFooter(
                  hasMore: hasMore,
                  isLoadingMore: isLoadingMore,
                  errorMessage: loadMoreError,
                  onRetry: onRetryLoadMore,
                  bottomPadding: window.isCompact || window.hasCompactHeight
                      ? 80
                      : 0,
                ),
              ],
            ),
          );
        }

        return _refreshable(
          context,
          CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) {
                      return const SizedBox(height: AppSpace.s);
                    }
                    final itemIndex = index ~/ 2;
                    final item = items[itemIndex];
                    return RequisitionCard(
                      requisition: item,
                      onPressed: () => onPressed(item),
                      canFinalize: canFinalize,
                      onFinalize: () => onFinalize(item),
                    );
                  },
                  childCount: items.isEmpty ? 0 : items.length * 2 - 1,
                ),
              ),
              _InfiniteScrollFooter(
                hasMore: hasMore,
                isLoadingMore: isLoadingMore,
                errorMessage: loadMoreError,
                onRetry: onRetryLoadMore,
                bottomPadding: window.isCompact || window.hasCompactHeight
                    ? 80
                    : 0,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _refreshable(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: theme.colorScheme.primary,
      backgroundColor: theme.cardColor,
      displacement: AppSpace.l,
      strokeWidth: 2.2,
      child: child,
    );
  }
}

class _InfiniteScrollFooter extends StatelessWidget {
  const _InfiniteScrollFooter({
    required this.hasMore,
    required this.isLoadingMore,
    required this.errorMessage,
    required this.onRetry,
    required this.bottomPadding,
  });

  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;
  final VoidCallback onRetry;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: (hasMore ? 72 : AppSpace.m) + bottomPadding,
        child: errorMessage != null
            ? Center(
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              )
            : hasMore && isLoadingMore
            ? const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
    );
  }
}

class _ConfirmFinalizeSheet extends StatelessWidget {
  const _ConfirmFinalizeSheet({
    required this.requisition,
    required this.onCancel,
    required this.onConfirm,
  });

  final Requisition requisition;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identifier =
        requisition.cud ?? requisition.subjectName ?? requisition.id;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.l),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.l,
            AppSpace.l,
            AppSpace.l,
            AppSpace.m + bottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: AppSize.iconL,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'Finalizar requisa',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'Esta acción sellará la requisa y no podrá deshacerse desde la aplicación.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                identifier,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpace.l),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('Sellar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.messageMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpace.m),
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpace.s),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpace.m),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRequisitionLauncher extends StatelessWidget {
  const _CreateRequisitionLauncher({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Registrar nueva requisa',
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [actionGradientStart, violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: textWhite),
        ),
      ),
    );
  }
}
