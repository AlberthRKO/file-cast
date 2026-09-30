import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_actions_menu.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RequisitionTable extends StatelessWidget {
  const RequisitionTable({
    required this.items,
    required this.onPressed,
    required this.scrollController,
    required this.hasMore,
    required this.canFinalize,
    required this.locationFor,
    required this.onViewLocation,
    required this.onFinalize,
    required this.onRefresh,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onRetryLoadMore,
    super.key,
  });

  final List<Requisition> items;
  final ValueChanged<Requisition> onPressed;
  final ScrollController scrollController;
  final bool hasMore;
  final bool canFinalize;
  final RequisitionLocation? Function(Requisition requisition) locationFor;
  final ValueChanged<Requisition> onViewLocation;
  final ValueChanged<Requisition> onFinalize;
  final Future<void> Function() onRefresh;
  final bool isLoadingMore;
  final String? loadMoreError;
  final VoidCallback onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.m,
                vertical: AppSpace.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('FECHA Y HORA', style: headerStyle),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('IDENTIFICACIÓN', style: headerStyle),
                  ),
                  Expanded(flex: 2, child: Text('ESTADO', style: headerStyle)),
                  Expanded(
                    flex: 2,
                    child: Text('EVIDENCIA', style: headerStyle),
                  ),
                  const SizedBox(
                    width: AppSize.minTouchTarget * 2 + AppSpace.xs,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).cardColor,
              displacement: AppSpace.l,
              strokeWidth: 2.2,
              child: ListView.separated(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: items.length + (hasMore ? 1 : 0),
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == items.length) {
                    return _LoadingMoreRow(
                      isLoading: isLoadingMore,
                      errorMessage: loadMoreError,
                      onRetry: onRetryLoadMore,
                    );
                  }
                  final item = items[index];
                  return _RequisitionTableRow(
                    requisition: item,
                    onPressed: () => onPressed(item),
                    canFinalize: canFinalize,
                    location: locationFor(item),
                    onViewLocation: () => onViewLocation(item),
                    onFinalize: () => onFinalize(item),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingMoreRow extends StatelessWidget {
  const _LoadingMoreRow({
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return SizedBox(
        height: 64,
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: Center(
        child: SizedBox.square(
          dimension: 20,
          child: isLoading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _RequisitionTableRow extends StatelessWidget {
  const _RequisitionTableRow({
    required this.requisition,
    required this.onPressed,
    required this.canFinalize,
    required this.location,
    required this.onViewLocation,
    required this.onFinalize,
  });

  final Requisition requisition;
  final VoidCallback onPressed;
  final bool canFinalize;
  final RequisitionLocation? location;
  final VoidCallback onViewLocation;
  final VoidCallback onFinalize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identifier =
        requisition.cud ?? requisition.subjectName ?? requisition.id;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                DateFormat(
                  'dd/MM/yyyy – HH:mm',
                ).format(requisition.registeredAt),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identifier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    requisition.caseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: RequisitionStatusBadge(status: requisition.status),
              ),
            ),
            Expanded(
              flex: 2,
              child: Wrap(
                spacing: AppSpace.m,
                children: [
                  _EvidenceCount(
                    icon: Icons.photo_camera_outlined,
                    count: requisition.imageEvidenceCount,
                  ),
                  _EvidenceCount(
                    icon: Icons.videocam_outlined,
                    count: requisition.videoEvidenceCount,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: AppSize.minTouchTarget * 2 + AppSpace.xs,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RequisitionDetailsButton(onTap: onPressed),
                  const SizedBox(width: AppSpace.xs),
                  RequisitionActionsMenu(
                    requisition: requisition,
                    canFinalize: canFinalize,
                    location: location,
                    onViewLocation: onViewLocation,
                    onFinalize: onFinalize,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCount extends StatelessWidget {
  const _EvidenceCount({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSize.iconS),
        const SizedBox(width: AppSpace.xs),
        Text('$count'),
      ],
    );
  }
}
