import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared action bar for individual and multi-mirror sources.
class MirrorCaptureControls extends StatelessWidget {
  const MirrorCaptureControls({
    required this.recordingPhase,
    required this.recordingDurationLabel,
    required this.isCapturing,
    required this.onBack,
    required this.onHome,
    required this.onCapture,
    required this.onToggleRecording,
    super.key,
  });

  final AcquisitionRecordingPhase recordingPhase;
  final String recordingDurationLabel;
  final bool isCapturing;
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final VoidCallback? onCapture;
  final VoidCallback? onToggleRecording;

  @override
  Widget build(BuildContext context) {
    final recording = recordingPhase == AcquisitionRecordingPhase.recording;
    final starting = recordingPhase == AcquisitionRecordingPhase.starting;
    final saving = recordingPhase == AcquisitionRecordingPhase.saving;
    final captureIcon = isCapturing
        ? const SizedBox.square(
            dimension: AppSize.iconM,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const _SvgActionIcon('assets/images/icons/camera.svg');
    final recordingIcon = starting || saving
        ? const SizedBox.square(
            dimension: AppSize.iconM,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : recording
        ? const Icon(Icons.stop_rounded)
        : const _SvgActionIcon('assets/images/icons/video.svg');
    final recordingStyle = FilledButton.styleFrom(
      backgroundColor: recording ? Theme.of(context).colorScheme.error : null,
      foregroundColor: recording ? Theme.of(context).colorScheme.onError : null,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            IconButton.filledTonal(
              onPressed: onBack,
              tooltip: 'Atrás',
              icon: const _SvgActionIcon(
                'assets/images/icons/arrow_left_icon.svg',
              ),
            ),
            IconButton.filledTonal(
              onPressed: onHome,
              tooltip: 'Inicio',
              icon: const _SvgActionIcon('assets/images/icons/home.svg'),
            ),
            if (compact)
              IconButton.filled(
                onPressed: isCapturing || starting || saving ? null : onCapture,
                tooltip: 'Capturar foto',
                icon: captureIcon,
              )
            else
              FilledButton.icon(
                onPressed: isCapturing || starting || saving ? null : onCapture,
                icon: captureIcon,
                label: const Text('Capturar foto'),
              ),
            if (compact)
              IconButton.filled(
                style: recordingStyle,
                onPressed: starting || saving ? null : onToggleRecording,
                tooltip: recording
                    ? 'Detener grabación · $recordingDurationLabel'
                    : 'Grabar video',
                icon: recordingIcon,
              )
            else
              FilledButton.icon(
                style: recordingStyle,
                onPressed: starting || saving ? null : onToggleRecording,
                icon: recordingIcon,
                label: Text(
                  starting
                      ? 'Preparando…'
                      : saving
                      ? 'Guardando…'
                      : recording
                      ? 'Detener · $recordingDurationLabel'
                      : 'Grabar video',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SvgActionIcon extends StatelessWidget {
  const _SvgActionIcon(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: AppSize.iconM,
    height: AppSize.iconM,
    colorFilter: ColorFilter.mode(
      IconTheme.of(context).color ?? Theme.of(context).colorScheme.onPrimary,
      BlendMode.srcIn,
    ),
  );
}
