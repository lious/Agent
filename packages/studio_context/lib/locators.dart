import 'package:studio_contracts/studio_contracts.dart';

enum LocatorKind { text, page, image, time }

/// Traceable evidence locator. bbox is origin-top-left and normalized 0..1.
final class EvidenceLocator {
  EvidenceLocator({
    required this.kind,
    required this.sourceId,
    required this.version,
    this.startByte,
    this.endByte,
    this.page,
    this.bbox,
    this.streamId,
    this.startPtsMs,
    this.endPtsMs,
    this.sampleStart,
    this.sampleEnd,
  }) {
    requireId(sourceId);
    if (kind == LocatorKind.text) {
      if (startByte == null || endByte == null || endByte! < startByte!) {
        throw const StudioException('INVALID_ID', 'text-span');
      }
    }
    if (kind == LocatorKind.page && (page == null || page! < 1)) {
      throw const StudioException('INVALID_ID', 'page');
    }
    if (kind == LocatorKind.image && (bbox == null || bbox!.length != 4)) {
      throw const StudioException('INVALID_ID', 'bbox');
    }
    if (kind == LocatorKind.time && (startPtsMs == null || endPtsMs == null)) {
      throw const StudioException('INVALID_ID', 'pts');
    }
    if (bbox != null) {
      final x = bbox![0], y = bbox![1], w = bbox![2], h = bbox![3];
      if (w <= 0 || h <= 0 || x < 0 || y < 0 || x + w > 1 || y + h > 1) {
        throw const StudioException('INVALID_ID', 'bbox-range');
      }
    }
  }

  final LocatorKind kind;
  final String sourceId;
  final int version;
  final int? startByte, endByte, page;
  final List<num>? bbox;
  final String? streamId;
  final int? startPtsMs, endPtsMs, sampleStart, sampleEnd;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'sourceId': sourceId,
    'version': version,
    'startByte': startByte,
    'endByte': endByte,
    'page': page,
    'bbox': bbox,
    'streamId': streamId,
    'startPtsMs': startPtsMs,
    'endPtsMs': endPtsMs,
    'sampleStart': sampleStart,
    'sampleEnd': sampleEnd,
  };
}
