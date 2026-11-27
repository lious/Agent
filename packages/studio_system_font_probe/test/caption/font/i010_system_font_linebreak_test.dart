import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_system_font_probe/studio_system_font_probe.dart';
import 'package:test/test.dart';

/// Increment 2.95 official I-010 / s4 leftover: caption layout must
/// use an explicit fontRef or font hash, not a platform system-font
/// default that would make line breaks differ across platforms.
///
/// This file does not invent a text shaper, does not re-qualify I-010
/// sidecar or font-fallback work, ADR 0019, C.001, C.002, or Increment
/// 2.94 CaptionSafeAreaAdmission, does not open source-interval crop
/// or MP4/preview burn-in, does not overwrite locked captions, and
/// does not claim deterministic shaping. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-010 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('an explicit fontRef or font hash is admitted; a platform system-font default is refused', () {
    final admission = SystemFontLineBreakAdmission();
    final byRef = admission.admit(
      const SystemFontLineBreakRequest(fontRef: 'font:licensed-sans'),
    );
    expect(byRef.explicitFont, isTrue);
    final byHash = admission.admit(
      const SystemFontLineBreakRequest(fontHash: 'sha256:font-bytes'),
    );
    expect(byHash.explicitFont, isTrue);
    expect(
      () => admission.admit(
        const SystemFontLineBreakRequest(
          fontRef: 'font:licensed-sans',
          platformSystemFontDefault: true,
        ),
      ),
      code('SYSTEM_FONT_DEFAULT_FORBIDDEN'),
    );
  });

  test('layout without an explicit fontRef or font hash is refused', () {
    final admission = SystemFontLineBreakAdmission();
    expect(
      () => admission.admit(const SystemFontLineBreakRequest()),
      code('FONT_REF_REQUIRED'),
    );
  });

  test('a text shaper, sidecar or font-fallback re-qualification, safe-area re-reading, and burn-in stay closed', () {
    final admission = SystemFontLineBreakAdmission();
    expect(admission.shaperInvented, isFalse);
    expect(admission.i010SidecarRequalified, isFalse);
    expect(admission.fontFallbackRequalified, isFalse);
    expect(admission.captionSafeAreaRequalified, isFalse);
    expect(admission.adr0019Requalified, isFalse);
    expect(admission.sourceIntervalCropOpened, isFalse);
    expect(admission.burnInOpened, isFalse);
    expect(admission.lockedCaptionsOverwritten, isFalse);
    expect(admission.deterministicShapingClaimed, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
