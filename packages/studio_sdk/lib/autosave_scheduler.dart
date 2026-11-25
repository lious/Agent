import 'dart:async';

/// Monotonic Timer deadlines. This creates local metadata checkpoints, NEVER
/// silently rewrites an external package. Timers restart on the next edit after
/// a surfaced failure; explicit lifecycle flush can retry immediately.
final class AutosaveScheduler {
  AutosaveScheduler({
    required this.checkpoint,
    this.onError,
    this.idle = const Duration(seconds: 2),
    this.maximum = const Duration(seconds: 30),
    this.commitLimit = 50,
  }) {
    if (idle <= Duration.zero || maximum < idle || commitLimit < 1) {
      throw ArgumentError('Invalid autosave policy');
    }
  }
  final void Function() checkpoint;
  final void Function(Object)? onError;
  final Duration idle, maximum;
  final int commitLimit;
  Timer? _idle, _maximum;
  int _pending = 0;
  bool _closed = false;
  Object? lastError;
  bool get pending => _pending > 0;
  void onDurableCommit() {
    if (_closed) throw StateError('Scheduler closed');
    _pending++;
    _idle?.cancel();
    _maximum ??= Timer(maximum, _attempt);
    _idle = Timer(idle, _attempt);
    if (_pending >= commitLimit) _attempt();
  }

  void _attempt() {
    try {
      flush();
    } catch (e) {
      onError?.call(e);
    }
  }

  void flush() {
    if (_closed) return;
    _idle?.cancel();
    _maximum?.cancel();
    _idle = null;
    _maximum = null;
    if (!pending) return;
    try {
      checkpoint();
      _pending = 0;
      lastError = null;
    } catch (e) {
      lastError = e;
      rethrow;
    }
  }

  void dispose() {
    _closed = true;
    _idle?.cancel();
    _maximum?.cancel();
  }
}
