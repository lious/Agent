import 'package:studio_contracts/studio_contracts.dart';

final class SystemFontLineBreakRequest {
  const SystemFontLineBreakRequest({
    this.fontRef,
    this.fontHash,
    this.platformSystemFontDefault = false,
  });

  final String? fontRef, fontHash;
  final bool platformSystemFontDefault;
}

final class SystemFontLineBreakReceipt {
  const SystemFontLineBreakReceipt({required this.explicitFont});

  final bool explicitFont;
}

/// DEV-PURE I-010 / s4 admission: caption layout must use an explicit
/// fontRef or font hash, not a platform system-font default that would
/// make line breaks differ across platforms. This is not a text shaper,
/// not a re-qualification of ADR 0019, C.001, C.002, or Increment 2.94
/// CaptionSafeAreaAdmission, and does not open source-interval crop or
/// MP4/preview burn-in.
final class SystemFontLineBreakAdmission {
  bool shaperInvented = false;
  bool i010SidecarRequalified = false;
  bool fontFallbackRequalified = false;
  bool captionSafeAreaRequalified = false;
  bool adr0019Requalified = false;
  bool sourceIntervalCropOpened = false;
  bool burnInOpened = false;
  bool lockedCaptionsOverwritten = false;
  bool deterministicShapingClaimed = false;
  bool paidApiCalled = false;

  SystemFontLineBreakReceipt admit(SystemFontLineBreakRequest request) {
    if (request.platformSystemFontDefault) {
      throw const StudioException('SYSTEM_FONT_DEFAULT_FORBIDDEN', 'font');
    }
    final ref = request.fontRef ?? '';
    final hash = request.fontHash ?? '';
    if (ref.isEmpty && hash.isEmpty) {
      throw const StudioException('FONT_REF_REQUIRED', 'font');
    }
    return const SystemFontLineBreakReceipt(explicitFont: true);
  }
}
