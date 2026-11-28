import 'package:flutter_test/flutter_test.dart';
import 'package:studio_assets/craft/signed_import/source_capture.dart';
import 'package:studio_web/import_fixture_composition.dart';

import 'import_late_reader.dart';

Future<void> until(bool Function() predicate) async {
  for (var i = 0; i < 100; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('controlled gate observation missing');
}

Map counts(LateReaderController c) => c.snapshot['counts'] as Map;
void main() {
  for (final phase in [
    AppImportFixtureReaderBoundary.open,
    AppImportFixtureReaderBoundary.length,
    AppImportFixtureReaderBoundary.read,
  ]) {
    test(
      'controlled ${phase.name}: null cancellation preserves busy until one close',
      () async {
        final capture = SkillSourceCapture();
        final c = LateReaderController(observe: (_) {});
        c.arm(phase);
        final result = c.choose(capture, () => true, () {});
        await until(() => c.snapshot['held'] == true);
        capture.cancel();
        expect(await result, isNull);
        expect(capture.busy, isTrue);
        c.arm(AppImportFixtureReaderBoundary.close);
        expect(counts(c)['armRefusals'], 1);
        c.release();
        c.release();
        await capture.quiescent;
        await until(() => counts(c)['quiescent'] == 1);
        expect(counts(c)['selections'], 1);
        expect(counts(c)['openStarted'], 1);
        expect(counts(c)['openCompleted'], 1);
        expect(counts(c)['closeCompleted'], 1);
        expect(counts(c)['outcomeBytes'], isNull);
        expect(
          counts(c)['readStarted'] ?? 0,
          phase == AppImportFixtureReaderBoundary.read ? 1 : 0,
        );
        expect(counts(c)['eof'] ?? 0, 0);
        expect(c.snapshot['watchdogFired'], isFalse);
        expect(() => counts(c)['selections'] = 2, throwsUnsupportedError);
        capture.dispose();
      },
    );
  }
  test(
    'close gate: natural null precedes close/quiescence and owner change',
    () async {
      final capture = SkillSourceCapture();
      var live = true;
      final c = LateReaderController(observe: (_) {});
      c.arm(AppImportFixtureReaderBoundary.close);
      final result = c.choose(capture, () => live, () {});
      await until(() => c.snapshot['held'] == true);
      expect(counts(c)['readCompleted'], 1);
      expect(counts(c)['eof'], 1);
      expect(c.snapshot['outcome'], 'pending');
      capture.cancel();
      expect(await result, isNull);
      await until(() => counts(c)['outcomeNull'] == 1);
      expect(capture.busy, isTrue);
      expect(counts(c)['closeCompleted'], isNull);
      live = false;
      c.release();
      await capture.quiescent;
      await until(() => counts(c)['quiescent'] == 1);
      final events = c.snapshot['events'] as List;
      expect(
        events.indexOf('outcomeNull'),
        lessThan(events.indexOf('closeCompleted')),
      );
      expect(
        events.indexOf('closeCompleted'),
        lessThan(events.indexOf('quiescent')),
      );
      capture.dispose();
    },
  );
  test(
    'TEST watchdog cancels and releases for cleanup, never success',
    () async {
      final capture = SkillSourceCapture();
      final c = LateReaderController(
        observe: (_) {},
        watchdog: const Duration(milliseconds: 10),
      );
      final result = c.choose(capture, () => true, () {});
      expect(await result, isNull);
      await capture.quiescent;
      await until(() => counts(c)['quiescent'] == 1);
      expect(c.snapshot['watchdogFired'], isTrue);
      expect(counts(c)['watchdog'], 1);
      expect(counts(c)['closeCompleted'], 1);
      expect(counts(c)['outcomeBytes'], isNull);
      capture.dispose();
    },
  );
  test('observer fault cannot replace original capture outcome', () async {
    final capture = SkillSourceCapture();
    final c = LateReaderController(
      observe: (_) => throw StateError('test sink'),
    );
    final result = c.choose(capture, () => true, () {});
    await until(() => c.snapshot['held'] == true);
    capture.cancel();
    expect(await result, isNull);
    c.release();
    await capture.quiescent;
    await until(() => counts(c)['quiescent'] == 1);
    expect(c.snapshot['observerFaults'] as int, greaterThan(0));
    expect(counts(c)['outcomeBytes'], isNull);
    capture.dispose();
  });
}
