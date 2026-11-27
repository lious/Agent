import 'package:studio_contracts/studio_contracts.dart';

const modelContextKinds = {'harnessContext'};

final class ModelContextRequest {
  const ModelContextRequest({
    required this.kind,
    this.providerOwnsSessionDatabase = false,
    this.migratesKvCache = false,
    this.migratesVendorReasoning = false,
    this.agentsShareImplicitContext = false,
    this.rerendersFormatsOnSwitch = true,
  });

  /// `harnessContext`.
  final String kind;
  final bool providerOwnsSessionDatabase;
  final bool migratesKvCache;
  final bool migratesVendorReasoning;
  final bool agentsShareImplicitContext;
  final bool rerendersFormatsOnSwitch;
}

final class ModelContextReceipt {
  const ModelContextReceipt({
    required this.admitted,
    required this.providerOwnsSessionDatabase,
    required this.kvMigrated,
    required this.vendorReasoningMigrated,
    required this.implicitContextShared,
    required this.formatsRerendered,
  });

  final bool admitted;
  final bool providerOwnsSessionDatabase;
  final bool kvMigrated;
  final bool vendorReasoningMigrated;
  final bool implicitContextShared;
  final bool formatsRerendered;
}

/// DEV-PURE s10 admission: a provider port must not own the session
/// database; after a model switch, system/tool formats and token
/// counts must be re-rendered and KV cache or vendor-proprietary
/// reasoning blocks must not be migrated; and two agents must not
/// share implicit context even when both are online.
///
/// This does not claim a real two-model I-034 handoff, invent a
/// durable mailbox or ContextCompiler runtime, or re-qualify I-030
/// StreamAssembler, I-031 private-reasoning journal omission,
/// Increment 3.32 LicenseExecutionAdmission, Increment 3.35
/// LicenseProvenanceAdmission, or Increment 3.36
/// SessionNavigationAdmission. Quote/apply and paid APIs are not
/// started.
final class ModelContextAdmission {
  bool i034HandoffClaimed = false;
  bool mailboxInvented = false;
  bool contextCompilerInvented = false;
  bool i030Requalified = false;
  bool i031Requalified = false;
  bool licenseExecutionRequalified = false;
  bool licenseProvenanceRequalified = false;
  bool sessionNavigationRequalified = false;
  bool quoteApplyStarted = false;
  bool paidApiCalled = false;

  ModelContextReceipt admit(ModelContextRequest request) {
    if (!modelContextKinds.contains(request.kind)) {
      throw const StudioException('MODEL_CONTEXT_KIND_UNKNOWN', 'validator');
    }
    if (request.providerOwnsSessionDatabase) {
      throw const StudioException('PROVIDER_PORT_NOT_SESSION_DB', 'validator');
    }
    if (!request.rerendersFormatsOnSwitch) {
      throw const StudioException('FORMATS_NOT_RERENDERED', 'validator');
    }
    if (request.migratesKvCache) {
      throw const StudioException('KV_CACHE_NOT_MIGRATED', 'validator');
    }
    if (request.migratesVendorReasoning) {
      throw const StudioException('VENDOR_REASONING_NOT_MIGRATED', 'validator');
    }
    if (request.agentsShareImplicitContext) {
      throw const StudioException('IMPLICIT_CONTEXT_NOT_SHARED', 'validator');
    }
    return const ModelContextReceipt(
      admitted: true,
      providerOwnsSessionDatabase: false,
      kvMigrated: false,
      vendorReasoningMigrated: false,
      implicitContextShared: false,
      formatsRerendered: true,
    );
  }
}
