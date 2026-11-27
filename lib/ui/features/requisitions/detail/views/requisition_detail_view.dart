import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/domain/models/evidence_offline_sync.dart';
import 'package:file_cast/domain/models/evidence_upload_progress.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/connectivity_repository.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/domain/services/audio_playback_service.dart';
import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/domain/services/evidence_image_thumbnail_service.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';
import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/feedback/app_feedback.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_action_button.dart';
import 'package:file_cast/ui/core/widgets/app_form_input_icon.dart';
import 'package:file_cast/ui/core/widgets/app_modal_bottom_sheet.dart';
import 'package:file_cast/ui/core/widgets/evidence_preview_dialog.dart';
import 'package:file_cast/ui/core/widgets/evidence_rename_sheet.dart';
import 'package:file_cast/ui/core/widgets/evidence_sync_badge.dart';
import 'package:file_cast/ui/core/widgets/evidence_thumbnail.dart';
import 'package:file_cast/ui/core/widgets/evidence_video_thumbnail.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:file_cast/ui/features/requisitions/detail/view_models/requisition_detail_view_model.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/case_detail_sheet.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/import_evidence_preview_dialog.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/evidence_information_sheet.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/participant_role_dropdown.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/participants_sheet.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_location_viewer.dart';
import 'package:file_cast/ui/features/requisitions/widgets/case_subjects_sheet.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_case_card.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_person_selection_card.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
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
      connectivity: context.read<ConnectivityRepository>(),
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
  EvidenceCategory? _openEvidenceCategory;

  RequisitionDetailViewModel get viewModel => widget.viewModel;

  RequisitionDetail get detail => widget.detail;

  @override
  void didUpdateWidget(covariant RequisitionDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _openEvidenceCategory = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = viewModel.evidenceCategories;
    final decryptionService = context.read<EvidenceDecryptionService>();
    final scaffold = Scaffold(
      // The rename/anchor sheets manage keyboard insets themselves. Keeping
      // the page behind them at its original height avoids a second resize of
      // the detail layout while the keyboard is opening.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Detalle de requisa'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          _RequisitionDetailActionsMenu(
            canViewCase: detail.requisition.cud?.trim().isNotEmpty ?? false,
            canAddParticipant: viewModel.canManageParticipants,
            canFinalize: viewModel.canFinalize,
            canLinkCase: viewModel.canLinkCase,
            onViewCase: () => _showCaseDetail(context),
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
      body: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Column(
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
                        offlineAvailableCount:
                            viewModel.offlineEvidenceAvailableCount,
                        offlineTotalCount: viewModel.offlineEvidenceTotalCount,
                        pendingCount: viewModel.pendingEvidenceCount,
                        failedCount: viewModel.failedEvidenceCount,
                        onRetry: viewModel.retryPendingEvidence,
                        onCancelUpload: viewModel.cancelPendingEvidenceSync,
                        isCancellingUpload: viewModel.isCancellingUpload,
                        onSyncOffline: viewModel.syncEvidenceForOffline,
                        networkAvailable: !viewModel.isWorkingOffline,
                        pendingEvidence: viewModel.pendingEvidence,
                        onViewPending: () => _showPendingEvidence(context),
                      ),
                      const SizedBox(height: AppSpace.m),
                      _EvidenceTotals(categories: categories),
                      for (final category in categories) ...[
                        const SizedBox(height: AppSpace.m),
                        _EvidenceSection(
                          summary: category,
                          decryptionService: decryptionService,
                          onOpenEvidence: (evidence) =>
                              _showEvidencePreview(context, evidence),
                          onInfoEvidence: (evidence) =>
                              _showEvidenceInformation(context, evidence),
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
                          onShowAll: () => _showEvidenceCategory(
                            category.category,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return PopScope(
      canPop: _openEvidenceCategory == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeEvidenceCategory();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          scaffold,
          if (_openEvidenceCategory != null)
            ModalBarrier(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: .54),
              onDismiss: _closeEvidenceCategory,
              semanticsLabel: 'Cerrar lista de evidencias',
            ),
          for (final category in categories)
            if (_openEvidenceCategory == category.category)
              Positioned.fill(
                key: ValueKey(category.category),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: double.infinity,
                    child: _AllEvidenceSheet(
                      storageKey: category.category.name,
                      title: _categoryLabel(category),
                      subtitle:
                          '${category.items.length} elementos · ${category.totalSizeLabel}',
                      evidence: category.items,
                      decryptionService: decryptionService,
                      onOpenEvidence: (evidence) =>
                          _showEvidencePreview(context, evidence),
                      onInfoEvidence: (evidence) =>
                          _showEvidenceInformation(context, evidence),
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
                      onClose: _closeEvidenceCategory,
                    ),
                  ),
                ),
              ),
          if (viewModel.isSelectingEvidence) ...[
            ModalBarrier(
              dismissible: false,
              color: Theme.of(context).cardColor.withValues(alpha: .24),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.m),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSize.formMaxWidth,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.l),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: AppSize.iconL,
                            height: AppSize.iconL,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: AppSpace.m),
                          Flexible(
                            child: Text(
                              'Preparando archivos seleccionados…',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEvidenceCategory(EvidenceCategory category) {
    if (!mounted) return;
    setState(() => _openEvidenceCategory = category);
  }

  void _closeEvidenceCategory() {
    if (!mounted || _openEvidenceCategory == null) return;
    setState(() => _openEvidenceCategory = null);
  }

  Future<void> _showAcquisitionActions(BuildContext context) =>
      showAppModalBottomSheet<void>(
        context: context,
        enableDrag: false,
        maxWidth: AppSize.formMaxWidth,
        builder: (sheetContext) => _AcquisitionActionSheet(
          showAndroidUsbActions: viewModel.supportsAndroidUsbAcquisition,
          showPhotoLibraryAction: viewModel.supportsPhotoLibraryImport,
          isImporting: viewModel.isImporting || viewModel.isSelectingEvidence,
          onCapture: () => _closeThen(
            context,
            sheetContext,
            () => _openAcquisition(context, transfer: false),
          ),
          onMultiMirror: () => _closeThen(
            context,
            sheetContext,
            () => _openMultiMirror(context),
          ),
          onTransfer: () => _closeThen(
            context,
            sheetContext,
            () => _openAcquisition(context, transfer: true),
          ),
          onImport: () => _closeThen(
            context,
            sheetContext,
            () => _importEvidence(context, EvidencePickerSource.files),
          ),
          onImportMedia: () => _closeThen(
            context,
            sheetContext,
            () => _importEvidence(context, EvidencePickerSource.photoLibrary),
          ),
        ),
      );

  Future<void> _importEvidence(
    BuildContext context,
    EvidencePickerSource source,
  ) async {
    final selected = await viewModel.selectEvidence(
      imagesOnly: false,
      source: source,
    );
    if (!context.mounted) {
      await viewModel.clearSelectedEvidence();
      return;
    }
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
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !context.mounted) {
      await viewModel.clearSelectedEvidence();
      return;
    }

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

  Future<void> _openMultiMirror(BuildContext context) async {
    if (!viewModel.supportsAndroidUsbAcquisition) return;
    final sessionId = await viewModel.ensureAcquisitionSession(
      sourcePlatform: 'ANDROID',
      transport: 'USB_OTG_SCRCPY_MULTI',
    );
    if (!context.mounted || sessionId == null) return;
    context.pushNamed(
      AppRouteName.multiMirrorConnect,
      pathParameters: {
        'requisitionId': detail.requisition.id,
        'sessionId': sessionId,
      },
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

  Future<void> _showSubjects(BuildContext context) {
    final subjects = detail.caseSubjects.isNotEmpty
        ? detail.caseSubjects
        : detail.subjectDetails;
    return showAppModalBottomSheet<void>(
      context: context,
      maxWidth: 560,
      builder: (_) => CaseSubjectsSheet.fromRequisition(
        subjects: subjects,
        fallbackNames: detail.subjects,
      ),
    );
  }

  Future<void> _showParticipants(BuildContext context) =>
      showAppModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        maxWidth: 560,
        builder: (_) => ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final participants =
                viewModel.detail?.participants ?? detail.participants;
            final changingActorIds = viewModel.changingParticipantRoleActorIds;
            return ParticipantsSheet(
              participants: participants,
              participantName: viewModel.participantName,
              currentActorId: viewModel.currentActorId,
              canManageRoles:
                  viewModel.canManageParticipants && changingActorIds.isEmpty,
              changingActorIds: changingActorIds,
              roleErrors: viewModel.participantRoleErrors,
              onChangeRole: (participant, role) async {
                await viewModel.changeParticipantRole(
                  participant: participant,
                  role: role,
                );
              },
            );
          },
        ),
      );

  Future<void> _showCaseDetail(BuildContext context) =>
      showAppModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        maxWidth: AppSize.formMaxWidth,
        builder: (_) => CaseDetailSheet(
          detail: viewModel.detail ?? detail,
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
      'El fiscal investigador fue agregado a la requisa.',
    );
  }

  Future<void> _showLocation(BuildContext context) {
    final location = _detailLocation(detail);
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
  ) => showEvidencePreviewDialog(
    context: context,
    evidence: evidence,
    prepare: () => viewModel.prepareEvidencePreview(evidence),
    disposePreview: viewModel.disposeEvidencePreview,
    audioPlaybackService: context.read<AudioPlaybackService>(),
  );

  Future<void> _showEvidenceInformation(
    BuildContext context,
    RequisitionEvidence evidence,
  ) {
    final sessions =
        viewModel.detail?.sessions ?? const <RequisitionAcquisitionSession>[];
    RequisitionAcquisitionSession? session;
    for (final candidate in sessions) {
      if (candidate.id == evidence.sessionId) {
        session = candidate;
        break;
      }
    }
    return showAppModalBottomSheet<void>(
      context: context,
      maxWidth: AppSize.formMaxWidth,
      builder: (_) =>
          EvidenceInformationSheet(evidence: evidence, session: session),
    );
  }

  Future<void> _showPendingEvidence(BuildContext context) {
    final evidence = viewModel.pendingEvidence;
    if (evidence.isEmpty) return Future<void>.value();

    final decryptionService = context.read<EvidenceDecryptionService>();
    return showAppModalBottomSheet<void>(
      context: context,
      expand: true,
      enableDrag: false,
      builder: (_) => ListenableBuilder(
        listenable: viewModel,
        builder: (_, _) {
          final currentEvidence = viewModel.pendingEvidence;
          final canUploadPending =
              !viewModel.isWorkingOffline &&
              !viewModel.isSyncing &&
              !viewModel.isCancellingUpload &&
              currentEvidence.isNotEmpty;
          final isBusy = viewModel.isSyncing || viewModel.isCancellingUpload;
          return _AllEvidenceSheet(
            title: 'Evidencias pendientes',
            subtitle:
                '${currentEvidence.length} ${currentEvidence.length == 1 ? 'archivo pendiente' : 'archivos pendientes'} · guardadas localmente',
            evidence: currentEvidence,
            emptyMessage: 'No quedan evidencias pendientes de carga.',
            decryptionService: decryptionService,
            onOpenEvidence: (item) => _showEvidencePreview(context, item),
            onInfoEvidence: (item) => _showEvidenceInformation(context, item),
            canDeleteEvidence: viewModel.canDeleteEvidence,
            isDeletingEvidence: viewModel.isDeletingEvidence,
            onDeleteEvidence: (item) => _deleteEvidence(context, item),
            canUploadEvidence: viewModel.canUploadEvidence,
            isUploadingEvidence: viewModel.isUploadingEvidence,
            onUploadEvidence: (item) => _uploadEvidence(context, item),
            onRenameEvidence: (item) => _renameEvidence(context, item),
            onAnchorEvidence: (item) => _anchorEvidence(context, item),
            showSubjectInfo: false,
            onUploadPending: currentEvidence.isEmpty
                ? null
                : viewModel.retryPendingEvidence,
            canUploadPending: canUploadPending,
            pendingUploadLabel: isBusy ? 'Carga en curso' : 'Cargar pendientes',
            pendingUploadDisabledMessage: viewModel.isWorkingOffline
                ? 'Conéctate para cargar las evidencias pendientes.'
                : isBusy
                ? 'La carga de evidencias ya está en curso.'
                : null,
          );
        },
      ),
    );
  }

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
    final result = await showAppModalBottomSheet<Object?>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      maxWidth: AppSize.formMaxWidth,
      builder: (_) => EvidenceRenameSheet(
        currentName: evidence.effectiveName,
        originalName: evidence.name,
        onSave: (name) => viewModel.renameEvidence(evidence, name),
      ),
    );
    if (!context.mounted) return;
    if (result is String) {
      await showAppErrorBottomSheet(context, result);
      return;
    }
    if (result != true) return;
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
        'El CUD no contiene sujetos disponibles para asignar a la evidencia.',
      );
      return;
    }
    final hasAssignedSubject = evidence.linkedSubjects.isNotEmpty;
    final initialPersonId = hasAssignedSubject
        ? evidence.linkedSubjects.first.personId
        : null;
    final result = await showAppModalBottomSheet<Object?>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      maxWidth: AppSize.formMaxWidth,
      builder: (_) => CaseSubjectsSheet.fromRequisition(
        subjects: subjects,
        title: hasAssignedSubject
            ? 'Cambiar sujeto de la evidencia'
            : 'Asignar sujeto a la evidencia',
        subtitle: evidence.effectiveName,
        selectionEnabled: true,
        singleSelection: true,
        initialSelectedPersonIds: {
          ?initialPersonId,
        },
        confirmLabel: hasAssignedSubject ? 'Guardar cambio' : 'Asignar sujeto',
        onConfirm: (personIds) =>
            viewModel.setEvidenceSubject(evidence, personIds.single),
      ),
    );
    if (!context.mounted) return;
    if (result is String) {
      await showAppErrorBottomSheet(context, result);
      return;
    }
    if (result != true) return;
    await showAppSuccessBottomSheet(
      context,
      'Sujeto de la evidencia actualizado.',
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
    viewModel.updateCaseLinkQuery('');
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

enum _RequisitionDetailAction { viewCase, addParticipant, finalize, linkCase }

class _RequisitionDetailActionsMenu extends StatelessWidget {
  const _RequisitionDetailActionsMenu({
    required this.canViewCase,
    required this.canAddParticipant,
    required this.canFinalize,
    required this.canLinkCase,
    required this.onViewCase,
    required this.onAddParticipant,
    required this.onFinalize,
    required this.onLinkCase,
  });

  final bool canViewCase;
  final bool canAddParticipant;
  final bool canFinalize;
  final bool canLinkCase;
  final VoidCallback onViewCase;
  final VoidCallback onAddParticipant;
  final VoidCallback onFinalize;
  final VoidCallback onLinkCase;

  bool get _hasActions =>
      canViewCase || canAddParticipant || canFinalize || canLinkCase;

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
              if (canViewCase)
                DropdownMenuItem<_RequisitionDetailAction>(
                  value: _RequisitionDetailAction.viewCase,
                  child: _DetailActionMenuRow(
                    iconAsset: 'eye.svg',
                    label: 'Ver detalle del caso',
                    color: iconColor,
                  ),
                ),
              if (canAddParticipant)
                DropdownMenuItem<_RequisitionDetailAction>(
                  value: _RequisitionDetailAction.addParticipant,
                  child: _DetailActionMenuRow(
                    iconAsset: 'user_plus.svg',
                    label: 'Agregar fiscal investigador',
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
                case _RequisitionDetailAction.viewCase:
                  onViewCase();
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
            ),
            menuItemStyleData: const MenuItemStyleData(
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
    final location = _detailLocation(detail);
    final locationLabel = _detailLocationLabel(detail);
    final locationLatitude = location?.latitude;
    final locationLongitude = location?.longitude;
    final hasLocation =
        (locationLabel?.isNotEmpty ?? false) ||
        locationLatitude != null ||
        locationLongitude != null;
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
        const SizedBox(height: AppSpace.s),
        if (hasCase && subjects.isNotEmpty && participants.isNotEmpty) ...[
          _PeoplePair(
            left: _PeopleSummary(
              title: subjects.length == 1 ? 'Sujeto' : 'Sujetos',
              people: subjects,
              onView: subjects.length > 1 ? onShowSubjects : null,
            ),
            right: _PeopleSummary(
              title: participants.length == 1
                  ? 'Fiscal investigador'
                  : 'Fiscales investigadores',
              people: participants,
              onView: participants.length > 1 || viewModel.canManageParticipants
                  ? onShowParticipants
                  : null,
            ),
          ),
        ] else if (hasCase && subjects.isNotEmpty) ...[
          _PeopleSummary(
            title: subjects.length == 1 ? 'Sujeto' : 'Sujetos',
            people: subjects,
            onView: subjects.length > 1 ? onShowSubjects : null,
          ),
        ] else if (participants.isNotEmpty) ...[
          _PeopleSummary(
            title: participants.length == 1
                ? 'Fiscal investigador'
                : 'Fiscales investigadores',
            people: participants,
            onView: participants.length > 1 || viewModel.canManageParticipants
                ? onShowParticipants
                : null,
          ),
        ],
        if (hasLocation) ...[
          _LocationSummary(
            label: locationLabel,
            latitude: locationLatitude,
            longitude: locationLongitude,
            onView: location == null ? null : onShowLocation,
          ),
        ],
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
    required this.networkAvailable,
    required this.pendingEvidence,
    required this.onViewPending,
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
  final bool networkAvailable;
  final List<RequisitionEvidence> pendingEvidence;
  final VoidCallback onViewPending;

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
      networkAvailable: networkAvailable,
      pendingEvidence: pendingEvidence,
      onViewPending: onViewPending,
    );

    final offlineAction = _OfflineSyncAction(
      progress: offlineSyncProgress,
      errorMessage: offlineSyncError,
      errors: offlineSyncErrors,
      isSyncing: isOfflineSyncing,
      availableCount: offlineAvailableCount,
      totalCount: offlineTotalCount,
      onPressed: onSyncOffline,
      networkAvailable: networkAvailable,
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
    required this.networkAvailable,
  });

  final EvidenceOfflineSyncProgress? progress;
  final String? errorMessage;
  final List<String> errors;
  final bool isSyncing;
  final int availableCount;
  final int totalCount;
  final VoidCallback onPressed;
  final bool networkAvailable;

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
    final title = !networkAvailable
        ? 'Sin conexión · copia local'
        : isSyncing
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
          onPressed: (allAvailable && !isSyncing) || !networkAvailable
              ? null
              : onPressed,
          foregroundColor: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: .10),
          leadingAsset: 'assets/images/icons/sync.svg',
          isLoading: isSyncing,
          label: !networkAvailable
              ? 'Requiere conexión'
              : allAvailable && !isSyncing
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
    required this.networkAvailable,
    required this.pendingEvidence,
    required this.onViewPending,
  });

  final EvidenceUploadProgress? progress;
  final bool isImporting;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final bool isCancelling;
  final bool networkAvailable;
  final List<RequisitionEvidence> pendingEvidence;
  final VoidCallback onViewPending;

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
    final subtitle = !networkAvailable && hasPending
        ? 'Guardados localmente. La carga se reanudará al recuperar conexión.'
        : isCancelling
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
                  TextButton.icon(
                    onPressed: pendingEvidence.isEmpty ? null : onViewPending,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver todo'),
                  ),
                  if (!active)
                    TextButton.icon(
                      onPressed: isCancelling || !networkAvailable
                          ? null
                          : onRetry,
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
    return InkWell(
      onTap: onPressed,
      child: Container(
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
      final summary = _SummaryLine(
        asset: 'assets/images/icons/users.svg',
        label: title,
        value: value,
      );
      if (onView == null) return summary;
      return Row(
        children: [
          Expanded(child: summary),
          _SummaryIconButton(
            asset: 'assets/images/icons/eye.svg',
            tooltip: 'Ver $title',
            onPressed: onView!,
          ),
        ],
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
  const _DisplayPerson({
    required this.name,
    this.secondary,
  });

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
                                  'Agregar fiscal investigador',
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
                                          ParticipantRoleDropdown(
                                            role: _role,
                                            enabled:
                                                !viewModel.isAddingParticipant,
                                            onChanged: (value) {
                                              setState(() => _role = value);
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
                                                    : 'Agregar fiscal investigador',
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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'detail-case-link-search');
    _controller = TextEditingController(
      text: widget.viewModel.caseLinkQuery,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
      await Future<void>.delayed(Duration.zero);
    }
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await widget.viewModel.searchCaseLinkCandidates();
    if (mounted) {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final theme = Theme.of(context);
        final selectedCase = viewModel.selectedCaseLinkCandidate;
        final maxVisibleSuggestions = MediaQuery.sizeOf(context).height < 480
            ? 2
            : 4;
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
                                alpha: .12,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.m),
                            ),
                            child: SvgPicture.asset(
                              'assets/images/icons/folder.svg',
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
                                  'Vincular requisa a un CUD',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpace.xs),
                                Text(
                                  'Selecciona el caso que corresponde a esta requisa.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: viewModel.isLinkingCase
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.m),
                      RequisitionSectionCard(
                        icon: Icons.search_rounded,
                        title: 'Buscar caso por CUD',
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 420;
                            final canSearch =
                                viewModel.selectedCaseLinkCandidate == null &&
                                viewModel.caseLinkQuery.trim().length >= 4 &&
                                viewModel.caseLinkSearchPhase !=
                                    CaseLinkSearchPhase.loading;
                            final suggestions = viewModel.caseLinkResults
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
                                .toList(growable: false);
                            final field = Expanded(
                              child: SearchField<EcosystemCaseSummary>(
                                controller: _controller,
                                focusNode: _focusNode,
                                suggestionState: Suggestion.hidden,
                                maxSuggestionsInViewPort: maxVisibleSuggestions,
                                itemHeight: 76,
                                suggestions: suggestions,
                                suggestionsDecoration: SuggestionDecoration(
                                  color: theme.cardColor,
                                  elevation: 6,
                                  border: Border.all(
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: .18,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.s,
                                  ),
                                ),
                                onSearchTextChanged: (query) {
                                  widget.viewModel.updateCaseLinkQuery(query);
                                  return const <
                                    SearchFieldListItem<EcosystemCaseSummary>
                                  >[];
                                },
                                onSuggestionTap: (suggestion) {
                                  final item = suggestion.item;
                                  if (item == null) return;
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      widget.viewModel.selectCaseLinkCandidate(
                                        item,
                                      );
                                    }
                                  });
                                },
                                textInputAction: TextInputAction.search,
                                onSubmit: (_) {
                                  if (canSearch) _search();
                                },
                                searchStyle: theme.textTheme.bodyLarge,
                                suggestionStyle: theme.textTheme.bodyMedium,
                                searchInputDecoration: InputDecoration(
                                  labelText: 'Buscar por número de CUD',
                                  prefixIcon: const AppFormInputIcon(
                                    asset: 'assets/images/icons/search.svg',
                                  ),
                                  errorText: viewModel.caseLinkError,
                                ),
                              ),
                            );
                            final searchButton = compact
                                ? IconButton.filledTonal(
                                    tooltip: 'Buscar CUD',
                                    onPressed: canSearch ? _search : null,
                                    icon: const Icon(Icons.search_rounded),
                                  )
                                : FilledButton.icon(
                                    onPressed: canSearch ? _search : null,
                                    icon: const Icon(Icons.search_rounded),
                                    label: const Text('Buscar'),
                                  );
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                field,
                                const SizedBox(width: AppSpace.s),
                                searchButton,
                              ],
                            );
                          },
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _focusNode,
                        builder: (context, _) {
                          if (!_focusNode.hasFocus ||
                              selectedCase != null ||
                              viewModel.caseLinkResults.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final visibleCount =
                              viewModel.caseLinkResults.length >
                                  maxVisibleSuggestions
                              ? maxVisibleSuggestions
                              : viewModel.caseLinkResults.length;
                          return SizedBox(height: visibleCount * 76.0);
                        },
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
                      if (selectedCase != null) ...[
                        const SizedBox(height: AppSpace.m),
                        RequisitionCaseCard(
                          cud: selectedCase.cud,
                          caseType: selectedCase.type,
                          division: selectedCase.division,
                          statusLabel: selectedCase.status,
                          onViewSubjects: () => showAppModalBottomSheet<void>(
                            context: context,
                            maxWidth: 560,
                            builder: (_) => CaseSubjectsSheet.fromEcosystem(
                              subjects: selectedCase.caseSubjects,
                              fallbackNames: selectedCase.subjects,
                            ),
                          ),
                          onRemove: () {
                            _controller.clear();
                            widget.viewModel.updateCaseLinkQuery('');
                          },
                        ),
                        const SizedBox(height: AppSpace.m),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: viewModel.isLinkingCase
                                ? null
                                : () => _link(selectedCase),
                            icon: viewModel.isLinkingCase
                                ? const SizedBox.square(
                                    dimension: AppSize.iconS,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.link_rounded),
                            label: Text(
                              viewModel.isLinkingCase
                                  ? 'Vinculando…'
                                  : 'Vincular al CUD',
                            ),
                          ),
                        ),
                      ],
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
                  _categoryLabel(summary),
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
    required this.onShowAll,
    required this.decryptionService,
    required this.onOpenEvidence,
    required this.onInfoEvidence,
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
  final VoidCallback onShowAll;
  final EvidenceDecryptionService decryptionService;
  final ValueChanged<RequisitionEvidence> onOpenEvidence;
  final ValueChanged<RequisitionEvidence> onInfoEvidence;
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
    final visible = summary.items.take(6).toList();
    final indexById = <String, int>{
      for (var index = 0; index < visible.length; index++)
        visible[index].id: index,
    };
    final title = _categoryLabel(summary);
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
                onPressed: onShowAll,
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
                findChildIndexCallback: (key) {
                  if (key is ValueKey<String>) return indexById[key.value];
                  return null;
                },
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
                  onInfo: () => onInfoEvidence(visible[index]),
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
    this.onInfo,
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
  final VoidCallback? onInfo;
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
                              thumbnailService: context
                                  .read<EvidenceImageThumbnailService>(),
                              fallback: imageFallback,
                            )
                          : evidence.contentUrl != null && !evidence.encrypted
                          ? Image.network(
                              evidence.contentUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => imageFallback,
                            )
                          : imageFallback
                    : evidence.type == RequisitionEvidenceType.video
                    ? EvidenceVideoThumbnail(
                        localPath: evidence.localPath,
                        evidenceId: evidence.id,
                        fileName: evidence.name,
                        wrappedKey: evidence.wrappedKey,
                        plaintextSha256: evidence.plaintextSha256,
                        plaintextByteLength: evidence.plaintextByteLength,
                        decryptionService: decryptionService,
                        thumbnailService: context
                            .read<EvidenceVideoThumbnailService>(),
                        fallback: imageFallback,
                      )
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
                            evidence.localPath?.trim().isNotEmpty ?? false,
                        compact: true,
                      ),
                    ],
                  ),
                  if (showSubjectInfo) ...[
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      evidence.linkedSubjects.isEmpty
                          ? 'Sin sujeto asignado'
                          : '${evidence.linkedSubjects.length == 1 ? 'Sujeto' : 'Sujetos'}: ${evidence.linkedSubjects.map((subject) => subject.name.toUpperCase()).join(', ')}',
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
            if (onInfo != null ||
                onDelete != null ||
                onUpload != null ||
                onRename != null ||
                onAnchor != null ||
                isDeleting ||
                isUploading)
              _EvidenceActionsMenu(
                onInfo: onInfo,
                onUpload: onUpload,
                onDelete: onDelete,
                onRename: onRename,
                onAnchor: onAnchor,
                hasAssignedSubject: evidence.linkedSubjects.isNotEmpty,
                isBusy: isDeleting || isUploading,
              ),
          ],
        ),
      ),
    );
  }
}

