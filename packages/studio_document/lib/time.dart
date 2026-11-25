import 'package:studio_contracts/studio_contracts.dart';

final _minI64 = -(BigInt.one << 63);
final maxI64 = (BigInt.one << 63) - BigInt.one;
final _maxDenominator = BigInt.from(1000000000);

enum Rounding { floor, ceil, tiesToEven }

/// Canonical rational seconds. Every operation uses BigInt before checked narrowing.
final class Q implements Comparable<Q> {
  factory Q(BigInt n, BigInt d) {
    if (d == BigInt.zero) throw const StudioException('TIME_DIVIDE_BY_ZERO');
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = n.gcd(d);
    n ~/= g;
    d ~/= g;
    if (n < _minI64 || n > maxI64 || d > _maxDenominator) {
      throw const StudioException('TIME_OVERFLOW');
    }
    return Q._(n, d);
  }
  const Q._(this.n, this.d);
  factory Q.of(int n, [int d = 1]) => Q(BigInt.from(n), BigInt.from(d));
  factory Q.fromJson(Map<String, dynamic> json) {
    final raw = json['n'];
    final den = json['d'];
    if (raw is! String ||
        !RegExp(r'^(0|-?[1-9][0-9]*)$').hasMatch(raw) ||
        den is! int ||
        den < 1 ||
        den > 1000000000) {
      throw const StudioException('TIME_ENCODING');
    }
    final q = Q(BigInt.parse(raw), BigInt.from(den));
    if (q.n.toString() != raw || q.d.toInt() != den) {
      throw const StudioException('TIME_NON_CANONICAL');
    }
    return q;
  }
  final BigInt n, d;
  Q operator +(Q b) => Q(n * b.d + b.n * d, d * b.d);
  Q operator -(Q b) => Q(n * b.d - b.n * d, d * b.d);
  Q operator *(Q b) => Q(n * b.n, d * b.d);
  Q operator /(Q b) => Q(n * b.d, d * b.n);
  @override
  int compareTo(Q b) => (n * b.d).compareTo(b.n * d);
  bool operator <(Q b) => compareTo(b) < 0;
  bool operator <=(Q b) => compareTo(b) <= 0;
  bool operator >(Q b) => compareTo(b) > 0;
  bool operator >=(Q b) => compareTo(b) >= 0;
  @override
  bool operator ==(Object other) => other is Q && n == other.n && d == other.d;
  @override
  int get hashCode => Object.hash(n, d);
  Map<String, Object> toJson() => {'n': n.toString(), 'd': d.toInt()};
  @override
  String toString() => '$n/$d';
}

/// Round the exact product directly, without first narrowing a transient Q.
BigInt _round(BigInt n, BigInt d, Rounding mode) {
  var floor = n ~/ d;
  var rem = n.remainder(d);
  if (rem.isNegative) {
    floor -= BigInt.one;
    rem += d;
  }
  if (rem == BigInt.zero || mode == Rounding.floor) return floor;
  if (mode == Rounding.ceil) return floor + BigInt.one;
  final cmp = (rem * BigInt.two).compareTo(d);
  return cmp > 0 || (cmp == 0 && floor.isOdd) ? floor + BigInt.one : floor;
}

final class FrameRate {
  FrameRate(this.n, this.d) {
    if (n < 1 || d < 1 || n > 0xffffffff || d > 0xffffffff) {
      throw const StudioException('INVALID_FRAME_RATE');
    }
  }
  final int n, d;
  Q frameTime(BigInt frame) => Q(frame * BigInt.from(d), BigInt.from(n));
  BigInt frameIndex(Q t, Rounding mode) =>
      _round(t.n * BigInt.from(n), t.d * BigInt.from(d), mode);
  Q quantize(Q t, Rounding mode) => frameTime(frameIndex(t, mode));
}

BigInt sampleIndex(Q t, int rate, Rounding mode) {
  if (rate < 1 || rate > 0xffffffff) {
    throw const StudioException('INVALID_SAMPLE_RATE');
  }
  return _round(t.n * BigInt.from(rate), t.d, mode);
}

final class TimeRange {
  TimeRange(this.start, this.duration) {
    if (duration <= Q.of(0)) throw const StudioException('INVALID_RANGE');
    end; // Force checked end overflow at construction, not later during commit.
  }
  final Q start, duration;
  Q get end => start + duration;
  bool overlaps(TimeRange b) => start < b.end && b.start < end;
  TimeRange? intersect(TimeRange b) {
    final s = start > b.start ? start : b.start;
    final e = end < b.end ? end : b.end;
    return s < e ? TimeRange(s, e - s) : null;
  }
}
