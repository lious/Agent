// TEST ONLY controlled first-read unit cases, not File/GTK qualification.
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_assets/craft/signed_import/source_capture.dart';

import 'import_native_reader.dart';

Future<void> waitHeld(NativeReaderController controller) async {
  for (var i = 0; i < 40; i++) {
    if (controller.snapshot['held'] == true) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('controlled reader never entered the first-read hold');
}

void main() {
  test(
    'natural null stays busy until close and refuses a second arm',
    () async {
      final controller = NativeReaderController(observe: (_) {});
      final capture = SkillSourceCapture();
      controller.arm();
      final future = controller.choose(capture, () => true, () {});
      await waitHeld(controller);
      expect(capture.busy, true);
      expect(controller.snapshot['outcome'], 'pending');
      controller.arm();
      capture.cancel();
      expect(await future, isNull);
      expect(capture.busy, true);
      expect((controller.snapshot['counts'] as Map)['closeCompleted'], isNull);
      controller.release();
      controller.release();
      await capture.quiescent;
      final counts = Map<String, int>.from(
        controller.snapshot['counts'] as Map,
      );
      expect(counts['selections'], 1);
      expect(counts['selected'], 1);
      expect(counts['openStarted'], 1);
      expect(counts['openCompleted'], 1);
      expect(counts['lengthStarted'], 1);
      expect(counts['lengthCompleted'], 1);
      expect(counts['readStarted'], 1);
      expect(counts['readCompleted'], 1);
      expect(counts['closeStarted'], 1);
      expect(counts['closeCompleted'], 1);
      expect(counts['outcomeNull'], 1);
      expect(counts['quiescent'], 1);
      expect(counts['manualReleases'], 1);
      expect(counts['ignoredReleases'], 1);
      expect(counts['armRefusals'], 1);
      expect(counts['outcomeBytes'], isNull);
      expect(counts['eof'], isNull);
      expect(controller.snapshot['outcome'], 'null');
      expect(controller.snapshot['busy'], false);
      expect(controller.snapshot['watchdogFired'], false);
      expect(
        Map.of(controller.snapshot['counts'] as Map),
        isNot(same(controller.snapshot['counts'])),
      );
    },
  );

  test('repeat release is ignored before the first hold', () {
    final controller = NativeReaderController(observe: (_) {});
    controller.release();
    expect((controller.snapshot['counts'] as Map)['ignoredReleases'], 1);
    expect((controller.snapshot['counts'] as Map)['manualReleases'], isNull);
  });

  test(
    'short TEST watchdog cancels then drains without byte success',
    () async {
      final controller = NativeReaderController(
        observe: (_) {},
        watchdog: const Duration(milliseconds: 20),
      );
      final capture = SkillSourceCapture();
      controller.arm();
      final future = controller.choose(capture, () => true, () {});
      expect(await future, isNull);
      await capture.quiescent;
      expect(controller.snapshot['watchdogFired'], true);
      expect(controller.snapshot['outcome'], 'null');
      final counts = Map<String, int>.from(
        controller.snapshot['counts'] as Map,
      );
      expect(counts['watchdog'], 1);
      expect(counts['outcomeBytes'], isNull);
      expect(counts['quiescent'], 1);
    },
  );

  test(
    'observer sink faults do not replace the original null outcome',
    () async {
      final controller = NativeReaderController(
        observe: (_) => throw StateError('observer'),
      );
      final capture = SkillSourceCapture();
      controller.arm();
      final future = controller.choose(capture, () => true, () {});
      await waitHeld(controller);
      capture.cancel();
      expect(await future, isNull);
      expect(capture.busy, true);
      controller.release();
      await capture.quiescent;
      expect(controller.snapshot['outcome'], 'null');
      expect((controller.snapshot['observerFaults'] as int) > 0, true);
      expect((controller.snapshot['counts'] as Map)['outcomeBytes'], isNull);
    },
  );

  test(
    'choose forwards the live guard, selected callback and original future',
    () async {
      var selected = 0, guarded = 0;
      final capture = SkillSourceCapture();
      final controller = NativeReaderController(observe: (_) {});
      controller.arm();
      final returned = controller.choose(capture, () {
        ++guarded;
        return true;
      }, () => ++selected);
      await waitHeld(controller);
      expect(selected, 1);
      expect(guarded, greaterThan(0));
      capture.cancel();
      expect(await returned, isNull);
      controller.release();
      await capture.quiescent;
    },
  );
}
