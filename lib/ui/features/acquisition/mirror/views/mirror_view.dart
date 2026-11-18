import 'dart:math' as math;

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/ui/core/navigation/route_args/mirror_route_args.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/acquisition/mirror/view_models/mirror_view_model.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/interactive_mirror_texture.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_capture_controls.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_diagnostics_panel.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_evidence_fab.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_evidence_pane.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_status_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class MirrorRoute extends StatelessWidget {
  const MirrorRoute({
    required this.args,
    required this.requisitionId,
    required this.sessionId,
    super.key,
  });
  final MirrorRouteArgs args;
  final String requisitionId;
  final String sessionId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => MirrorViewModel(
      repository: context.read<AcquisitionRepository>(),
      requisitionId: requisitionId,
      sessionId: sessionId,
      textureId: args.textureId,
      videoWidth: args.videoSize.width.round(),
      videoHeight: args.videoSize.height.round(),
    )..load(),
    child: MirrorView(args: args),
  );
}

class MirrorView extends StatelessWidget {
  const MirrorView({required this.args, super.key});
  final MirrorRouteArgs args;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MirrorViewModel>();
    final compactWindow = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      // Interactive sheets handle the keyboard inset; do not resize the
      // mirror/evidence panes underneath while a rename sheet is focused.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Captura del dispositivo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'CUD ${viewModel.detail?.requisition.cud ?? viewModel.requisitionId}',
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
          IconButton(
            onPressed:
                viewModel.isRestarting ||
                    viewModel.isCapturing ||
                    viewModel.recordingPhase != AcquisitionRecordingPhase.idle
                ? null
                : viewModel.restartMirror,
            tooltip: 'Recargar imagen del mirror',
            icon: viewModel.isRestarting
                ? const SizedBox.square(
                    dimension: AppSize.iconM,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SvgPicture.asset(
                    'assets/images/icons/refresh.svg',
                    width: AppSize.iconM,
                    height: AppSize.iconM,
                    colorFilter: ColorFilter.mode(
                      IconTheme.of(context).color ??
                          Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.m),
            child: _ConnectionChip(
              deviceName: compactWindow ? 'Conectado' : args.deviceName,
            ),
          ),
        ],
      ),
      floatingActionButton: viewModel.showEvidence
          ? null
          : MirrorEvidenceFab(
              heroTag: 'mirror-evidence',
              totalCount: viewModel.totalEvidence,
              pendingCount: viewModel.pendingEvidenceCount,
              onPressed: viewModel.toggleEvidence,
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final expanded = constraints.maxWidth >= 840;
            final mirror = _MirrorPane(args: args, viewModel: viewModel);
            final evidence = viewModel.evidencePaneInitialized
                ? MirrorEvidencePane(
                    key: const ValueKey('mirror-evidence-pane'),
                    evidence: viewModel.evidence,
                    totalEvidence: viewModel.totalEvidence,
                    compact: !expanded,
                    onClose: viewModel.hideEvidence,
                    onRename: viewModel.renameEvidence,
                  )
                : null;
            if (expanded) {
              return Padding(
                padding: const EdgeInsets.all(AppSpace.m),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: mirror),
                    if (viewModel.showEvidence)
                      const SizedBox(width: AppSpace.m),
                    if (evidence != null)
                      Offstage(
                        offstage: !viewModel.showEvidence,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 320,
                            maxWidth: 420,
                          ),
                          child: evidence,
                        ),
                      ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s,
                AppSpace.s,
                AppSpace.s,
                0,
              ),
              child: Column(
                children: [
                  Expanded(child: mirror),
                  if (viewModel.showEvidence)
                    const SizedBox(height: AppSpace.s),
                  if (evidence != null)
                    Offstage(
                      offstage: !viewModel.showEvidence,
                      child: SizedBox(
                        height: math.min(200, constraints.maxHeight * .34),
                        child: evidence,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MirrorPane extends StatelessWidget {
  const _MirrorPane({required this.args, required this.viewModel});
  final MirrorRouteArgs args;
  final MirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.s),
    decoration: _cardDecoration(context),
    child: Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
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
                        textureId: viewModel.textureId,
                        videoSize: Size(
                          viewModel.videoWidth > 0
                              ? viewModel.videoWidth.toDouble()
                              : args.videoSize.width,
                          viewModel.videoHeight > 0
                              ? viewModel.videoHeight.toDouble()
                              : args.videoSize.height,
                        ),
                        interactionEnabled: !viewModel.isRestarting,
                        onTouch: viewModel.sendTouch,
                        onScroll: viewModel.sendScroll,
                      ),
                    ),
                  ),
                ),
                if (viewModel.showDiagnostics)
                  Positioned(
                    top: AppSpace.s,
                    right: AppSpace.s,
                    width: math.min(
                      420.0,
                      math.max(0.0, constraints.maxWidth - AppSpace.m),
                    ),
                    height: math.min(260.0, constraints.maxHeight * .55),
                    child: MirrorDiagnosticsPanel(
                      log: viewModel.diagnosticLog,
                      onRefresh: viewModel.refreshDiagnostics,
                      onClose: viewModel.toggleDiagnostics,
                    ),
                  ),
                if (viewModel.message != null ||
                    viewModel.recordingPhase ==
                        AcquisitionRecordingPhase.starting ||
                    viewModel.recordingPhase ==
                        AcquisitionRecordingPhase.saving)
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
                            message:
                                viewModel.message ??
                                (viewModel.recordingPhase ==
                                        AcquisitionRecordingPhase.starting
                                    ? 'Preparando la grabación desde el siguiente frame clave…'
                                    : 'Guardando el video de forma segura…'),
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
        const SizedBox(height: AppSpace.s),
        MirrorCaptureControls(
          recordingPhase: viewModel.recordingPhase,
          recordingDurationLabel: viewModel.recordingDurationLabel,
          isCapturing: viewModel.isCapturing,
          onBack: viewModel.isRestarting ? null : viewModel.sendBack,
          onHome: viewModel.isRestarting ? null : viewModel.sendHome,
          onCapture: viewModel.isRestarting
              ? null
              : viewModel.captureScreenshot,
          onToggleRecording: viewModel.isRestarting
              ? null
              : viewModel.toggleRecording,
        ),
      ],
    ),
  );
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.deviceName});
  final String deviceName;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 220),
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.green.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.circle, size: 8, color: Colors.green),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(
            deviceName,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    ),
  );
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
  color: Theme.of(context).cardColor,
  borderRadius: BorderRadius.circular(AppRadius.l),
  boxShadow: const [
    BoxShadow(color: Color(0x0D000000), blurRadius: 15, offset: Offset(0, 7)),
  ],
);
