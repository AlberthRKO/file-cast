import 'dart:async';

import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/models/evidence_upload_progress.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/feedback/app_feedback.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_action_button.dart';
import 'package:file_cast/ui/core/widgets/app_form_input_icon.dart';
import 'package:file_cast/ui/core/widgets/app_modal_bottom_sheet.dart';
import 'package:file_cast/ui/core/widgets/evidence_thumbnail.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:file_cast/ui/features/requisitions/detail/view_models/requisition_detail_view_model.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/evidence_preview_sheet.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/import_evidence_preview_dialog.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_location_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:searchfield/searchfield.dart';

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
      requisitionRepository: context.read<RequisitionRepository>(),
      creationRepository: context.read<RequisitionCreationRepository>(),
      previewService: context.read<EvidencePreviewService>(),
      requisitionId: requisitionId,
      currentActorId: context
          .read<AuthSessionController>()
          .user
          ?.id
          ?.toString(),
      currentActorName: context
          .read<AuthSessionController>()
          .user
          ?.nombreCompleto,
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

class RequisitionDetailView extends StatefulWidget {
  const RequisitionDetailView({
    required this.viewModel,
    required this.detail,
    super.key,
  });

  final RequisitionDetailViewModel viewModel;
  final RequisitionDetail detail;

  @override
  State<RequisitionDetailView> createState() => _RequisitionDetailViewState();
}

class _RequisitionDetailViewState extends State<RequisitionDetailView> {
  bool _showInfo = true;

  RequisitionDetailViewModel get viewModel => widget.viewModel;

  RequisitionDetail get detail => widget.detail;

