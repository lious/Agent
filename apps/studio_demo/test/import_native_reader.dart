// TEST ONLY controlled first-read port, NOT File/GTK/OS/crypto qualification.
import 'dart:async';
import 'dart:typed_data';

import 'package:studio_assets/craft/signed_import/source_capture.dart';
import 'package:studio_demo/import_fixture_composition.dart';

final class NativeReaderController
    implements NativeImportFixtureReaderControls {
  NativeReaderController({
    required this.observe,
    this.watchdog = const Duration(seconds: 15),
  });
  final void Function(Map<String, Object?>) observe;
  final Duration watchdog;
  bool _armed = false, _started = false, _watchdogFired = false;
  int _observerFaults = 0;
  final _counts = <String, int>{};
  final _events = <String>[];
  String _outcome = 'pending';
  SkillSourceCapture? _capture;
  _NativeHeldReader? _reader;
  Timer? _timer;
  Stopwatch? _watch;
  Map<String, Object?> get snapshot => Map.unmodifiable({
    'held': _reader?.held ?? false,
    'busy': _capture?.busy ?? false,
    'outcome': _outcome,
    'counts': Map<String, int>.unmodifiable(_counts),
    'events': List<String>.unmodifiable(_events),
    'watchdogFired': _watchdogFired,
    'observerFaults': _observerFaults,
    'elapsedSeconds': (_watch?.elapsedMicroseconds ?? 0) / 1000000,
  });
  void _trace() {
    try {
      observe(snapshot);
    } catch (_) {
      ++_observerFaults;
    }
  }

  void _hit(String key) {
    _counts[key] = (_counts[key] ?? 0) + 1;
    _events.add(key);
    _trace();
  }

  @override
  void arm() {
    if (_started || (_capture?.busy ?? false) || _armed) {
      _hit('armRefusals');
      return;
    }
    _armed = true;
    _hit('armed');
  }

  @override
  void release() {
    if (!(_reader?.release() ?? false)) {
      _hit('ignoredReleases');
      return;
    }
    _hit('manualReleases');
  }

  Future<Uint8List?> choose(
    SkillSourceCapture capture,
    bool Function() guard,
    void Function() selected,
  ) {
    _capture = capture;
    final result = capture.choose(
      () {
        _started = true;
        _hit('selections');
        _reader = _NativeHeldReader(this);
        return SkillSourceSelection(
          Future.value(_reader),
          dispose: () => _hit('disposeHooks'),
        );
      },
      currentAppStillValid: guard,
      onSelected: () {
        _watch = Stopwatch()..start();
        _timer = Timer(watchdog, () {
          _watchdogFired = true;
          _hit('watchdog');
          capture.cancel();
          _reader?.release(force: true);
        });
        _hit('selected');
        selected();
      },
    );
    result.then<void>(
      (bytes) {
        _outcome = bytes == null ? 'null' : 'bytes';
        _hit(bytes == null ? 'outcomeNull' : 'outcomeBytes');
      },
      onError: (Object e, StackTrace s) {
        _outcome = 'error';
        _hit('outcomeErrors');
      },
    );
    capture.quiescent.then((_) {
      _timer?.cancel();
      _watch?.stop();
      _hit('quiescent');
    });
    return result; // ORIGINAL actual capture future, no substituted result.
  }
}

final class _NativeHeldReader implements SkillSourceReader {
  _NativeHeldReader(this.owner);
  final NativeReaderController owner;
  final _gate = Completer<void>();
  Future<void>? _opening;
  bool held = false;
  bool release({bool force = false}) {
    if (_gate.isCompleted || (!held && !force)) return false;
    _gate.complete();
    return true;
  }

  Future<void> _open() => _opening ??= () async {
    owner._hit('openStarted');
    owner._hit('openCompleted');
  }();

  @override
  Future<int> length() async {
    owner._hit('lengthStarted');
    await _open();
    owner._hit('lengthCompleted');
    return 4;
  }

  @override
  Future<Uint8List> read(int start, int end) async {
    if (start >= 4) {
      owner._hit('eof');
      return Uint8List(0);
    }
    owner._hit('readStarted');
    held = true;
    owner._hit('held');
    await _gate.future;
    held = false;
    owner._hit('readCompleted');
    return Uint8List((end - start) < (4 - start) ? end - start : 4 - start);
  }

  @override
  Future<void> close() async {
    owner._hit('closeStarted');
    await _opening;
    owner._hit('closeCompleted');
  }
}
