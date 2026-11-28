// TEST ONLY: bounded controlled source, NOT File or verifier-success qualification.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'package:studio_assets/craft/signed_import/source_capture.dart';

int _opens = 0, _reads = 0, _completions = 0, _closes = 0;
void _trace() => web.document.documentElement?.setAttribute(
  'data-signed-import-fixture-reader',
  jsonEncode({
    'opens': _opens,
    'reads': _reads,
    'completions': _completions,
    'closes': _closes,
  }),
);

Future<Uint8List?> chooseHeldFixtureSource(
  SkillSourceCapture capture,
  bool Function() guard,
  void Function() selected,
) => capture.choose(
  () {
    ++_opens;
    _trace();
    return SkillSourceSelection(Future.value(_HeldReader()));
  },
  currentAppStillValid: guard,
  onSelected: selected,
);

final class _HeldReader implements SkillSourceReader {
  final _gate = Completer<void>();
  late final JSFunction _pagehide;
  _HeldReader() {
    _pagehide = ((web.Event event) {
      Timer(const Duration(milliseconds: 100), () {
        if (!_gate.isCompleted) _gate.complete();
      });
    }).toJS;
    web.window.addEventListener('pagehide', _pagehide);
  }
  @override
  Future<int> length() async => 4;
  @override
  Future<Uint8List> read(int start, int end) async {
    if (start >= 4) return Uint8List(0);
    ++_reads;
    _trace();
    await _gate.future;
    ++_completions;
    _trace();
    // If these bytes ever reach import, that is a test failure, not fake success.
    return Uint8List(end - start);
  }

  @override
  Future<void> close() async {
    web.window.removeEventListener('pagehide', _pagehide);
    ++_closes;
    _trace();
  }
}
