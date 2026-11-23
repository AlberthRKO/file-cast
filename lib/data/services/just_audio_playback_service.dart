import 'dart:async';

import 'package:file_cast/domain/services/audio_playback_service.dart';
import 'package:just_audio/just_audio.dart';

final class JustAudioPlaybackService implements AudioPlaybackService {
  @override
  AudioPlaybackSession createSession() => _JustAudioPlaybackSession();
}

final class _JustAudioPlaybackSession implements AudioPlaybackSession {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playerStateStream.map(
    (state) =>
        state.playing && state.processingState != ProcessingState.completed,
  );

  @override
  Stream<bool> get bufferingStream => _player.playerStateStream.map(
    (state) =>
        state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering,
  );

  @override
  Stream<bool> get completedStream => _player.playerStateStream.map(
    (state) => state.processingState == ProcessingState.completed,
  );

  @override
  Future<Duration?> openFile(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}
