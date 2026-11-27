import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_export/studio_export.dart';
import 'package:test/test.dart';

/// Increment 2.72 official I-024 leftover: smart render is not the
/// default, mixed stream-copy is disabled, preview screenshots are
/// not exports, and a missing encoder or full disk fails explicitly.
/// Changing HDR, fps, or upload needs a new approval. This file does
/// not invent a muxer, does not claim a 60s golden or 1-frame/20ms
/// achievement, does not re-qualify already-official
/// audio_export_test / local_video_test cancel and revision suites,
/// does not re-qualify V-004 Pulse or drop-disclosure work, does not
/// start I-059, I-061, or I-055, and does not mark I-037, I-038,
/// V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056,
/// I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048,
/// V-006, I-058, or V-004 complete. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. V-003 stays
/// unclaimed. I-024 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('smart render is not the default and mixed stream-copy is disabled', () {
    final export = ExportService();
    expect(export.smartRenderDefault, isFalse);
    final preview = export.preview(const ExportPlan());
    expect(preview.smartRenderDefault, isFalse);
    expect(preview.reencodeRequired, isTrue);
    expect(preview.published, isFalse);
    expect(preview.fakeSuccess, isFalse);
    expect(
      () => export.preview(const ExportPlan(smartRender: true)),
      code('SMART_RENDER_NOT_DEFAULT'),
    );
    expect(
      () => ExportService(smartRenderDefault: true).preview(const ExportPlan()),
      code('SMART_RENDER_NOT_DEFAULT'),
    );
    expect(
      () => export.preview(const ExportPlan(streamCopy: true)),
      code('STREAM_COPY_DISABLED'),
    );
    expect(export.smartRenderEnabled, isFalse);
  });

  test('a preview screenshot is not an export; a missing encoder or a full disk fails explicitly', () {
    final export = ExportService();
    expect(
      () => export.preview(const ExportPlan(screenshotPreview: true)),
      code('PREVIEW_SCREENSHOT_NOT_EXPORT'),
    );
    expect(
      () => export.preview(const ExportPlan(encoderAvailable: false)),
      code('ENCODER_UNAVAILABLE'),
    );
    expect(
      () => export.preview(const ExportPlan(diskFull: true)),
      code('DISK_FULL'),
    );
    expect(export.muxerInvented, isFalse);
  });

  test('changing HDR, fps, or upload requires a new approval; timing and cancel leftovers are not re-claimed', () {
    final export = ExportService();
    expect(
      () => export.preview(const ExportPlan(changeHdr: true)),
      code('APPROVAL_REQUIRED'),
    );
    expect(
      () => export.preview(const ExportPlan(changeFps: true)),
      code('APPROVAL_REQUIRED'),
    );
    expect(
      () => export.preview(const ExportPlan(upload: true)),
      code('APPROVAL_REQUIRED'),
    );
    expect(
      export
          .preview(const ExportPlan(changeHdr: true, hdrApproved: true))
          .reencodeRequired,
      isTrue,
    );
    expect(export.v003Claimed, isFalse);
    expect(export.durationClaimed, isFalse);
    expect(export.avSyncClaimed, isFalse);
    expect(export.cancelSuiteRequalified, isFalse);
    expect(export.revisionSuiteRequalified, isFalse);
    expect(export.paidApiCalled, isFalse);
  });
}
