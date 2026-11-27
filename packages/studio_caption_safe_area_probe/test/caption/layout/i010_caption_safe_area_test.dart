import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_caption_safe_area_probe/studio_caption_safe_area_probe.dart';
import 'package:test/test.dart';

/// Increment 2.94 official I-010 / s4 leftover: captions stay inside
/// the inner rectangle defined by `brandPolicy.safeArea` insets
/// (they avoid the unsafe margin bands). This file does not invent a
/// text shaper, does not re-qualify I-010 sidecar or font-fallback
/// work, does not open source-interval crop or MP4/preview burn-in,
/// and does not overwrite locked captions. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-010 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('zero insets admit a full-canvas layout; a box inside nonzero insets is admitted', () {
    final admission = CaptionSafeAreaAdmission();
    final zero = admission.admit(
      const CaptionSafeAreaRequest(
        safeAreaInsets: [0, 0, 0, 0],
        layoutNormalized: [0, 0, 1, 1],
      ),
    );
    expect(zero.stayedInsideSafeArea, isTrue);
    final inset = admission.admit(
      const CaptionSafeAreaRequest(
        safeAreaInsets: [0.1, 0.1, 0.1, 0.1],
        layoutNormalized: [0.1, 0.8, 0.9, 0.9],
      ),
    );
    expect(inset.stayedInsideSafeArea, isTrue);
  });

  test('a layout that enters the inset margins is refused; a degenerate safe area is refused', () {
    final admission = CaptionSafeAreaAdmission();
    expect(
      () => admission.admit(
        const CaptionSafeAreaRequest(
          safeAreaInsets: [0.1, 0.1, 0.1, 0.1],
          layoutNormalized: [0, 0.8, 0.9, 0.9],
        ),
      ),
      code('SAFE_AREA_VIOLATION'),
    );
    expect(
      () => admission.admit(
        const CaptionSafeAreaRequest(
          safeAreaInsets: [0.5, 0, 0.5, 0],
          layoutNormalized: [0.2, 0.2, 0.3, 0.3],
        ),
      ),
      code('SAFE_AREA_INVALID'),
    );
    expect(
      () => admission.admit(
        const CaptionSafeAreaRequest(
          safeAreaInsets: [0.1, 0.1, 0.1, 0.1],
          layoutNormalized: [0.8, 0.8, 0.2, 0.9],
        ),
      ),
      code('LAYOUT_RECT_INVALID'),
    );
  });

  test('a text shaper, I-010 sidecar or font-fallback re-qualification, source-interval crop, and burn-in stay closed', () {
    final admission = CaptionSafeAreaAdmission();
    expect(admission.shaperInvented, isFalse);
    expect(admission.i010SidecarRequalified, isFalse);
    expect(admission.fontFallbackRequalified, isFalse);
    expect(admission.sourceIntervalCropOpened, isFalse);
    expect(admission.burnInOpened, isFalse);
    expect(admission.lockedCaptionsOverwritten, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
