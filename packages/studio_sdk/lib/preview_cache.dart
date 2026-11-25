import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

final class SourcePreviewFrame {
  factory SourcePreviewFrame(Map<String, dynamic> value) {
    final width = value['width'],
        height = value['height'],
        pixels = value['rgba'];
    if (width is! int ||
        height is! int ||
        width < 1 ||
        height < 1 ||
        width > 128 ||
        height > 128 ||
        pixels is! List ||
        pixels.length != width * height * 4 ||
        pixels.any((v) => v is! int || v < 0 || v > 255)) {
      throw const StudioException('PREVIEW_FRAME_INVALID');
    }
    final pts = BigInt.parse(value['pts'] as String),
        start = BigInt.parse(value['startPts'] as String),
        base = Q.fromJson(value['timeBase']);
    final packets = value['packetsRead'];
    if (packets is! int || packets < 0 || pts < start || base <= Q.of(0)) {
      throw const StudioException('PREVIEW_FRAME_INVALID');
    }
    return SourcePreviewFrame._(
      width,
      height,
      pts,
      start,
      base,
      packets,
      Uint8List.fromList(pixels.cast<int>()).asUnmodifiableView(),
    );
  }
  SourcePreviewFrame._(
    this.width,
    this.height,
    this.pts,
    this.startPts,
    this.timeBase,
    this.packetsRead,
    this.rgba,
  );
  final int width, height, packetsRead;
  final BigInt pts, startPts;
  final Q timeBase;
  final Uint8List rgba;
}

/// Strict retained pixel-byte LRU budget + entry cap, not a total RSS guarantee.
/// No disk/media cache or cross-namespace mutable shared frame references.
final class SourcePreviewCache {
  SourcePreviewCache({this.budgetBytes = 2 * 1024 * 1024}) {
    if (budgetBytes < 0 || budgetBytes > 64 * 1024 * 1024) {
      throw const StudioException('CACHE_BUDGET_INVALID');
    }
  }
  final int budgetBytes;
  int _bytes = 0;
  final _frames = <String, SourcePreviewFrame>{};
  int get bytes => _bytes;
  int get entries => _frames.length;
  SourcePreviewFrame? get(String key) {
    final frame = _frames.remove(key);
    if (frame != null) _frames[key] = frame;
    return frame;
  }

  void put(String key, SourcePreviewFrame frame) {
    final old = _frames.remove(key);
    if (old != null) _bytes -= old.rgba.length;
    if (frame.rgba.length > budgetBytes) return;
    while (_frames.isNotEmpty &&
        (_bytes + frame.rgba.length > budgetBytes || _frames.length >= 256)) {
      final removed = _frames.remove(_frames.keys.first)!;
      _bytes -= removed.rgba.length;
    }
    _frames[key] = frame;
    _bytes += frame.rgba.length;
  }

  void clear() {
    _frames.clear();
    _bytes = 0;
  }
}
