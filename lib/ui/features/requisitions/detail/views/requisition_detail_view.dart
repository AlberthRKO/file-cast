import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/requisitions/detail/view_models/requisition_detail_view_model.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_case_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

const _detailCardShadow = [
  BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 15,
    offset: Offset(0, 7),
  ),
];

class RequisitionDetailRoute extends StatelessWidget {
  const RequisitionDetailRoute({required this.requisitionId, super.key});
  final String requisitionId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => RequisitionDetailViewModel(
      repository: context.read<RequisitionDetailRepository>(),
      requisitionId: requisitionId,
    )..load(),
    child: const _RequisitionDetailConnector(),
  );
}

class _RequisitionDetailConnector extends StatelessWidget {
  const _RequisitionDetailConnector();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RequisitionDetailViewModel>();
    if (viewModel.phase == RequisitionDetailPhase.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (viewModel.phase == RequisitionDetailPhase.error ||
        viewModel.detail == null) {
      return Scaffold(
        body: Center(
          child: Text(viewModel.errorMessage ?? 'Requisa no disponible.'),
        ),
      );
    }
    return RequisitionDetailView(
      viewModel: viewModel,
      detail: viewModel.detail!,
    );
  }
}

class RequisitionDetailView extends StatelessWidget {
  const RequisitionDetailView({
    required this.viewModel,
    required this.detail,
    super.key,
  });
  final RequisitionDetailViewModel viewModel;
  final RequisitionDetail detail;

  @override
  Widget build(BuildContext context) {
    final requisition = detail.requisition;
    final categories = viewModel.evidenceCategories;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de requisa'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAcquisitionActions(context),
        tooltip: 'Agregar evidencia',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _CaseHeader(
            child: RequisitionCaseCard(
              cud: requisition.cud ?? requisition.id,
              caseType: requisition.caseName,
              division: detail.division,
              subjectCount: detail.subjects.length,
              statusLabel: 'En curso',
            ),
          ),
          Expanded(
            child: ConstrainedContent(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.m,
                AppSpace.m,
                AppSpace.m,
                0,
              ),
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpace.xxl * 2),
                children: [
                  _EvidenceTotals(categories: categories),
                  for (final category in categories) ...[
                    _EvidenceSection(summary: category),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAcquisitionActions(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _AcquisitionActionSheet(
          isImporting: viewModel.isImporting,
          onCapture: () => _closeThen(context, sheetContext, () {
            context.pushNamed(
              AppRouteName.acquisitionConnect,
              pathParameters: {
                'requisitionId': detail.requisition.id,
                'sessionId': detail.sessionId,
              },
            );
          }),
          onTransfer: () => _closeThen(context, sheetContext, () {
            context.pushNamed(
              AppRouteName.fileTransfer,
              pathParameters: {'requisitionId': detail.requisition.id},
            );
          }),
          onImport: () => _closeThen(
            context,
            sheetContext,
            () => viewModel.importEvidence(imagesOnly: false),
          ),
        ),
      );

  void _closeThen(
    BuildContext pageContext,
    BuildContext sheetContext,
    VoidCallback action,
  ) {
    Navigator.of(sheetContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageContext.mounted) action();
    });
  }
}

class _CaseHeader extends StatelessWidget {
  const _CaseHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      AppSpace.m,
      AppSpace.s,
      AppSpace.m,
      AppSpace.m,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.l),
      ),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

class _EvidenceTotals extends StatelessWidget {
  const _EvidenceTotals({required this.categories});

  final List<EvidenceCategorySummary> categories;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Resumen de archivos',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpace.s),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 3 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: AppSpace.s,
              mainAxisSpacing: AppSpace.s,
              mainAxisExtent: 100,
            ),
            itemBuilder: (context, index) =>
                _FolderSummaryCard(summary: categories[index]),
          );
        },
      ),
    ],
  );
}

class _FolderSummaryCard extends StatelessWidget {
  const _FolderSummaryCard({required this.summary});

