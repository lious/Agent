# Increment 3.61 — cumulative frozen evidence audit / native plan only

Base `7c616a4aab245505f3fdd9fac15095fd640f5e3b` was clean on
feat/studio-foundation-20261125 and matched its tracked origin before editing.
No runtime files, dependency locks, original test assertions or third-party
license bytes change. No historical App/crypto/source suite is re-executed.

## Audit method and findings

`python3 tools/audit/signed_import_app_evidence.py --output .../audit.json`
reads committed artifacts at their ORIGINAL qualification commits and compares
all evidence bytes with the checkout. It checks source hashes against those
commits, case identities, recorded pass/no-write/storage/error/CSP flags, pinned
vendor hashes/SRI and served main hashes against each original build manifest.
It preserves raw diagnostic/failure logs and hashes them without promoting
those diagnostic attempts to qualified cases. A negative static check proves
source-hash mismatches fail closed. This is evidence-integrity/coverage auditing,
not 39 new browser executions or current-binary qualification.

| Frozen scope | Original commit | Recorded profiles | Build records |
| --- | --- | ---: | ---: |
| B01–B04 | c30441a71e0285bd597ac85c1fa7357822678c8a | 4 | 3 |
| B05–B08 | 2a137beb9ef088aaf855a343a7a3d3c56694c525 | 11 | 4 |
| B09–B11 | f42d46d30f9dc88f9a15106022ba34c3cea5d69b | 12 | 3 |
| L01 | e499a223995bf067edbf506bb8e45d681a5b8ad6 | 2 | 3 |
| G3/L02–L03 | 7c616a4aab245505f3fdd9fac15095fd640f5e3b | 10 | 3 |

Total: 39 historical browser profiles, 16 historical build records; no inconsistent
frozen source hashes, served-main identities or contradictory recorded pass/fail
were found. L01 passive observer methods are byte-identical across 3.59/3.60.
**This does not establish binary equivalence**: L01 used main hash
`afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29`, while
L02–L03 used `935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb`.
App-late C2:58–66 requires one late-phase binary, and C7:190–212 specifies combined
gates. Neither frozen per-slice contract claims all G1–G5 complete. The union
therefore remains scoped historical evidence, not combined G1–G5 acceptance.
No relaxation, retroactive pass, evidence rewrite or L01 rerun is made. There is
no contradictory frozen evidence that requires reopening L01 in this increment.

### ADR dependency audit

- 0248: existing-App ownership, bounded selection, immutable separate consent;
  no API invention or source-backend result promoted to UI qualification.
- 0249: actual host CSP prerequisite only; 0250: adapter-only GTK/Web bounds;
  both remain historical dependencies, not new native positive acceptance.
- 0251: live fence/per-await generation and busy-until-quiescent preservation.
- 0252: actual owner/widget composition, Linux needsReview/default clock, Web
  readiness negatives; its explicit unfinished matrix is not erased.
- 0253: test-entrypoint isolation/trusted owner composition/matrix/no-write binding.
- 0254: four positive/rebuild browser profiles; B03 standard semantics is NOT OS AT.
- 0255: 11 cancellation/lifecycle profiles; real navigation/BFCache observations
  remain distinct from labeled synthetic pagehide/framework delivery.
- 0256: 12 owner/time profiles; B10 signer expiry is not an invented preview TTL.
- 0257: source preflight is not runtime; C2/C7 combined obligations remain open.
- 0258: L01 pending REAL factory, bounded vendor-body release, no readiness stub.
- 0259: controlled G3 reader, 9 L02 + 1 L03, natural null-before-close; not File.

All twelve ADR hashes are recorded in audit.json. Their earlier statements of
pending work describe their own historical slices, not contradictory results.

## A6.1–A6.7 disposition (App v1:342–374)

| Obligation | Frozen evidence and remaining boundary |
| --- | --- |
| A6.1 native chooser | 3.51 source prerequisite and 3.53 actual-App needsReview selection are scoped dependencies; N01 positive native input/ack remains pending |
| A6.2 compiled Web | 3.53 readiness negatives plus recorded B File/CSP/storage flows; no manual OS/device claim or new requalification |
| A6.3 bounded fake sources | Existing cap/deadline/fence dependencies; L01 real pending factory, G3/L02/L03 controlled phases recorded; no reopening old boundary/vector suites and no aggregate gate promotion |
| A6.4 actual widgets/semantics | 3.53 widgets/default labels and B01–B04 positive browser; native trusted host/keyboard/semantics and its exclusion proof remain pending |
| A6.5 separate action/staleness | Browser positive/repetition/lifecycle/owner/time rows recorded; N01/N02 native counterparts remain pending |
| A6.6 no writes | Per-row browser continuous storage/network and snapshots recorded; 3.53 native byte snapshots alone do not satisfy new native continuous-observation transport |
| A6.7 static/compile/integration | Original per-slice logs retained; new native seam/transport/analyzer/build/profile obligations have not run; combined closure not asserted |

No table entry means full cross-platform acceptance passed. In particular a
browser row's name cannot stand for every native alternative. There is no native
CAS/shelf service invented to make the baseline observable.

## Completed official planning, implementation deferred

Native v1 N1–N7 / ADR 0260 bind actual SkillImportHost.testImport trusted policy/time
and real workspace, private retirement, real native backend, keyboard versus
framework-standard-semantics input, four N02 lifecycle/late cases, continuous
watcher/syscall/network witnesses and separate release artifact exclusion.
Seven native case IDs and NG0–NG5 are explicitly pending. The syscall tracer is
not installed; independent tracer/watcher/focus/watchdog qualification is required,
not assumed. No native fixture constructor, hook or runtime test is added now.

The audited native root lacks trusted test composition/lifetime; baseline-only
native snapshots lack the new independent observation transport. Implementing a
partial constructor together with this multi-slice evidence audit would leave
unqualified hooks. This increment intentionally lands only the permitted plan
and gates. Recommended 3.62: implement/qualify NG0–NG3, then the seven native cases
if coherent; otherwise land only independently qualified prerequisites. Do not
rerun frozen browser/crypto/source rows to inflate the new slice's test count.

## Verification and safety

- New official static/provenance/native-plan suite: 10 tests pass, including a
  negative source-provenance test. This suite reads old evidence, not old runtimes.
- Python syntax compilation and `git diff --check` pass.
- Original acceptance suite remains 5 pass / 1 known historical strict-equality
  failure, untouched (`unchanged-acceptance-suite.log`).
- No Dart/runtime changes: no new analyzer/native compile/runtime acceptance claim.
  Preserved Git tree/blob identities cover apps/packages/native/fixtures/lock and
  original acceptance test; LICENSE.core is byte-identical and never staged.

Counts 0 complete / 62 partial / 12 planned / 13 blocked; fullTasksCompleted=0,
I-037 partial, T-4/program unfinished. Original remainingAcceptance/remainingScope,
user_version=9 and restoreSnapshot unchanged. Full A6/combined G1–G5 remain false.
No installation, cross-namespace import, production roots/FTS/RAG, real-device,
model/provider/OS assistive-device/paid API/store acceptance, Mac/XS, deployment,
main merge or force push.