  @override
  Widget build(BuildContext context) {
    final categories = viewModel.evidenceCategories;
    final decryptionService = context.read<EvidenceDecryptionService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de requisa'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: _showInfo
                ? 'Ocultar información de la requisa'
                : 'Mostrar información de la requisa',
            onPressed: () => setState(() => _showInfo = !_showInfo),
            icon: SvgPicture.asset(
              'assets/images/icons/info.svg',
              width: AppSize.iconL,
              height: AppSize.iconL,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: viewModel.canAcquire
          ? FloatingActionButton(
              onPressed: () => _showAcquisitionActions(context),
              tooltip: 'Agregar evidencia',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _showInfo
                ? _CaseHeader(
                    detail: detail,
                    viewModel: viewModel,
                    onShowSubjects: () => _showSubjects(context),
                    onShowParticipants: () => _showParticipants(context),
                    onShowLocation: () => _showLocation(context),
                    onLinkCase: () => _showCaseLink(context),
                  )
                : const SizedBox.shrink(),
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
                padding: EdgeInsets.only(
                  bottom:
                      AppSpace.xxl * 2 +
                      MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  _EvidenceTotals(categories: categories),
                  if (viewModel.canFinalize) ...[
                    const SizedBox(height: AppSpace.m),
                    _FinalizeCard(
                      isFinalizing: viewModel.isFinalizing,
                      canSeal: viewModel.canSeal,
                      onPressed: () => _finalize(context),
                    ),
                  ],
                  for (final category in categories) ...[
                    const SizedBox(height: AppSpace.m),
                    _EvidenceSection(
                      summary: category,
                      decryptionService: decryptionService,
                      onOpenEvidence: (evidence) =>
                          _showEvidencePreview(context, evidence),
                    ),
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
      showAppModalBottomSheet<void>(
        context: context,
        enableDrag: false,
        maxWidth: AppSize.formMaxWidth,
        builder: (sheetContext) => _AcquisitionActionSheet(
          isImporting: viewModel.isImporting || viewModel.isSelectingEvidence,
          onCapture: () => _closeThen(
            context,
            sheetContext,
            () => _openAcquisition(context, transfer: false),
          ),
          onTransfer: () => _closeThen(
            context,
            sheetContext,
            () => _openAcquisition(context, transfer: true),
          ),
          onImport: () => _closeThen(
            context,
            sheetContext,
            () => _importFiles(context),
          ),
        ),
      );

  Future<void> _importFiles(BuildContext context) async {
    final selected = await viewModel.selectEvidence(imagesOnly: false);
    if (!context.mounted) return;
    if (viewModel.errorMessage != null) {
      await showAppErrorBottomSheet(context, viewModel.errorMessage!);
      return;
    }
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ImportEvidencePreviewDialog(
        evidence: selected,
        onCancel: () {
          viewModel.clearSelectedEvidence();
          Navigator.of(dialogContext).pop(false);
        },
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La carga comenzó. Puedes seguir usando la aplicación.',
        ),
      ),
    );
    unawaited(_confirmImportInBackground(context));
  }

  Future<void> _confirmImportInBackground(BuildContext context) async {
    final imported = await viewModel.confirmSelectedEvidence();
    if (!context.mounted || imported || viewModel.errorMessage == null) return;
    await showAppErrorBottomSheet(context, viewModel.errorMessage!);
  }

  Future<void> _openAcquisition(
    BuildContext context, {
    required bool transfer,
  }) async {
    final sessionId = await viewModel.ensureAcquisitionSession(
      sourcePlatform: 'ANDROID',
      transport: transfer ? 'USB_OTG_ADB' : 'USB_OTG_SCRCPY',
    );
    if (!context.mounted) return;
    if (sessionId == null) {
      await showAppErrorBottomSheet(
        context,
        viewModel.errorMessage ?? 'No se pudo abrir la sesión de adquisición.',
      );
      return;
    }
    context.pushNamed(
      AppRouteName.acquisitionConnect,
      pathParameters: {
        'requisitionId': detail.requisition.id,
        'sessionId': sessionId,
      },
      queryParameters: transfer ? {'destination': 'transfer'} : const {},
    );
  }

  Future<void> _finalize(BuildContext context) async {
    final confirmed = await showAppModalBottomSheet<bool>(
      context: context,
      maxWidth: 520,
      builder: (sheetContext) => _ConfirmDetailFinalizeSheet(
        onCancel: () => Navigator.of(sheetContext).pop(false),
        onConfirm: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await viewModel.finalizeRequisition();
    if (!context.mounted) return;
    if (error == null) {
      await showAppSuccessBottomSheet(
        context,
        'La requisa fue finalizada y sellada correctamente.',
      );
    } else {
      await showAppErrorBottomSheet(context, error);
    }
  }

  Future<void> _showSubjects(BuildContext context) =>
      showAppModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        maxWidth: 560,
        builder: (_) => _PeopleSheet(
          title: 'Sujetos del caso',
          people: _subjectPeople(detail),
        ),
      );

  Future<void> _showParticipants(BuildContext context) =>
      showAppModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        maxWidth: 560,
        builder: (_) => _PeopleSheet(
          title: 'Participantes de la requisa',
          people: detail.participants
              .map(
                (participant) => _DisplayPerson(
                  name: viewModel.participantName(participant),
                  secondary: _participantRoleLabel(participant.role),
                ),
              )
              .toList(growable: false),
        ),
      );

  Future<void> _showLocation(BuildContext context) {
    final location = detail.location;
    if (location == null) return Future<void>.value();
    return showAppModalBottomSheet<void>(
      context: context,
      enableDrag: false,
      maxWidth: 560,
      builder: (sheetContext) => RequisitionLocationViewer(
        location: location,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  Future<void> _showEvidencePreview(
    BuildContext context,
    RequisitionEvidence evidence,
  ) => showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final windowSize = MediaQuery.sizeOf(dialogContext);
      final availableWidth = windowSize.width - (AppSpace.m * 2);
      final availableHeight = windowSize.height - (AppSpace.m * 2);
      final dialogWidth = availableWidth > 920 ? 920.0 : availableWidth;
      final dialogHeight = availableHeight > 820 ? 820.0 : availableHeight;
      return Dialog(
        insetPadding: const EdgeInsets.all(AppSpace.m),
        backgroundColor: Colors.transparent,
        elevation: 12,
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: EvidencePreviewSheet(
            evidence: evidence,
            prepare: () => viewModel.prepareEvidencePreview(evidence),
            disposePreview: viewModel.disposeEvidencePreview,
          ),
        ),
      );
    },
  );

  Future<void> _showCaseLink(BuildContext context) async {
    final linked = await showAppModalBottomSheet<EcosystemCaseSummary>(
      context: context,
      enableDrag: false,
      maxWidth: AppSize.formMaxWidth,
      builder: (_) => _CaseLinkSheet(viewModel: viewModel),
    );
    if (!context.mounted || linked == null) return;
    await showAppSuccessBottomSheet(
      context,
      'El CUD fue vinculado a la requisa.',
    );
  }

  void _closeThen(
    BuildContext pageContext,
    BuildContext sheetContext,
    FutureOr<void> Function() action,
  ) {
    Navigator.of(sheetContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageContext.mounted) unawaited(Future<void>.sync(action));
    });
  }
}

class _CaseHeader extends StatelessWidget {
  const _CaseHeader({
    required this.detail,
    required this.viewModel,
    required this.onShowSubjects,
    required this.onShowParticipants,
    required this.onShowLocation,
    required this.onLinkCase,
  });

