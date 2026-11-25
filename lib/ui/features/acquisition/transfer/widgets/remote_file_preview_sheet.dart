import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/domain/services/audio_playback_service.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/audio_preview_player.dart';
import 'package:file_cast/ui/core/widgets/document_preview_content.dart';
import 'package:file_cast/ui/core/widgets/office_document_preview.dart';
import 'package:file_cast/ui/core/widgets/video_preview_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RemoteFilePreviewSheet extends StatefulWidget {
  const RemoteFilePreviewSheet({
    required this.file,
    required this.preview,
    required this.sizeLabel,
    required this.selected,
    required this.onToggleSelection,
    required this.audioPlaybackService,
    super.key,
  });

  final RemoteFileEntry file;
  final RemoteFilePreview preview;
  final String sizeLabel;
  final bool selected;
  final VoidCallback onToggleSelection;
  final AudioPlaybackService audioPlaybackService;

  @override
  State<RemoteFilePreviewSheet> createState() => _RemoteFilePreviewSheetState();
}

class _RemoteFilePreviewSheetState extends State<RemoteFilePreviewSheet> {
  late bool _selected;
  double? _mediaAspectRatio;
  bool _closing = false;

  bool get _needsNativeViewerTeardown {
    final extension = widget.file.name.toLowerCase().split('.').last;
    return extension == 'pdf' ||
        OfficeDocumentPreview.supportedExtensions.contains(extension);
  }

  Future<void> _close() async {
    if (_closing) return;
    if (!_needsNativeViewerTeardown) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _closing = true);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 64));
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  void _setSelected(bool? value) {
    if (value == null || value == _selected) return;
    widget.onToggleSelection();
    setState(() => _selected = value);
  }

  void _setMediaAspectRatio(double value) {
    if (!value.isFinite || value <= 0) return;
    if (_mediaAspectRatio != null && (_mediaAspectRatio! - value).abs() < .01) {
      return;
    }
    setState(() => _mediaAspectRatio = value);
  }

  double _heightFactor(Size windowSize) {
    final extension = widget.file.name.toLowerCase().split('.').last;
    if (widget.file.kind == RemoteFileKind.image ||
        extension == 'pdf' ||
        OfficeDocumentPreview.supportedExtensions.contains(extension) ||
        const {'txt', 'json', 'xml', 'log'}.contains(extension)) {
      return .9;
    }
    if (widget.file.kind == RemoteFileKind.audio) {
      return windowSize.height < 480 ? .86 : .58;
    }
    final aspectRatio = _mediaAspectRatio;
    if (aspectRatio == null) return .72;
    final contentWidth = math.min(
      windowSize.width - (AppSpace.m * 2),
      840.0,
    );
    // El reproductor ahora incluye thumb, tiempos y controles fuera del
    // video; reservar ese espacio evita que el scrubber quede comprimido.
    final desiredHeight = (contentWidth / aspectRatio) + 180;
    final minimum = windowSize.height < 480 ? .72 : .32;
    return (desiredHeight / windowSize.height).clamp(minimum, .9).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.biggest;
          return Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              height: available.height * _heightFactor(available),
              child: Material(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.l),
                ),
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
                        const Center(child: _SheetHandle()),
                        const SizedBox(height: AppSpace.s),
                        _PreviewHeader(
                          file: widget.file,
                          sizeLabel: widget.sizeLabel,
                          selected: _selected,
                          onSelected: _setSelected,
                          onClose: () => unawaited(_close()),
                        ),
                        const SizedBox(height: AppSpace.m),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.l),
                            child: ColoredBox(
                              color: theme.scaffoldBackgroundColor,
                              child: _closing
                                  ? const SizedBox.expand()
                                  : _PreviewContent(
                                      file: widget.file,
                                      preview: widget.preview,
                                      onAspectRatio: _setMediaAspectRatio,
                                      audioPlaybackService:
                                          widget.audioPlaybackService,
                                    ),
                            ),
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
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.file,
    required this.sizeLabel,
    required this.selected,
    required this.onSelected,
    required this.onClose,
  });

  final RemoteFileEntry file;
  final String sizeLabel;
  final bool selected;
  final ValueChanged<bool?> onSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: AppSize.minTouchTarget,
          height: AppSize.minTouchTarget,
          padding: const EdgeInsets.all(AppSpace.s + 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: SvgPicture.asset(
            'assets/images/icons/${_assetFor(file.kind)}',
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
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Vista previa · $sizeLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: selected
              ? 'Quitar de la transferencia'
              : 'Seleccionar para transferir',
          child: Checkbox(value: selected, onChanged: onSelected),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.file,
    required this.preview,
    required this.onAspectRatio,
    required this.audioPlaybackService,
  });

  final RemoteFileEntry file;
  final RemoteFilePreview preview;
  final ValueChanged<double> onAspectRatio;
  final AudioPlaybackService audioPlaybackService;

  @override
  Widget build(BuildContext context) {
    final extension = file.name.toLowerCase().split('.').last;
    if (file.kind == RemoteFileKind.image) {
      return _ImagePreview(
        localPath: preview.localPath,
        onAspectRatio: onAspectRatio,
      );
    }
    if (file.kind == RemoteFileKind.video) {
      return VideoPreviewPlayer(
        path: preview.localPath,
        onAspectRatio: onAspectRatio,
      );
    }
    if (file.kind == RemoteFileKind.audio) {
      return AudioPreviewPlayer(
        path: preview.localPath,
        playbackService: audioPlaybackService,
      );
    }
    if (extension == 'pdf') {
      return _PdfPreview(localPath: preview.localPath);
    }
    if (OfficeDocumentPreview.supportedExtensions.contains(extension)) {
      return OfficeDocumentPreview(
        path: preview.localPath,
        name: file.name,
        extension: extension,
        fallbackText: preview.documentText,
      );
    }
    if (const {'txt', 'json', 'xml', 'log'}.contains(extension)) {
      return DocumentPreviewContent(
        content:
            preview.documentText ?? 'No se encontró texto previsualizable.',
        extension: extension,
      );
    }
    return const _PreviewFailure(
      message: 'Este formato no admite vista previa.',
    );
  }
}

