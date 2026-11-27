import 'package:studio_contracts/studio_contracts.dart';

final class CaptionSafeAreaRequest {
  const CaptionSafeAreaRequest({
    required this.safeAreaInsets,
    required this.layoutNormalized,
  });

  /// `brandPolicy.safeArea` as normalized edge insets
  /// `[left, top, right, bottom]` in `[0, 1]`.
  final List<double> safeAreaInsets;

  /// Caption layout box in normalized canvas coordinates
  /// `[left, top, right, bottom]`. This admission does not decode
  /// canvas-pixel `layoutRect` packing or shape glyphs.
  final List<double> layoutNormalized;
}

final class CaptionSafeAreaReceipt {
  const CaptionSafeAreaReceipt({required this.stayedInsideSafeArea});

  final bool stayedInsideSafeArea;
}

/// DEV-PURE I-010 / s4 admission: captions stay inside the inner
/// rectangle defined by `brandPolicy.safeArea` insets, and therefore
/// avoid the unsafe margin bands. This is not a text shaper, not a
/// re-qualification of I-010 sidecar or font-fallback work, and does
/// not open source-interval crop or MP4/preview burn-in.
final class CaptionSafeAreaAdmission {
  bool shaperInvented = false;
  bool i010SidecarRequalified = false;
  bool fontFallbackRequalified = false;
  bool sourceIntervalCropOpened = false;
  bool burnInOpened = false;
  bool lockedCaptionsOverwritten = false;
  bool paidApiCalled = false;

  CaptionSafeAreaReceipt admit(CaptionSafeAreaRequest request) {
    final insets = request.safeAreaInsets;
    if (!_insets(insets)) {
      throw const StudioException('SAFE_AREA_INVALID', 'caption');
    }
    final layout = request.layoutNormalized;
    if (!_box(layout)) {
      throw const StudioException('LAYOUT_RECT_INVALID', 'caption');
    }
    final innerLeft = insets[0];
    final innerTop = insets[1];
    final innerRight = 1 - insets[2];
    final innerBottom = 1 - insets[3];
    if (layout[0] < innerLeft ||
        layout[1] < innerTop ||
        layout[2] > innerRight ||
        layout[3] > innerBottom) {
      throw const StudioException('SAFE_AREA_VIOLATION', 'caption');
    }
    return const CaptionSafeAreaReceipt(stayedInsideSafeArea: true);
  }
}

bool _insets(List<double> insets) {
  if (insets.length != 4) return false;
  if (insets.any((value) => !value.isFinite || value < 0 || value > 1)) {
    return false;
  }
  return insets[0] + insets[2] < 1 && insets[1] + insets[3] < 1;
}

bool _box(List<double> box) {
  if (box.length != 4) return false;
  if (box.any((value) => !value.isFinite)) return false;
  return box[0] < box[2] && box[1] < box[3];
}
