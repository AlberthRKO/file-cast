import 'dart:async';
import 'dart:collection';

/// Limits all expensive image/video preparation to one job at a time. The work
/// stays lazy: a tile joins the queue only when its builder mounts it.
final class EvidenceThumbnailWorkQueue {
  EvidenceThumbnailWorkQueue._();

  static final images = EvidenceThumbnailWorkQueue._();
  static final videos = images;

  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();
  int _running = 0;
  bool _coolingDown = false;
  static const _maximumConcurrent = 1;

  Future<void> run(Future<void> Function() work) async {
    final ready = Completer<void>();
    _waiting.add(ready);
    _startNext();
    await ready.future;
    try {
      await work();
    } finally {
      _running--;
      _coolingDown = true;
      Timer(const Duration(milliseconds: 32), () {
        _coolingDown = false;
        _startNext();
      });
    }
  }

  void _startNext() {
    if (_coolingDown) return;
    while (_running < _maximumConcurrent && _waiting.isNotEmpty) {
      _running++;
      _waiting.removeFirst().complete();
    }
  }
}
