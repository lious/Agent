import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_still_image_clip_probe/studio_still_image_clip_probe.dart';
import 'package:test/test.dart';

/// Increment 2.96 official I-008 / s4 leftover: an imageDocument or
/// image Asset clip uses `streamId=null`, a synthesized
/// `[0, Clip.duration)` static sampling domain, and linear 1x. Video
/// availableRange rules must not refuse a still.
///
/// This file does not re-qualify ADR 0108 Ken Burns transform
/// keyframes, I-026 leftovers, or I-008 leftover-acceptance /
/// keyframe suites. Ken Burns stays transform keyframes, not video
/// generation. This is not a V-003 measurement and does not invent an
/// unregistered plugin. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-008 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('an imageDocument or image Asset clip is admitted with a null streamId and a static 1x domain', () {
    final admission = StillImageClipAdmission();
    final document = admission.admit(
      const StillImageClipRequest(sourceKind: 'imageDocument'),
    );
    expect(document.streamIdNull, isTrue);
    expect(document.staticSamplingDomain, isTrue);
    final asset = admission.admit(
      const StillImageClipRequest(sourceKind: 'image'),
    );
    expect(asset.streamIdNull, isTrue);
    expect(
      () => admission.admit(
        const StillImageClipRequest(
          sourceKind: 'image',
          videoAvailableRangeApplied: true,
        ),
      ),
      code('VIDEO_AVAILABLE_RANGE_ON_STILL'),
    );
  });

  test('a still clip with a streamId, or a non-static / non-1x source domain, is refused', () {
    final admission = StillImageClipAdmission();
    expect(
      () => admission.admit(
        const StillImageClipRequest(
          sourceKind: 'imageDocument',
          streamId: 'video-stream',
        ),
      ),
      code('SOURCE_STREAM_MISMATCH'),
    );
    expect(
      () => admission.admit(
        const StillImageClipRequest(sourceKind: 'image', linear1x: false),
      ),
      code('STATIC_SOURCE_DOMAIN_INVALID'),
    );
    expect(
      () => admission.admit(
        const StillImageClipRequest(
          sourceKind: 'imageDocument',
          sourceRangeIsStaticDomain: false,
        ),
      ),
      code('STATIC_SOURCE_DOMAIN_INVALID'),
    );
    expect(
      () => admission.admit(const StillImageClipRequest(sourceKind: 'video')),
      code('STILL_IMAGE_KIND_REQUIRED'),
    );
  });

  test(
    'Ken Burns, I-026 leftovers, I-008 keyframe suites, and V-003 stay closed',
    () {
      final admission = StillImageClipAdmission();
      expect(admission.kenBurnsRequalified, isFalse);
      expect(admission.i026Requalified, isFalse);
      expect(admission.i008KeyframeRequalified, isFalse);
      expect(admission.videoGenerationInvented, isFalse);
      expect(admission.v003Claimed, isFalse);
      expect(admission.unregisteredPluginInvented, isFalse);
      expect(admission.paidApiCalled, isFalse);
    },
  );
}
