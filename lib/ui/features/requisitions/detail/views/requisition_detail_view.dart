import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/domain/models/evidence_offline_sync.dart';
import 'package:file_cast/domain/models/evidence_upload_progress.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
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
import 'package:file_cast/ui/core/widgets/evidence_sync_badge.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:file_cast/ui/features/requisitions/detail/view_models/requisition_detail_view_model.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/evidence_preview_sheet.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/import_evidence_preview_dialog.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_location_viewer.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_person_selection_card.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_section_card.dart';
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
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  viewModel.errorMessage ?? 'Requisa no disponible.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.m),
                FilledButton.icon(
                  onPressed: viewModel.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
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
          _RequisitionDetailActionsMenu(
            canAddParticipant: viewModel.canManageParticipants,
            canFinalize: viewModel.canFinalize,
            canLinkCase: viewModel.canLinkCase,
            onAddParticipant: () => _showParticipantForm(context),
            onFinalize: () => _finalize(context),
            onLinkCase: () => _showCaseLink(context),
          ),
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
              child: RefreshIndicator(
                onRefresh: viewModel.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom:
                        AppSpace.xxl * 2 +
                        MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: [
                    _EvidenceTotals(categories: categories),
                    for (final category in categories) ...[
                      const SizedBox(height: AppSpace.m),
                      _EvidenceSection(
                        summary: category,
                        decryptionService: decryptionService,
                        onOpenEvidence: (evidence) =>
                            _showEvidencePreview(context, evidence),
                        canDeleteEvidence: viewModel.canDeleteEvidence,
                        isDeletingEvidence: viewModel.isDeletingEvidence,
                        onDeleteEvidence: (evidence) =>
                            _deleteEvidence(context, evidence),
                        canUploadEvidence: viewModel.canUploadEvidence,
                        isUploadingEvidence: viewModel.isUploadingEvidence,
                        onUploadEvidence: (evidence) =>
                            _uploadEvidence(context, evidence),
                        onRenameEvidence: (evidence) =>
                            _renameEvidence(context, evidence),
                        onAnchorEvidence: (evidence) =>
                            _anchorEvidence(context, evidence),
                        showSubjectInfo: detail.requisition.cud != null,
                      ),
                    ],
                  ],
                ),
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
          showAndroidUsbActions: viewModel.supportsAndroidUsbAcquisition,
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
    if (!viewModel.supportsAndroidUsbAcquisition) return;
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

  Future<void> _showParticipantForm(BuildContext context) async {
    final added = await showAppModalBottomSheet<bool>(
      context: context,
      enableDrag: false,
      maxWidth: AppSize.formMaxWidth,
      builder: (_) => _ParticipantSheet(viewModel: viewModel),
    );
    if (!context.mounted || added != true) return;
    await showAppSuccessBottomSheet(
      context,
      'El participante fue agregado a la requisa.',
    );
  }

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

  Future<void> _deleteEvidence(
    BuildContext context,
    RequisitionEvidence evidence,
  ) async {
    final confirmed = await showAppModalBottomSheet<bool>(
      context: context,
      maxWidth: 520,
      builder: (sheetContext) => _ConfirmEvidenceDeleteSheet(
        evidence: evidence,
        onCancel: () => Navigator.of(sheetContext).pop(false),
        onConfirm: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await viewModel.deletePendingEvidence(evidence);
    if (!context.mounted) return;
    if (error != null) {
      await showAppErrorBottomSheet(context, error);
      return;
    }
    await showAppSuccessBottomSheet(
      context,
      evidence.isBackendRecord
          ? 'La evidencia pendiente fue eliminada del servidor y del dispositivo.'
          : 'La evidencia pendiente fue eliminada del dispositivo.',
    );
  }

  Future<void> _renameEvidence(
    BuildContext context,
    RequisitionEvidence evidence,
  ) async {
    final name = await showAppModalBottomSheet<String>(
      context: context,
      maxWidth: AppSize.formMaxWidth,
      builder: (_) => _RenameEvidenceSheet(evidence: evidence),
    );
    if (!context.mounted || name == null) return;
    final error = await viewModel.renameEvidence(evidence, name);
    if (!context.mounted) return;
    if (error != null) {
      await showAppErrorBottomSheet(context, error);
      return;
    }
    await showAppSuccessBottomSheet(
      context,
      'Nombre de evidencia actualizado.',
    );
  }

  Future<void> _anchorEvidence(
    BuildContext context,
    RequisitionEvidence evidence,
  ) async {
    final subjectsByPersonId = <int, RequisitionSubjectSummary>{};
    for (final subject in detail.caseSubjects) {
      final personId = subject.personId;
      if (personId != null)
        subjectsByPersonId.putIfAbsent(personId, () => subject);
    }
    final subjects = subjectsByPersonId.values.toList(growable: false);
    if (subjects.isEmpty) {
      await showAppErrorBottomSheet(
        context,
        'El CUD no contiene sujetos con personaId utilizable para anclar.',
      );
      return;
    }
    final selected = await showAppModalBottomSheet<List<int>>(
      context: context,
      maxWidth: AppSize.formMaxWidth,
      builder: (_) => _EvidenceSubjectSheet(
        evidence: evidence,
        subjects: subjects,
      ),
    );
    if (!context.mounted || selected == null) return;
    final error = await viewModel.setEvidenceSubjects(evidence, selected);
    if (!context.mounted) return;
    if (error != null) {
      await showAppErrorBottomSheet(context, error);
      return;
    }
    await showAppSuccessBottomSheet(
      context,
      'Sujetos de la evidencia actualizados.',
    );
  }

  Future<void> _uploadEvidence(
    BuildContext context,
    RequisitionEvidence evidence,
  ) async {
    final error = await viewModel.uploadPendingEvidence(evidence);
    if (!context.mounted) return;
    if (error != null) {
      await showAppErrorBottomSheet(context, error);
      return;
    }
    await showAppSuccessBottomSheet(
      context,
      'La evidencia fue cargada y sincronizada con el servidor.',
    );
  }

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

enum _RequisitionDetailAction { addParticipant, finalize, linkCase }

class _RequisitionDetailActionsMenu extends StatelessWidget {
  const _RequisitionDetailActionsMenu({
    required this.canAddParticipant,
    required this.canFinalize,
    required this.canLinkCase,
    required this.onAddParticipant,
    required this.onFinalize,
    required this.onLinkCase,
  });

  final bool canAddParticipant;
  final bool canFinalize;
  final bool canLinkCase;
  final VoidCallback onAddParticipant;
  final VoidCallback onFinalize;
  final VoidCallback onLinkCase;

  bool get _hasActions => canAddParticipant || canFinalize || canLinkCase;

  @override
  Widget build(BuildContext context) {
    if (!_hasActions) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final iconColor =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth < 232
            ? 220.0
            : 240.0;

        return DropdownButtonHideUnderline(
          child: DropdownButton2<_RequisitionDetailAction>(
            customButton: Tooltip(
              message: 'Acciones de la requisa',
              child: SizedBox.square(
                dimension: AppSize.minTouchTarget,
                child: Center(
                  child: SvgPicture.asset(
                    '${assetImgIcon}ellipsisH.svg',
                    width: AppSize.iconM,
                    colorFilter: ColorFilter.mode(
                      iconColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            items: [
              if (canAddParticipant)
                DropdownMenuItem<_RequisitionDetailAction>(
                  value: _RequisitionDetailAction.addParticipant,
                  child: _DetailActionMenuRow(
                    iconAsset: 'user_plus.svg',
                    label: 'Agregar participante',
                    color: iconColor,
                  ),
                ),
              if (canFinalize)
                DropdownMenuItem<_RequisitionDetailAction>(
                  value: _RequisitionDetailAction.finalize,
                  child: _DetailActionMenuRow(
                    iconAsset: 'lock.svg',
                    label: 'Cerrar requisa',
                    color: theme.colorScheme.error,
                  ),
                ),
              if (canLinkCase)
                DropdownMenuItem<_RequisitionDetailAction>(
                  value: _RequisitionDetailAction.linkCase,
                  child: _DetailActionMenuRow(
                    iconAsset: 'link.svg',
                    label: 'Vincular a un caso',
                    color: iconColor,
                  ),
                ),
            ],
            onChanged: (action) {
              if (action == null) return;
              switch (action) {
                case _RequisitionDetailAction.addParticipant:
                  onAddParticipant();
                case _RequisitionDetailAction.finalize:
                  onFinalize();
                case _RequisitionDetailAction.linkCase:
                  onLinkCase();
              }
            },
            dropdownStyleData: DropdownStyleData(
              maxHeight: 220,
              width: menuWidth,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              useSafeArea: true,
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: AppSize.minTouchTarget,
              padding: EdgeInsets.symmetric(horizontal: AppSpace.m),
            ),
            barrierColor: Colors.transparent,
          ),
        );
      },
    );
  }
}

class _DetailActionMenuRow extends StatelessWidget {
  const _DetailActionMenuRow({
    required this.iconAsset,
    required this.label,
    required this.color,
  });

  final String iconAsset;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          '$assetImgIcon$iconAsset',
          width: AppSize.iconM,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaseHeader extends StatelessWidget {
  const _CaseHeader({
    required this.detail,
    required this.viewModel,
    required this.onShowSubjects,
    required this.onShowParticipants,
    required this.onShowLocation,
  });

  final RequisitionDetail detail;
  final RequisitionDetailViewModel viewModel;
  final VoidCallback onShowSubjects;
  final VoidCallback onShowParticipants;
  final VoidCallback onShowLocation;

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
  });

  final RequisitionDetail detail;
  final RequisitionDetailViewModel viewModel;
  final VoidCallback onShowSubjects;
  final VoidCallback onShowParticipants;
  final VoidCallback onShowLocation;

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
          sessionsLabel: '${detail.sessions.length} sesiones',
          evidenceLabel: viewModel.failedEvidenceCount > 0
              ? 'Evidencias con errores'
              : viewModel.pendingEvidenceCount > 0
              ? 'Evidencias pendientes'
              : 'Evidencias sincronizadas',
          uploadProgress: viewModel.uploadProgress,
          offlineSyncProgress: viewModel.offlineSyncProgress,
          offlineSyncError: viewModel.offlineSyncError,
          offlineSyncErrors: viewModel.offlineSyncErrors,
          isImporting: viewModel.isImporting,
          isSyncing: viewModel.isSyncing,
          isOfflineSyncing: viewModel.isOfflineSyncing,
          offlineAvailableCount: viewModel.offlineEvidenceAvailableCount,
          offlineTotalCount: viewModel.offlineEvidenceTotalCount,
          pendingCount: viewModel.pendingEvidenceCount,
          failedCount: viewModel.failedEvidenceCount,
          onRetry: viewModel.retryPendingEvidence,
          onCancelUpload: viewModel.cancelPendingEvidenceSync,
          isCancellingUpload: viewModel.isCancellingUpload,
          onSyncOffline: viewModel.syncEvidenceForOffline,
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
    required this.sessionsLabel,
    required this.evidenceLabel,
    required this.uploadProgress,
    required this.offlineSyncProgress,
    required this.offlineSyncError,
    required this.offlineSyncErrors,
    required this.isImporting,
    required this.isSyncing,
    required this.isOfflineSyncing,
    required this.offlineAvailableCount,
    required this.offlineTotalCount,
    required this.pendingCount,
    required this.failedCount,
    required this.onRetry,
    required this.onCancelUpload,
    required this.isCancellingUpload,
    required this.onSyncOffline,
  });

  final String sessionsLabel;
  final String evidenceLabel;
  final EvidenceUploadProgress? uploadProgress;
  final EvidenceOfflineSyncProgress? offlineSyncProgress;
  final String? offlineSyncError;
  final List<String> offlineSyncErrors;
  final bool isImporting;
  final bool isSyncing;
  final bool isOfflineSyncing;
  final int offlineAvailableCount;
  final int offlineTotalCount;
  final int pendingCount;
  final int failedCount;
  final VoidCallback onRetry;
  final VoidCallback onCancelUpload;
  final bool isCancellingUpload;
  final VoidCallback onSyncOffline;

  @override
  Widget build(BuildContext context) {
    final allOfflineAvailable =
        offlineTotalCount > 0 &&
        offlineAvailableCount >= offlineTotalCount &&
        !isOfflineSyncing;
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
        if (allOfflineAvailable)
          _SummaryMetric(
            asset: 'assets/images/icons/sync.svg',
            label: '$offlineAvailableCount/$offlineTotalCount offline',
          ),
      ],
    );

    final uploadIndicator = _UploadProgressIndicator(
      progress: uploadProgress,
      isImporting: isImporting,
      isSyncing: isSyncing,
      pendingCount: pendingCount,
      failedCount: failedCount,
      onRetry: onRetry,
      onCancel: onCancelUpload,
      isCancelling: isCancellingUpload,
    );

    final offlineAction = _OfflineSyncAction(
      progress: offlineSyncProgress,
      errorMessage: offlineSyncError,
      errors: offlineSyncErrors,
      isSyncing: isOfflineSyncing,
      availableCount: offlineAvailableCount,
      totalCount: offlineTotalCount,
      onPressed: onSyncOffline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isImporting ||
            isSyncing ||
            (uploadProgress?.isActive ?? false) ||
            pendingCount > 0) ...[
          uploadIndicator,
          const SizedBox(height: AppSpace.s),
        ],
        if (offlineTotalCount > 0 && !allOfflineAvailable) ...[
          offlineAction,
          const SizedBox(height: AppSpace.s),
        ],
        metrics,
      ],
    );
  }
}

