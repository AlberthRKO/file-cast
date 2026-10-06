import 'dart:async';
import 'dart:io';

import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Reproductor local de evidencia con controles consistentes entre las
/// previews del detalle y de transferencia.
///
/// El controlador usa explícitamente reproducción sin loop. El scrubber
/// pausa mientras se arrastra y reanuda únicamente si el video estaba
/// reproduciéndose antes de la búsqueda.
class VideoPreviewPlayer extends StatefulWidget {
  const VideoPreviewPlayer({
    required this.path,
    this.onAspectRatio,
    super.key,
  });

  final String path;
  final ValueChanged<double>? onAspectRatio;

  @override
  State<VideoPreviewPlayer> createState() => _VideoPreviewPlayerState();
}

class _VideoPreviewPlayerState extends State<VideoPreviewPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  Duration? _scrubPosition;
  bool _wasPlayingBeforeScrub = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    // Los previews de evidencia son reproducciones únicas. Esto también
    // fuerza el comportamiento esperado del backend media_kit.
    await _controller.setLooping(false);

    final aspectRatio = _controller.value.aspectRatio;
    if (widget.onAspectRatio != null &&
        aspectRatio.isFinite &&
        aspectRatio > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAspectRatio!(aspectRatio);
      });
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onScrubStart(double value) {
    _wasPlayingBeforeScrub = _controller.value.isPlaying;
    if (_wasPlayingBeforeScrub) unawaited(_controller.pause());
    setState(() => _scrubPosition = _durationFromMilliseconds(value));
  }

  void _onScrubChanged(double value) {
    setState(() => _scrubPosition = _durationFromMilliseconds(value));
  }

  void _onScrubEnd(double value) {
    unawaited(_finishScrub(value));
  }

  Future<void> _finishScrub(double value) async {
    final duration = _controller.value.duration;
    final target = _durationFromMilliseconds(value);
    final shouldResume = _wasPlayingBeforeScrub && target < duration && mounted;

    setState(() => _scrubPosition = null);
    await _controller.seekTo(target);
    if (shouldResume) await _controller.play();
    _wasPlayingBeforeScrub = false;
  }

  Duration _durationFromMilliseconds(double milliseconds) {
    final duration = _controller.value.duration;
    final maximum = duration.inMilliseconds.toDouble();
    return Duration(
      milliseconds: milliseconds.clamp(0, maximum).round(),
    );
  }

  Future<void> _togglePlayback() async {
    final value = _controller.value;
    if (value.isPlaying) {
      await _controller.pause();
      return;
    }
    // VideoPlayerController.play() también reinicia cuando está exactamente
    // al final, que es el comportamiento habitual de un reproductor.
    await _controller.play();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _VideoPreviewLoading();
      }
      if (snapshot.hasError || !_controller.value.isInitialized) {
        return const _VideoPreviewFailure(
          message: 'El códec o contenedor de este video no es compatible.',
        );
      }

      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          final duration = value.duration;
          final position = _scrubPosition ?? value.position;
          final maximum = duration.inMilliseconds.toDouble();
          final sliderValue = maximum <= 0
              ? 0.0
              : position.inMilliseconds
                    .clamp(0, duration.inMilliseconds)
                    .toDouble();

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_controller),
                        if (value.isBuffering)
                          const IgnorePointer(
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          ),
                        IconButton.filled(
                          tooltip: value.isPlaying ? 'Pausar' : 'Reproducir',
                          iconSize: 34,
                          onPressed: () => unawaited(_togglePlayback()),
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.m,
                  AppSpace.s,
                  AppSpace.m,
                  0,
                ),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 15,
                        ),
                        activeTrackColor: Theme.of(
                          context,
                        ).colorScheme.primary,
                        inactiveTrackColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .22),
                        thumbColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: Slider(
                        min: 0,
                        max: maximum > 0 ? maximum : 1,
                        value: sliderValue,
                        onChangeStart: maximum <= 0 ? null : _onScrubStart,
                        onChanged: maximum <= 0 ? null : _onScrubChanged,
                        onChangeEnd: maximum <= 0 ? null : _onScrubEnd,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatVideoDuration(position)),
                        Text(_formatVideoDuration(duration)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _VideoPreviewLoading extends StatelessWidget {
  const _VideoPreviewLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: AppSpace.m),
        Text('Preparando video…'),
      ],
    ),
  );
}

class _VideoPreviewFailure extends StatelessWidget {
  const _VideoPreviewFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

String _formatVideoDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
}
