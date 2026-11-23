import 'dart:async';
import 'dart:io';

import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' as platform_video;

/// Reproductor local de evidencia con controles consistentes entre las
/// previews del detalle y de transferencia.
///
/// En Android se fuerza la decodificación por software para evitar fallos del
/// decodificador MediaCodec de ciertos fabricantes. iOS conserva AVPlayer.
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
  late _VideoPlaybackAdapter _adapter;
  late Future<void> _initialization;

  Duration? _scrubPosition;
  bool _wasPlayingBeforeScrub = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _replaceAdapter();
  }

  @override
  void didUpdateWidget(covariant VideoPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      unawaited(_adapter.dispose());
      _scrubPosition = null;
      _wasPlayingBeforeScrub = false;
      _isMuted = false;
      _replaceAdapter();
    }
  }

  void _replaceAdapter() {
    _adapter = Platform.isAndroid
        ? _MediaKitVideoPlaybackAdapter(widget.path)
        : _VideoPlayerPlaybackAdapter(widget.path);
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _adapter.initialize();
    } on TimeoutException {
      throw StateError(
        'El video tardó demasiado en abrirse. Puede estar incompleto o usar '
        'un formato no compatible.',
      );
    }

    final aspectRatio = _adapter.state.value.aspectRatio;
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
    unawaited(_adapter.dispose());
    super.dispose();
  }

  void _onScrubStart(double value) {
    _wasPlayingBeforeScrub = _adapter.state.value.isPlaying;
    if (_wasPlayingBeforeScrub) unawaited(_adapter.pause());
    setState(() => _scrubPosition = _durationFromMilliseconds(value));
  }

  void _onScrubChanged(double value) {
    setState(() => _scrubPosition = _durationFromMilliseconds(value));
  }

  void _onScrubEnd(double value) {
    unawaited(_finishScrub(value));
  }

  Future<void> _finishScrub(double value) async {
    final current = _adapter.state.value;
    final target = _durationFromMilliseconds(value);
    final shouldResume =
        _wasPlayingBeforeScrub && target < current.duration && mounted;

    setState(() => _scrubPosition = null);
    await _adapter.seek(target);
    if (shouldResume) await _adapter.play();
    _wasPlayingBeforeScrub = false;
  }

  Duration _durationFromMilliseconds(double milliseconds) {
    final maximum = _adapter.state.value.duration.inMilliseconds.toDouble();
    return Duration(milliseconds: milliseconds.clamp(0, maximum).round());
  }

  Future<void> _togglePlayback(_VideoPlaybackState value) async {
    if (value.isPlaying) {
      await _adapter.pause();
      return;
    }
    if (value.duration > Duration.zero && value.position >= value.duration) {
      await _adapter.seek(Duration.zero);
    }
    await _adapter.play();
  }

  Future<void> _toggleMute() async {
    final nextMuted = !_isMuted;
    setState(() => _isMuted = nextMuted);
    await _adapter.setVolume(nextMuted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _VideoPreviewLoading();
      }
      if (snapshot.hasError) {
        return _VideoPreviewFailure(
          message: _videoInitializationError(snapshot.error),
        );
      }

      return ValueListenableBuilder<_VideoPlaybackState>(
        valueListenable: _adapter.state,
        builder: (context, value, _) {
          if (value.error != null) {
            return _VideoPreviewFailure(message: value.error!);
          }

          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final duration = value.duration;
          final position = _scrubPosition ?? value.position;
          final maximum = duration.inMilliseconds.toDouble();
          final sliderValue = maximum <= 0
              ? 0.0
              : position.inMilliseconds
                    .clamp(0, duration.inMilliseconds)
                    .toDouble();

          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.l),
            child: ColoredBox(
              color: theme.cardColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: value.aspectRatio,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          child: ColoredBox(
                            color: Colors.black,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _adapter.buildVideoSurface(),
                                if (value.isBuffering)
                                  const IgnorePointer(
                                    child: SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                if (!value.isPlaying && !value.isBuffering)
                                  IconButton(
                                    tooltip: 'Reproducir',
                                    iconSize: 38,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      minimumSize: const Size(68, 68),
                                      padding: const EdgeInsets.only(left: 4),
                                    ),
                                    onPressed: () =>
                                        unawaited(_togglePlayback(value)),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.m,
                      AppSpace.s,
                      AppSpace.m,
                      AppSpace.xs,
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
                            activeTrackColor: scheme.primary,
                            inactiveTrackColor: scheme.onSurface.withValues(
                              alpha: .22,
                            ),
                            thumbColor: scheme.primary,
                          ),
                          child: Slider(
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
                            Text(
                              _formatVideoDuration(position),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _formatVideoDuration(duration),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: value.isPlaying
                                  ? 'Pausar'
                                  : 'Reproducir',
                              color: scheme.onSurface,
                              iconSize: 27,
                              onPressed: () =>
                                  unawaited(_togglePlayback(value)),
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                            IconButton(
                              tooltip: _isMuted
                                  ? 'Activar sonido'
                                  : 'Silenciar',
                              color: scheme.onSurface,
                              iconSize: 25,
                              onPressed: () => unawaited(_toggleMute()),
                              icon: Icon(
                                _isMuted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

abstract interface class _VideoPlaybackAdapter {
  ValueListenable<_VideoPlaybackState> get state;

  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
  Widget buildVideoSurface();
}

class _VideoPlaybackState {
  const _VideoPlaybackState({
    this.isPlaying = false,
    this.isBuffering = false,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.aspectRatio = 16 / 9,
    this.error,
  });

  final bool isPlaying;
  final bool isBuffering;
  final Duration duration;
  final Duration position;
  final double aspectRatio;
  final String? error;

  _VideoPlaybackState copyWith({
    bool? isPlaying,
    bool? isBuffering,
    Duration? duration,
    Duration? position,
    double? aspectRatio,
    String? error,
  }) => _VideoPlaybackState(
    isPlaying: isPlaying ?? this.isPlaying,
    isBuffering: isBuffering ?? this.isBuffering,
    duration: duration ?? this.duration,
    position: position ?? this.position,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    error: error ?? this.error,
  );
}

abstract class _VideoPlaybackAdapterBase implements _VideoPlaybackAdapter {
  @override
  final ValueNotifier<_VideoPlaybackState> state = ValueNotifier(
    const _VideoPlaybackState(),
  );

  @override
  Future<void> play();

  @override
  Future<void> pause();

  @override
  Future<void> seek(Duration position);

  @override
  Future<void> setVolume(double volume);

  @override
  Future<void> dispose() async {
    state.dispose();
  }

  @override
  Widget buildVideoSurface();

  @override
  Future<void> initialize();
}

class _VideoPlayerPlaybackAdapter extends _VideoPlaybackAdapterBase {
  _VideoPlayerPlaybackAdapter(String path)
    : _path = path,
      _controller = platform_video.VideoPlayerController.file(File(path)) {
    _controller.addListener(_syncState);
  }

  final String _path;
  final platform_video.VideoPlayerController _controller;

  @override
  Future<void> initialize() async {
    final file = File(_path);
    if (!await file.exists()) {
      throw StateError('El archivo de video ya no está disponible.');
    }
    if (await file.length() == 0) {
      throw StateError('El archivo de video está vacío o incompleto.');
    }
    await _controller.initialize().timeout(const Duration(seconds: 20));
    await _controller.setLooping(false);
    _syncState();
  }

  void _syncState() {
    final value = _controller.value;
    state.value = _VideoPlaybackState(
      isPlaying: value.isPlaying,
      isBuffering: value.isBuffering,
      duration: value.duration,
      position: value.position,
      aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
      error: value.hasError ? value.errorDescription : null,
    );
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seek(Duration position) => _controller.seekTo(position);

  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume);

  @override
  Future<void> dispose() async {
    _controller.removeListener(_syncState);
    await _controller.dispose();
    await super.dispose();
  }

  @override
  Widget buildVideoSurface() => platform_video.VideoPlayer(_controller);
}

class _MediaKitVideoPlaybackAdapter extends _VideoPlaybackAdapterBase {
  _MediaKitVideoPlaybackAdapter(this._path) {
    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(hwdec: 'no'),
    );
    _subscriptions.addAll([
      _player.stream.playing.listen(
        (value) => _update((current) => current.copyWith(isPlaying: value)),
      ),
      _player.stream.buffering.listen(
        (value) => _update((current) => current.copyWith(isBuffering: value)),
      ),
      _player.stream.duration.listen(
        (value) => _update((current) => current.copyWith(duration: value)),
      ),
      _player.stream.position.listen(
        (value) => _update((current) => current.copyWith(position: value)),
      ),
      _player.stream.videoParams.listen(_updateVideoParams),
      _player.stream.error.listen(_updatePlayerError),
    ]);
  }

  final String _path;
  final Player _player = Player();
  late final VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Completer<void> _videoReady = Completer<void>();
  final Completer<void> _decoderFailed = Completer<void>();

  @override
  Future<void> initialize() async {
    final file = File(_path);
    if (!await file.exists()) {
      throw StateError('El archivo de video ya no está disponible.');
    }
    if (await file.length() == 0) {
      throw StateError('El archivo de video está vacío o incompleto.');
    }

    await _player.handle.timeout(const Duration(seconds: 20));
    await _videoController.platform.future.timeout(
      const Duration(seconds: 20),
    );
    await _player
        .open(Media(_path), play: false)
        .timeout(const Duration(seconds: 20));
    await Future.any<void>([_videoReady.future, _decoderFailed.future]).timeout(
      const Duration(seconds: 20),
    );

    if (state.value.error != null) {
      throw StateError(state.value.error!);
    }
  }

  void _updateVideoParams(VideoParams params) {
    final width = params.dw ?? params.w;
    final height = params.dh ?? params.h;
    final ratio =
        params.aspect ??
        (width != null && height != null && height > 0 ? width / height : null);
    _update(
      (current) => current.copyWith(
        aspectRatio: ratio != null && ratio.isFinite && ratio > 0
            ? ratio
            : current.aspectRatio,
      ),
    );
    if (width != null && height != null && width > 0 && height > 0) {
      if (!_videoReady.isCompleted) _videoReady.complete();
    }
  }

  void _updatePlayerError(String _) {
    const fallback =
        'No se pudo decodificar el video en este dispositivo. El archivo puede '
        'usar un formato, perfil o resolución que el reproductor no admite.';
    _update((current) => current.copyWith(error: fallback));
    if (!_videoReady.isCompleted && !_decoderFailed.isCompleted) {
      _decoderFailed.complete();
    }
  }

  void _update(_VideoPlaybackState Function(_VideoPlaybackState) change) {
    state.value = change(state.value);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume * 100);

  @override
  Future<void> dispose() async {
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    await _player.dispose();
    await super.dispose();
  }

  @override
  Widget buildVideoSurface() => Video(
    controller: _videoController,
    controls: (_) => const SizedBox.shrink(),
    wakelock: false,
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

String _videoInitializationError(Object? error) {
  final message = error?.toString().replaceFirst('Bad state: ', '').trim();
  if (message != null && message.isNotEmpty) return message;
  return 'El códec o contenedor de este video no es compatible.';
}

String _formatVideoDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
}
