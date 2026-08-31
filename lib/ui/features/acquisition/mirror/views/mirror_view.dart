import 'dart:math' as math;

import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/ui/core/navigation/route_args/mirror_route_args.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/acquisition/mirror/view_models/mirror_view_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MirrorViewModel(
        adbClient: context.read<AdbClient>(),
        videoWidth: args.videoSize.width.round(),
        videoHeight: args.videoSize.height.round(),
      ),
      child: MirrorView(
        args: args,
        requisitionId: requisitionId,
        sessionId: sessionId,
      ),
    );
  }
}

class MirrorView extends StatelessWidget {
  const MirrorView({
    required this.args,
    required this.requisitionId,
    required this.sessionId,
    super.key,
  });

  final MirrorRouteArgs args;
  final String requisitionId;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MirrorViewModel>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: context.canPop() ? context.pop : null,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          args.deviceName,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        actions: [
          IconButton(
            tooltip: viewModel.showControls
                ? 'Ocultar controles'
                : 'Mostrar controles',
            onPressed: viewModel.toggleControls,
            icon: Icon(
              viewModel.showControls ? Icons.gamepad : Icons.touch_app,
              color: viewModel.showControls ? Colors.blue : Colors.white,
            ),
          ),
          IconButton(
            tooltip: viewModel.showLogs ? 'Ocultar logs' : 'Mostrar logs',
            onPressed: viewModel.toggleLogs,
            icon: Icon(
              viewModel.showLogs ? Icons.bug_report : Icons.terminal,
              color: viewModel.showLogs ? Colors.orange : Colors.white,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panelWidth = math.min(
              300.0,
              math.max(0.0, constraints.maxWidth - (AppSpace.m * 2)),
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: _MirrorTexture(args: args, viewModel: viewModel),
                ),
                if (viewModel.showControls)
                  Positioned(
                    left: AppSpace.m,
                    bottom: AppSpace.m,
                    width: math.min(240.0, panelWidth),
                    child: _ControlsPanel(viewModel: viewModel),
                  ),
                if (viewModel.showLogs)
                  Positioned(
                    right: AppSpace.m,
                    top: AppSpace.m,
                    width: panelWidth,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.min(
                          240.0,
                          constraints.maxHeight * .45,
                        ),
                      ),
                      child: _LogsPanel(log: viewModel.log),
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

class _MirrorTexture extends StatelessWidget {
  const _MirrorTexture({required this.args, required this.viewModel});

  final MirrorRouteArgs args;
  final MirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        final available = Size(constraints.maxWidth, constraints.maxHeight);
        final deviceAspect = args.videoSize.aspectRatio;
        final availableAspect = available.aspectRatio;
        final renderWidth = deviceAspect > availableAspect
            ? available.width
            : available.height * deviceAspect;
        final renderHeight = deviceAspect > availableAspect
            ? available.width / deviceAspect
            : available.height;
        final renderSize = Size(renderWidth, renderHeight);

        Offset toDevice(Offset position) => Offset(
          (position.dx * args.videoSize.width / renderWidth)
              .clamp(0.0, args.videoSize.width)
              .toDouble(),
          (position.dy * args.videoSize.height / renderHeight)
              .clamp(0.0, args.videoSize.height)
              .toDouble(),
        );

        void sendPointer(int action, PointerEvent event) {
          final devicePosition = toDevice(event.localPosition);
          viewModel.sendTouch(
            action,
            devicePosition.dx.toInt(),
            devicePosition.dy.toInt(),
          );
        }

        return Center(
          child: SizedBox.fromSize(
            size: renderSize,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => sendPointer(0, event),
              onPointerMove: (event) => sendPointer(2, event),
              onPointerUp: (event) => sendPointer(1, event),
              onPointerCancel: (event) => sendPointer(1, event),
              child: Texture(textureId: args.textureId),
            ),
          ),
        );
      },
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({required this.viewModel});

  final MirrorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    Future<void> run(String label, Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label: $error')),
        );
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.85),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          runSpacing: AppSpace.xs,
          children: [
            _ControlButton(
              icon: Icons.arrow_back,
              label: 'Atrás',
              onTap: () => run('Atrás', viewModel.sendBack),
            ),
            _ControlButton(
              icon: Icons.home,
              label: 'Inicio',
              onTap: () => run('Inicio', viewModel.sendHome),
            ),
            _ControlButton(
              icon: Icons.crop_square,
              label: 'Recientes',
              onTap: () => run('Recientes', viewModel.sendAppSwitch),
            ),
            _ControlButton(
              icon: Icons.volume_up,
              label: 'Volumen +',
              onTap: () => run('Volumen +', viewModel.sendVolumeUp),
            ),
            _ControlButton(
              icon: Icons.volume_down,
              label: 'Volumen -',
              onTap: () => run('Volumen -', viewModel.sendVolumeDown),
            ),
            _ControlButton(
              icon: Icons.power_settings_new,
              label: 'Encendido',
              onTap: () => run('Encendido', viewModel.sendPower),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogsPanel extends StatelessWidget {
  const _LogsPanel({required this.log});

  final String log;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.85),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s),
        child: SingleChildScrollView(
          child: SelectableText(
            log.isEmpty ? 'Esperando datos…' : log,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.green.shade300,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(
          width: AppSize.minTouchTarget,
          height: AppSize.minTouchTarget,
        ),
        tooltip: label,
        onPressed: onTap,
        color: Colors.white,
        icon: Icon(icon),
      ),
    );
  }
}
