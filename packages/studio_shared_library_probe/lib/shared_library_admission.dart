import 'package:studio_contracts/studio_contracts.dart';

final class SharedLibraryRequest {
  const SharedLibraryRequest({
    this.explicitSharedLibrary = false,
    this.sameProtocol = false,
    this.namespaceAuthorized = false,
  });

  /// An explicit shared library (spec s5b names App Group as the
  /// example) is being opened, not a private workspace.
  final bool explicitSharedLibrary;
  final bool sameProtocol;
  final bool namespaceAuthorized;
}

final class SharedLibraryReceipt {
  const SharedLibraryReceipt({
    required this.admitted,
    required this.sharedLibraryAuthorized,
  });

  final bool admitted;
  final bool sharedLibraryAuthorized;
}

/// DEV-PURE I-003 / s5b admission: an explicit shared library must use
/// the same protocol and namespace authorization.
///
/// This is the leftover fencing clause after Increment 3.12, not a
/// re-qualification of existing cross-App private-workspace isolation
/// in `workspace_test.dart`, Increment 3.12 PreparedStageAdmission,
/// Increment 3.09 WriterFenceAdmission, or I-003 revision tests. An
/// OS lock runtime, an App Group runtime, crash takeover, and a
/// publish-path serial coordinator are not invented. I-003
/// namespace-isolation labels (`namespace越界读写=0`) are not cleared.
final class SharedLibraryAdmission {
  bool preparedStageRequalified = false;
  bool writerFenceRequalified = false;
  bool sqlCloudSideEffectRequalified = false;
  bool workspaceIsolationRequalified = false;
  bool i003RevisionTestsRewritten = false;
  bool i003NamespaceLabelsCleared = false;
  bool osLockRuntimeInvented = false;
  bool appGroupRuntimeInvented = false;
  bool crashTakeoverOfficialized = false;
  bool i032PlanGraphFenceRequalified = false;

  SharedLibraryReceipt admit(SharedLibraryRequest request) {
    if (!request.explicitSharedLibrary) {
      throw const StudioException(
        'EXPLICIT_SHARED_LIBRARY_REQUIRED',
        'workspace',
      );
    }
    if (!request.sameProtocol) {
      throw const StudioException(
        'SHARED_LIBRARY_PROTOCOL_REQUIRED',
        'workspace',
      );
    }
    if (!request.namespaceAuthorized) {
      throw const StudioException(
        'SHARED_LIBRARY_NAMESPACE_UNAUTHORIZED',
        'workspace',
      );
    }
    return const SharedLibraryReceipt(
      admitted: true,
      sharedLibraryAuthorized: true,
    );
  }
}
