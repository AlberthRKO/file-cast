import 'dart:math' as math;

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/domain/services/audio_playback_service.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:file_cast/ui/core/navigation/route_args/multi_mirror_route_args.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/evidence_preview_dialog.dart';
import 'package:file_cast/ui/features/acquisition/mirror/view_models/multi_mirror_view_model.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/interactive_mirror_texture.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_capture_controls.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_diagnostics_panel.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_evidence_fab.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_evidence_pane.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_status_overlay.dart';
import 'package:file_cast/ui/features/acquisition/shared/widgets/acquisition_subject_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class MultiMirrorRoute extends StatelessWidget {
  const MultiMirrorRoute({
    required this.args,
    required this.requisitionId,
    required this.sessionId,
    super.key,
  });

  final MultiMirrorRouteArgs args;
  final String requisitionId;
  final String sessionId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => MultiMirrorViewModel(
      repository: context.read<AcquisitionRepository>(),
      previewService: context.read<EvidencePreviewService>(),
      requisitionId: requisitionId,
      sessionId: sessionId,
      sources: args.sources,
    )..load(),
    child: const MultiMirrorView(),
  );
}

class MultiMirrorView extends StatelessWidget {
  const MultiMirrorView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MultiMirrorViewModel>();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Captura múltiple (${viewModel.sources.length})'),
            Text(
              'Requisa ${viewModel.requisitionId}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: viewModel.toggleDiagnostics,
            tooltip: viewModel.showDiagnostics
                ? 'Ocultar diagnóstico'
                : 'Mostrar diagnóstico',
            icon: Icon(
              viewModel.showDiagnostics
                  ? Icons.bug_report
                  : Icons.bug_report_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton: viewModel.showEvidence
          ? null
          : MirrorEvidenceFab(
              heroTag: 'multi-mirror-evidence',
              totalCount: viewModel.totalEvidence,
              pendingCount: viewModel.pendingEvidenceCount,
              onPressed: viewModel.toggleEvidence,
            ),
      body: SafeArea(
        child: _MultiMirrorBody(viewModel: viewModel),
      ),
    );
  }
}

class _MultiMirrorBody extends StatelessWidget {
  const _MultiMirrorBody({required this.viewModel});