  final RequisitionDetail detail;
  final RequisitionDetailViewModel viewModel;
  final VoidCallback onShowSubjects;
  final VoidCallback onShowParticipants;
  final VoidCallback onShowLocation;
  final VoidCallback onLinkCase;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight.clamp(0.0, 360.0)
                  : 360.0;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: _RequisitionSummaryCard(
                    detail: detail,
                    viewModel: viewModel,
                    onShowSubjects: onShowSubjects,
                    onShowParticipants: onShowParticipants,
                    onShowLocation: onShowLocation,
                    onLinkCase: onLinkCase,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RequisitionSummaryCard extends StatelessWidget {
  const _RequisitionSummaryCard({
    required this.detail,
    required this.viewModel,
    required this.onShowSubjects,
    required this.onShowParticipants,
    required this.onShowLocation,
    required this.onLinkCase,
  });

  final RequisitionDetail detail;
  final RequisitionDetailViewModel viewModel;
  final VoidCallback onShowSubjects;
  final VoidCallback onShowParticipants;
  final VoidCallback onShowLocation;
  final VoidCallback onLinkCase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requisition = detail.requisition;
    final hasCase = requisition.cud?.trim().isNotEmpty ?? false;
    final subjects = _subjectPeople(detail);
    final participants = detail.participants
        .map(
          (participant) => _DisplayPerson(
            name: viewModel.participantName(participant),
            secondary: _participantRoleLabel(participant.role),
          ),
        )
        .toList(growable: false);
    final location = detail.location;
    final hasCoordinates = detail.latitude != null || detail.longitude != null;
    final primaryPerson = subjects.length == 1 ? subjects.single : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              hasCase
                  ? 'assets/images/icons/folder.svg'
                  : 'assets/images/icons/cardEmployee.svg',
              width: AppSize.iconL,
              height: AppSize.iconL,
              colorFilter: ColorFilter.mode(
                theme.colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCase
                        ? 'CUD'
                        : primaryPerson?.secondary?.isNotEmpty ?? false
                        ? 'Persona · CI: ${primaryPerson?.secondary}'
                        : 'Persona',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    hasCase
                        ? requisition.cud!
                        : primaryPerson?.name ??
                              requisition.subjectName ??
                              'Persona no registrada',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s),
            _StatusBadge(status: _statusLabel(requisition.status)),
          ],
        ),
        if (detail.description?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpace.s),
          Text(
            detail.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (detail.procedureAt != null) ...[
          const SizedBox(height: AppSpace.s),
          _SummaryLine(
            asset: 'assets/images/icons/calendarDay.svg',
            label: 'Fecha del procedimiento',
            value: DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(detail.procedureAt!),
          ),
        ],
        const SizedBox(height: AppSpace.s),
        if (hasCase) ...[
          _SummaryPair(
            left: _SummaryLine(
              asset: 'assets/images/icons/contrato.svg',
              label: 'Delito',
              value: requisition.caseName,
            ),
            right: _SummaryLine(
              asset: 'assets/images/icons/marca.svg',
              label: 'Tipo',
              value: detail.division,
            ),
          ),
        ],
        if (hasCase && subjects.isNotEmpty && participants.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s),
          _PeoplePair(
            left: _PeopleSummary(
              title: subjects.length == 1 ? 'Sujeto' : 'Sujetos',
              people: subjects,
              onView: subjects.length > 1 ? onShowSubjects : null,
            ),
            right: _PeopleSummary(
              title: participants.length == 1
                  ? 'Participante'
                  : 'Participantes',
              people: participants,
              onView: participants.length > 1 ? onShowParticipants : null,
            ),
          ),
        ] else if (hasCase && subjects.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s),
          _PeopleSummary(
            title: subjects.length == 1 ? 'Sujeto' : 'Sujetos',
            people: subjects,
            onView: subjects.length > 1 ? onShowSubjects : null,
          ),
        ] else if (participants.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s),
          _PeopleSummary(
            title: participants.length == 1 ? 'Participante' : 'Participantes',
            people: participants,
            onView: participants.length > 1 ? onShowParticipants : null,
          ),
        ],
        if (location != null ||
            hasCoordinates ||
            (detail.locationLabel?.isNotEmpty ?? false)) ...[
          _LocationSummary(
            label: detail.locationLabel,
            latitude: detail.latitude,
            longitude: detail.longitude,
            onView: location == null ? null : onShowLocation,
          ),
        ],
        _SummaryFooter(
          canLinkCase: !hasCase && viewModel.canLinkCase,
          onLinkCase: onLinkCase,
          sessionsLabel: '${detail.sessions.length} sesiones',
          evidenceLabel: detail.requisition.isSynchronized
              ? 'Evidencias sincronizadas'
              : 'Evidencias pendientes',
          uploadProgress: viewModel.uploadProgress,
          isImporting: viewModel.isImporting,
          isSyncing: viewModel.isSyncing,
          pendingCount: viewModel.pendingEvidenceCount,
          onRetry: viewModel.retryPendingEvidence,
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s,
          vertical: AppSpace.xs,
        ),
        child: Text(
          status,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              asset,
              width: AppSize.iconS,
              height: AppSize.iconS,
              colorFilter: ColorFilter.mode(
                theme.colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryFooter extends StatelessWidget {
  const _SummaryFooter({
    required this.canLinkCase,
    required this.onLinkCase,
    required this.sessionsLabel,
    required this.evidenceLabel,
    required this.uploadProgress,
    required this.isImporting,
    required this.isSyncing,
    required this.pendingCount,
    required this.onRetry,
  });

  final bool canLinkCase;
  final VoidCallback onLinkCase;
  final String sessionsLabel;
  final String evidenceLabel;
  final EvidenceUploadProgress? uploadProgress;
  final bool isImporting;
  final bool isSyncing;
  final int pendingCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final metrics = Wrap(
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      children: [
        _SummaryMetric(
          asset: 'assets/images/icons/folder.svg',
          label: sessionsLabel,
        ),
        _SummaryMetric(
          asset: 'assets/images/icons/sync.svg',
          label: evidenceLabel,
        ),
      ],
    );

    final uploadIndicator = _UploadProgressIndicator(
      progress: uploadProgress,
      isImporting: isImporting,
      isSyncing: isSyncing,
      pendingCount: pendingCount,
      onRetry: onRetry,
    );

    final linkButton = AppActionButton(
      label: 'Vincular a un caso',
      onPressed: onLinkCase,
      foregroundColor: textWhite,
      gradient: const LinearGradient(
        colors: [actionGradientStart, violet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      leadingAsset: 'assets/images/icons/link.svg',
      maxWidth: 240,
      elevation: 2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
    );

    final footer = !canLinkCase
        ? metrics
        : LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    metrics,
                    const SizedBox(height: AppSpace.s),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: linkButton,
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: metrics),
                  const SizedBox(width: AppSpace.m),
                  SizedBox(width: 240, child: linkButton),
                ],
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isImporting ||
            isSyncing ||
            uploadProgress?.isActive == true ||
            pendingCount > 0) ...[
          uploadIndicator,
          const SizedBox(height: AppSpace.s),
        ],
        footer,
      ],
    );
  }
}

