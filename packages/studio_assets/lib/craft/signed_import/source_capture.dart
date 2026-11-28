/// Opt-in App-lifetime source capture only. No verification, install or approval.
library;

import 'dart:async';
import 'dart:typed_data';

const skillSourceMaxBytes = 4194304;
const skillSourceChunkBytes = 65536;
const skillSourceDeadline = Duration(milliseconds: 30000);

/// A local UI outcome, deliberately not a StudioException/protocol error code.
final class SkillSourceException implements Exception {
  const SkillSourceException(this.reason);
  final String reason;
  @override
  String toString() => 'SkillSourceException($reason)';
}

/// App-internal reader port; not an OS capability/security attestation. Test
/// readers exercise resource/lifetime faults, never cryptographic verification.
abstract interface class SkillSourceReader {
  Future<int> length();
  Future<Uint8List> read(int start, int end);
  Future<void> close();
}

/// Ordinary cancel must not pretend a native/browser picker has settled. The
/// optional cleanup hook is for TERMINAL App disposal, not ordinary invalidation.
final class SkillSourceSelection {
  SkillSourceSelection(this.selected, {this.dispose});
  final Future<SkillSourceReader?> selected;
  final void Function()? dispose;
}

/// One instance per App lifetime, including project switches. A retired, busy
/// instance must quiesce before a successor can select in the same App/realm.
final class SkillSourceCapture {
  bool _busy = false, _disposed = false;
  int _generation = 0;
  SkillSourceSelection? _selection;
  Completer<Uint8List?>? _outcome;
  Completer<void>? _settled;
  bool get busy => _busy;
  Future<void> get quiescent => _settled?.future ?? Future<void>.value();

  Future<Uint8List?> choose(SkillSourceSelection Function() picker) {
    if (_disposed) throw const SkillSourceException('disposed');
    if (_busy) throw const SkillSourceException('busy');
    _busy = true;
    final generation = ++_generation;
    final result = _outcome = Completer<Uint8List?>();
    final settled = _settled = Completer<void>();
    // Picker activation stays SYNCHRONOUS in the trusted Choose call stack.
    try {
      _selection = picker();
    } catch (_) {
      _busy = false;
      _outcome = null;
      settled.complete();
      result.completeError(const SkillSourceException('selectionFailed'));
      return result.future;
    }
    unawaited(_capture(generation, _selection!, result, settled));
    return result.future;
  }

  void cancel() {
    ++_generation;
    if (_outcome case final result? when !result.isCompleted) {
      result.complete(null);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
    _selection?.dispose?.call();
  }

  Future<void> _capture(
    int generation,
    SkillSourceSelection selection,
    Completer<Uint8List?> result,
    Completer<void> settled,
  ) async {
    SkillSourceReader? reader;
    Timer? timer;
    Stopwatch? watch;
    Uint8List? bytes;
    SkillSourceException? failure;
    void live() {
      if (_disposed || _generation != generation) {
        throw const SkillSourceException('cancelled');
      }
      if (watch != null && watch.elapsed >= skillSourceDeadline) {
        throw const SkillSourceException('deadline');
      }
    }

    try {
      reader = await selection.selected;
      live();
      if (reader != null) {
        watch = Stopwatch()..start();
        timer = Timer(skillSourceDeadline, () {
          ++_generation;
          if (!result.isCompleted) {
            result.completeError(const SkillSourceException('deadline'));
          }
        });
        final expected = await reader.length();
        live();
        if (expected < 0 || expected > skillSourceMaxBytes) {
          throw const SkillSourceException('limit');
        }
        final buffer = BytesBuilder(copy: true);
        var total = 0;
        while (true) {
          live();
          final remaining = skillSourceMaxBytes + 1 - total;
          final count = remaining < skillSourceChunkBytes
              ? remaining
              : skillSourceChunkBytes;
          final chunk = await reader.read(total, total + count);
          live();
          if (chunk.length > count) throw const SkillSourceException('limit');
          if (chunk.isEmpty) break;
          total += chunk.length;
          if (total > skillSourceMaxBytes) {
            throw const SkillSourceException('limit');
          }
          buffer.add(Uint8List.fromList(chunk));
        }
        if (total != expected) throw const SkillSourceException('changed');
        bytes = Uint8List.fromList(buffer.takeBytes()).asUnmodifiableView();
      }
    } on SkillSourceException catch (e) {
      failure = e;
    } catch (_) {
      failure = const SkillSourceException('unreadable');
    } finally {
      try {
        await reader?.close();
      } catch (_) {
        failure = const SkillSourceException('unreadable');
      }
      if (watch != null && watch.elapsed >= skillSourceDeadline) {
        failure = const SkillSourceException('deadline');
      }
      timer?.cancel();
      watch?.stop();
      _selection = null;
      _outcome = null;
      _busy = false;
      settled.complete();
    }
    if (!result.isCompleted) {
      if (failure != null) {
        result.completeError(failure);
      } else {
        result.complete(bytes);
      }
    }
  }
}
