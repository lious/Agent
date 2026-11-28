import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:studio_assets/craft/signed_import/source_capture.dart';
import 'package:test/test.dart';

final class Reader implements SkillSourceReader {
  Reader(
    this.size, {
    int? declared,
    this.partial = 65536,
    this.failRead = false,
    this.failLength = false,
    this.failClose = false,
  }) : declared = declared ?? size;
  final int size, declared, partial;
  final bool failRead, failLength, failClose;
  int reads = 0, closes = 0, lengths = 0, maxRequested = 0;
  Completer<int>? lengthGate;
  Completer<Uint8List>? readGate;
  Completer<void>? closeGate;
  Uint8List? last;
  @override
  Future<int> length() async {
    lengths++;
    if (failLength) throw StateError('private path');
    return lengthGate == null ? declared : await lengthGate!.future;
  }

  @override
  Future<Uint8List> read(int start, int end) async {
    reads++;
    maxRequested = end - start > maxRequested ? end - start : maxRequested;
    if (failRead) throw StateError('private bytes');
    if (readGate != null) return readGate!.future;
    if (start >= size) return Uint8List(0);
    final length = [
      end - start,
      size - start,
      partial,
    ].reduce((a, b) => a < b ? a : b);
    last = Uint8List.fromList(
      List<int>.generate(length, (i) => (start + i) % 251),
    );
    return last!;
  }

  @override
  Future<void> close() async {
    closes++;
    if (closeGate != null) await closeGate!.future;
    if (failClose) throw StateError('private filename');
  }
}

Matcher failure(String reason) => throwsA(
  isA<SkillSourceException>().having(
    (e) => e.reason,
    'safe local reason',
    reason,
  ),
);
Future<Uint8List?> load(SkillSourceCapture c, Reader r) =>
    c.choose(() => SkillSourceSelection(Future.value(r)));

