import 'dart:math';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

void main() {
  test('10000 exact rational arithmetic and JSON roundtrips', () {
    final random = Random(801);
    for (var i = 0; i < 10000; i++) {
      final a = Q.of(random.nextInt(200000) - 100000, random.nextInt(1000) + 1);
      final b = Q.of(random.nextInt(200000) - 100000, random.nextInt(1000) + 1);
      expect((a + b) - b, a);
      expect(Q.fromJson(a.toJson()), a);
      expect(a.compareTo(b), -(b.compareTo(a)));
    }
  });
  test(
    '300 frames at NTSC are 10.01 seconds and no cumulative sample drift',
    () {
      final fps = FrameRate(30000, 1001);
      expect(fps.frameTime(BigInt.from(300)), Q.of(1001, 100));
      var samples = BigInt.zero;
      for (var i = 0; i < 10000; i++) {
        samples +=
            sampleIndex(
              fps.frameTime(BigInt.from(i + 1)),
              48000,
              Rounding.tiesToEven,
            ) -
            sampleIndex(
              fps.frameTime(BigInt.from(i)),
              48000,
              Rounding.tiesToEven,
            );
      }
      expect(
        samples,
        sampleIndex(
          fps.frameTime(BigInt.from(10000)),
          48000,
          Rounding.tiesToEven,
        ),
      );
    },
  );
  test('negative and positive ties to even, floor and ceil', () {
    final fps = FrameRate(1, 1);
    for (final pair in [(-5, -2), (-3, -2), (-1, 0), (1, 0), (3, 2), (5, 2)]) {
      expect(
        fps.frameIndex(Q.of(pair.$1, 2), Rounding.tiesToEven),
        BigInt.from(pair.$2),
      );
    }
    expect(fps.frameIndex(Q.of(-1, 3), Rounding.floor), BigInt.from(-1));
    expect(fps.frameIndex(Q.of(-1, 3), Rounding.ceil), BigInt.zero);
  });
  test('canonical wire rejects noncanonical, overflow and divide by zero', () {
    for (final value in [
      {'n': '2', 'd': 4},
      {'n': '-0', 'd': 1},
      {'n': '0', 'd': 2},
      {'n': '9223372036854775808', 'd': 1},
      {'n': '1', 'd': 0},
    ]) {
      expect(() => Q.fromJson(value), throwsA(isA<StudioException>()));
    }
    expect(
      () => Q(maxI64 + BigInt.one, BigInt.one),
      throwsA(isA<StudioException>()),
    );
    expect(() => Q.of(1, 1000000001), throwsA(isA<StudioException>()));
    expect(() => Q.of(1, 0), throwsA(isA<StudioException>()));
    expect(() => Q.of(1) / Q.of(0), throwsA(isA<StudioException>()));
  });
  test('half-open intervals and checked end', () {
    final a = TimeRange(Q.of(0), Q.of(1)), b = TimeRange(Q.of(1), Q.of(1));
    expect(a.overlaps(b), false);
    expect(a.intersect(b), null);
    expect(a.intersect(TimeRange(Q.of(1, 2), Q.of(1)))!.duration, Q.of(1, 2));
    expect(() => TimeRange(Q.of(0), Q.of(0)), throwsA(isA<StudioException>()));
    expect(
      () => TimeRange(Q(maxI64, BigInt.one), Q.of(1)),
      throwsA(isA<StudioException>()),
    );
  });
  test('frame rate and sample rate bounds', () {
    expect(() => FrameRate(0, 1), throwsA(isA<StudioException>()));
    expect(() => FrameRate(1, 0x100000000), throwsA(isA<StudioException>()));
    expect(
      () => sampleIndex(Q.of(1), 0, Rounding.floor),
      throwsA(isA<StudioException>()),
    );
  });
}
