import 'package:studio_contracts/studio_contracts.dart';

const commandBoundCodes = {
  'SOURCE_OUT_OF_RANGE',
  'TRANSITION_HANDLE_SHORT',
  'COLLISION',
  'SYNC_LOCKED',
};

enum CommandOrigin { user, ai }

final class CommandClampRequest {
  const CommandClampRequest({
    required this.origin,
    required this.isFinalCommand,
    required this.outOfRange,
    this.boundCode = 'SOURCE_OUT_OF_RANGE',
    this.previewClamped = false,
    this.submitsClampedExactParameters = false,
    this.userVisibleClampedParameters = false,
    this.silentlyCorrected = false,
  });

  final CommandOrigin origin;
  final bool isFinalCommand;
  final bool outOfRange;
  final String boundCode;
  final bool previewClamped;
  final bool submitsClampedExactParameters;
  final bool userVisibleClampedParameters;
  final bool silentlyCorrected;
}

final class CommandClampReceipt {
  const CommandClampReceipt({
    required this.wrote,
    required this.previewClamped,
  });

  final bool wrote;
  final bool previewClamped;
}

/// DEV-PURE I-005 / s3 admission: a preview drag may clamp in real
/// time, but a final command must submit the clamped exact parameters
/// and those parameters must be visible to the user. An AI call that
/// would be out of range is refused; it must not be silently corrected.
/// An unclamped out-of-range final command does not write.
///
/// This is not a TrimPlanner, not a Flutter widget tree, and not a
/// re-qualification of Increment 2.82 0.02s link-offset work or the
/// frozen s3 1/30s suite. Video/caption muted/solo, OS clipboard,
/// auto-close, and mobile gestures stay closed.
final class CommandClampAdmission {
  bool trimPlannerInvented = false;
  bool videoMutedSoloOpened = false;
  bool osClipboardInvented = false;
  bool autoCloseInvented = false;
  bool mobileGesturesInvented = false;
  bool flutterWidgetTreeInvented = false;
  bool linkOffsetRequalified = false;
  bool frozenS3SuiteRewritten = false;
  bool newTrimModesInvented = false;

  CommandClampReceipt admit(CommandClampRequest request) {
    if (request.silentlyCorrected ||
        (request.origin == CommandOrigin.ai && request.outOfRange)) {
      throw const StudioException('SILENT_CORRECTION_FORBIDDEN', 'command');
    }
    if (!request.isFinalCommand) {
      return CommandClampReceipt(
        wrote: false,
        previewClamped: request.previewClamped || request.outOfRange,
      );
    }
    if (request.outOfRange && !request.submitsClampedExactParameters) {
      final code = commandBoundCodes.contains(request.boundCode)
          ? request.boundCode
          : 'SOURCE_OUT_OF_RANGE';
      throw StudioException(code, 'command');
    }
    if (request.submitsClampedExactParameters &&
        !request.userVisibleClampedParameters) {
      throw const StudioException('CLAMPED_PARAMETERS_NOT_VISIBLE', 'command');
    }
    return const CommandClampReceipt(wrote: true, previewClamped: false);
  }
}
