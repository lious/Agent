// NEW live-App fence tests only. No old source-adapter/crypto/runtime reruns.
import 'dart:async';
import 'dart:typed_data';

import 'package:studio_assets/craft/signed_import/source_capture.dart';
import 'package:test/test.dart';

final class PendingReader implements SkillSourceReader {
  PendingReader(this.phase, {this.failClose = false});
  final String phase;
  final bool failClose;
  final entered = Completer<void>(), release = Completer<void>();
  int lengths = 0, reads = 0, closes = 0;
  Future<void> pause(String at) async {
    if (phase == at) {
      entered.complete();
      await release.future;
    }
  }

  @override
  Future<int> length() async {
    lengths++;
    await pause('length');
    return 1;
  }

  @override
  Future<Uint8List> read(int start, int end) async {
    reads++;
    if (start == 0) {
      await pause('read');
    } else {
      await pause('eof');
    }
    return Uint8List.fromList(start == 0 ? [42] : []);
  }

  @override
  Future<void> close() async {
    closes++;
    await pause('close');
    if (failClose) throw StateError('private cleanup detail');
  }
}

Matcher scopeChanged() => isA<SkillSourceException>().having(
  (e) => e.reason,
  'safe local reason',
  'scopeChanged',
);
Future<Uint8List?> start(
  SkillSourceCapture c,
  PendingReader r,
  bool Function() current,
) => c.choose(
  () => SkillSourceSelection(Future.value(r)),
  currentAppStillValid: current,
);
void main() {
  test('invalid before picker cannot select or reserve capacity', () {
    final c = SkillSourceCapture();
    var picked = false;
    expect(
      () => c.choose(() {
        picked = true;
        throw StateError('not reached');
      }, currentAppStillValid: () => false),
      throwsA(scopeChanged()),
    );
    expect(picked, false);
    expect(c.busy, false);
  });
  test('throwing callback before picker is sanitized', () {
    final c = SkillSourceCapture();
    expect(
      () => c.choose(
        () => throw StateError('not reached'),
        currentAppStillValid: () => throw StateError('private App detail'),
      ),
      throwsA(scopeChanged()),
    );
    expect(c.busy, false);
  });
  test('trusted picker activation remains synchronous', () async {
    final c = SkillSourceCapture();
    var picked = false;
    final reader = PendingReader('none');
    final outcome = c.choose(() {
      picked = true;
      return SkillSourceSelection(Future.value(reader));
    }, currentAppStillValid: () => true);
    expect(picked, true);
    expect((await outcome)!.single, 42);
    expect(reader.closes, 1);
  });
  test(
    'drift while picker pending closes late reader without opening',
    () async {
      final c = SkillSourceCapture(),
          selected = Completer<SkillSourceReader?>();
      var live = true;
      final outcome = c.choose(
        () => SkillSourceSelection(selected.future),
        currentAppStillValid: () => live,
      );
      final check = expectLater(outcome, throwsA(scopeChanged()));
      live = false;
      final r = PendingReader('none');
      selected.complete(r);
      await check;
      await c.quiescent;
      expect(r.lengths, 0);
      expect(r.reads, 0);
      expect(r.closes, 1);
      expect(c.busy, false);
    },
  );
  for (final phase in ['length', 'read', 'eof', 'close']) {
    for (final throwing in [false, true]) {
      test(
        'live App ${throwing ? 'exception' : 'drift'} after $phase await never publishes bytes',
        () async {
          final c = SkillSourceCapture(), r = PendingReader(phase);
          var live = true, calls = 0;
          bool current() {
            calls++;
            if (!live && throwing) throw StateError('private state');
            return live;
          }

          final outcome = start(c, r, current);
          // Attach the error observer before resolving the pending boundary.
          final observed = expectLater(outcome, throwsA(scopeChanged()));
          await r.entered.future;
          live = false;
          r.release.complete();
          await observed;
          await c.quiescent;
          expect(r.closes, 1);
          expect(
            r.reads,
            phase == 'length'
                ? 0
                : phase == 'read'
                ? 1
                : 2,
          );
          expect(c.busy, false);
          expect(calls, greaterThan(1));
        },
      );
    }
  }
  test('false predicate latches and cannot revive on close', () async {
    final c = SkillSourceCapture(), r = PendingReader('read');
    var live = true, invalidSamples = 0;
    bool current() {
      if (!live) {
        invalidSamples++;
        return invalidSamples != 1;
      }
      return true;
    }

    final out = start(c, r, current);
    final observed = expectLater(out, throwsA(scopeChanged()));
    await r.entered.future;
    live = false;
    r.release.complete();
    await observed;
    expect(invalidSamples, 1);
    expect(r.reads, 1);
    expect(r.closes, 1);
  });
  test(
    'ABA restored values still fail a trusted monotonic generation comparison',
    () async {
      final c = SkillSourceCapture(), r = PendingReader('length');
      var epoch = 0, scope = 'A';
      final captured = epoch;
      final out = start(c, r, () => epoch == captured && scope == 'A');
      final observed = expectLater(out, throwsA(scopeChanged()));
      await r.entered.future;
      scope = 'B';
      epoch++;
      scope = 'A';
      epoch++;
      r.release.complete();
      await observed;
      expect(r.reads, 0);
    },
  );
  test(
    'ordinary cancel wins while late scope failure drains one operation',
    () async {
      final c = SkillSourceCapture(), r = PendingReader('read');
      var live = true;
      final out = start(c, r, () => live);
      await r.entered.future;
      c.cancel();
      live = false;
      expect(await out, null);
      expect(c.busy, true);
      expect(
        () => start(c, PendingReader('none'), () => true),
        throwsA(
          isA<SkillSourceException>().having((e) => e.reason, 'reason', 'busy'),
        ),
      );
      r.release.complete();
      await c.quiescent;
      expect(c.busy, false);
      expect(r.closes, 1);
      expect(r.reads, 1);
    },
  );
  test(
    'close error plus App drift cannot publish bytes or private errors',
    () async {
      final c = SkillSourceCapture(),
          r = PendingReader('close', failClose: true);
      var live = true;
      final out = start(c, r, () => live);
      final observed = expectLater(out, throwsA(scopeChanged()));
      await r.entered.future;
      live = false;
      r.release.complete();
      await observed;
      expect(r.closes, 1);
    },
  );
  test(
    'busy rejection does not invoke another App predicate or picker',
    () async {
      final c = SkillSourceCapture(),
          selected = Completer<SkillSourceReader?>();
      final out = c.choose(
        () => SkillSourceSelection(selected.future),
        currentAppStillValid: () => true,
      );
      var sampled = false;
      expect(
        () => c.choose(
          () => throw StateError('not reached'),
          currentAppStillValid: () {
            sampled = true;
            return true;
          },
        ),
        throwsA(isA<SkillSourceException>()),
      );
      expect(sampled, false);
      selected.complete(null);
      expect(await out, null);
    },
  );
}
