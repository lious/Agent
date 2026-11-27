import 'dart:math' as math;

import 'package:studio_contracts/studio_contracts.dart';

/// Pixel-center point in source or model space.
final class SrcPoint {
  const SrcPoint(this.x, this.y);
  final double x, y;

  double distanceTo(SrcPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

final class SourceRoi {
  const SourceRoi(this.x, this.y, this.width, this.height);
  final double x, y, width, height;
}

enum EraseMode { removeAndFill, alphaOnly }

/// Official s8p viewport/ROI/orientation mapper. This is not a SAM
/// runtime and not a real inpainting engine.
final class CoordinateMapper {
  static const modelLongSide = 1024;

  const CoordinateMapper({
    required this.rawWidth,
    required this.rawHeight,
    required this.orientation,
    required this.roi,
  });

  final int rawWidth, rawHeight, orientation;
  final SourceRoi roi;

  int get uprightWidth => orientation >= 5 ? rawHeight : rawWidth;
  int get uprightHeight => orientation >= 5 ? rawWidth : rawHeight;

  int get resizedWidth {
    final longSide = math.max(roi.width, roi.height);
    return (roi.width * modelLongSide / longSide).round();
  }

  int get resizedHeight {
    final longSide = math.max(roi.width, roi.height);
    return (roi.height * modelLongSide / longSide).round();
  }

  int get padLeft => 0;
  int get padTop => 0;

  SrcPoint rawToUpright(SrcPoint raw) =>
      _orient(raw, rawWidth, rawHeight, orientation, inverse: false);

  SrcPoint uprightToRaw(SrcPoint upright) =>
      _orient(upright, uprightWidth, uprightHeight, orientation, inverse: true);

  SrcPoint uprightToModel(SrcPoint source) {
    return SrcPoint(
      (source.x - roi.x) * resizedWidth / roi.width + padLeft,
      (source.y - roi.y) * resizedHeight / roi.height + padTop,
    );
  }

  SrcPoint modelToUpright(SrcPoint model) {
    // Inverse uses rw/newW and rh/newH separately.
    return SrcPoint(
      roi.x + (model.x - padLeft) * roi.width / resizedWidth,
      roi.y + (model.y - padTop) * roi.height / resizedHeight,
    );
  }

  SrcPoint rawToModel(SrcPoint raw) => uprightToModel(rawToUpright(raw));

  SrcPoint modelToRaw(SrcPoint model) => uprightToRaw(modelToUpright(model));

  SrcPoint _orient(
    SrcPoint point,
    int width,
    int height,
    int orientation, {
    required bool inverse,
  }) {
    final x = point.x;
    final y = point.y;
    final w = width.toDouble();
    final h = height.toDouble();
    final code = inverse ? _inverseOrientation(orientation) : orientation;
    switch (code) {
      case 1:
        return SrcPoint(x, y);
      case 2:
        return SrcPoint(w - x, y);
      case 3:
        return SrcPoint(w - x, h - y);
      case 4:
        return SrcPoint(x, h - y);
      case 5:
        return SrcPoint(y, x);
      case 6:
        return SrcPoint(h - y, x);
      case 7:
        return SrcPoint(h - y, w - x);
      case 8:
        return SrcPoint(y, w - x);
      default:
        throw const StudioException('MASK_OUT_OF_BOUNDS', 'orientation');
    }
  }

  int _inverseOrientation(int orientation) {
    const inverse = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 8, 7: 7, 8: 6};
    return inverse[orientation] ?? orientation;
  }
}

final class MaskVersion {
  MaskVersion({
    required this.id,
    required this.version,
    required this.sourceFrameHash,
    this.lockedTileIds = const [],
    this.uprightPoints = const [],
  }) {
    requireId(id);
  }

  final String id, sourceFrameHash;
  final int version;
  final List<String> lockedTileIds;
  final List<SrcPoint> uprightPoints;
}

final class EraseAcceptReceipt {
  EraseAcceptReceipt({
    required this.newLayerId,
    required this.originalHash,
    required this.transactionCount,
    required this.newLayerAttached,
    required this.calledInpaint,
    required this.binaryMaskTreatedAsMatting,
    required this.inferredBackgroundIsFact,
  });

  final String newLayerId, originalHash;
  final int transactionCount;
  final bool newLayerAttached,
      calledInpaint,
      binaryMaskTreatedAsMatting,
      inferredBackgroundIsFact;
}

/// DEV-PURE I-043 MaskService / EraseLayer. Does not invent
/// auto-segmentation or a real inpainting engine.
final class EraseLayerSession {
  EraseLayerSession({required this.originalHash, MaskVersion? mask})
    : mask =
          mask ??
          MaskVersion(id: 'mask-1', version: 1, sourceFrameHash: originalHash);