class _OfflineSyncAction extends StatelessWidget {
  const _OfflineSyncAction({
    required this.progress,
    required this.errorMessage,
    required this.errors,
    required this.isSyncing,
    required this.availableCount,
    required this.totalCount,
    required this.onPressed,
  });

  final EvidenceOfflineSyncProgress? progress;
  final String? errorMessage;
  final List<String> errors;
  final bool isSyncing;
  final int availableCount;
  final int totalCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allAvailable = totalCount > 0 && availableCount >= totalCount;
    if (allAvailable && !isSyncing) {
      return const SizedBox.shrink();
    }
    final processed = progress?.processed ?? 0;
    final syncTotal = progress?.total ?? totalCount;
    final failedCount = progress?.failed ?? 0;
    final pendingOfflineCount = (totalCount - availableCount).clamp(
      0,
      totalCount,
    );
    final displayedErrors = errors.isNotEmpty
        ? errors
        : errorMessage?.trim().isNotEmpty ?? false
        ? [errorMessage!]
        : const <String>[];
    final hasFailed = failedCount > 0 || displayedErrors.isNotEmpty;
    final globalSummary =
        '$availableCount de $totalCount evidencias disponibles offline'
        '${pendingOfflineCount > 0 ? ' · $pendingOfflineCount ${pendingOfflineCount == 1 ? 'pendiente' : 'pendientes'}' : ''}.';
    final lastAttemptSummary = progress == null || syncTotal <= 0
        ? null
        : 'Último intento: $processed de $syncTotal procesadas · '
              '${progress!.completed} recuperadas · '
              '${progress!.skipped} ya disponibles · '
              '$failedCount con error.';
    final title = isSyncing
        ? progress?.total == null || progress!.total == 0
              ? 'Preparando evidencias offline'
              : 'Sincronizando $processed de $syncTotal'
        : allAvailable
        ? 'Evidencias disponibles offline'
        : hasFailed
        ? 'Sincronización incompleta'
        : 'Sincronizar para uso offline';
    final currentFileName = isSyncing ? progress?.currentFileName : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final button = AppActionButton(
          onPressed: allAvailable && !isSyncing ? null : onPressed,
          foregroundColor: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: .10),
          leadingAsset: 'assets/images/icons/sync.svg',
          isLoading: isSyncing,
          label: allAvailable && !isSyncing
              ? 'Todo disponible offline'
              : hasFailed
              ? 'Reintentar sincronización'
              : 'Sincronizar evidencias',
          maxWidth: 280,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.m,
            vertical: AppSpace.s,
          ),
        );
        final summaryContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            if (currentFileName != null) ...[
              Text(
                currentFileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
            ],
            Text(
              globalSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!isSyncing && hasFailed && lastAttemptSummary != null) ...[
              const SizedBox(height: AppSpace.xxs),
              Text(
                lastAttemptSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (!isSyncing && hasFailed) ...[
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      failedCount > 0
                          ? '$failedCount ${failedCount == 1 ? 'evidencia no pudo recuperarse' : 'evidencias no pudieron recuperarse'}.'
                          : 'No se pudo completar la sincronización.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (displayedErrors.isNotEmpty)
                    TextButton(
                      onPressed: () => _showOfflineErrors(
                        context,
                        displayedErrors,
                      ),
                      child: const Text('Ver detalle'),
                    ),
                ],
              ),
            ],
            if (isSyncing && progress?.fraction != null) ...[
              const SizedBox(height: AppSpace.xs),
              LinearProgressIndicator(
                value: progress!.fraction,
                minHeight: 3,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ],
          ],
        );
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              summaryContent,
              const SizedBox(height: AppSpace.s),
              Align(alignment: Alignment.centerLeft, child: button),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: summaryContent),
            const SizedBox(width: AppSpace.m),
            button,
          ],
        );
      },
    );
  }

  void _showOfflineErrors(BuildContext context, List<String> errors) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final windowSize = MediaQuery.sizeOf(dialogContext);
        final dialogWidth = (windowSize.width - 48).clamp(280.0, 520.0);
        final dialogHeight = (windowSize.height - 220).clamp(160.0, 420.0);
        return AlertDialog(
          title: const Text('Evidencias no recuperadas'),
          content: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: ListView.separated(
              itemCount: errors.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s),
              itemBuilder: (_, index) => Text(
                errors[index],
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

class _UploadProgressIndicator extends StatelessWidget {
  const _UploadProgressIndicator({
    required this.progress,
    required this.isImporting,
    required this.isSyncing,
    required this.pendingCount,
    required this.failedCount,
    required this.onRetry,
    required this.onCancel,
    required this.isCancelling,
  });

  final EvidenceUploadProgress? progress;
  final bool isImporting;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final bool isCancelling;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = isImporting || isSyncing || (progress?.isActive ?? false);
    final isPreparingUpload =
        !isImporting &&
        active &&
        progress?.stage == EvidenceUploadStage.preparing;
    final hasPending = pendingCount > 0;
    final hasError =
        !active &&
        hasPending &&
        (failedCount > 0 ||
            progress?.stage == EvidenceUploadStage.error ||
            (progress?.hasFailures ?? false) ||
            (progress?.errorMessage?.trim().isNotEmpty ?? false));
    final title = isCancelling
        ? 'Pausando sincronización'
        : isImporting
        ? 'Preparando archivos para subir'
        : isPreparingUpload
        ? 'Preparando seguridad · $pendingCount ${pendingCount == 1 ? 'pendiente' : 'pendientes'}'
        : active
        ? 'Subiendo evidencia · $pendingCount ${pendingCount == 1 ? 'pendiente' : 'pendientes'}'
        : hasError
        ? _pendingTitle(pendingCount, failedCount)
        : hasPending
        ? _pendingTitle(pendingCount, failedCount)
        : 'Evidencias sincronizadas';
    final subtitle = isCancelling
        ? 'Los archivos seguirán cifrados y guardados en este dispositivo.'
        : progress?.errorMessage ??
              (isPreparingUpload
                  ? 'Generando accesos cifrados para ${progress?.currentFileName ?? 'la evidencia'}.'
                  : progress?.currentFileName ??
                        (isImporting
                            ? 'Se están cifrando localmente.'
                            : hasError
                            ? 'La carga se detuvo. Puedes reintentarlo.'
                            : hasPending
                            ? 'Guardados localmente. Puedes cargar todos o elegir uno desde su menú.'
                            : 'No hay evidencias pendientes de sincronización.'));

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: AppSize.iconM,
                  child: active || isCancelling
                      ? CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        )
                      : SvgPicture.asset(
                          hasError
                              ? 'assets/images/icons/sync.svg'
                              : hasPending
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (active &&
                          (progress?.processed ?? 0) > 0 &&
                          progress?.fraction != null) ...[
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
              ],
            ),
            if (hasPending && !isImporting) ...[
              const SizedBox(height: AppSpace.xs),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: [
                  if (!active)
                    TextButton.icon(
                      onPressed: isCancelling ? null : onRetry,
                      icon: SvgPicture.asset(
                        'assets/images/icons/sync.svg',
                        width: AppSize.iconS,
                        height: AppSize.iconS,
                        colorFilter: ColorFilter.mode(
                          scheme.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                      label: Text(
                        hasError ? 'Reintentar' : 'Cargar pendientes',
                      ),
                    ),
                  if (active)
                    TextButton.icon(
                      onPressed: isCancelling ? null : onCancel,
                      icon: isCancelling
                          ? const SizedBox.square(
                              dimension: AppSize.iconS,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.pause_circle_outline,
                              color: scheme.error,
                            ),
                      label: const Text('Pausar carga'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _pendingTitle(int pendingCount, int failedCount) {
    if (failedCount <= 0) {
      return '$pendingCount ${pendingCount == 1 ? 'archivo pendiente' : 'archivos pendientes'}';
    }
    if (failedCount >= pendingCount) {
      return '$failedCount ${failedCount == 1 ? 'archivo con error' : 'archivos con error'}';
    }
    final remaining = pendingCount - failedCount;
    return '$failedCount con error · $remaining pendientes';
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
  const _DisplayPerson({required this.name, this.secondary, this.details});

  final String name;
  final String? secondary;
  final String? details;
}

List<_DisplayPerson> _subjectPeople(RequisitionDetail detail) {
  if (detail.subjectDetails.isNotEmpty) {
    return detail.subjectDetails
        .map(
          (subject) {
            final details = <String>[
              if (subject.role != null && subject.documentNumber != null)
                'Rol: ${subject.role}',
              if (subject.personId != null) 'personaId: ${subject.personId}',
              if (subject.caseSubjectId != null)
                'Sujeto del caso: ${subject.caseSubjectId}',
              if (subject.subjectTypeId != null && subject.role == null)
                'Tipo de sujeto: ${subject.subjectTypeId}',
              if (subject.legalSituationId != null)
                'Situación jurídica: ${subject.legalSituationId}',
              if (subject.alias?.isNotEmpty == true) 'Alias: ${subject.alias}',
              if (subject.legalEntityName?.isNotEmpty == true)
                'Entidad: ${subject.legalEntityName}',
              if (subject.identityReserved) 'Identidad reservada',
              if (subject.currentSubjectState?.isNotEmpty == true)
                'Estado: ${subject.currentSubjectState}',
            ];
            return _DisplayPerson(
              name: subject.name,
              secondary: subject.documentNumber ?? subject.role,
              details: details.isEmpty ? null : details.join(' · '),
            );
          },
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
                        subtitle:
                            person.secondary == null && person.details == null
                            ? null
                            : Text(
                                [
                                  if (person.secondary != null)
                                    person.secondary!,
                                  if (person.details != null) person.details!,
                                ].join('\n'),
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

class _ParticipantSheet extends StatefulWidget {
  const _ParticipantSheet({required this.viewModel});

  final RequisitionDetailViewModel viewModel;

  @override
  State<_ParticipantSheet> createState() => _ParticipantSheetState();
}

class _ParticipantSheetState extends State<_ParticipantSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  RequisitionParticipantRole _role = RequisitionParticipantRole.viewer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.viewModel.participantQuery,
    );
    _focusNode = FocusNode(debugLabel: 'detail-participant-search');
  }

  @override
  void dispose() {
    _controller.dispose();
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
        final candidate = viewModel.participantCandidate;
        final canSearch =
            viewModel.canManageParticipants &&
            viewModel.participantQuery.trim().length >= 3 &&
            viewModel.participantSearchPhase != ParticipantSearchPhase.loading;
        final alreadyAdded =
            candidate != null && viewModel.isParticipantAlreadyAdded(candidate);
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
                  maxWidth: AppSize.formMaxWidth,
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
                          Container(
                            width: AppSize.minTouchTarget,
                            height: AppSize.minTouchTarget,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.m),
                            ),
                            child: SvgPicture.asset(
                              'assets/images/icons/cardEmployee.svg',
                              width: AppSize.iconL,
                              height: AppSize.iconL,
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
                                  'Agregar participante',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpace.xs),
                                Text(
                                  'Busca una cuenta institucional y define su acceso.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.m),
                      RequisitionSectionCard(
                        icon: Icons.person_search_rounded,
                        title: 'Usuario institucional',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'CARNET DE IDENTIDAD',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  ' *',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.s),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 420;
                                final field = Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.search,
                                    enabled: !viewModel.isAddingParticipant,
                                    onChanged: viewModel.updateParticipantQuery,
                                    onSubmitted: (_) {
                                      if (canSearch) {
                                        unawaited(
                                          viewModel.searchParticipantUser(),
                                        );
                                      }
                                    },
                                    style: theme.textTheme.bodyLarge,
                                    decoration: InputDecoration(
                                      labelText: 'Buscar por CI',
                                      labelStyle: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: .5),
                                            height: 1,
                                          ),
                                      prefixIcon: const AppFormInputIcon(
                                        asset:
                                            'assets/images/icons/cardEmployee.svg',
                                      ),
                                      errorText:
                                          viewModel.participantSearchPhase ==
                                              ParticipantSearchPhase.error
                                          ? viewModel.participantError
                                          : null,
                                    ),
                                  ),
                                );
                                final button = compact
                                    ? IconButton.filledTonal(
                                        tooltip: 'Buscar usuario',
                                        onPressed: canSearch
                                            ? () => unawaited(
                                                viewModel
                                                    .searchParticipantUser(),
                                              )
                                            : null,
                                        icon: const Icon(Icons.search_rounded),
                                      )
                                    : FilledButton.icon(
                                        onPressed: canSearch
                                            ? () => unawaited(
                                                viewModel
                                                    .searchParticipantUser(),
                                              )
                                            : null,
                                        icon: const Icon(Icons.search_rounded),
                                        label: const Text('Buscar'),
                                      );
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    field,
                                    const SizedBox(width: AppSpace.s),
                                    button,
                                  ],
                                );
                              },
                            ),
                            if (viewModel.participantSearchPhase ==
                                ParticipantSearchPhase.loading)
                              const Padding(
                                padding: EdgeInsets.only(top: AppSpace.s),
                                child: LinearProgressIndicator(),
                              ),
                            if (candidate != null) ...[
                              const SizedBox(height: AppSpace.m),
                              RequisitionPersonSelectionCard(
                                name: candidate.fullName.isNotEmpty
                                    ? candidate.fullName
                                    : candidate.username,
                                ci: candidate.ci,
                                username: candidate.username,
                                onRemove: () {
                                  _controller.clear();
                                  viewModel.updateParticipantQuery('');
                                },
                                footer: alreadyAdded
                                    ? Text(
                                        'Este usuario ya tiene acceso a la requisa.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.error,
                                            ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          DropdownButtonFormField<
                                            RequisitionParticipantRole
                                          >(
                                            value: _role,
                                            style: theme.textTheme.bodyLarge,
                                            dropdownColor: theme.cardColor,
                                            iconEnabledColor:
                                                theme.colorScheme.primary,
                                            decoration: const InputDecoration(
                                              labelText: 'Nivel de acceso',
                                            ),
                                            items: RequisitionParticipantRole
                                                .values
                                                .map(
                                                  (role) => DropdownMenuItem(
                                                    value: role,
                                                    child: Text(role.label),
                                                  ),
                                                )
                                                .toList(growable: false),
                                            onChanged:
                                                viewModel.isAddingParticipant
                                                ? null
                                                : (value) {
                                                    if (value != null) {
                                                      setState(
                                                        () => _role = value,
                                                      );
                                                    }
                                                  },
                                          ),
                                          const SizedBox(height: AppSpace.m),
                                          SizedBox(
                                            width: double.infinity,
                                            child: FilledButton.icon(
                                              onPressed:
                                                  viewModel.isAddingParticipant
                                                  ? null
                                                  : () => unawaited(
                                                      _addParticipant(),
                                                    ),
                                              icon:
                                                  viewModel.isAddingParticipant
                                                  ? const SizedBox.square(
                                                      dimension: AppSize.iconS,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons
                                                          .person_add_alt_1_rounded,
                                                    ),
                                              label: Text(
                                                viewModel.isAddingParticipant
                                                    ? 'Agregando...'
                                                    : 'Agregar ${_role.label.toLowerCase()}',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                            if (viewModel.participantError != null &&
                                viewModel.participantSearchPhase !=
                                    ParticipantSearchPhase.error)
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpace.s),
                                child: Text(
                                  viewModel.participantError!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            const SizedBox(height: AppSpace.s),
                            Text(
                              'Ingresa el CI y presiona Buscar. Puedes reemplazar el usuario con la X antes de agregarlo.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(
                                      alpha: 0.65,
                                    ),
                              ),
                            ),
                          ],
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
    );
  }

  Future<void> _addParticipant() async {
    final error = await widget.viewModel.addParticipant(role: _role);
    if (!mounted) return;
    if (error == null) Navigator.of(context).pop(true);
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
    required this.canDeleteEvidence,
    required this.isDeletingEvidence,
    required this.onDeleteEvidence,
    required this.canUploadEvidence,
    required this.isUploadingEvidence,
    required this.onUploadEvidence,
    required this.onRenameEvidence,
    required this.onAnchorEvidence,
    required this.showSubjectInfo,
  });

  final EvidenceCategorySummary summary;
  final EvidenceDecryptionService decryptionService;
  final ValueChanged<RequisitionEvidence> onOpenEvidence;
  final bool Function(RequisitionEvidence) canDeleteEvidence;
  final bool Function(RequisitionEvidence) isDeletingEvidence;
  final ValueChanged<RequisitionEvidence> onDeleteEvidence;
  final bool Function(RequisitionEvidence) canUploadEvidence;
  final bool Function(RequisitionEvidence) isUploadingEvidence;
  final ValueChanged<RequisitionEvidence> onUploadEvidence;
  final ValueChanged<RequisitionEvidence> onRenameEvidence;
  final ValueChanged<RequisitionEvidence> onAnchorEvidence;
  final bool showSubjectInfo;

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
                  mainAxisExtent: showSubjectInfo ? 88 : 68,
                ),
                itemBuilder: (context, index) => _EvidencePreview(
                  key: ValueKey(visible[index].id),
                  evidence: visible[index],
                  decryptionService: decryptionService,
                  onOpen: () => onOpenEvidence(visible[index]),
                  onDelete: canDeleteEvidence(visible[index])
                      ? () => onDeleteEvidence(visible[index])
                      : null,
                  onUpload: canUploadEvidence(visible[index])
                      ? () => onUploadEvidence(visible[index])
                      : null,
                  onRename: () => onRenameEvidence(visible[index]),
                  onAnchor: showSubjectInfo && visible[index].isBackendRecord
                      ? () => onAnchorEvidence(visible[index])
                      : null,
                  showSubjectInfo: showSubjectInfo,
                  isDeleting: isDeletingEvidence(visible[index]),
                  isUploading: isUploadingEvidence(visible[index]),
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
      canDeleteEvidence: canDeleteEvidence,
      isDeletingEvidence: isDeletingEvidence,
      onDeleteEvidence: onDeleteEvidence,
      canUploadEvidence: canUploadEvidence,
      isUploadingEvidence: isUploadingEvidence,
      onUploadEvidence: onUploadEvidence,
      onRenameEvidence: onRenameEvidence,
      onAnchorEvidence: onAnchorEvidence,
      showSubjectInfo: showSubjectInfo,
    ),
  );
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({
    required this.evidence,
    required this.decryptionService,
    required this.onOpen,
    this.onDelete,
    this.onUpload,
    this.onRename,
    this.onAnchor,
    this.showSubjectInfo = false,
    this.isDeleting = false,
    this.isUploading = false,
    super.key,
  });
  final RequisitionEvidence evidence;
  final EvidenceDecryptionService decryptionService;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onUpload;
  final VoidCallback? onRename;
  final VoidCallback? onAnchor;
  final bool showSubjectInfo;
  final bool isDeleting;
  final bool isUploading;

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
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.s),
              child: Container(
                width: AppSize.minTouchTarget,
                height: AppSize.minTouchTarget,
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
                              plaintextByteLength: evidence.plaintextByteLength,
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
                    : Padding(
                        padding: const EdgeInsets.all(
                          AppSpace.m - AppSpace.s,
                        ),
                        child: SvgPicture.asset(
                          'assets/images/icons/$iconAsset',
                          colorFilter: ColorFilter.mode(
                            scheme.primary,
                            BlendMode.srcIn,
                          ),
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
                    evidence.effectiveName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${evidence.sizeLabel} · ${_evidenceStatusLabel(evidence)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      EvidenceSyncBadge(
                        uploadStatus: evidence.uploadStatus,
                        hasLocalCopy:
                            evidence.localPath?.trim().isNotEmpty == true,
                        compact: true,
                      ),
                    ],
                  ),
                  if (showSubjectInfo) ...[
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      evidence.linkedSubjects.isEmpty
                          ? 'Sin sujetos anclados'
                          : 'Sujetos: ${evidence.linkedSubjects.map((subject) => subject.name).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
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
            if (onDelete != null ||
                onUpload != null ||
                onRename != null ||
                onAnchor != null ||
                isDeleting ||
                isUploading)
              _EvidenceActionsMenu(
                onUpload: onUpload,
                onDelete: onDelete,
                onRename: onRename,
                onAnchor: onAnchor,
                isBusy: isDeleting || isUploading,
              ),
          ],
        ),
      ),
    );
  }
}

