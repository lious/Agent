# Increment 3.52 — live-App source fence prerequisite only

Base `013a8e50c8dcf6be716c065f4e357c636fdc5737` was clean on
feat/studio-foundation-20261125 and matched origin before edits. Recorded
2026-11-28 Asia/Shanghai. [ADR 0251](../../../adr/0251-import-composition-live-app-fence.md)
and the appended A3 subsection in
[s8f App v1](../../../studio/spec/s8f-signed-import-app-v1.md) explain the concrete
A2 per-await live-App planning gap, completed BEFORE implementing this seam.

## Implemented boundary — not the requested full composition

The 3.51 source helper observes its own cancellation generation, not live App
profile/policy/scope. A final check after its byte Future is insufficient to stop
stale reads. This slice adds optional synchronous `currentAppStillValid`
forwarding to both App adapters and a latching fence at pre-picker, selected-reader,
length/open-port, each data/EOF read and post-close checkpoints. False/exception
returns only local scopeChanged and never publishes bytes. Existing cancellation
and pending-I/O quiescence remain in force. Callback omission is permitted ONLY
for source-only use, never full App-composition acceptance.

The actual App-lifetime owner, monotonic change-generation publication, live
ImportAppSnapshot comparator, readiness and preview/acknowledgment widgets are
NOT implemented here. A callback returning true is not proof of those bindings.
In particular the ABA unit test models an owner counter; it is not the real App
comparator, a grant store, trusted clock or signature/publisher provisioning.

## Independent results / reproduction

Run at repo root with `/workspace/toolchains/flutter/bin` on PATH:

```
dart test packages/studio_assets/test/skills/import_composition/source_fence_test.dart
```

**17/17 NEW Dart controlled-reader cases** (`tests.log`): pre-picker false and
exception, synchronous picker activation, pending selection drift, false/exception
at length/read/EOF/close awaits, latching, ABA generation comparison, cancellation
priority with one busy operation until drain, cleanup failure, and busy rejection
without another predicate/picker call. No old tests, fake backends or crypto vector
helpers are imported. Tests establish this shared source-fence seam in Dart VM,
NOT GTK/Web runtime, real App state or browser/UI/CSP behavior.

Analyze and format all four `.dart` paths listed in contract.json:
**no issues**, **4 files / 0 formatting changes**. Web source adapter plus helper
compile to JS (`web-compile-only.log`) using the existing public-fixture probe as
a compilation target ONLY; the probe was NOT run and its old results are NOT
counted. This is syntax/type/compile compatibility, not browser fence qualification.

**54/54 Python static/evidence/preservation checks** (`static-tests.log`):

```
python3 -m unittest tools.tests.test_import_composition_live_fence tools.tests.test_signed_import_source_adapters tools.tests.test_signed_import_app_plan tools.tests.test_signed_import_app_host tools.tests.test_signed_import_plan tools.tests.test_signed_import_runtime_contract tools.tests.test_signed_import_web_plan tools.tests.test_signed_import_web_runtime
```

Six are new fence-specific checks; 48 inspect historical evidence/plans only.
No old crypto/importer/format/host/GTK/Web qualification runtime was rerun.

The unchanged acceptance suite remains **5 pass / 1 historical strict-equality
failure** at test_acceptance.py:52 (`unchanged-acceptance-suite.log`):

```
python3 -m unittest tools.tests.test_acceptance
```

Neither that test nor original remainingAcceptance / remainingScope was rewritten.
contract.json binds source hashes, the exact four-path runtime delta, unchanged
App mains/host/importer/verifiers/dependency lock/store/schema, and honest false
full-composition/combined-acceptance flags. No UI, package, schema or privilege
contract changes are hidden in this prerequisite. Log terminal padding is trimmed.

## Deferred / next

Stop here rather than wire a partially accepted UI. Recommended **3.53** completes
the REAL existing-App lifetime/snapshot/generation owner and selection / immutable
preview / separate non-authorizing acknowledgment, then independently qualifies
combined actual-App CSP/readiness, widget/accessibility, stale-state, no-write and
no-authority behavior under A1–A6. The new guard must be supplied and observed by
that real owner; tests of this seam cannot replace combined acceptance.

Default roots remain empty. signed=true is neither verification nor approval;
invalid signatures must not downgrade. No durable installation, cross-namespace
import, publisher provisioning, production FTS/RAG, user Mac/XS, paid API,
deployment, hardware/model/provider/store claims or other standing exclusions.
Counts remain **0 complete / 62 partial / 12 planned / 13 blocked**; I-037 partial,
fullTasksCompleted=0, T-4/program unfinished, user_version=9,
InversePatch=restoreSnapshot.
