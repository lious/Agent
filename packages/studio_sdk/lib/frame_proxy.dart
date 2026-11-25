import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'preview_cache.dart';

/// Ephemeral preview-only RGBA image sequence. Never exported as source or
/// silently injected into ProjectDocument.proxyRefs. Missing -> explicit rebuild.
final class FrameProxy {
  FrameProxy._(
    this.directory,
    this.width,
    this.height,
    this.startPts,
    this.timeBase,
    this.pts,
    this.durations,
    this.frameHashes,
    this.blobHash,
    this.bytes,
  );
  static const pipeline = 'rgba128-pts-v1';
  final Directory directory;
  final int width, height, bytes;
  final BigInt startPts;
  final Q timeBase;
  final List<BigInt> pts, durations;
  final List<String> frameHashes;
  final String blobHash;
  int _readers = 0;
  bool _disposed = false;
  Object? cleanupError;
  File get file => File('${directory.path}/frames.rgba');
  static Future<FrameProxy> admit(
    Directory directory,
    Map<String, dynamic> facts,
  ) async {
    final w = facts['width'], h = facts['height'], table = facts['frames'];
    if (facts['schema'] != 1 ||
        facts['pipeline'] != pipeline ||
        w is! int ||
        h is! int ||
        w < 1 ||
        h < 1 ||
        w > 128 ||
        h > 128 ||
        table is! List ||
        table.isEmpty ||
        table.length > 2048) {
      throw const StudioException('PROXY_MANIFEST_INVALID');
    }
    BigInt integer(dynamic value) {
      if (value is! String || !RegExp(r'^-?[0-9]{1,20}$').hasMatch(value)) {
        throw const StudioException('PROXY_MANIFEST_INVALID');
      }
      final result = BigInt.parse(value);
      if (result < -(BigInt.one << 63) || result >= (BigInt.one << 63)) {
        throw const StudioException('PROXY_MANIFEST_INVALID');
      }
      return result;
    }

    final base = Q.fromJson(facts['timeBase']),
        start = integer(facts['startPts']);
    if (base <= Q.of(0)) throw const StudioException('PROXY_MANIFEST_INVALID');
    final points = <BigInt>[], lengths = <BigInt>[];
    for (final point in table) {
      if (point is! Map) throw const StudioException('PROXY_MANIFEST_INVALID');
      final p = integer(point['pts']), n = integer(point['duration']);
      if (n <= BigInt.zero ||
          (points.isEmpty ? p != start : p <= points.last)) {
        throw const StudioException('PROXY_MANIFEST_INVALID');
      }
      points.add(p);
      lengths.add(n);
    }
    final f = File('${directory.path}/frames.rgba'),
        bytes = w * h * 4 * points.length;
    if (FileSystemEntity.typeSync(f.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const StudioException('PROXY_FILE_INVALID');
    }
    if (bytes > 64 * 1024 * 1024 ||
        facts['bytes'] != bytes ||
        await f.length() != bytes) {
      throw const StudioException('PROXY_LENGTH_MISMATCH');
    }
    final hashes = <String>[];
    final read = await f.open();
    try {
      for (var i = 0; i < points.length; i++) {
        final data = await read.read(w * h * 4);
        if (data.length != w * h * 4) {
          throw const StudioException('PROXY_LENGTH_MISMATCH');
        }
        hashes.add(sha256.convert(data).toString());
      }
    } finally {
      await read.close();
    }
    final hash = 'sha256:${await sha256.bind(f.openRead()).first}';
    return FrameProxy._(
      directory,
      w,
      h,
      start,
      base,
      List.unmodifiable(points),
      List.unmodifiable(lengths),
      List.unmodifiable(hashes),
      hash,
      bytes,
    );
  }

  int indexAt(Q relative) {
    final target = Q(startPts, BigInt.one) * timeBase + relative;
    if (relative < Q.of(0) ||
        target >= Q(pts.last + durations.last, BigInt.one) * timeBase) {
      throw const StudioException('PROXY_TIME_OUT_OF_RANGE');
    }
    var lo = 0, hi = pts.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (Q(pts[mid], BigInt.one) * timeBase <= target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo == 0) throw const StudioException('PROXY_TIME_OUT_OF_RANGE');
    return lo - 1;
  }

  Future<SourcePreviewFrame> read(int index) async {
    if (_disposed) throw const StudioException('PROXY_DISPOSED');
    if (index < 0 || index >= pts.length) {
      throw const StudioException('PROXY_TIME_OUT_OF_RANGE');
    }
    _readers++;
    try {
      if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const StudioException('PROXY_FILE_INVALID');
      }
      final input = await file.open();
      late Uint8List data;
      try {
        if (await input.length() != bytes) {
          throw const StudioException('PROXY_LENGTH_MISMATCH');
        }
        await input.setPosition(index * width * height * 4);
        data = await input.read(width * height * 4);
      } finally {
        await input.close();
      }
      if (data.length != width * height * 4 ||
          sha256.convert(data).toString() != frameHashes[index]) {
        throw const StudioException('PROXY_FRAME_HASH_MISMATCH');
      }
      if (_disposed) throw const StudioException('PROXY_DISPOSED');
      return SourcePreviewFrame({
        'width': width,
        'height': height,
        'rgba': data,
        'pts': pts[index].toString(),
        'startPts': startPts.toString(),
        'timeBase': timeBase.toJson(),
        'packetsRead': 0,
      });
    } finally {
      _readers--;
      _cleanup();
    }
  }

  void dispose() {
    _disposed = true;
    _cleanup();
  }

  void _cleanup() {
    if (_disposed && _readers == 0 && directory.existsSync()) {
      try {
        directory.deleteSync(recursive: true);
      } catch (e) {
        cleanupError = e;
      }
    }
  }
}

final class TimelinePreviewFrame {
  const TimelinePreviewFrame({
    required this.pixels,
    required this.snapshotHash,
    required this.playbackGeneration,
    required this.clockEpoch,
    required this.clockSample,
    required this.clipId,
    required this.assetId,
    required this.proxyIndex,
    required this.gap,
  });
  final SourcePreviewFrame pixels;
  final String snapshotHash, clipId;
  final String? assetId;
  final int playbackGeneration, clockEpoch, clockSample, proxyIndex;
  final bool gap;
}