enum _EvidenceAction { upload, rename, anchor, delete }

class _EvidenceActionsMenu extends StatelessWidget {
  const _EvidenceActionsMenu({
    required this.onUpload,
    required this.onDelete,
    required this.onRename,
    required this.onAnchor,
    required this.isBusy,
  });

  final VoidCallback? onUpload;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onAnchor;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox.square(
        dimension: AppSize.minTouchTarget,
        child: Center(
          child: SizedBox.square(
            dimension: AppSize.iconM,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface;
    return DropdownButtonHideUnderline(
      child: DropdownButton2<_EvidenceAction>(
        customButton: Tooltip(
          message: 'Acciones de la evidencia',
          child: SizedBox.square(
            dimension: AppSize.minTouchTarget,
            child: Center(
              child: SvgPicture.asset(
                '${assetImgIcon}ellipsisH.svg',
                width: AppSize.iconM,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
        ),
        items: [
          if (onUpload != null)
            DropdownMenuItem<_EvidenceAction>(
              value: _EvidenceAction.upload,
              child: _EvidenceActionRow(
                icon: Icons.cloud_upload_outlined,
                label: 'Cargar',
                color: theme.colorScheme.primary,
              ),
            ),
          if (onRename != null)
            DropdownMenuItem<_EvidenceAction>(
              value: _EvidenceAction.rename,
              child: _EvidenceActionRow(
                icon: Icons.edit_outlined,
                label: 'Cambiar nombre',
                color: theme.colorScheme.onSurface,
              ),
            ),
          if (onAnchor != null)
            DropdownMenuItem<_EvidenceAction>(
              value: _EvidenceAction.anchor,
              child: _EvidenceActionRow(
                icon: Icons.link_outlined,
                label: 'Anclar a sujetos',
                color: theme.colorScheme.onSurface,
              ),
            ),
          if (onDelete != null)
            DropdownMenuItem<_EvidenceAction>(
              value: _EvidenceAction.delete,
              child: _EvidenceActionRow(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar',
                color: theme.colorScheme.error,
              ),
            ),
        ],
        onChanged: (action) {
          switch (action) {
            case _EvidenceAction.upload:
              onUpload?.call();
            case _EvidenceAction.delete:
              onDelete?.call();
            case _EvidenceAction.rename:
              onRename?.call();
            case _EvidenceAction.anchor:
              onAnchor?.call();
            case null:
              return;
          }
        },
        dropdownStyleData: DropdownStyleData(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: .18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.m),
        ),
        barrierColor: Colors.transparent,
      ),
    );
  }
}

class _EvidenceActionRow extends StatelessWidget {
  const _EvidenceActionRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: AppSize.iconM, color: color),
      const SizedBox(width: AppSpace.s),
      Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      ),
    ],
  );
}

