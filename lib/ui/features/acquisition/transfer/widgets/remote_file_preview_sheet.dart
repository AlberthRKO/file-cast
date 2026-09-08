import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_card_surface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class RemoteFilePreviewSheet extends StatefulWidget {
  const RemoteFilePreviewSheet({
    required this.file,
    required this.preview,
    required this.sizeLabel,
    required this.selected,
    required this.onToggleSelection,
    super.key,
  });

  final RemoteFileEntry file;
  final RemoteFilePreview preview;
  final String sizeLabel;
  final bool selected;
  final VoidCallback onToggleSelection;

  @override
  State<RemoteFilePreviewSheet> createState() => _RemoteFilePreviewSheetState();
}

class _RemoteFilePreviewSheetState extends State<RemoteFilePreviewSheet> {
  late bool _selected;
  double? _mediaAspectRatio;

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
    if (extension == 'pdf' ||
        extension == 'docx' ||
        const {'txt', 'csv', 'json', 'xml', 'log'}.contains(extension)) {
      return .9;
    }
    if (widget.file.kind == RemoteFileKind.audio) {
      return windowSize.height < 480 ? .78 : .42;
    }
    final aspectRatio = _mediaAspectRatio;
    if (aspectRatio == null) return .72;
    final contentWidth = math.min(
      windowSize.width - (AppSpace.m * 2),
      840.0,
    );
    final desiredHeight = (contentWidth / aspectRatio) + 112;
    final minimum = windowSize.height < 480 ? .72 : .32;
    return (desiredHeight / windowSize.height).clamp(minimum, .9).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windowSize = MediaQuery.sizeOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: windowSize.height * _heightFactor(windowSize),
        child: Material(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.l),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.m,
                AppSpace.s,
                AppSpace.m,
                AppSpace.m,
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
                  ),
                  const SizedBox(height: AppSpace.m),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                      child: ColoredBox(
                        color: theme.scaffoldBackgroundColor,
                        child: _PreviewContent(
                          file: widget.file,
                          preview: widget.preview,
                          onAspectRatio: _setMediaAspectRatio,
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
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.file,
    required this.sizeLabel,
    required this.selected,
    required this.onSelected,
  });

  final RemoteFileEntry file;
  final String sizeLabel;
  final bool selected;
  final ValueChanged<bool?> onSelected;

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
          onPressed: () => Navigator.of(context).pop(),
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
  });

  final RemoteFileEntry file;
  final RemoteFilePreview preview;
  final ValueChanged<double> onAspectRatio;

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
      return _VideoPreview(
        localPath: preview.localPath,
        onAspectRatio: onAspectRatio,
      );
    }
    if (file.kind == RemoteFileKind.audio) {
      return _AudioPreview(localPath: preview.localPath);
    }
    if (extension == 'pdf') {
      return _PdfPreview(localPath: preview.localPath);
    }
    if (extension == 'docx' ||
        const {'txt', 'csv', 'json', 'xml', 'log'}.contains(extension)) {
      return _DocxPreview(
        content:
            preview.documentText ?? 'No se encontró texto previsualizable.',
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
        errorBuilder: (_, _, _) => const _PreviewFailure(
          message: 'Android no pudo decodificar esta imagen.',
        ),
      ),
    ),
  );
}

class _DocxPreview extends StatelessWidget {
  const _DocxPreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final pages = _paginate(content);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpace.m),
        itemCount: pages.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.m),
        itemBuilder: (context, index) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: LayoutBuilder(
              builder: (context, constraints) => Container(
                constraints: BoxConstraints(
                  minHeight: constraints.maxWidth * 1.32,
                ),
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Página ${index + 1}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: AppSpace.m),
                    SelectableText(
                      pages[index],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _paginate(String source) {
    const targetCharacters = 2400;
    final pages = <String>[];
    for (final explicitPage in source.split('\f')) {
      final buffer = StringBuffer();
      for (final paragraph in explicitPage.split('\n\n')) {
        if (buffer.length > 0 &&
            buffer.length + paragraph.length > targetCharacters) {
          pages.add(buffer.toString().trim());
          buffer.clear();
        }
        if (buffer.length > 0) buffer.write('\n\n');
        buffer.write(paragraph);
      }
      if (buffer.length > 0) pages.add(buffer.toString().trim());
    }
    return pages.isEmpty ? ['Documento sin contenido visible.'] : pages;
  }
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

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({
    required this.localPath,
    required this.onAspectRatio,
  });

  final String localPath;
  final ValueChanged<double> onAspectRatio;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.localPath));
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAspectRatio(_controller.value.aspectRatio);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !_controller.value.isInitialized) {
        return const _PreviewFailure(
          message: 'El códec o contenedor de este video no es compatible.',
        );
      }
      return Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          IconButton.filled(
            iconSize: 36,
            onPressed: () async {
              if (_controller.value.isPlaying) {
                await _controller.pause();
              } else {
                await _controller.play();
              }
              if (mounted) setState(() {});
            },
            icon: Icon(
              _controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
          Positioned(
            left: AppSpace.m,
            right: AppSpace.m,
            bottom: AppSpace.s,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
            ),
          ),
        ],
      );
    },
  );
}

class _AudioPreview extends StatefulWidget {
  const _AudioPreview({required this.localPath});

  final String localPath;

  @override
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
  late final AudioPlayer _player;
  late final Future<Duration?> _initialization;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initialization = _player.setFilePath(widget.localPath);
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Duration?>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return const _PreviewFailure(
          message: 'El formato o códec de este audio no es compatible.',
        );
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: AppCardSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 38,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    initialData: Duration.zero,
                    builder: (context, positionSnapshot) {
                      final duration = _player.duration ?? Duration.zero;
                      final position = positionSnapshot.data ?? Duration.zero;
                      final maximum = math.max(
                        duration.inMilliseconds.toDouble(),
                        1.0,
                      );
                      return Column(
                        children: [
                          Slider(
                            value: position.inMilliseconds
                                .clamp(0, maximum.toInt())
                                .toDouble(),
                            max: maximum,
                            onChanged: duration == Duration.zero
                                ? null
                                : (value) async => _player.seek(
                                    Duration(milliseconds: value.round()),
                                  ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position)),
                              Text(_formatDuration(duration)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, stateSnapshot) {
                      final state = stateSnapshot.data;
                      final playing = state?.playing ?? false;
                      final completed =
                          state?.processingState == ProcessingState.completed;
                      return IconButton.filled(
                        iconSize: 32,
                        tooltip: playing ? 'Pausar' : 'Reproducir',
                        onPressed: () async {
                          if (completed) await _player.seek(Duration.zero);
                          playing
                              ? await _player.pause()
                              : await _player.play();
                        },
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  return hours > 0
      ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
      : '$minutes:$seconds';
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