  final String originalHash;
  MaskVersion mask;
  String? attachedLayerId;
  int transactionCount = 0;
  int documentWrites = 0;
  int userLayersWritten = 0;
  bool quarantined = false;
  bool originalDeleted = false;
  bool autoSegmentationInvented = false;
  bool inpaintEngineInvented = false;
  bool v011Claimed = false;
  bool submitted = false;
  bool paidApiCalled = false;

  MaskVersion refine({
    required String sourceFrameHash,
    required List<String> lockedTileIds,
    List<String> targetTileIds = const [],
    List<SrcPoint> uprightPoints = const [],
  }) {
    if (sourceFrameHash != mask.sourceFrameHash) {
      throw const StudioException('MASK_SOURCE_CHANGED', 'refine');
    }
    final locked = {...mask.lockedTileIds, ...lockedTileIds};
    if (targetTileIds.any(locked.contains)) {
      throw const StudioException('MASK_LOCK_CONFLICT', 'refine');
    }
    mask = MaskVersion(
      id: mask.id,
      version: mask.version + 1,
      sourceFrameHash: mask.sourceFrameHash,
      lockedTileIds: locked.toList(),
      uprightPoints: uprightPoints.isEmpty ? mask.uprightPoints : uprightPoints,
    );
    documentWrites = 0;
    return mask;
  }

  void groundWithText({required bool grounderInstalled}) {
    if (!grounderInstalled) {
      throw const StudioException('GROUNDING_UNAVAILABLE', 'textSelect');
    }
  }

  void claimLlmBoxesAsGrounding() {
    throw const StudioException('GROUNDING_UNAVAILABLE', 'llmBoxes');
  }

  void claimBinaryMaskAsMatting() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'binaryMatting');
  }

  void claimConfidenceAsPhysicalAlpha() {
    throw const StudioException(
      'UNSUPPORTED_EDIT_TECHNIQUE',
      'confidenceAlpha',
    );
  }

  EraseAcceptReceipt propose({
    required EraseMode mode,
    bool packVerified = false,
    bool labelClassicAsIntelligent = false,
  }) {
    if (mode == EraseMode.removeAndFill) {
      if (!packVerified && labelClassicAsIntelligent) {
        throw const StudioException(
          'UNSUPPORTED_EDIT_TECHNIQUE',
          'classicMislabel',
        );
      }
      if (!packVerified) {
        throw const StudioException('MODEL_ABI_UNVERIFIED', 'inpaint');
      }
    }
    documentWrites = 0;
    submitted = false;
    return EraseAcceptReceipt(
      newLayerId: 'layer-candidate',
      originalHash: originalHash,
      transactionCount: 0,
      newLayerAttached: false,
      calledInpaint: false,
      binaryMaskTreatedAsMatting: false,
      inferredBackgroundIsFact: false,
    );
  }

  EraseAcceptReceipt accept({required EraseMode mode}) {
    if (mode == EraseMode.removeAndFill) {
      throw const StudioException('MODEL_ABI_UNVERIFIED', 'inpaint');
    }
    attachedLayerId = 'layer-erase-1';
    transactionCount = 1;
    userLayersWritten = 1;
    documentWrites = 0;
    submitted = false;
    return EraseAcceptReceipt(
      newLayerId: attachedLayerId!,
      originalHash: originalHash,
      transactionCount: transactionCount,
      newLayerAttached: true,
      calledInpaint: false,
      binaryMaskTreatedAsMatting: false,
      inferredBackgroundIsFact: false,
    );
  }

  void undo() {
    attachedLayerId = null;
    userLayersWritten = 0;
    originalDeleted = false;
    documentWrites = 0;
  }

  void lateCancel() {
    quarantined = true;
    userLayersWritten = 0;
    attachedLayerId = null;
    documentWrites = 0;
  }
}

/// Official s8p golden: ROI(100,50,1000,500), source (600,300) -> model (512,256).
CoordinateMapper officialRoiMapper({int orientation = 1}) {
  return CoordinateMapper(
    rawWidth: orientation >= 5 ? 600 : 1200,
    rawHeight: orientation >= 5 ? 1200 : 600,
    orientation: orientation,
    roi: const SourceRoi(100, 50, 1000, 500),
  );
}