enum _EvidenceAction { info, upload, rename, anchor, delete }

class _EvidenceActionsMenu extends StatelessWidget {
  const _EvidenceActionsMenu({
    required this.onInfo,
    required this.onUpload,
    required this.onDelete,
    required this.onRename,
    required this.onAnchor,
    required this.hasAssignedSubject,
    required this.isBusy,
  });

  final VoidCallback? onUpload;
  final VoidCallback? onInfo;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onAnchor;
  final bool hasAssignedSubject;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
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
          if (onInfo != null)
            DropdownMenuItem<_EvidenceAction>(
              value: _EvidenceAction.info,
              child: _EvidenceActionRow(
                icon: Icons.info_outline,
                label: 'Información',
                color: theme.colorScheme.onSurface,
              ),
            ),
          if (onUpload != null && !isBusy)
            DropdownMenuItem<_EvidenceAction>(
              value: _EvidenceAction.upload,
              child: _EvidenceActionRow(
                icon: Icons.cloud_upload_outlined,
                label: 'Cargar',
                color: theme.colorScheme.primary,
              ),
            ),
          if (onRename != null && !isBusy)
            DropdownMenuItem<_EvidenceAction>(
              value: _EvidenceAction.rename,
              child: _EvidenceActionRow(
                icon: Icons.edit_outlined,
                label: 'Cambiar nombre',
                color: theme.colorScheme.onSurface,
              ),
            ),
          if (onAnchor != null && !isBusy)
            DropdownMenuItem<_EvidenceAction>(
              value: _EvidenceAction.anchor,
              child: _EvidenceActionRow(
                icon: hasAssignedSubject
                    ? Icons.person_pin_circle_outlined
                    : Icons.person_add_alt_1_outlined,
                label: hasAssignedSubject ? 'Cambiar sujeto' : 'Asignar sujeto',
                color: theme.colorScheme.onSurface,
              ),
            ),
          if (onDelete != null && !isBusy)
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
            case _EvidenceAction.info:
              onInfo?.call();
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

String _categoryLabel(EvidenceCategorySummary summary) {
  final title = _categoryTitle(summary.category);
  if (summary.pendingCount == 0) return title;
  return '$title (${summary.pendingCount} ${summary.pendingCount == 1 ? 'pendiente' : 'pendientes'})';
}

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
    required this.onInfoEvidence,
    required this.canDeleteEvidence,
    required this.isDeletingEvidence,
    required this.onDeleteEvidence,
    required this.canUploadEvidence,
    required this.isUploadingEvidence,
    required this.onUploadEvidence,
    required this.onRenameEvidence,
    required this.onAnchorEvidence,
    required this.showSubjectInfo,
    this.storageKey,
    this.onUploadPending,
    this.canUploadPending = false,
    this.pendingUploadLabel = 'Cargar pendientes',
    this.pendingUploadDisabledMessage,
    this.emptyMessage,
    this.onClose,
  });
  final String title;
  final String subtitle;
  final List<RequisitionEvidence> evidence;
  final EvidenceDecryptionService decryptionService;
  final ValueChanged<RequisitionEvidence> onOpenEvidence;
  final ValueChanged<RequisitionEvidence> onInfoEvidence;
  final bool Function(RequisitionEvidence) canDeleteEvidence;
  final bool Function(RequisitionEvidence) isDeletingEvidence;
  final ValueChanged<RequisitionEvidence> onDeleteEvidence;
  final bool Function(RequisitionEvidence) canUploadEvidence;
  final bool Function(RequisitionEvidence) isUploadingEvidence;
  final ValueChanged<RequisitionEvidence> onUploadEvidence;
  final ValueChanged<RequisitionEvidence> onRenameEvidence;
  final ValueChanged<RequisitionEvidence> onAnchorEvidence;
  final bool showSubjectInfo;
  final String? storageKey;
  final VoidCallback? onUploadPending;
  final bool canUploadPending;
  final String pendingUploadLabel;
  final String? pendingUploadDisabledMessage;
  final String? emptyMessage;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final indexById = <String, int>{
      for (var index = 0; index < evidence.length; index++)
        evidence[index].id: index,
    };

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
                  onClose: () => _close(context),
                ),
                const SizedBox(height: AppSpace.m),
                Expanded(
                  child: evidence.isEmpty
                      ? Center(
                          child: Text(
                            emptyMessage ?? 'No hay evidencias para mostrar.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 760 ? 2 : 1;
                            return GridView.builder(
                              key: PageStorageKey(
                                'requisition-evidence-${storageKey ?? title}',
                              ),
                              itemCount: evidence.length,
                              findChildIndexCallback: (key) {
                                if (key is ValueKey<String>) {
                                  return indexById[key.value];
                                }
                                return null;
                              },
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
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
                                        _closeAndRun(
                                          context,
                                          () => onDeleteEvidence(
                                            evidence[index],
                                          ),
                                        );
                                      }
                                    : null,
                                onUpload: canUploadEvidence(evidence[index])
                                    ? () {
                                        _closeAndRun(
                                          context,
                                          () => onUploadEvidence(
                                            evidence[index],
                                          ),
                                        );
                                      }
                                    : null,
                                onRename: () => _closeAndRun(
                                  context,
                                  () => onRenameEvidence(evidence[index]),
                                ),
                                onAnchor:
                                    showSubjectInfo &&
                                        evidence[index].isBackendRecord
                                    ? () => _closeAndRun(
                                        context,
                                        () => onAnchorEvidence(
                                          evidence[index],
                                        ),
                                      )
                                    : null,
                                showSubjectInfo: showSubjectInfo,
                                isDeleting: isDeletingEvidence(evidence[index]),
                                isUploading: isUploadingEvidence(
                                  evidence[index],
                                ),
                                onOpen: () => _closeAndRun(
                                  context,
                                  () => onOpenEvidence(evidence[index]),
                                ),
                                onInfo: () => onInfoEvidence(evidence[index]),
                              ),
                            );
                          },
                        ),
                ),
                if (onUploadPending != null) ...[
                  const SizedBox(height: AppSpace.s),
                  if (!canUploadPending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xs),
                      child: Text(
                        pendingUploadDisabledMessage ??
                            'Conéctate para cargar las evidencias pendientes.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canUploadPending
                          ? () => _closeAndRun(
                              context,
                              () => onUploadPending?.call(),
                            )
                          : null,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(pendingUploadLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _close(BuildContext context) {
    final close = onClose;
    if (close != null) {
      close();
    } else {
      context.pop();
    }
  }

  void _closeAndRun(BuildContext context, VoidCallback action) {
    _close(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }
}

class _AcquisitionActionSheet extends StatelessWidget {
  const _AcquisitionActionSheet({
    required this.showAndroidUsbActions,
    required this.showPhotoLibraryAction,
    required this.onCapture,
    required this.onMultiMirror,
    required this.onTransfer,
    required this.onImport,
    required this.onImportMedia,
    required this.isImporting,
  });
  final bool showAndroidUsbActions;
  final bool showPhotoLibraryAction;
  final VoidCallback onCapture;
  final VoidCallback onMultiMirror;
  final VoidCallback onTransfer;
  final VoidCallback onImport;
  final VoidCallback onImportMedia;
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
          title: 'Mirror múltiple',
          subtitle: 'Conecta varios Android mediante un hub USB.',
          asset: 'camera.svg',
          onTap: onMultiMirror,
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
        subtitle: 'Selecciona documentos y archivos desde Archivos.',
        asset: 'upload.svg',
        onTap: isImporting ? null : onImport,
      ),
      if (showPhotoLibraryAction)
        _ActionData(
          title: 'Importar fotos y videos',
          subtitle: 'Selecciona fotos, capturas y videos desde Fotos.',
          asset: 'gallery.svg',
          onTap: isImporting ? null : onImportMedia,
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

RequisitionLocation? _detailLocation(RequisitionDetail detail) {
  final latitude = detail.caseInfo?.factLatitude ?? detail.latitude;
  final longitude = detail.caseInfo?.factLongitude ?? detail.longitude;
  if (latitude == null || longitude == null) return null;
  final location = RequisitionLocation(
    latitude: latitude,
    longitude: longitude,
    label: _detailLocationLabel(detail),
  );
  return location.isValid ? location : null;
}

String? _detailLocationLabel(RequisitionDetail detail) {
  final caseLocation = [
    detail.caseInfo?.factAddress,
    detail.caseInfo?.factZone,
    detail.caseInfo?.factMunicipality,
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
  if (caseLocation.isNotEmpty) return caseLocation;
  return detail.locationLabel?.trim().isNotEmpty ?? false
      ? detail.locationLabel!.trim()
      : null;
}
