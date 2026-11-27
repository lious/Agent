import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_future_major_probe/studio_future_major_probe.dart';
import 'package:test/test.dart';

/// Increment 3.16 official I-014 / s5d leftover: a future major
/// schema may be scanned only at the recognizable outer layer; the
/// unknown core is read-only metadata, the original package is kept,
/// and the core must not be interpreted or executed.
///
/// This file does not re-qualify the already-official I-014
/// “不支持feature只读保留” bound, Increment 3.15
/// IdentityCollisionAdmission, or Increment 2.51 restore event-seq.
/// An I-014 RestoreService and a schema migrator are not invented.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. Schema v10 is not merged. I-014 stays partial. Existing
/// I-014 remainingAcceptance wording is not silently rewritten.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a future major schema is admitted as read-only outer metadata, keeps the original package, and must not execute the unknown core', () {
    final admission = FutureMajorAdmission();
    final receipt = admission.admit(
      const FutureMajorRequest(
        futureMajorSchema: true,
        limitedOuterScan: true,
        readOnlyMetadata: true,
        keepsOriginalPackage: true,
      ),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.readOnly, isTrue);
    expect(receipt.executed, isFalse);
    expect(receipt.originalPackageKept, isTrue);
    expect(
      () => admission.admit(const FutureMajorRequest()),
      code('FUTURE_MAJOR_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const FutureMajorRequest(
          futureMajorSchema: true,
          limitedOuterScan: true,
          readOnlyMetadata: true,
          keepsOriginalPackage: true,
          interpretsAndExecutesUnknownCore: true,
        ),
      ),
      code('FUTURE_MAJOR_MUST_NOT_EXECUTE'),
    );
    expect(
      () => admission.admit(
        const FutureMajorRequest(
          futureMajorSchema: true,
          limitedOuterScan: true,
          keepsOriginalPackage: true,
        ),
      ),
      code('FUTURE_MAJOR_READ_ONLY'),
    );
    expect(
      () => admission.admit(
        const FutureMajorRequest(
          futureMajorSchema: true,
          limitedOuterScan: true,
          readOnlyMetadata: true,
        ),
      ),
      code('FUTURE_MAJOR_ORIGINAL_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const FutureMajorRequest(
          futureMajorSchema: true,
          readOnlyMetadata: true,
          keepsOriginalPackage: true,
        ),
      ),
      code('FUTURE_MAJOR_SCAN_BOUNDED'),
    );
  });

  test('unsupported-feature read-only, Increment 3.15 identity-collision, Increment 2.51, an I-014 RestoreService, and a schema migrator stay closed', () {
    final admission = FutureMajorAdmission();
    expect(admission.identityCollisionRequalified, isFalse);
    expect(admission.unsupportedFeatureReadonlyRequalified, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
    expect(admission.migrationCopyRequalified, isFalse);
    expect(admission.restoreEventSeqRequalified, isFalse);
    expect(admission.schemaMigratorInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.idRemapOfficialized, isFalse);
    expect(admission.casDbGapRequalified, isFalse);
  });
}
