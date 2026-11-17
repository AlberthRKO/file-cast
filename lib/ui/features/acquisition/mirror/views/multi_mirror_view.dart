import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/ui/core/navigation/route_args/multi_mirror_route_args.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/acquisition/mirror/view_models/multi_mirror_view_model.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/interactive_mirror_texture.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_capture_controls.dart';
import 'package:file_cast/ui/features/acquisition/mirror/widgets/mirror_diagnostics_panel.dart';
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
      body: SafeArea(
        child: LayoutBuilder(
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
                        focused:
                            viewModel.focusedSourceId == source.sourceSessionId,
                        showFocusAction: true,
                      );
                    },
                  );
            return Column(
              children: [
                if (sources.length > 1)
                  _MultiMirrorModeBar(
                    viewModel: viewModel,
                    compactHeight: constraints.maxHeight < 480,
                    compactLayout: constraints.maxWidth < 600,
                  ),
                Expanded(child: mirrorContent),
                if (viewModel.message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
                    child: _MessageBanner(viewModel: viewModel),
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
        ),
      ),
    );
  }
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
                  child: Text(
                    source.deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (viewModel.isRecording(source.sourceSessionId))
                  Icon(
                    Icons.fiber_manual_record,
                    color: Theme.of(context).colorScheme.error,
                    size: 16,
                  ),
                if (showFocusAction)
                  IconButton.filledTonal(
                    onPressed: () => viewModel.toggleOverviewControl(
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
                        !showFocusAction ||
                        viewModel.isOverviewControlEnabled(
                          source.sourceSessionId,
                        ),
                    onTouch: (action, pointerId, x, y) => viewModel.sendTouch(
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
            onBack: sourceId == null
                ? null
                : () => viewModel.sendKey(sourceId, 4),
            onHome: sourceId == null
                ? null
                : () => viewModel.sendKey(sourceId, 3),
            onCapture: sourceId == null ? null : viewModel.captureScreenshot,
            onToggleRecording: sourceId == null
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
    required this.compactHeight,
    required this.compactLayout,
  });

  final MultiMirrorViewModel viewModel;
  final bool compactHeight;
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
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _WideModeSelector(viewModel: viewModel),
                  ),
                ),
                if (!compactHeight &&
                    viewModel.layoutMode == MultiMirrorLayoutMode.focused) ...[
                  const SizedBox(height: AppSpace.s),
                  SizedBox(
                    height: AppSize.minTouchTarget,
                    child: sourceSelector,
                  ),
                ],
              ],
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

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.viewModel});

  final MultiMirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final color = viewModel.messageIsError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Text(viewModel.message!, style: TextStyle(color: color)),
    );
  }
}
