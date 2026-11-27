import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_close_checkpoint_probe/studio_close_checkpoint_probe.dart';
import 'package:test/test.dart';

/// Increment 3.07 official I-012 / s5b leftover: background,
/// project-switch, or close must request a checkpoint immediately and
/// must not wait for a long generation or a ZIP. An unfinished
/// external package must not be claimed as written; a desktop exit
/// keeps the local recovery point. A mobile OS expiry may promise
/// only work that already has a local ACK, not an unbounded
/// background task.
///
/// This file does not re-qualify Increment 3.05
/// PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission,
/// ADR 0098 I-012 leftovers, or ADR 0028 gesture cancel. A SAF or
/// iCloud adapter, a Flutter widget tree, and I-013 job archival are
/// not invented. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9. I-012 stays partial. Existing I-012
/// remainingAcceptance wording is not silently rewritten.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('background, project-switch, or close requests a checkpoint immediately and does not wait for a generation or a ZIP', () {
    final admission = CloseCheckpointAdmission();
    for (final trigger in const ['background', 'projectSwitch', 'close']) {
      final receipt = admission.admit(
        CloseCheckpointRequest(
          trigger: trigger,
          checkpointRequestedImmediately: true,
        ),
      );
      expect(receipt.checkpointRequested, isTrue);
      expect(receipt.externalFileWritten, isFalse);
    }
    expect(
      () => admission.admit(
        const CloseCheckpointRequest(
          trigger: 'close',
          checkpointRequestedImmediately: true,
          waitsForLongGeneration: true,
        ),
      ),
      code('CLOSE_MUST_NOT_WAIT'),
    );
    expect(
      () => admission.admit(
        const CloseCheckpointRequest(trigger: 'background', waitsForZip: true),
      ),
      code('CLOSE_MUST_NOT_WAIT'),
    );
    expect(
      () => admission.admit(const CloseCheckpointRequest(trigger: 'close')),
      code('CHECKPOINT_REQUIRED_IMMEDIATELY'),
    );
  });

  test('an unfinished external package must not be claimed as written; a desktop exit keeps the local recovery point; a mobile expiry must not start an unbounded background task', () {
    final admission = CloseCheckpointAdmission();
    final desktop = admission.admit(
      const CloseCheckpointRequest(
        trigger: 'desktopExit',
        checkpointRequestedImmediately: true,
        externalPackageUnfinished: true,
        localRecoveryPointRetained: true,
      ),
    );
    expect(desktop.checkpointRequested, isTrue);
    expect(desktop.externalFileWritten, isFalse);
    expect(desktop.localRecoveryPointRetained, isTrue);
    expect(
      () => admission.admit(
        const CloseCheckpointRequest(
          trigger: 'desktopExit',
          checkpointRequestedImmediately: true,
          externalPackageUnfinished: true,
          claimsExternalFileWritten: true,
          localRecoveryPointRetained: true,
        ),
      ),
      code('EXTERNAL_FILE_NOT_WRITTEN'),
    );
    expect(
      () => admission.admit(
        const CloseCheckpointRequest(
          trigger: 'desktopExit',
          checkpointRequestedImmediately: true,
          externalPackageUnfinished: true,
        ),
      ),
      code('LOCAL_RECOVERY_POINT_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const CloseCheckpointRequest(
          trigger: 'mobileOsExpiry',
          checkpointRequestedImmediately: true,
          unboundedBackgroundTask: true,
        ),
      ),
      code('UNBOUNDED_BACKGROUND_TASK_FORBIDDEN'),
    );
  });

  test('Increment 3.05 package auto-update, Increment 3.06 artifact-kind, ADR 0098, a SAF/iCloud adapter, and a Flutter widget tree stay closed', () {
    final admission = CloseCheckpointAdmission();
    expect(admission.packageAutoUpdateRequalified, isFalse);
    expect(admission.artifactKindRequalified, isFalse);
    expect(admission.i012UserSavedRevisionRequalified, isFalse);
    expect(admission.gestureCancelRequalified, isFalse);
    expect(admission.safIcloudInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.v005QualificationClaimed, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
  });
}