void main() {
  for (final size in [0, 1, 65535, 65536, 65537, 4194303, 4194304]) {
    test('exact capture and EOF sentinel $size', () async {
      final c = SkillSourceCapture(), r = Reader(size);
      final bytes = await load(c, r);
      expect(bytes!.length, size);
      expect(r.maxRequested, lessThanOrEqualTo(65536));
      expect(r.closes, 1);
      expect(c.busy, false);
      if (size > 0) {
        expect(bytes.last, (size - 1) % 251);
        expect(() => bytes[0] = 3, throwsUnsupportedError);
      }
    });
  }
  for (final mode in [
    'declared',
    'growth',
    'changed',
    'read',
    'length',
    'close',
  ]) {
    test('bounded rejection $mode', () async {
      final r = switch (mode) {
        'declared' => Reader(0, declared: 4194305),
        'growth' => Reader(4194305, declared: 4194304),
        'changed' => Reader(3, declared: 4),
        'read' => Reader(3, failRead: true),
        'length' => Reader(3, failLength: true),
        _ => Reader(3, failClose: true),
      };
      final c = SkillSourceCapture();
      await expectLater(
        load(c, r),
        failure(
          ['declared', 'growth'].contains(mode)
              ? 'limit'
              : mode == 'changed'
              ? 'changed'
              : 'unreadable',
        ),
      );
      expect(r.closes, 1);
      expect(c.busy, false);
      if (mode == 'declared') expect(r.reads, 0);
    });
  }
  test('partial reads and independent copies', () async {
    final r = Reader(200, partial: 7);
    final c = SkillSourceCapture();
    final bytes = (await load(c, r))!;
    r.last!.fillRange(0, r.last!.length, 0);
    expect(bytes.last, 199);
    expect(r.reads, greaterThan(20));
  });
  test(
    'single operation, cancellation, late reader closes without opening',
    () async {
      final c = SkillSourceCapture(), picked = Completer<SkillSourceReader?>();
      final result = c.choose(() => SkillSourceSelection(picked.future));
      expect(c.busy, true);
      expect(
        () => c.choose(() => throw StateError('must not select')),
        failure('busy'),
      );
      c.cancel();
      expect(await result, null);
      expect(c.busy, true);
      final r = Reader(4);
      picked.complete(r);
      await c.quiescent;
      expect(r.lengths, 0);
      expect(r.reads, 0);
      expect(r.closes, 1);
      expect(c.busy, false);
      expect((await load(c, Reader(2)))!.length, 2);
    },
  );
  test(
    'terminal dispose detaches selector but does not invent picker settlement',
    () async {
      final c = SkillSourceCapture(), picked = Completer<SkillSourceReader?>();
      var disposed = 0;
      final result = c.choose(
        () => SkillSourceSelection(picked.future, dispose: () => disposed++),
      );
      c.dispose();
      c.dispose();
      expect(await result, null);
      expect(disposed, 1);
      expect(c.busy, true);
      expect(
        () => c.choose(() => throw StateError('never')),
        failure('disposed'),
      );
      picked.complete(null);
      await c.quiescent;
      expect(c.busy, false);
    },
  );
  test('picker cancel and picker failure have no reader', () async {
    final c = SkillSourceCapture();
    expect(
      await c.choose(() => SkillSourceSelection(Future.value(null))),
      null,
    );
    await expectLater(
      c.choose(() => throw StateError('/private/name')),
      failure('selectionFailed'),
    );
    expect(c.busy, false);
  });
  for (final phase in ['length', 'read', 'close']) {
    test('exact 30000ms deadline and quiescence during $phase', () {
      fakeAsync((clock) {
        final c = SkillSourceCapture(), r = Reader(1);
        if (phase == 'length') r.lengthGate = Completer<int>();
        if (phase == 'read') r.readGate = Completer<Uint8List>();
        if (phase == 'close') r.closeGate = Completer<void>();
        String? error;
        load(c, r).then<void>(
          (_) => fail('must time out'),
          onError: (Object e) {
            error = (e as SkillSourceException).reason;
          },
        );
        clock.flushMicrotasks();
        clock.elapse(const Duration(milliseconds: 29999));
        expect(error, null);
        clock.elapse(const Duration(milliseconds: 1));
        expect(error, 'deadline');
        expect(c.busy, true);
        expect(
          () => c.choose(() => throw StateError('never')),
          failure('busy'),
        );
        if (phase == 'length') r.lengthGate!.complete(1);
        if (phase == 'read') r.readGate!.complete(Uint8List.fromList([1]));
        if (phase == 'close') r.closeGate!.complete();
        clock.flushMicrotasks();
        expect(c.busy, false);
        expect(r.closes, 1);
      });
    });
  }
  test('human picker time not a read deadline', () {
    fakeAsync((clock) {
      final c = SkillSourceCapture(), picked = Completer<SkillSourceReader?>();
      var done = false;
      c
          .choose(() => SkillSourceSelection(picked.future))
          .then((_) => done = true);
      clock.elapse(const Duration(minutes: 2));
      expect(done, false);
      expect(c.busy, true);
      picked.complete(Reader(1));
      clock.flushMicrotasks();
      expect(done, true);
      expect(c.busy, false);
    });
  });
  for (final phase in ['length', 'read', 'close']) {
    test('invalidate pending $phase produces no bytes and drains', () async {
      final c = SkillSourceCapture(), r = Reader(1);
      if (phase == 'length') r.lengthGate = Completer<int>();
      if (phase == 'read') r.readGate = Completer<Uint8List>();
      if (phase == 'close') r.closeGate = Completer<void>();
      final f = load(c, r);
      await Future<void>.delayed(Duration.zero);
      c.cancel();
      expect(await f, null);
      expect(c.busy, true);
      if (phase == 'length') r.lengthGate!.complete(1);
      if (phase == 'read') r.readGate!.complete(Uint8List.fromList([1]));
      if (phase == 'close') r.closeGate!.complete();
      await c.quiescent;
      expect(r.closes, 1);
      expect(c.busy, false);
    });
  }
}
