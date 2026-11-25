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
/// Android e iOS usan MediaKit. En Android se fuerza la decodificación por
/// software para evitar fallos del decodificador MediaCodec de ciertos equipos.
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
  bool _isPriming = false;
  bool _isInitialized = false;
  double? _reportedAspectRatio;
  double _volume = 1;
  double _lastAudibleVolume = 1;

  @override
  void initState() {
    super.initState();
    _replaceAdapter();
  }

  @override
  void didUpdateWidget(covariant VideoPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _adapter.state.removeListener(_reportAspectRatio);
      unawaited(_adapter.dispose());
      _scrubPosition = null;
      _wasPlayingBeforeScrub = false;
      _volume = 1;
      _lastAudibleVolume = 1;
      _replaceAdapter();
    }
  }

  void _replaceAdapter() {
    final useMediaKit = Platform.isAndroid || Platform.isIOS;
    _isPriming = useMediaKit;
    _isInitialized = false;
    _reportedAspectRatio = null;
    _adapter = useMediaKit
        ? _MediaKitVideoPlaybackAdapter(widget.path)
        : _VideoPlayerPlaybackAdapter(widget.path);
    _adapter.state.addListener(_reportAspectRatio);
    _initialization = _initialize(_adapter);
  }

  void _reportAspectRatio() {
    if (!_isInitialized || widget.onAspectRatio == null) return;
    final adapter = _adapter;
    final ratio = adapter.state.value.aspectRatio;
    if (!ratio.isFinite ||
        ratio <= 0 ||
        (_reportedAspectRatio != null &&
            (_reportedAspectRatio! - ratio).abs() < .01)) {
      return;
    }
    _reportedAspectRatio = ratio;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_adapter, adapter)) {
        widget.onAspectRatio?.call(ratio);
      }
    });
  }

  Future<void> _initialize(_VideoPlaybackAdapter adapter) async {
    try {
      await adapter.initialize();
    } on TimeoutException {
      throw StateError(
        'El reproductor tardó demasiado en preparar el video en este '
        'dispositivo. Cierra la vista previa e inténtalo de nuevo.',
      );
    }

    if (!mounted || !identical(_adapter, adapter)) return;
    _isInitialized = true;
    _reportAspectRatio();
    if (adapter is _MediaKitVideoPlaybackAdapter) {
      // Prepara un cuadro con la textura montada y el audio silenciado.
      // Al terminar, el video debe quedar pausado en el inicio.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_adapter, adapter)) {
          unawaited(_primeMediaKitPlayback(adapter));
        }
      });
    }
  }

  Future<void> _primeMediaKitPlayback(
    _MediaKitVideoPlaybackAdapter adapter,
  ) async {
    try {
      // MediaKit abre el archivo pausado; iniciar la decodificación solo
      // después de montar la textura evita bloquear la apertura en equipos
      // con decodificación por software lenta.
      await adapter.play().timeout(const Duration(seconds: 15));
      await adapter.waitForPlaybackProgress().timeout(
        const Duration(seconds: 45),
      );
    } on Object catch (error) {
      // Un archivo puede no informar posición durante la preparación. Deja
      // disponibles los controles para intentar reproducirlo manualmente.
      if (kDebugMode) debugPrint('VideoPreviewPlayer: $error');
    }
    if (!mounted || !identical(_adapter, adapter)) return;
    try {
      await adapter.pause().timeout(const Duration(seconds: 10));
      await adapter.seek(Duration.zero).timeout(const Duration(seconds: 10));
      try {
        await adapter.waitForStartFrame().timeout(const Duration(seconds: 3));
      } on Object catch (error) {
        // No bloquear Play si el decoder no emite el evento de posición cero.
        if (kDebugMode) debugPrint('VideoPreviewPlayer start frame: $error');
      }
      await adapter.setVolume(1).timeout(const Duration(seconds: 10));
    } on Object {
      if (!mounted || !identical(_adapter, adapter)) return;
      adapter.reportStartupFailure();
      return;
    }
    if (!mounted || !identical(_adapter, adapter)) return;
    setState(() => _isPriming = false);
  }

  @override
  void dispose() {
    _adapter.state.removeListener(_reportAspectRatio);
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

  void _setVolume(double value) {
    setState(() {
      _volume = value;
      if (value > 0) _lastAudibleVolume = value;
    });
    unawaited(_adapter.setVolume(value));
  }

  void _toggleMute() {
    _setVolume(_volume > 0 ? 0 : _lastAudibleVolume);
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
                                if (_isPriming)
                                  const Positioned.fill(
                                    child: ColoredBox(
                                      color: Colors.black,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (!_isPriming && value.isBuffering)
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
                                if (!_isPriming &&
                                    !value.isPlaying &&
                                    !value.isBuffering)
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
                  if (!_isPriming)
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
                              onChangeStart: maximum <= 0
                                  ? null
                                  : _onScrubStart,
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
                                tooltip: _volume == 0
                                    ? 'Activar sonido'
                                    : 'Silenciar',
                                color: scheme.onSurface,
                                iconSize: 25,
                                onPressed: _toggleMute,
                                icon: Icon(
                                  _volume == 0
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                ),
                              ),
                              Flexible(
                                child: SizedBox(
                                  width: AppSize.mediaVolumeSliderWidth,
                                  child: Slider(
                                    value: _volume,
                                    onChanged: _setVolume,
                                    semanticFormatterCallback: (value) =>
                                        'Volumen ${(value * 100).round()} por ciento',
                                  ),
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
      configuration: Platform.isAndroid
          ? const VideoControllerConfiguration(hwdec: 'no')
          : const VideoControllerConfiguration(),
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
  Future<void>? _disposal;
  String? _lastPlayerError;

  Future<void> waitForPlaybackProgress() async {
    bool advanced(Duration position) {
      final duration = state.value.duration;
      final target =
          duration > Duration.zero && duration < const Duration(seconds: 2)
          ? Duration(
              milliseconds: (duration.inMilliseconds ~/ 2).clamp(1, 250),
            )
          : const Duration(milliseconds: 250);
      return position >= target;
    }

    if (advanced(state.value.position)) return;
    await _player.stream.position.firstWhere(
      advanced,
    );
  }

  Future<void> waitForStartFrame() async {
    if (state.value.position > const Duration(milliseconds: 100)) {
      await _player.stream.position.firstWhere(
        (position) => position <= const Duration(milliseconds: 100),
      );
    }
    if (state.value.isBuffering) {
      await _player.stream.buffering.firstWhere((buffering) => !buffering);
    }
    // El evento de posición precede al repintado de la textura en Android.
    // Mantener la cubierta durante unos cuadros evita mostrar el salto de
    // preparación antes de habilitar Play.
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void reportStartupFailure() {
    final detail = _lastPlayerError;
    _update(
      (current) => current.copyWith(
        error: detail == null || detail.isEmpty
            ? 'El video no comenzó a reproducirse. El dispositivo puede no admitir este perfil de video.'
            : 'El video no comenzó a reproducirse. MediaKit: $detail',
      ),
    );
  }

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
    await _player.setVolume(0).timeout(const Duration(seconds: 5));
    await _player
        .open(Media(_path), play: false)
        .timeout(
          const Duration(seconds: 45),
        );
    // Los metadatos de video pueden llegar antes del primer cuadro visible.
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
  }

  void _updatePlayerError(String detail) {
    _lastPlayerError = detail.trim();
    if (kDebugMode) debugPrint('VideoPreviewPlayer MediaKit: $detail');
    // Algunos decodificadores fallan durante el sondeo y libmpv se recupera.
    // Conserva la textura y deja que el usuario intente reproducir el archivo.
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
  Future<void> dispose() => _disposal ??= _disposeOnce();

  Future<void> _disposeOnce() async {
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
