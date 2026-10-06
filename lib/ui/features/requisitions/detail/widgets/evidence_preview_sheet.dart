import 'dart:async';
import 'dart:io';

import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/video_preview_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';

class EvidencePreviewSheet extends StatefulWidget {
  const EvidencePreviewSheet({
    required this.evidence,
    required this.prepare,
    required this.disposePreview,
    this.showHandle = false,
    super.key,
  });

  final RequisitionEvidence evidence;
  final Future<PreparedEvidencePreview> Function() prepare;
  final Future<void> Function(PreparedEvidencePreview preview) disposePreview;
  final bool showHandle;

  @override
  State<EvidencePreviewSheet> createState() => _EvidencePreviewSheetState();
}

class _EvidencePreviewSheetState extends State<EvidencePreviewSheet> {
  late final Future<PreparedEvidencePreview> _previewFuture;
  PreparedEvidencePreview? _preview;

  @override
  void initState() {
    super.initState();
    _previewFuture = widget.prepare();
    _previewFuture.then<void>(
      (preview) {
        if (mounted) {
          _preview = preview;
        } else {
          unawaited(widget.disposePreview(preview));
        }
      },
      onError: (Object _, StackTrace __) {},
    );
  }

  @override
  void dispose() {
    final preview = _preview;
    if (preview != null) unawaited(widget.disposePreview(preview));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(24),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showHandle) const Center(child: _PreviewSheetHandle()),
              _PreviewHeader(
                evidence: widget.evidence,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: AppSpace.s),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  child: ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                    child: FutureBuilder<PreparedEvidencePreview>(
                      future: _previewFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const _PreviewLoading();
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return _PreviewError(
                            message: _previewErrorMessage(snapshot.error),
                          );
                        }
                        _preview ??= snapshot.data;
                        return _PreviewContent(
                          evidence: widget.evidence,
                          preview: snapshot.data!,
                        );
                      },
                    ),
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

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.evidence, required this.onClose});

  final RequisitionEvidence evidence;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: AppSize.minTouchTarget,
          height: AppSize.minTouchTarget,
          padding: const EdgeInsets.all(AppSpace.s + 2),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: SvgPicture.asset(
            'assets/images/icons/${_evidenceAsset(evidence.type)}',
            colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                evidence.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                'Vista previa · ${evidence.sizeLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Cerrar vista previa',
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.evidence, required this.preview});

  final RequisitionEvidence evidence;
  final PreparedEvidencePreview preview;

  @override
  Widget build(BuildContext context) {
    if (evidence.type == RequisitionEvidenceType.image) {
      return InteractiveViewer(
        minScale: .8,
        maxScale: 4,
        child: Center(
          child: Image.file(
            File(preview.path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _PreviewError(
              message: 'No se pudo abrir la imagen.',
            ),
          ),
        ),
      );
    }
    if (evidence.type == RequisitionEvidenceType.video) {
      return VideoPreviewPlayer(path: preview.path);
    }
    if (evidence.type == RequisitionEvidenceType.audio) {
      return _AudioPreview(path: preview.path);
    }
    if (_isPdf(evidence)) {
      return PDFView(filePath: preview.path, enableSwipe: true);
    }
    if (preview.documentText != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.m),
        child: SelectableText(preview.documentText!),
      );
    }
    return const _PreviewError(
      message: 'Este formato todavía no tiene una vista previa disponible.',
    );
  }
}

class _AudioPreview extends StatefulWidget {
  const _AudioPreview({required this.path});

  final String path;

  @override
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
  final AudioPlayer _player = AudioPlayer();
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _player.setFilePath(widget.path).then((_) {});
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _PreviewLoading();
      }
      if (snapshot.hasError) {
        return const _PreviewError(message: 'No se pudo abrir el audio.');
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq_rounded, size: 72),
            const SizedBox(height: AppSpace.m),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return IconButton(
                  tooltip: playing ? 'Pausar' : 'Reproducir',
                  onPressed: playing ? _player.pause : _player.play,
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 56,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpace.s),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) => Text(
                _formatDuration(snapshot.data ?? Duration.zero),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: AppSpace.m),
        Text('Preparando vista previa segura…'),
      ],
    ),
  );
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _PreviewSheetHandle extends StatelessWidget {
  const _PreviewSheetHandle();

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

String _evidenceAsset(RequisitionEvidenceType type) => switch (type) {
  RequisitionEvidenceType.image => 'gallery.svg',
  RequisitionEvidenceType.video => 'video.svg',
  RequisitionEvidenceType.audio => 'microphone.svg',
  RequisitionEvidenceType.document => 'file.svg',
  RequisitionEvidenceType.other => 'paper.svg',
};

bool _isPdf(RequisitionEvidence evidence) =>
    evidence.name.toLowerCase().endsWith('.pdf') ||
    evidence.mimeType == 'application/pdf';

String _previewErrorMessage(Object? error) {
  final message = error?.toString().replaceFirst('Bad state: ', '').trim();
  return message == null || message.isEmpty
      ? 'No se pudo preparar la vista previa.'
      : message;
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
}