String _categoryTitle(EvidenceCategory category) => switch (category) {
  EvidenceCategory.images => 'Imágenes',
  EvidenceCategory.videos => 'Videos',
  EvidenceCategory.files => 'Archivos',
};

String _evidenceStatusLabel(RequisitionEvidence evidence) =>
    switch (evidence.uploadStatus?.toUpperCase()) {
      'AVAILABLE' =>
        evidence.encrypted && evidence.localPath == null
            ? 'En servidor · pendiente offline'
            : 'Sincronizada',
      'PENDING_UPLOAD' => 'Pendiente',
      'UPLOADING' => 'Subiendo',
      'ERROR' => 'Error de subida · reintentar',
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
    required this.canDeleteEvidence,
    required this.isDeletingEvidence,
    required this.onDeleteEvidence,
    required this.canUploadEvidence,
    required this.isUploadingEvidence,
    required this.onUploadEvidence,
    required this.onRenameEvidence,
    required this.onAnchorEvidence,
    required this.showSubjectInfo,
  });
  final String title;
  final String subtitle;
  final List<RequisitionEvidence> evidence;
  final EvidenceDecryptionService decryptionService;
  final ValueChanged<RequisitionEvidence> onOpenEvidence;
  final bool Function(RequisitionEvidence) canDeleteEvidence;
  final bool Function(RequisitionEvidence) isDeletingEvidence;
  final ValueChanged<RequisitionEvidence> onDeleteEvidence;
  final bool Function(RequisitionEvidence) canUploadEvidence;
  final bool Function(RequisitionEvidence) isUploadingEvidence;
  final ValueChanged<RequisitionEvidence> onUploadEvidence;
  final ValueChanged<RequisitionEvidence> onRenameEvidence;
  final ValueChanged<RequisitionEvidence> onAnchorEvidence;
  final bool showSubjectInfo;

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
                          mainAxisExtent: showSubjectInfo ? 88 : 68,
                        ),
                        itemBuilder: (context, index) => _EvidencePreview(
                          key: ValueKey(evidence[index].id),
                          evidence: evidence[index],
                          decryptionService: decryptionService,
                          onDelete: canDeleteEvidence(evidence[index])
                              ? () {
                                  Navigator.of(context).pop();
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => onDeleteEvidence(evidence[index]),
                                  );
                                }
                              : null,
                          onUpload: canUploadEvidence(evidence[index])
                              ? () {
                                  Navigator.of(context).pop();
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => onUploadEvidence(evidence[index]),
                                  );
                                }
                              : null,
                          onRename: () {
                            Navigator.of(context).pop();
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => onRenameEvidence(evidence[index]),
                            );
                          },
                          onAnchor:
                              showSubjectInfo && evidence[index].isBackendRecord
                              ? () {
                                  Navigator.of(context).pop();
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => onAnchorEvidence(evidence[index]),
                                  );
                                }
                              : null,
                          showSubjectInfo: showSubjectInfo,
                          isDeleting: isDeletingEvidence(evidence[index]),
                          isUploading: isUploadingEvidence(evidence[index]),
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

