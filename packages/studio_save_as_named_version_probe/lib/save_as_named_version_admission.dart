import 'package:studio_contracts/studio_contracts.dart';

const saveAsNamedVersionKinds = {'saveAs', 'namedVersion'};

final class SaveAsNamedVersionRequest {
  const SaveAsNamedVersionRequest({
    required this.kind,
    this.existingTarget = false,
    this.overwriteConfirmed = false,
    this.claimsFork = false,
    this.claimsRollback = false,
  });

  /// `saveAs` or `namedVersion`.
  final String kind;
  final bool existingTarget;
  final bool overwriteConfirmed;
  final bool claimsFork;
  final bool claimsRollback;
}

final class SaveAsNamedVersionReceipt {
  const SaveAsNamedVersionReceipt({
    required this.admitted,
    required this.silentOverwrite,
    required this.isLabelPin,
    required this.isFork,
    required this.isRollback,
  });

  final bool admitted;
  final bool silentOverwrite;
  final bool isLabelPin;
  final bool isFork;
  final bool isRollback;
}

/// DEV-PURE I-012 / s5b admission: Save As must not silently
/// overwrite an existing file, and a named version is a label pin
/// of an immutable checkpoint, not a fork or a rollback.
///
/// This does not re-qualify `CHECKPOINT_NAME_EXISTS` in
/// `checkpoint_retention_test.dart`, fork-new-projectId,
/// Increment 3.10 ExplicitSaveAdmission, or Increment 3.11
/// CheckpointIdentityAdmission (including “do not recopy media”).
/// The “new project copy defaults to a new projectId” and “keep
/// the id and explicitly switch binding” clauses of the same s5b
/// row are not officialized here. A Flutter widget tree, a
/// StoragePort runtime, and an I-014 RestoreService are not
/// invented.
final class SaveAsNamedVersionAdmission {
  bool checkpointNameExistsRequalified = false;
  bool forkNewProjectIdRequalified = false;
  bool explicitSaveRequalified = false;
  bool checkpointIdentityRequalified = false;
  bool uniqueCopyRequalified = false;
  bool packageProjectionRequalified = false;
  bool flutterWidgetTreeInvented = false;
  bool storagePortInvented = false;
  bool restoreInvented = false;
  bool walCheckpointInvented = false;

  SaveAsNamedVersionReceipt admit(SaveAsNamedVersionRequest request) {
    if (!saveAsNamedVersionKinds.contains(request.kind)) {
      throw const StudioException('SAVE_AS_KIND_UNKNOWN', 'publication');
    }
    if (request.kind == 'saveAs') {
      if (request.existingTarget && !request.overwriteConfirmed) {
        throw const StudioException(
          'SILENT_OVERWRITE_FORBIDDEN',
          'publication',
        );
      }
      return const SaveAsNamedVersionReceipt(
        admitted: true,
        silentOverwrite: false,
        isLabelPin: false,
        isFork: false,
        isRollback: false,
      );
    }
    if (request.claimsFork) {
      throw const StudioException('NAMED_VERSION_NOT_FORK', 'publication');
    }
    if (request.claimsRollback) {
      throw const StudioException('NAMED_VERSION_NOT_ROLLBACK', 'publication');
    }
    return const SaveAsNamedVersionReceipt(
      admitted: true,
      silentOverwrite: false,
      isLabelPin: true,
      isFork: false,
      isRollback: false,
    );
  }
}
