import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_command_clamp_probe/studio_command_clamp_probe.dart';
import 'package:test/test.dart';

/// Increment 3.02 official I-005 / s3 leftover: a preview drag may
/// clamp in real time, but a final command must submit the clamped
/// exact parameters and the user must see them. An AI call defaults
/// to refusal rather than silent correction. An unclamped out-of-range
/// final command does not write.
///
/// This file does not invent a TrimPlanner or a Flutter widget tree,
/// and does not re-qualify Increment 2.82 0.02s link-offset work or
/// the frozen s3 1/30s suite. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-005 stays partial. Remaining I-005
/// remainingAcceptance labels are not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a preview drag may clamp without writing; a final command that submits visible clamped parameters is admitted', () {
    final admission = CommandClampAdmission();
    final preview = admission.admit(
      const CommandClampRequest(
        origin: CommandOrigin.user,
        isFinalCommand: false,
        outOfRange: true,
        previewClamped: true,
      ),
    );
    expect(preview.wrote, isFalse);
    expect(preview.previewClamped, isTrue);
    final committed = admission.admit(
      const CommandClampRequest(
        origin: CommandOrigin.user,
        isFinalCommand: true,
        outOfRange: true,
        submitsClampedExactParameters: true,
        userVisibleClampedParameters: true,
      ),
    );
    expect(committed.wrote, isTrue);
  });

  test('an unclamped out-of-range final command does not write; hidden clamped parameters and AI silent correction are refused', () {
    final admission = CommandClampAdmission();
    expect(
      () => admission.admit(
        const CommandClampRequest(
          origin: CommandOrigin.user,
          isFinalCommand: true,
          outOfRange: true,
        ),
      ),
      code('SOURCE_OUT_OF_RANGE'),
    );
    expect(
      () => admission.admit(
        const CommandClampRequest(
          origin: CommandOrigin.user,
          isFinalCommand: true,
          outOfRange: true,
          boundCode: 'TRANSITION_HANDLE_SHORT',
        ),
      ),
      code('TRANSITION_HANDLE_SHORT'),
    );
    expect(
      () => admission.admit(
        const CommandClampRequest(
          origin: CommandOrigin.user,
          isFinalCommand: true,
          outOfRange: true,
          submitsClampedExactParameters: true,
        ),
      ),
      code('CLAMPED_PARAMETERS_NOT_VISIBLE'),
    );
    expect(
      () => admission.admit(
        const CommandClampRequest(
          origin: CommandOrigin.ai,
          isFinalCommand: true,
          outOfRange: true,
          silentlyCorrected: true,
        ),
      ),
      code('SILENT_CORRECTION_FORBIDDEN'),
    );
  });

  test('a TrimPlanner, Flutter widget tree, muted/solo, clipboard, auto-close, and already-official I-005 link-offset work stay closed', () {
    final admission = CommandClampAdmission();
    expect(admission.trimPlannerInvented, isFalse);
    expect(admission.videoMutedSoloOpened, isFalse);
    expect(admission.osClipboardInvented, isFalse);
    expect(admission.autoCloseInvented, isFalse);
    expect(admission.mobileGesturesInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.linkOffsetRequalified, isFalse);
    expect(admission.frozenS3SuiteRewritten, isFalse);
    expect(admission.newTrimModesInvented, isFalse);
  });
}