class _UploadProgressIndicator extends StatelessWidget {
  const _UploadProgressIndicator({
    required this.progress,
    required this.isImporting,
    required this.isSyncing,
    required this.pendingCount,
    required this.onRetry,
  });

  final EvidenceUploadProgress? progress;
  final bool isImporting;
  final bool isSyncing;
  final int pendingCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = isImporting || isSyncing || progress?.isActive == true;
    final hasError = !active && pendingCount > 0;
    final completed = progress?.processed ?? 0;
    final total = progress?.total ?? pendingCount;
    final title = isImporting
        ? 'Preparando archivos para subir'
        : active && total > 0
        ? 'Subiendo $completed de $total archivos'
        : active
        ? 'Subiendo evidencias'
        : hasError
        ? '$pendingCount ${pendingCount == 1 ? 'archivo pendiente' : 'archivos pendientes'}'
        : 'Evidencias sincronizadas';
    final subtitle =
        progress?.currentFileName ??
        (isImporting
            ? 'Se están cifrando localmente.'
            : hasError
            ? 'La carga se reintentará cuando haya conexión.'
            : 'La carga continúa en segundo plano.');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(color: scheme.primary.withValues(alpha: .14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s,
          vertical: AppSpace.xs,
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: AppSize.iconM,
              child: active
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    )
                  : SvgPicture.asset(
                      hasError
                          ? 'assets/images/icons/sync.svg'
                          : 'assets/images/icons/check.svg',
                      colorFilter: ColorFilter.mode(
                        scheme.primary,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (active && progress?.fraction != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    LinearProgressIndicator(
                      value: progress!.fraction,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ] else if (isImporting || active) ...[
                    const SizedBox(height: AppSpace.xs),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            if (hasError) ...[
              const SizedBox(width: AppSpace.xs),
              IconButton(
                onPressed: onRetry,
                tooltip: 'Reintentar carga',
                icon: SvgPicture.asset(
                  'assets/images/icons/sync.svg',
                  width: AppSize.iconS,
                  height: AppSize.iconS,
                  colorFilter: ColorFilter.mode(
                    scheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.asset,
    required this.label,
    required this.value,
  });

  final String asset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          asset,
          width: AppSize.iconS,
          height: AppSize.iconS,
          colorFilter: ColorFilter.mode(
            theme.colorScheme.primary,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryPair extends StatelessWidget {
  const _SummaryPair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: AppSpace.xs),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: AppSpace.m),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _SummaryIconButton extends StatelessWidget {
  const _SummaryIconButton({
    required this.asset,
    required this.tooltip,
    required this.onPressed,
  });

  final String asset;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppSize.minTouchTarget),
        maximumSize: const Size.square(AppSize.minTouchTarget),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        side: BorderSide.none,
      ),
      constraints: const BoxConstraints(
        minWidth: AppSize.minTouchTarget,
        minHeight: AppSize.minTouchTarget,
      ),
      icon: Container(
        width: AppSize.iconL + AppSpace.s,
        height: AppSize.iconL + AppSpace.s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: .45),
          ),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          asset,
          width: AppSize.iconS,
          height: AppSize.iconS,
          colorFilter: ColorFilter.mode(
            theme.colorScheme.primary,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.onView,
  });

  final String? label;
  final double? latitude;
  final double? longitude;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = label?.trim().isNotEmpty ?? false ? label!.trim() : '';
    final coordinates = latitude == null && longitude == null
        ? null
        : '${latitude?.toStringAsFixed(6) ?? '—'}, ${longitude?.toStringAsFixed(6) ?? '—'}';
    final value = coordinates == null
        ? reference
        : '${reference == '' ? '' : '·'} $coordinates';

    return Row(
      children: [
        SvgPicture.asset(
          'assets/images/icons/address.svg',
          width: AppSize.iconS,
          height: AppSize.iconS,
          colorFilter: ColorFilter.mode(
            theme.colorScheme.primary,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                TextSpan(
                  text: 'Lugar del hecho: ',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
        if (onView != null) ...[
          const SizedBox(width: AppSpace.xs),
          _SummaryIconButton(
            asset: 'assets/images/icons/punto.svg',
            tooltip: 'Ver ubicación',
            onPressed: onView!,
          ),
        ],
      ],
    );
  }
}

class _PeopleSummary extends StatelessWidget {
  const _PeopleSummary({
    required this.title,
    required this.people,
    this.onView,
  });

  final String title;
  final List<_DisplayPerson> people;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (people.length == 1) {
      final person = people.single;
      final value = person.secondary?.isNotEmpty ?? false
          ? '${person.name} - ${person.secondary}'
          : person.name;
      return _SummaryLine(
        asset: 'assets/images/icons/users.svg',
        label: title,
        value: value,
      );
    }
    return Row(
      children: [
        SvgPicture.asset(
          'assets/images/icons/users.svg',
          width: AppSize.iconS,
          height: AppSize.iconS,
          colorFilter: ColorFilter.mode(
            theme.colorScheme.primary,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(
            '$title: ${people.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        _SummaryIconButton(
          asset: 'assets/images/icons/eye.svg',
          tooltip: 'Ver $title',
          onPressed: onView!,
        ),
      ],
    );
  }
}

class _PeoplePair extends StatelessWidget {
  const _PeoplePair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: AppSpace.xs),
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: AppSpace.s),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _DisplayPerson {
  const _DisplayPerson({required this.name, this.secondary});

  final String name;
  final String? secondary;
}

List<_DisplayPerson> _subjectPeople(RequisitionDetail detail) {
  if (detail.subjectDetails.isNotEmpty) {
    return detail.subjectDetails
        .map(
          (subject) => _DisplayPerson(
            name: subject.name,
            secondary: subject.documentNumber ?? subject.role,
          ),
        )
        .toList(growable: false);
  }
  return detail.subjects
      .map((name) => _DisplayPerson(name: name))
      .toList(growable: false);
}

String _participantRoleLabel(String role) => switch (role.toUpperCase()) {
  'OWNER' => 'Propietario',
  'EDITOR' => 'Editor',
  'VIEWER' => 'Lector',
  _ => role,
};

class _PeopleSheet extends StatelessWidget {
  const _PeopleSheet({required this.title, required this.people});

  final String title;
  final List<_DisplayPerson> people;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.l),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.m,
              AppSpace.s,
              AppSpace.m,
              AppSpace.m,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: people.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SvgPicture.asset(
                          'assets/images/icons/cardEmployee.svg',
                          width: AppSize.iconM,
                          height: AppSize.iconM,
                          colorFilter: ColorFilter.mode(
                            theme.colorScheme.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                        title: Text(person.name),
                        subtitle: person.secondary == null
                            ? null
                            : Text(person.secondary!),
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
}

class _CaseLinkSheet extends StatefulWidget {
  const _CaseLinkSheet({required this.viewModel});

  final RequisitionDetailViewModel viewModel;

  @override
  State<_CaseLinkSheet> createState() => _CaseLinkSheetState();
}

class _CaseLinkSheetState extends State<_CaseLinkSheet> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'detail-case-link-search');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final theme = Theme.of(context);
        final suggestions = viewModel.caseLinkResults
            .map(
              (item) => SearchFieldListItem<EcosystemCaseSummary>(
                item.cud,
                item: item,
                child: ListTile(
                  dense: true,
                  title: Text(item.cud),
                  subtitle: Text('${item.type} - ${item.division}'),
                ),
              ),
            )
            .toList(growable: false);
        return Material(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.l),
          ),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: MediaQuery.sizeOf(context).height * .9,
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.m,
                    AppSpace.s,
                    AppSpace.m,
                    AppSpace.m + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vincular requisa a un CUD',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      Text(
                        'Busca el caso del ecosistema para asociarlo a esta requisa por persona.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpace.m),
                      SearchField<EcosystemCaseSummary>(
                        focusNode: _focusNode,
                        suggestionAction: SuggestionAction.unfocus,
                        searchStyle: theme.textTheme.bodyLarge,
                        suggestionStyle: theme.textTheme.bodyMedium,
                        itemHeight: 76,
                        suggestionsDecoration: SuggestionDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(AppRadius.s),
                        ),
                        onSearchTextChanged: (query) {
                          widget.viewModel.updateCaseLinkQuery(query);
                          return widget.viewModel.caseLinkResults
                              .map(
                                (item) =>
                                    SearchFieldListItem<EcosystemCaseSummary>(
                                      item.cud,
                                      item: item,
                                      child: ListTile(
                                        dense: true,
                                        title: Text(item.cud),
                                        subtitle: Text(
                                          '${item.type} - ${item.division}',
                                        ),
                                      ),
                                    ),
                              )
                              .toList();
                        },
                        suggestions: suggestions,
                        onSuggestionTap: (suggestion) {
                          final item = suggestion.item;
                          if (item == null) return;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _link(item);
                          });
                        },
                        searchInputDecoration: InputDecoration(
                          labelText: 'Buscar por número de CUD',
                          prefixIcon: const AppFormInputIcon(
                            asset: 'assets/images/icons/search.svg',
                          ),
                          errorText: viewModel.caseLinkError,
                        ),
                      ),
                      if (viewModel.caseLinkSearchPhase ==
                          CaseLinkSearchPhase.loading)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpace.s),
                          child: LinearProgressIndicator(),
                        ),
                      if (viewModel.caseLinkSearchPhase ==
                          CaseLinkSearchPhase.empty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s),
                          child: Text(
                            'No se encontraron casos para ese CUD.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      if (viewModel.isLinkingCase)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpace.m),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _link(EcosystemCaseSummary item) async {
    final error = await widget.viewModel.linkCase(item);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(item);
    }
  }
}