  final EvidenceCategorySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: _detailCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: AppSize.minXsTouchTarget,
            height: AppSize.minXsTouchTarget,
            padding: const EdgeInsets.all(AppSpace.m - AppSpace.s),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: SvgPicture.asset(
              'assets/images/icons/folder.svg',
              colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _categoryTitle(summary.category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${summary.items.length} archivos · ${summary.totalSizeLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.summary});

  final EvidenceCategorySummary summary;

  @override
  Widget build(BuildContext context) {
    final visible = summary.items.take(5).toList();
    final title = _categoryTitle(summary.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (summary.items.isNotEmpty)
              TextButton(
                onPressed: () => _showAll(context),
                child: const Text('Ver todo'),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s),
        if (visible.isEmpty)
          _EmptyEvidence(
            message: 'Aún no hay ${title.toLowerCase()} en esta requisa.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              return GridView.builder(
                padding: const EdgeInsets.only(bottom: AppSpace.s),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpace.s,
                  mainAxisSpacing: AppSpace.s,
                  mainAxisExtent: 68,
                ),
                itemBuilder: (context, index) =>
                    _EvidencePreview(evidence: visible[index]),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showAll(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AllEvidenceSheet(
      title: _categoryTitle(summary.category),
      subtitle: '${summary.items.length} elementos · ${summary.totalSizeLabel}',
      evidence: summary.items,
    ),
  );
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({required this.evidence});
  final RequisitionEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconAsset = switch (evidence.type) {
      RequisitionEvidenceType.image => 'gallery.svg',
      RequisitionEvidenceType.video => 'video.svg',
      RequisitionEvidenceType.audio => 'microphone.svg',
      RequisitionEvidenceType.document => 'file.svg',
      RequisitionEvidenceType.other => 'paper.svg',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpace.s),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: _detailCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: AppSize.minTouchTarget,
            height: AppSize.minTouchTarget,
            padding: const EdgeInsets.all(AppSpace.m - AppSpace.s),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: SvgPicture.asset(
              'assets/images/icons/$iconAsset',
              colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evidence.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  evidence.sizeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.more_horiz_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

String _categoryTitle(EvidenceCategory category) => switch (category) {
  EvidenceCategory.images => 'Imágenes',
  EvidenceCategory.videos => 'Videos',
  EvidenceCategory.files => 'Archivos',
};

class _EmptyEvidence extends StatelessWidget {
  const _EmptyEvidence({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpace.l),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.m),
      boxShadow: _detailCardShadow,
    ),
    child: Text(message, textAlign: TextAlign.center),
  );
}

class _AllEvidenceSheet extends StatelessWidget {
  const _AllEvidenceSheet({
    required this.title,
    required this.subtitle,
    required this.evidence,
  });
  final String title;
  final String subtitle;
  final List<RequisitionEvidence> evidence;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .88,
    child: Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.m,
            AppSpace.s,
            AppSpace.m,
            AppSpace.m,
          ),
          child: Column(
            children: [
              const _SheetHandle(),
              _ModalHeader(
                title: title,
                subtitle: subtitle,
                asset: 'folder.svg',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: AppSpace.m),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 2 : 1;
                    return GridView.builder(
                      itemCount: evidence.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: AppSpace.s,
                        mainAxisSpacing: AppSpace.s,
                        mainAxisExtent: 68,
                      ),
                      itemBuilder: (context, index) =>
                          _EvidencePreview(evidence: evidence[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AcquisitionActionSheet extends StatelessWidget {
  const _AcquisitionActionSheet({
    required this.onCapture,
    required this.onTransfer,
    required this.onImport,
    required this.isImporting,
  });
  final VoidCallback onCapture;
  final VoidCallback onTransfer;
  final VoidCallback onImport;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        title: 'Capturar pantalla',
        subtitle: 'Conecta el dispositivo e inicia la captura.',
        asset: 'camera.svg',
        onTap: onCapture,
      ),
      _ActionData(
        title: 'Transferencia de archivos',
        subtitle: 'Recibe archivos desde el dispositivo conectado.',
        asset: 'share.svg',
        onTap: onTransfer,
      ),
      _ActionData(
        title: 'Importar archivos',
        subtitle: 'Selecciona imágenes, videos, audios u otros archivos.',
        asset: 'upload.svg',
        onTap: isImporting ? null : onImport,
      ),
    ];
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.m,
              AppSpace.s,
              AppSpace.m,
              AppSpace.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _SheetHandle()),
                _ModalHeader(
                  title: 'Agregar evidencia',
                  subtitle:
                      'Selecciona cómo deseas incorporar información a la requisa.',
                  asset: 'clip.svg',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: AppSpace.m),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 840
                        ? 3
                        : constraints.maxWidth >= 600
                        ? 2
                        : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: actions.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: AppSpace.s,
                        mainAxisSpacing: AppSpace.s,
                        mainAxisExtent: 82,
                      ),
                      itemBuilder: (context, index) =>
                          _SheetActionCard(data: actions[index]),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 4,
    margin: const EdgeInsets.only(bottom: AppSpace.s),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.outlineVariant,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
  );
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final String asset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: AppSize.minTouchTarget,
          height: AppSize.minTouchTarget,
          padding: const EdgeInsets.all(AppSpace.m - AppSpace.s),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: SvgPicture.asset(
            'assets/images/icons/$asset',
            colorFilter: ColorFilter.mode(
              theme.colorScheme.primary,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: .65,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
        ),
      ],
    );
  }
}

class _ActionData {
  const _ActionData({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String asset;
  final VoidCallback? onTap;
}

class _SheetActionCard extends StatelessWidget {
  const _SheetActionCard({required this.data});
  final _ActionData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.m),
          boxShadow: _detailCardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s),
          child: Row(
            children: [
              Container(
                width: AppSize.minTouchTarget,
                height: AppSize.minTouchTarget,
                padding: const EdgeInsets.all(AppSpace.m - AppSpace.s),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                child: SvgPicture.asset(
                  'assets/images/icons/${data.asset}',
                  colorFilter: ColorFilter.mode(
                    scheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
