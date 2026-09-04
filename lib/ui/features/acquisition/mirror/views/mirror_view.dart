import 'dart:math' as math;

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/ui/core/navigation/route_args/mirror_route_args.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/acquisition/mirror/view_models/mirror_view_model.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/evidence_thumbnail.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.m),
            child: _ConnectionChip(
              deviceName: compactWindow ? 'Conectado' : args.deviceName,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final expanded = constraints.maxWidth >= 840;
            final mirror = _MirrorPane(args: args, viewModel: viewModel);
            final evidence = _EvidencePane(
              viewModel: viewModel,
              compact: !expanded,
            );
            if (expanded) {
              return Padding(
                padding: const EdgeInsets.all(AppSpace.m),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: mirror),
                    const SizedBox(width: AppSpace.m),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 320,
                        maxWidth: 420,
                      ),
                      child: evidence,
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
                  const SizedBox(height: AppSpace.s),
                  SizedBox(
                    height: math.min(190, constraints.maxHeight * .32),
                    child: evidence,
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
                      child: _InteractiveTexture(
                        args: args,
                        viewModel: viewModel,
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
                    child: _DiagnosticsPanel(viewModel: viewModel),
                  ),
                if (viewModel.message != null)
                  Positioned(
                    left: AppSpace.s,
                    right: AppSpace.s,
                    bottom: AppSpace.s,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _MirrorStatusOverlay(
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
        const SizedBox(height: AppSpace.s),
        _CaptureControls(viewModel: viewModel),
      ],
    ),
  );
}

class _MirrorStatusOverlay extends StatelessWidget {
  const _MirrorStatusOverlay({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = isError ? colorScheme.error : Colors.green;
    return Material(
      color: Theme.of(context).cardColor.withValues(alpha: .96),
      elevation: 8,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.m,
          vertical: AppSpace.s,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: accent,
              size: AppSize.iconM,
            ),
            const SizedBox(width: AppSpace.s),
            Flexible(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveTexture extends StatelessWidget {
  const _InteractiveTexture({required this.args, required this.viewModel});
  final MirrorRouteArgs args;
  final MirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0)
        return const SizedBox.shrink();
      final videoSize = Size(
        viewModel.videoWidth > 0
            ? viewModel.videoWidth.toDouble()
            : args.videoSize.width,
        viewModel.videoHeight > 0
            ? viewModel.videoHeight.toDouble()
            : args.videoSize.height,
      );
      final available = Size(constraints.maxWidth, constraints.maxHeight);
      final deviceAspect = videoSize.aspectRatio;
      final renderWidth = deviceAspect > available.aspectRatio
          ? available.width
          : available.height * deviceAspect;
      final renderHeight = deviceAspect > available.aspectRatio
          ? available.width / deviceAspect
          : available.height;

      void send(int action, PointerEvent event) {
        final maxX = math.max(0, videoSize.width.round() - 1);
        final maxY = math.max(0, videoSize.height.round() - 1);
        final x = (event.localPosition.dx * videoSize.width / renderWidth)
            .clamp(0, maxX)
            .round();
        final y = (event.localPosition.dy * videoSize.height / renderHeight)
            .clamp(0, maxY)
            .round();
        viewModel.sendTouch(action, event.pointer, x, y);
      }

      void sendScroll(PointerScrollEvent event) {
        final maxX = math.max(0, videoSize.width.round() - 1);
        final maxY = math.max(0, videoSize.height.round() - 1);
        final x = (event.localPosition.dx * videoSize.width / renderWidth)
            .clamp(0, maxX)
            .round();
        final y = (event.localPosition.dy * videoSize.height / renderHeight)
            .clamp(0, maxY)
            .round();
        viewModel.sendScroll(x, y, event.scrollDelta.dy.round());
      }

      return Center(
        child: SizedBox(
          width: renderWidth,
          height: renderHeight,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => send(0, event),
            onPointerMove: (event) => send(2, event),
            onPointerUp: (event) => send(1, event),
            onPointerCancel: (event) => send(1, event),
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) sendScroll(event);
            },
            child: Texture(textureId: args.textureId),
          ),
        ),
      );
    },
  );
}

class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({required this.viewModel});

  final MirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .88),
    borderRadius: BorderRadius.circular(AppRadius.m),
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: Colors.white70, size: 18),
              const SizedBox(width: AppSpace.xs),
              const Expanded(
                child: Text(
                  'Diagnóstico de control',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                onPressed: viewModel.refreshDiagnostics,
                tooltip: 'Actualizar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
              IconButton(
                onPressed: viewModel.toggleDiagnostics,
                tooltip: 'Cerrar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                viewModel.diagnosticLog.isEmpty
                    ? 'Recopilando datos…'
                    : viewModel.diagnosticLog,
                style: TextStyle(
                  color: Colors.green.shade200,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CaptureControls extends StatelessWidget {
  const _CaptureControls({required this.viewModel});
  final MirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final recording =
        viewModel.recordingPhase == AcquisitionRecordingPhase.recording;
    final saving = viewModel.recordingPhase == AcquisitionRecordingPhase.saving;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      children: [
        IconButton.filledTonal(
          onPressed: viewModel.sendBack,
          tooltip: 'Atrás',
          icon: const Icon(Icons.arrow_back),
        ),
        IconButton.filledTonal(
          onPressed: viewModel.sendHome,
          tooltip: 'Inicio',
          icon: const Icon(Icons.home_outlined),
        ),
        FilledButton.icon(
          onPressed: viewModel.isCapturing ? null : viewModel.captureScreenshot,
          icon: viewModel.isCapturing
              ? const SizedBox.square(
                  dimension: AppSize.iconM,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera_outlined),
          label: const Text('Capturar foto'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: recording
                ? Theme.of(context).colorScheme.error
                : null,
            foregroundColor: recording
                ? Theme.of(context).colorScheme.onError
                : null,
          ),
          onPressed: saving ? null : viewModel.toggleRecording,
          icon: Icon(
            recording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
          ),
          label: Text(
            saving
                ? 'Guardando…'
                : recording
                ? 'Detener · ${viewModel.recordingDurationLabel}'
                : 'Grabar video',
          ),
        ),
      ],
    );
  }
}

class _EvidencePane extends StatelessWidget {
  const _EvidencePane({required this.viewModel, required this.compact});
  final MirrorViewModel viewModel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final evidence = viewModel.recentEvidence;
    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Evidencia registrada (${viewModel.totalEvidence})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const Icon(Icons.verified_user_outlined, size: AppSize.iconM),
            ],
          ),
          const SizedBox(height: AppSpace.s),
          Expanded(
            child: evidence.isEmpty
                ? const Center(child: Text('Las capturas aparecerán aquí.'))
                : compact
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: evidence.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpace.s),
                    itemBuilder: (_, index) => SizedBox(
                      width: 150,
                      child: _EvidenceCard(evidence: evidence[index]),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpace.s,
                          mainAxisSpacing: AppSpace.s,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: evidence.length,
                    itemBuilder: (_, index) =>
                        _EvidenceCard(evidence: evidence[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.evidence});
  final RequisitionEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final path = evidence.localPath;
    final isImage = evidence.type == RequisitionEvidenceType.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
            child: isImage
                ? EvidenceThumbnail(
                    localPath: path,
                    fallback: const Icon(Icons.image_outlined, size: 36),
                  )
                : Icon(
                    evidence.type == RequisitionEvidenceType.video
                        ? Icons.play_circle_outline
                        : Icons.insert_drive_file_outlined,
                    size: 36,
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.s),
              color: Colors.black.withValues(alpha: .68),
              child: Text(
                evidence.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
