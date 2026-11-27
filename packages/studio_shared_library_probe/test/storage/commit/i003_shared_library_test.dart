import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_shared_library_probe/studio_shared_library_probe.dart';
import 'package:test/test.dart';

/// Increment 3.13 official I-003 / s5b leftover: an explicit shared
/// library must use the same protocol and namespace authorization.
///
/// This file does not re-qualify existing cross-App private-workspace
/// isolation in `workspace_test.dart`, Increment 3.12
/// PreparedStageAdmission, Increment 3.09 WriterFenceAdmission,
/// Increment 3.08 SqlCloudSideEffectAdmission, or I-003 revision
/// tests. An OS lock runtime, an App Group runtime, and crash
/// takeover are not invented. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-003 stays
/// partial. Existing I-003 remainingAcceptance labels (100 concurrent
/// same-baseRevision, undo creates a new revision, no half-write,
/// namespace isolation) are not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('an explicit shared library is admitted only with the same protocol and namespace authorization', () {
    final admission = SharedLibraryAdmission();
    final receipt = admission.admit(
      const SharedLibraryRequest(
        explicitSharedLibrary: true,
        sameProtocol: true,
        namespaceAuthorized: true,
      ),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.sharedLibraryAuthorized, isTrue);
    expect(
      () => admission.admit(const SharedLibraryRequest()),
      code('EXPLICIT_SHARED_LIBRARY_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const SharedLibraryRequest(explicitSharedLibrary: true),
      ),
      code('SHARED_LIBRARY_PROTOCOL_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const SharedLibraryRequest(
          explicitSharedLibrary: true,
          sameProtocol: true,
        ),
      ),
      code('SHARED_LIBRARY_NAMESPACE_UNAUTHORIZED'),
    );
  });

  test('Increment 3.12 prepared-stage, Increment 3.09 writer-fence, workspace_test isolation, an OS lock runtime, an App Group runtime, and I-003 namespace labels stay closed', () {
    final admission = SharedLibraryAdmission();
    expect(admission.preparedStageRequalified, isFalse);
    expect(admission.writerFenceRequalified, isFalse);
    expect(admission.sqlCloudSideEffectRequalified, isFalse);
    expect(admission.workspaceIsolationRequalified, isFalse);
    expect(admission.i003RevisionTestsRewritten, isFalse);
    expect(admission.i003NamespaceLabelsCleared, isFalse);
    expect(admission.osLockRuntimeInvented, isFalse);
    expect(admission.appGroupRuntimeInvented, isFalse);
    expect(admission.crashTakeoverOfficialized, isFalse);
    expect(admission.i032PlanGraphFenceRequalified, isFalse);
  });
}
