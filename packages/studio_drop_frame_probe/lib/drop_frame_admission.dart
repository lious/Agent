import 'package:studio_contracts/studio_contracts.dart';

const dropFrameKinds = {'dropFrameDisplay'};

final class DropFrameRequest {
  const DropFrameRequest({required this.kind, this.deletesMediaFrames = false});

  /// `dropFrameDisplay`.
  final String kind;

  /// True when drop-frame timecode is treated as deleting media frames.
  final bool deletesMediaFrames;
}

final class DropFrameReceipt {
  const DropFrameReceipt({
    required this.admitted,
    required this.displayNumberingOnly,
    required this.mediaFramesDeleted,
  });

  final bool admitted;
  final bool displayNumberingOnly;
  final bool mediaFramesDeleted;
}

/// DEV-PURE s2 admission: drop-frame timecode only changes display
/// numbering and must not delete media frames.
///
/// This does not re-qualify Increment 3.31 ErrorClassAdmission, the
/// remaining I-002 measurement labels (10k rational roundtrips,
/// illegal FK/overlap/overflow refusal, existing synthetic projects),
/// Increment 3.32 LicenseExecutionAdmission, or I-010 sidecar /
/// SUBTITLE_TIMECODE work. A drop-frame converter or text shaper is
/// not invented. Schema v10 is not merged. The closed root is not
/// extended. Unknown fields are not swallowed.
final class DropFrameAdmission {
  bool rationalOpsRequalified = false;
  bool fkOverlapOverflowRequalified = false;
  bool syntheticProjectRequalified = false;
  bool errorClassRequalified = false;
  bool licenseExecutionRequalified = false;
  bool captionTimecodeRequalified = false;
  bool closedRootExtended = false;
  bool unknownFieldsSwallowed = false;
  bool dropFrameRuntimeInvented = false;
  bool shaperInvented = false;

  DropFrameReceipt admit(DropFrameRequest request) {
    if (!dropFrameKinds.contains(request.kind)) {
      throw const StudioException('DROP_FRAME_KIND_UNKNOWN', 'validator');
    }
    if (request.deletesMediaFrames) {
      throw const StudioException('DROP_FRAME_DELETES_MEDIA', 'validator');
    }
    return const DropFrameReceipt(
      admitted: true,
      displayNumberingOnly: true,
      mediaFramesDeleted: false,
    );
  }
}
