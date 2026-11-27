import 'package:studio_contracts/studio_contracts.dart';

final class ExportPlan {
  const ExportPlan({
    this.smartRender = false,
    this.streamCopy = false,
    this.screenshotPreview = false,
    this.encoderAvailable = true,
    this.diskFull = false,
    this.changeHdr = false,
    this.changeFps = false,
    this.upload = false,
    this.hdrApproved = false,
    this.fpsApproved = false,
    this.uploadApproved = false,
  });

  final bool smartRender,
      streamCopy,
      screenshotPreview,
      encoderAvailable,
      diskFull,
      changeHdr,
      changeFps,
      upload,
      hdrApproved,
      fpsApproved,
      uploadApproved;
}

final class ExportReceipt {
  ExportReceipt({
    required this.smartRenderDefault,
    required this.reencodeRequired,
    required this.published,
    required this.fakeSuccess,
  });

  final bool smartRenderDefault, reencodeRequired, published, fakeSuccess;
}

/// DEV-PURE I-024 ExportService policy. This is not a muxer, not a
/// 60s golden, and not a re-qualification of already-official
/// cancel/revision or 20ms/1-frame export suites.
final class ExportService {
  ExportService({this.smartRenderDefault = false});

  final bool smartRenderDefault;

  bool muxerInvented = false;
  bool smartRenderEnabled = false;
  bool v003Claimed = false;
  bool durationClaimed = false;
  bool avSyncClaimed = false;
  bool cancelSuiteRequalified = false;
  bool revisionSuiteRequalified = false;
  bool paidApiCalled = false;

  ExportReceipt preview(ExportPlan plan) {
    _refuse(plan);
    return ExportReceipt(
      smartRenderDefault: smartRenderDefault,
      reencodeRequired: true,
      published: false,
      fakeSuccess: false,
    );
  }

  void _refuse(ExportPlan plan) {
    if (plan.smartRender || smartRenderDefault) {
      throw const StudioException('SMART_RENDER_NOT_DEFAULT', 'smartRender');
    }
    if (plan.streamCopy) {
      throw const StudioException('STREAM_COPY_DISABLED', 'streamCopy');
    }
    if (plan.screenshotPreview) {
      throw const StudioException(
        'PREVIEW_SCREENSHOT_NOT_EXPORT',
        'screenshot',
      );
    }
    if (!plan.encoderAvailable) {
      throw const StudioException('ENCODER_UNAVAILABLE', 'encoder');
    }
    if (plan.diskFull) {
      throw const StudioException('DISK_FULL', 'disk');
    }
    if (plan.changeHdr && !plan.hdrApproved) {
      throw const StudioException('APPROVAL_REQUIRED', 'hdr');
    }
    if (plan.changeFps && !plan.fpsApproved) {
      throw const StudioException('APPROVAL_REQUIRED', 'fps');
    }
    if (plan.upload && !plan.uploadApproved) {
      throw const StudioException('APPROVAL_REQUIRED', 'upload');
    }
  }
}
