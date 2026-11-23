import 'dart:async';

import 'package:file_cast/domain/services/audio_playback_service.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';

/// Controles compartidos por las vistas previas de audio local y transferido.
class AudioPreviewPlayer extends StatefulWidget {
  const AudioPreviewPlayer({
    required this.path,
    required this.playbackService,
    super.key,
  });

  final String path;
  final AudioPlaybackService playbackService;

  @override
  State<AudioPreviewPlayer> createState() => _AudioPreviewPlayerState();
}

class _AudioPreviewPlayerState extends State<AudioPreviewPlayer> {
  late AudioPlaybackSession _session;
  late Future<void> _initialization;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<bool>? _completedSubscription;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _scrubPosition;
  bool _playing = false;
  bool _buffering = false;
  bool _completed = false;
  bool _wasPlayingBeforeScrub = false;
  Future<void>? _pauseForScrub;
  double _volume = 1;
  double _lastAudibleVolume = 1;
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    _replaceSession();
  }

  @override
  void didUpdateWidget(covariant AudioPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.playbackService != widget.playbackService) {
      _releaseSession();
      _position = Duration.zero;
      _duration = Duration.zero;
      _scrubPosition = null;
      _playing = false;
      _buffering = false;
      _completed = false;
      _wasPlayingBeforeScrub = false;
      _pauseForScrub = null;
      _volume = 1;
      _lastAudibleVolume = 1;
      _playbackError = null;
      _replaceSession();
    }
  }

  void _replaceSession() {
    _session = widget.playbackService.createSession();
    final session = _session;
    _positionSubscription = session.positionStream.listen((value) {
      if (mounted && identical(session, _session)) {
        setState(() => _position = value);
      }
    });
    _durationSubscription = session.durationStream.listen((value) {
      if (mounted && identical(session, _session) && value != null) {
        setState(() => _duration = value);
      }
    });
    _playingSubscription = session.playingStream.listen((value) {
      if (mounted && identical(session, _session)) {
        setState(() => _playing = value);
      }
    });
    _bufferingSubscription = session.bufferingStream.listen((value) {
      if (mounted && identical(session, _session)) {
        setState(() => _buffering = value);
      }
    });
    _completedSubscription = session.completedStream.listen((value) {
      if (mounted && identical(session, _session)) {
        setState(() => _completed = value);
      }
    });
    _initialization = _open(session);
  }

  Future<void> _open(AudioPlaybackSession session) async {
    final duration = await session.openFile(widget.path);
    if (mounted && identical(session, _session) && duration != null) {
      setState(() => _duration = duration);
    }
  }

  void _releaseSession() {
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_playingSubscription?.cancel());
    unawaited(_bufferingSubscription?.cancel());
    unawaited(_completedSubscription?.cancel());
    unawaited(_session.dispose());
  }

  @override
  void dispose() {
    _releaseSession();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _playbackError = 'No se pudo reproducir este audio.');
      }
    }
  }

  Future<void> _togglePlayback() async {
    await _perform(() async {
      if (_playing) {
        await _session.pause();
        return;
      }
      if (_completed || (_duration > Duration.zero && _position >= _duration)) {
        await _session.seek(Duration.zero);
      }
      await _session.play();
    });
  }

  Duration _at(double milliseconds) => Duration(
    milliseconds: milliseconds.clamp(0, _duration.inMilliseconds).round(),
  );

  void _onScrubStart(double value) {
    _wasPlayingBeforeScrub = _playing;
    _pauseForScrub = _playing ? _perform(_session.pause) : null;
    setState(() => _scrubPosition = _at(value));
  }

  void _onScrubChanged(double value) {
    setState(() => _scrubPosition = _at(value));
  }

  void _onScrubEnd(double value) {
    unawaited(_finishScrub(_at(value)));
  }

  Future<void> _finishScrub(Duration target) async {
    final resume = _wasPlayingBeforeScrub && target < _duration;
    setState(() => _scrubPosition = target);
    try {
      await _pauseForScrub;
      await _session.seek(target);
      if (resume) unawaited(_perform(_session.play));
    } catch (_) {
      if (mounted) {
        setState(() => _playbackError = 'No se pudo avanzar en este audio.');
      }
    } finally {
      if (mounted) setState(() => _scrubPosition = null);
      _wasPlayingBeforeScrub = false;
      _pauseForScrub = null;
    }
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value;
      if (value > 0) _lastAudibleVolume = value;
    });
    unawaited(_perform(() => _session.setVolume(value)));
  }

  void _toggleMute() {
    _setVolume(_volume > 0 ? 0 : _lastAudibleVolume);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || _playbackError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Text(
              _playbackError ??
                  'El formato o códec de este audio no es compatible.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final position = _scrubPosition ?? _position;
      final maximum = _duration.inMilliseconds.toDouble();
      final sliderValue = maximum <= 0
          ? 0.0
          : position.inMilliseconds
                .clamp(0, _duration.inMilliseconds)
                .toDouble();

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.m),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.l),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.m),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                      child: _buffering
                          ? Padding(
                              padding: const EdgeInsets.all(AppSpace.l),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.graphic_eq_rounded,
                              size: 38,
                              color: scheme.primary,
                            ),
                    ),
                    const SizedBox(height: AppSpace.m),
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
                        semanticFormatterCallback: (value) =>
                            _formatDuration(_at(value)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Row(
                      children: [
                        IconButton(
                          tooltip: _playing ? 'Pausar' : 'Reproducir',
                          iconSize: 28,
                          color: scheme.onSurface,
                          onPressed: () => unawaited(_togglePlayback()),
                          icon: Icon(
                            _playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: _volume == 0
                              ? 'Activar sonido'
                              : 'Silenciar',
                          iconSize: 25,
                          color: scheme.onSurface,
                          onPressed: _toggleMute,
                          icon: Icon(
                            _volume == 0
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                          ),
                        ),
                        Flexible(
                          fit: FlexFit.loose,
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
