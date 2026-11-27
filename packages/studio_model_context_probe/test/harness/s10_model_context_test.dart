import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_model_context_probe/studio_model_context_probe.dart';
import 'package:test/test.dart';

/// Increment 3.37 official s10 leftover: a provider port must not
/// own the session database; a model switch must re-render formats
/// and must not migrate KV cache or vendor reasoning; and agents
/// must not share implicit context.
///
/// This file does not claim a real two-model I-034 handoff or
/// re-qualify I-030, I-031, Increment 3.32, Increment 3.35, or
/// Increment 3.36. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. This is not an I-013 packing or
/// archive slice, not an I-002 measurement claim, and not a
/// license or session-navigation leftover already officialized in
/// 3.32, 3.35, or 3.36.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a provider port must not own the session database, a model switch must not migrate KV or vendor reasoning, and agents must not share implicit context', () {
    final admission = ModelContextAdmission();
    final receipt = admission.admit(
      const ModelContextRequest(kind: 'harnessContext'),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.providerOwnsSessionDatabase, isFalse);
    expect(receipt.kvMigrated, isFalse);
    expect(receipt.vendorReasoningMigrated, isFalse);
    expect(receipt.implicitContextShared, isFalse);
    expect(receipt.formatsRerendered, isTrue);

    expect(
      () => admission.admit(const ModelContextRequest(kind: 'unknown')),
      code('MODEL_CONTEXT_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const ModelContextRequest(
          kind: 'harnessContext',
          providerOwnsSessionDatabase: true,
        ),
      ),
      code('PROVIDER_PORT_NOT_SESSION_DB'),
    );
    expect(
      () => admission.admit(
        const ModelContextRequest(
          kind: 'harnessContext',
          rerendersFormatsOnSwitch: false,
        ),
      ),
      code('FORMATS_NOT_RERENDERED'),
    );
    expect(
      () => admission.admit(
        const ModelContextRequest(
          kind: 'harnessContext',
          migratesKvCache: true,
        ),
      ),
      code('KV_CACHE_NOT_MIGRATED'),
    );
    expect(
      () => admission.admit(
        const ModelContextRequest(
          kind: 'harnessContext',
          migratesVendorReasoning: true,
        ),
      ),
      code('VENDOR_REASONING_NOT_MIGRATED'),
    );
    expect(
      () => admission.admit(
        const ModelContextRequest(
          kind: 'harnessContext',
          agentsShareImplicitContext: true,
        ),
      ),
      code('IMPLICIT_CONTEXT_NOT_SHARED'),
    );
  });

  test('a real two-model I-034 handoff, mailbox schema, I-030, I-031, and recent license or session-navigation admissions stay closed', () {
    final admission = ModelContextAdmission();
    expect(admission.i034HandoffClaimed, isFalse);
    expect(admission.mailboxInvented, isFalse);
    expect(admission.contextCompilerInvented, isFalse);
    expect(admission.i030Requalified, isFalse);
    expect(admission.i031Requalified, isFalse);
    expect(admission.licenseExecutionRequalified, isFalse);
    expect(admission.licenseProvenanceRequalified, isFalse);
    expect(admission.sessionNavigationRequalified, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