  final MultiMirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 840;
      final workspace = _MultiMirrorWorkspace(viewModel: viewModel);
      final focusedName = viewModel.focusedSource?.deviceName;
      final evidence = viewModel.evidencePaneInitialized
          ? MirrorEvidencePane(
              key: const ValueKey('multi-mirror-evidence-pane'),
              evidence: viewModel.evidence,
              totalEvidence: viewModel.totalEvidence,
              compact: !wide,
              visible: viewModel.showEvidence,
              contextLabel: focusedName == null
                  ? null
                  : 'Captura activa: $focusedName',
              onClose: viewModel.hideEvidence,
              onRename: viewModel.renameEvidence,
              onOpenEvidence: (evidence) => showEvidencePreviewDialog(
                context: context,
                evidence: evidence,
                prepare: () => viewModel.prepareEvidencePreview(evidence),
                disposePreview: viewModel.disposeEvidencePreview,
                audioPlaybackService: context.read<AudioPlaybackService>(),
              ),
            )
          : null;
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: workspace),
            if (viewModel.showEvidence) const SizedBox(width: AppSpace.s),
            if (evidence != null)
              Offstage(
                offstage: !viewModel.showEvidence,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    AppSpace.m,
                    AppSpace.m,
                    AppSpace.m,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 320,
                      maxWidth: 420,
                    ),
                    child: evidence,
                  ),
                ),
              ),
          ],
        );
      }
      return Column(
        children: [
          Expanded(child: workspace),
          if (viewModel.showEvidence) const SizedBox(height: AppSpace.s),
          if (evidence != null)
            Offstage(
              offstage: !viewModel.showEvidence,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s,
                  0,
                  AppSpace.s,
                  AppSpace.s,
                ),
                child: SizedBox(
                  height: math.min(200, constraints.maxHeight * .34),
                  child: evidence,
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _MultiMirrorWorkspace extends StatelessWidget {
  const _MultiMirrorWorkspace({required this.viewModel});

  final MultiMirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1200
          ? 3
          : constraints.maxWidth >= 600
          ? 2
          : 1;
      final sources = viewModel.sources;
      final focusedSource = viewModel.focusedSource;
      final showingOverview =
          sources.length > 1 &&
          viewModel.layoutMode == MultiMirrorLayoutMode.overview;
      final mirrorContent = sources.isEmpty
          ? const _EmptyMultiMirrorState()
          : !showingOverview
          ? Padding(
              padding: const EdgeInsets.all(AppSpace.m),
              child: _MultiMirrorCard(
                source: focusedSource ?? sources.first,
                viewModel: viewModel,
                focused: true,
                showFocusAction: false,
              ),
            )
          : GridView.builder(
              physics: viewModel.overviewControlSourceId == null
                  ? null
                  : const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.m),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpace.m,
                mainAxisSpacing: AppSpace.m,
                childAspectRatio: columns == 1 ? .82 : 1.05,
              ),
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                return _MultiMirrorCard(
                  source: source,
                  viewModel: viewModel,
                  focused: viewModel.focusedSourceId == source.sourceSessionId,
                  showFocusAction: true,
                );
              },
            );
      return Column(
        children: [
          if (sources.length > 1)
            _MultiMirrorModeBar(
              viewModel: viewModel,
              compactLayout: constraints.maxWidth < 600,
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: mirrorContent),
                if (viewModel.message != null &&
                    viewModel.messageSourceId == null)
                  Positioned(
                    left: AppSpace.m,
                    right: AppSpace.m,
                    bottom: AppSpace.s,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: MirrorStatusOverlay(
                            message: viewModel.message!,
                            isError: viewModel.messageIsError,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _MultiMirrorControls(viewModel: viewModel),
          if (viewModel.showDiagnostics)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.m,
                0,
                AppSpace.m,
                AppSpace.m,
              ),
              child: SizedBox(
                height: constraints.maxHeight < 480 ? 120 : 180,
                child: MirrorDiagnosticsPanel(
                  log: viewModel.diagnosticLog,
                  onRefresh: viewModel.refreshDiagnostics,
                  onClose: viewModel.toggleDiagnostics,
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _EmptyMultiMirrorState extends StatelessWidget {
  const _EmptyMultiMirrorState();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.usb_off_outlined,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpace.m),
                Text(
                  'No quedan mirrors conectados',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Vuelve a la pantalla anterior para detectar y seleccionar los objetivos ADB del hub.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _MultiMirrorCard extends StatelessWidget {
  const _MultiMirrorCard({
    required this.source,
    required this.viewModel,
    required this.focused,
    required this.showFocusAction,
  });

  final MultiMirrorSourceArgs source;
  final MultiMirrorViewModel viewModel;
  final bool focused;
  final bool showFocusAction;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.l),
      side: focused
          ? BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            )
          : BorderSide.none,
    ),
    child: InkWell(
      onTap: () => viewModel.focus(source.sourceSessionId),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s,
              AppSpace.s,
              AppSpace.s,
              AppSpace.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.green),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (viewModel.selectedSubject(source.sourceSessionId)
                          case final subject?)
                        Text(
                          subject.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  ),
                ),
                if (viewModel.isRecording(source.sourceSessionId))
                  Icon(
                    Icons.fiber_manual_record,
                    color: Theme.of(context).colorScheme.error,
                    size: 16,
                  ),
                IconButton(
                  onPressed:
                      viewModel.isRestarting(source.sourceSessionId) ||
                          viewModel.isCapturing ||
                          viewModel.recordingPhase(source.sourceSessionId) !=
                              AcquisitionRecordingPhase.idle
                      ? null
                      : () => viewModel.restartSource(source.sourceSessionId),
                  tooltip: 'Recargar imagen de ${source.deviceName}',
                  icon: viewModel.isRestarting(source.sourceSessionId)
                      ? const SizedBox.square(
                          dimension: AppSize.iconM,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const _MirrorSvgIcon(
                          'assets/images/icons/refresh.svg',
                          size: 20,
                        ),
                ),
                IconButton(
                  onPressed:
                      viewModel.canChangeSubject(
                        source.sourceSessionId,
                      )
                      ? () => showAcquisitionSubjectPicker(
                          context: context,
                          subjects: viewModel.availableSubjects,
                          selectedPersonId: viewModel.selectedSubjectPersonId(
                            source.sourceSessionId,
                          ),
                          onSelected: (personId) => viewModel.selectSubject(
                            source.sourceSessionId,
                            personId,
                          ),
                          deviceName: source.deviceName,
                        )
                      : null,
                  tooltip: viewModel.availableSubjects.isEmpty
                      ? 'La requisa no tiene sujetos de un CUD para vincular'
                      : viewModel.selectedSubject(source.sourceSessionId) ==
                            null
                      ? 'Vincular dispositivo a un sujeto'
                      : 'Cambiar sujeto vinculado',
                  icon: Icon(
                    viewModel.selectedSubject(source.sourceSessionId) == null
                        ? Icons.person_add_alt_1_outlined
                        : Icons.person_pin_circle_rounded,
                  ),
                ),
                if (showFocusAction)
                  IconButton.filledTonal(
                    onPressed: viewModel.isRestarting(source.sourceSessionId)
                        ? null
                        : () => viewModel.toggleOverviewControl(
                            source.sourceSessionId,
                          ),
                    tooltip:
                        viewModel.isOverviewControlEnabled(
                          source.sourceSessionId,
                        )
                        ? 'Liberar control y desplazar la cuadrícula'
                        : 'Controlar este mirror',
                    isSelected: viewModel.isOverviewControlEnabled(
                      source.sourceSessionId,
                    ),
                    selectedIcon: const _MirrorSvgIcon(
                      'assets/images/icons/finger.svg',
                      size: 19,
                    ),
                    icon: const _MirrorSvgIcon(
                      'assets/images/icons/finger.svg',
                      size: 19,
                    ),
                  ),
                if (showFocusAction)
                  IconButton(
                    onPressed: () => viewModel.showFocused(
                      source.sourceSessionId,
                    ),
                    tooltip: 'Ver este mirror en grande',
                    icon: const _MirrorSvgIcon(
                      'assets/images/icons/expand.svg',
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xs),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        child: InteractiveMirrorTexture(
                          textureId: source.textureId,
                          videoSize: source.videoSize,
                          interactionEnabled:
                              !viewModel.isRestarting(
                                source.sourceSessionId,
                              ) &&
                              (!showFocusAction ||
                                  viewModel.isOverviewControlEnabled(
                                    source.sourceSessionId,
                                  )),
                          onTouch: (action, pointerId, x, y) =>
                              viewModel.sendTouch(
                                source.sourceSessionId,
                                action,
                                pointerId,
                                x,
                                y,
                              ),
                          onScroll: (x, y, deltaY) => viewModel.sendScroll(
                            source.sourceSessionId,
                            x,
                            y,
                            deltaY,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (viewModel.message != null &&
                      viewModel.messageSourceId == source.sourceSessionId)
                    Positioned(
                      left: AppSpace.s,
                      right: AppSpace.s,
                      bottom: AppSpace.s,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: MirrorStatusOverlay(
                              message: viewModel.message!,
                              isError: viewModel.messageIsError,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MultiMirrorControls extends StatelessWidget {
  const _MultiMirrorControls({required this.viewModel});

  final MultiMirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final sourceId = viewModel.focusedSourceId;
    final focusedSource = viewModel.focusedSource;
    final controlActive =
        viewModel.layoutMode == MultiMirrorLayoutMode.focused ||
        (sourceId != null && viewModel.isOverviewControlEnabled(sourceId));
    return Padding(
      padding: const EdgeInsets.all(AppSpace.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (focusedSource != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _MirrorSvgIcon(
                  'assets/images/icons/finger.svg',
                  size: 18,
                ),
                const SizedBox(width: AppSpace.xs),
                Flexible(
                  child: Text(
                    '${controlActive ? 'Controlando' : 'Seleccionado'}: ${focusedSource.deviceName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s),
          ],
          MirrorCaptureControls(
            recordingPhase: sourceId == null
                ? AcquisitionRecordingPhase.idle
                : viewModel.recordingPhase(sourceId),
            recordingDurationLabel: sourceId == null
                ? '00:00'
                : viewModel.recordingDurationLabel(sourceId),
            isCapturing: viewModel.isCapturing,
            onBack: sourceId == null || viewModel.isRestarting(sourceId)
                ? null
                : () => viewModel.sendKey(sourceId, 4),
            onHome: sourceId == null || viewModel.isRestarting(sourceId)
                ? null
                : () => viewModel.sendKey(sourceId, 3),
            onCapture: sourceId == null || viewModel.isRestarting(sourceId)
                ? null
                : viewModel.captureScreenshot,
            onToggleRecording:
                sourceId == null || viewModel.isRestarting(sourceId)
                ? null
                : viewModel.toggleRecording,
          ),
        ],
      ),
    );
  }
}

class _MultiMirrorModeBar extends StatelessWidget {
  const _MultiMirrorModeBar({
    required this.viewModel,
    required this.compactLayout,
  });

  final MultiMirrorViewModel viewModel;
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    final sourceSelector = _MirrorSourceSelector(
      viewModel: viewModel,
      compact: compactLayout,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.m,
        AppSpace.s,
        AppSpace.m,
        0,
      ),
      child: compactLayout
          ? SizedBox(
              height: AppSize.minTouchTarget,
              child: Row(
                children: [
                  _CompactModeButton(
                    selected:
                        viewModel.layoutMode == MultiMirrorLayoutMode.overview,
                    asset: 'assets/images/icons/dash.svg',
                    tooltip: 'Ver todos los mirrors',
                    onPressed: viewModel.showOverview,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  _CompactModeButton(
                    selected:
                        viewModel.layoutMode == MultiMirrorLayoutMode.focused,
                    asset: 'assets/images/icons/expand.svg',
                    tooltip: 'Ver un mirror enfocado',
                    onPressed: () => viewModel.setLayoutMode(
                      MultiMirrorLayoutMode.focused,
                    ),
                  ),
                  if (viewModel.layoutMode ==
                      MultiMirrorLayoutMode.overview) ...[
                    const SizedBox(width: AppSpace.s),
                    Expanded(
                      child: Text(
                        '${viewModel.sources.length} mirrors',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                  if (viewModel.layoutMode ==
                      MultiMirrorLayoutMode.focused) ...[
                    const SizedBox(width: AppSpace.s),
                    Expanded(child: sourceSelector),
                  ],
                ],
              ),
            )
          : SizedBox(
              height: 56,
              child: Row(
                children: [
                  SizedBox(
                    width: 400,
                    child: _WideModeSelector(viewModel: viewModel),
                  ),
                  const SizedBox(width: AppSpace.m),
                  if (viewModel.layoutMode == MultiMirrorLayoutMode.focused)
                    Expanded(
                      child: SizedBox(
                        height: AppSize.minTouchTarget,
                        child: sourceSelector,
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        '${viewModel.sources.length} mirrors activos',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _WideModeSelector extends StatelessWidget {
  const _WideModeSelector({required this.viewModel});

  final MultiMirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.l),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: _ModeOption(
              selected: viewModel.layoutMode == MultiMirrorLayoutMode.overview,
              asset: 'assets/images/icons/dash.svg',
              label: 'Simultáneo',
              onPressed: viewModel.showOverview,
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: _ModeOption(
              selected: viewModel.layoutMode == MultiMirrorLayoutMode.focused,
              asset: 'assets/images/icons/expand.svg',
              label: 'Enfocado',
              onPressed: () => viewModel.setLayoutMode(
                MultiMirrorLayoutMode.focused,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.selected,
    required this.asset,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final String asset;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;
    return Material(
      color: selected ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.minTouchTarget),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MirrorSvgIcon(asset, size: 19, color: foreground),
              const SizedBox(width: AppSpace.s),
              Text(label, style: TextStyle(color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactModeButton extends StatelessWidget {
  const _CompactModeButton({
    required this.selected,
    required this.asset,
    required this.tooltip,
    required this.onPressed,
  });

  final bool selected;
  final String asset;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    isSelected: selected,
    onPressed: onPressed,
    tooltip: tooltip,
    selectedIcon: _MirrorSvgIcon(asset, size: 19),
    icon: _MirrorSvgIcon(asset, size: 19),
  );
}

class _MirrorSourceSelector extends StatelessWidget {
  const _MirrorSourceSelector({required this.viewModel, required this.compact});

  final MultiMirrorViewModel viewModel;
  final bool compact;

  @override
  Widget build(BuildContext context) => ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: viewModel.sources.length,
    separatorBuilder: (context, index) => const SizedBox(width: AppSpace.xs),
    itemBuilder: (context, index) {
      final source = viewModel.sources[index];
      return _MirrorSourceButton(
        source: source,
        selected: viewModel.focusedSourceId == source.sourceSessionId,
        compact: compact,
        onPressed: () => viewModel.showFocused(source.sourceSessionId),
      );
    },
  );
}

class _MirrorSourceButton extends StatelessWidget {
  const _MirrorSourceButton({
    required this.source,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final MultiMirrorSourceArgs source;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpace.s : AppSpace.m,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MirrorSvgIcon(
                'assets/images/icons/phone.svg',
                size: 17,
                color: foreground,
              ),
              const SizedBox(width: AppSpace.xs),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 104 : 180),
                child: Text(
                  source.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MirrorSvgIcon extends StatelessWidget {
  const _MirrorSvgIcon(
    this.asset, {
    this.size = AppSize.iconM,
    this.color,
  });

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ??
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
  );
}
