import 'package:studio_contracts/studio_contracts.dart';

const explicitSaveModes = {'saveManaged', 'saveBoundPackage'};

final class ExplicitSaveRequest {
  const ExplicitSaveRequest({
    required this.mode,
    this.boundToExternalFile = false,
    this.checkpointWritten = false,
    this.explicitSaveReceiptWritten = false,
    this.claimsLibrarySaved = false,
    this.claimsExternalFileWritten = false,
    this.storagePortReceipt = false,
    this.claimsBoundSuccess = false,
  });

  /// `saveManaged` or `saveBoundPackage`.
  final String mode;
  final bool boundToExternalFile;
  final bool checkpointWritten;
  final bool explicitSaveReceiptWritten;
  final bool claimsLibrarySaved;
  final bool claimsExternalFileWritten;
  final bool storagePortReceipt;
  final bool claimsBoundSuccess;
}

final class ExplicitSaveReceipt {
  const ExplicitSaveReceipt({
    required this.admitted,
    required this.librarySaved,
    required this.externalFileWritten,
    required this.boundSuccess,
  });

  final bool admitted;
  final bool librarySaved;
  final bool externalFileWritten;
  final bool boundSuccess;
}

/// DEV-PURE I-012 / s5b admission: library-mode `saveManaged` writes a
/// checkpoint and an explicit save receipt and must not imply a
/// `.studioproj` was written. `saveBoundPackage` requires an external
/// binding and may claim success only after a StoragePort receipt.
///
/// This is not a re-qualification of Increment 3.07
/// CloseCheckpointAdmission, Increment 3.05 PackageAutoUpdateAdmission,
/// Increment 3.06 ArtifactKindAdmission, or ADR 0098 I-012 leftovers.
/// A Flutter widget tree, a SAF or iCloud adapter, a StoragePort
/// runtime, and an I-014 RestoreService are not invented. The 30s/120s
/// s5b figures are not claimed as a measured qualification.
final class ExplicitSaveAdmission {
  bool closeCheckpointRequalified = false;
  bool packageAutoUpdateRequalified = false;
  bool artifactKindRequalified = false;
  bool i012UserSavedRevisionRequalified = false;
  bool flutterWidgetTreeInvented = false;
  bool safIcloudInvented = false;
  bool storagePortRuntimeInvented = false;
  bool i014RestoreInvented = false;
  bool v005QualificationClaimed = false;
  bool writerFenceRequalified = false;

  ExplicitSaveReceipt admit(ExplicitSaveRequest request) {
    if (!explicitSaveModes.contains(request.mode)) {
      throw const StudioException('EXPLICIT_SAVE_MODE_UNKNOWN', 'save');
    }
    final impliesPackage =
        request.claimsExternalFileWritten || request.claimsBoundSuccess;
    if (request.mode == 'saveManaged') {
      if (!request.checkpointWritten || !request.explicitSaveReceiptWritten) {
        throw const StudioException('EXPLICIT_SAVE_RECEIPT_REQUIRED', 'save');
      }
      if (impliesPackage) {
        throw const StudioException('UNBOUND_STUDIOPROJ_NOT_IMPLIED', 'save');
      }
      return const ExplicitSaveReceipt(
        admitted: true,
        librarySaved: true,
        externalFileWritten: false,
        boundSuccess: false,
      );
    }
    if (!request.boundToExternalFile) {
      throw const StudioException('EXTERNAL_BINDING_REQUIRED', 'save');
    }
    if (impliesPackage && !request.storagePortReceipt) {
      throw const StudioException('STORAGE_PORT_RECEIPT_REQUIRED', 'save');
    }
    return ExplicitSaveReceipt(
      admitted: true,
      librarySaved: false,
      externalFileWritten: request.storagePortReceipt,
      boundSuccess: request.storagePortReceipt,
    );
  }
}