class _ImagePreview extends StatefulWidget {
  const _ImagePreview({
    required this.localPath,
    required this.onAspectRatio,
  });

  final String localPath;
  final ValueChanged<double> onAspectRatio;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  late final FileImage _provider;
  late final ImageStreamListener _listener;
  ImageStream? _stream;

  @override
  void initState() {
    super.initState();
    _provider = FileImage(File(widget.localPath));
    _listener = ImageStreamListener((info, _) {
      final ratio = info.image.width / info.image.height;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAspectRatio(ratio);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    minScale: .5,
    maxScale: 5,
    child: Center(
      child: Image(
        image: _provider,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const _PreviewFailure(
          message: 'Android no pudo decodificar esta imagen.',
        ),
      ),
    ),
  );
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.localPath});

  final String localPath;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const _PreviewFailure(
        message: 'No se pudo renderizar este documento PDF.',
      );
    }
    return PDFView(
      filePath: widget.localPath,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: false,
      pageSnap: false,
      fitEachPage: false,
      showScrollIndicators: true,
      fitPolicy: FitPolicy.WIDTH,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      onError: (error) {
        if (mounted) setState(() => _error = error);
      },
      onPageError: (_, error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }
}

class _PreviewFailure extends StatelessWidget {
  const _PreviewFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpace.s),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 4,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .2),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
  );
}

String _assetFor(RemoteFileKind kind) => switch (kind) {
  RemoteFileKind.image => 'gallery.svg',
  RemoteFileKind.video => 'video.svg',
  RemoteFileKind.audio => 'microphone.svg',
  RemoteFileKind.document => 'file.svg',
  _ => 'file.svg',
};