class _RenameEvidenceSheet extends StatefulWidget {
  const _RenameEvidenceSheet({required this.evidence});

  final RequisitionEvidence evidence;

  @override
  State<_RenameEvidenceSheet> createState() => _RenameEvidenceSheetState();
}

class _RenameEvidenceSheetState extends State<_RenameEvidenceSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.evidence.effectiveName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.m,
        AppSpace.m,
        AppSpace.m,
        AppSpace.m + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cambiar nombre', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.s),
          Text(
            'Este cambio solo modifica el nombre visible, no el archivo original.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.m),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Nombre de evidencia'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: AppSpace.s),
              FilledButton(onPressed: _save, child: const Text('Guardar')),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }
}

class _EvidenceSubjectSheet extends StatefulWidget {
  const _EvidenceSubjectSheet({required this.evidence, required this.subjects});

  final RequisitionEvidence evidence;
  final List<RequisitionSubjectSummary> subjects;

  @override
  State<_EvidenceSubjectSheet> createState() => _EvidenceSubjectSheetState();
}

class _EvidenceSubjectSheetState extends State<_EvidenceSubjectSheet> {
  late final Set<int> _selected = {
    for (final subject in widget.evidence.linkedSubjects) subject.personId,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.m,
          AppSpace.m,
          AppSpace.m,
          AppSpace.s,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight.clamp(280.0, 620.0).toDouble(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Anclar evidencia a sujetos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  widget.evidence.effectiveName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.s),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.subjects.length,
                    itemBuilder: (context, index) {
                      final subject = widget.subjects[index];
                      final personId = subject.personId!;
                      return CheckboxListTile(
                        value: _selected.contains(personId),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(personId);
                          } else {
                            _selected.remove(personId);
                          }
                        }),
                        title: Text(subject.name),
                        subtitle: Text(
                          [
                            if (subject.documentNumber != null)
                              'CI ${subject.documentNumber}',
                            if (subject.role != null) subject.role!,
                            'personaId $personId',
                          ].join(' · '),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpace.s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: AppSpace.s),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_selected.toList()),
                      child: const Text('Anclar'),
                    ),
                  ],
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
    required this.showAndroidUsbActions,
    required this.onCapture,
    required this.onTransfer,
    required this.onImport,
    required this.isImporting,
  });
  final bool showAndroidUsbActions;
  final VoidCallback onCapture;
  final VoidCallback onTransfer;
  final VoidCallback onImport;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final actions = <_ActionData>[
      if (showAndroidUsbActions) ...[
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
      ],
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
                    final preferredColumns = constraints.maxWidth >= 840
                        ? 3
                        : constraints.maxWidth >= 600
                        ? 2
                        : 1;
                    final columns = actions.length < preferredColumns
                        ? actions.length
                        : preferredColumns;
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

class _ConfirmEvidenceDeleteSheet extends StatelessWidget {
  const _ConfirmEvidenceDeleteSheet({
    required this.evidence,
    required this.onCancel,
    required this.onConfirm,
  });

  final RequisitionEvidence evidence;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
              Text('Eliminar evidencia', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpace.s),
              Text(
                evidence.isBackendRecord
                    ? 'Se eliminará “${evidence.name}” del servidor y del dispositivo. Esta acción solo aplica a evidencias pendientes de sincronización.'
                    : 'Se eliminará “${evidence.name}” del dispositivo. Esta acción solo aplica a evidencias pendientes de sincronización.',
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
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      icon: SvgPicture.asset(
                        'assets/images/icons/delete.svg',
                        width: AppSize.iconS,
                        height: AppSize.iconS,
                        colorFilter: ColorFilter.mode(
                          scheme.onError,
                          BlendMode.srcIn,
                        ),
                      ),
                      label: const Text('Eliminar'),
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
