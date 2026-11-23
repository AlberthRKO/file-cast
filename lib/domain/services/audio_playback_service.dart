import 'dart:async';

abstract interface class AudioPlaybackService {
  AudioPlaybackSession createSession();
}

abstract interface class AudioPlaybackSession {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<bool> get completedStream;

  Future<Duration?> openFile(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