class _FinalizeCard extends StatelessWidget {
  const _FinalizeCard({
    required this.isFinalizing,
    required this.canSeal,
    required this.onPressed,
  });

  final bool isFinalizing;
  final bool canSeal;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = FilledButton.icon(
      onPressed: isFinalizing || !canSeal ? null : onPressed,
      icon: isFinalizing
          ? const SizedBox.square(
              dimension: AppSize.iconS,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.lock_outline),
      label: const Text('Sellar'),
    );
    final explanation = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cerrar requisa', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpace.xs),
        Text(
          canSeal
              ? 'El backend verificará el caso y la disponibilidad de las evidencias antes de sellarla.'
              : 'Hay evidencias pendientes de sincronización. Deben estar disponibles antes de sellar la requisa.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: _detailCardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                explanation,
                const SizedBox(height: AppSpace.m),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: explanation),
              const SizedBox(width: AppSpace.s),
              button,
            ],
          );
        },
      ),
    );
  }
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
  const _EvidenceSection({
    required this.summary,
    required this.decryptionService,
    required this.onOpenEvidence,
  });

  final EvidenceCategorySummary summary;
  final EvidenceDecryptionService decryptionService;
  final ValueChanged<RequisitionEvidence> onOpenEvidence;

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
                itemBuilder: (context, index) => _EvidencePreview(
                  evidence: visible[index],
                  decryptionService: decryptionService,
                  onOpen: () => onOpenEvidence(visible[index]),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showAll(BuildContext context) => showAppModalBottomSheet<void>(
    context: context,
    expand: true,
    enableDrag: false,
    builder: (_) => _AllEvidenceSheet(
      title: _categoryTitle(summary.category),
      subtitle: '${summary.items.length} elementos · ${summary.totalSizeLabel}',
      evidence: summary.items,
      decryptionService: decryptionService,
      onOpenEvidence: onOpenEvidence,
    ),
  );
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({
    required this.evidence,
    required this.decryptionService,
    required this.onOpen,
  });
  final RequisitionEvidence evidence;
  final EvidenceDecryptionService decryptionService;
  final VoidCallback onOpen;

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
    final imageFallback = SvgPicture.asset(
      'assets/images/icons/$iconAsset',
      colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
    );
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.m),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.s),
                child: Container(
                  width: AppSize.minTouchTarget,
                  height: AppSize.minTouchTarget,
                  padding: const EdgeInsets.all(AppSpace.m - AppSpace.s),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: evidence.type == RequisitionEvidenceType.image
                      ? evidence.localPath != null
                            ? EvidenceThumbnail(
                                localPath: evidence.localPath,
                                evidenceId: evidence.id,
                                wrappedKey: evidence.wrappedKey,
                                plaintextSha256: evidence.plaintextSha256,
                                plaintextByteLength:
                                    evidence.plaintextByteLength,
                                decryptionService: decryptionService,
                                fallback: imageFallback,
                              )
                            : evidence.contentUrl != null && !evidence.encrypted
                            ? Image.network(
                                evidence.contentUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => imageFallback,
                              )
                            : imageFallback
                      : SvgPicture.asset(
                          'assets/images/icons/$iconAsset',
                          colorFilter: ColorFilter.mode(
                            scheme.primary,
                            BlendMode.srcIn,
                          ),
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
                      evidence.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      '${evidence.sizeLabel} · ${_evidenceStatusLabel(evidence)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpen,
                tooltip: 'Ver evidencia',
                icon: SvgPicture.asset(
                  'assets/images/icons/eye.svg',
                  width: AppSize.iconS,
                  height: AppSize.iconS,
                  colorFilter: ColorFilter.mode(
                    scheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _categoryTitle(EvidenceCategory category) => switch (category) {
  EvidenceCategory.images => 'Imágenes',
  EvidenceCategory.videos => 'Videos',
  EvidenceCategory.files => 'Archivos',
};

String _evidenceStatusLabel(RequisitionEvidence evidence) =>
    switch (evidence.uploadStatus?.toUpperCase()) {
      'AVAILABLE' => 'Sincronizada',
      'PENDING_UPLOAD' => 'Pendiente',
      'UPLOADING' => 'Cargando',
      _ => 'Local',
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
    required this.decryptionService,
    required this.onOpenEvidence,
  });
  final String title;
  final String subtitle;
  final List<RequisitionEvidence> evidence;
  final EvidenceDecryptionService decryptionService;
  final ValueChanged<RequisitionEvidence> onOpenEvidence;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return FractionallySizedBox(
      heightFactor: .88,
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.m,
              AppSpace.s,
              AppSpace.m,
              AppSpace.m + bottomInset,
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
                        itemBuilder: (context, index) => _EvidencePreview(
                          evidence: evidence[index],
                          decryptionService: decryptionService,
                          onOpen: () {
                            Navigator.of(context).pop();
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => onOpenEvidence(evidence[index]),
                            );
                          },
                        ),
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
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
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.m,
              AppSpace.s,
              AppSpace.m,
              AppSpace.l + bottomInset,
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

class _ConfirmDetailFinalizeSheet extends StatelessWidget {
  const _ConfirmDetailFinalizeSheet({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Finalizar y sellar', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpace.s),
              const Text(
                'Esta acción cierra la requisa y no permite agregar nuevas evidencias. ¿Deseas continuar?',
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
                      icon: const Icon(Icons.lock_outline),
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

String _statusLabel(RequisitionStatus status) => switch (status) {
  RequisitionStatus.draft => 'Borrador',
  RequisitionStatus.inProgress => 'En curso',
  RequisitionStatus.finalizing => 'Finalizando',
  RequisitionStatus.finalized => 'Finalizada',
  RequisitionStatus.cancelled => 'Cancelada',
};
