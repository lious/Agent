# Increment 3.57 — actual-App B09–B11 late-state/time acceptance

Clean matching feature/origin base: `2a137beb9ef088aaf855a343a7a3d3c56694c525`.
Official plan: App acceptance v1 P2/P3/P5 and its new 3.57 transport supplement,
ADRs 0248/0250–0256. Concrete transport bindings were completed before code.

## Recorded results — 2026-11-28 Asia/Shanghai

**Twelve independent fresh compiled-App Chrome profiles PASS**:

| Cases | New combined observation |
| --- | --- |
| B09-profile | Distinct equal-field profile identity; terminal retirement |
| B09-epoch / key-removal | Each owner-derived policy change independently retires |
| B09-installed / session / branch | Each grant set changes separately; no authority |
| B09-owner | Actual in-memory project id changes, namespace/store stay unchanged |
| B09-aba | Empty session grant -> one tool -> empty synchronously; no revival |
| B10 | Forward 1001 retains report; 10000 reaches exclusive signer expiry; actual acknowledgment refused; new File selection is independently refused with SKILL_IMPORT_SIGNATURE |
| B11-backward / confidence / rollback | Each adverse clock condition separately retires |

Known changes signal the private actual owner lifetime BEFORE publication. Retired
cases cannot acknowledge or reselect and remain retired through ordinary App
rebuild. Before activating a transition, the driver requires the verified report
still present, so scroll-induced disposal cannot masquerade as the tested change.
Read-only UI facts confirm the actual applied state. No repository/verifier/action
port/snapshot replacement or consent callback is exposed.

B10 does NOT substitute forced retirement for repository rejection: acknowledgment
remains enabled through normal forward ticks, and the real separate standard
button produces the actual stale/refused result. No acknowledgment is accepted.
B10 uses existing signer eligibility, not a newly invented preview TTL or pack
expiry field (signed-import v1 S3/S4, App v1 A4). No old crypto suite is rerun.

Every case uses actual WebStudioApp.testImport, owner/panel/store, real Web factory,
standard keyboard input and public File injection. Strict CSP/readiness, verified
vendor hash/length/SRI, exact report identity checks, continuous component mutation/
network observation and full post-open storage snapshots pass. No component writes,
requests, installation, tool approval or execution. Startup is separate from import.

Three release/CSP/source-map artifacts PASS: default, ordinary opt-in, late-state
fixture. Public fixture roots/fingerprint, trusted time entrypoint and new fixture
controls/facts are excluded from both production-shaped artifacts. No held reader
is compiled into any target. Dart format/analyzer, Node/Python syntax, seven new
static evidence/preservation tests and git diff checks pass. Historical acceptance
remains **5 pass / 1 known strict-equality failure**, unchanged code/wording.

## Reproduce / artifact provenance

`python3 tools/acceptance/run_skill_import_app_late_state.py` builds three actual
release targets from a fresh disposable Flutter compiler cache and runs ONLY these
new cases. A source-change guard and mandatory read-only-fact artifact sentinels
prevent stale incremental development output from being accepted. No source input
was changed during the final fresh build or subsequent browser run.

`fresh-build-and-reselection-diagnostic.log` retains the final fresh three builds
and development failure caused by expecting a generic error label instead of the
existing SKILL_IMPORT_SIGNATURE. The test was corrected to require that exact
existing code; runtime behavior was not rewritten. Final all-pass `runner.log` uses
`--reuse-verified-artifacts`: all Dart/lock source and main/source-map SHA-256 values
are rechecked, all exclusion assertions and pre-execution vendor integrity checks
rerun, and all twelve cases use fresh browser profiles. This is verified artifact
reuse, not a browser-only qualification bypass. `artifacts.json`, `contract.json`,
`public-fixture.json`, per-case JSON and `environment.json` bind the result.
No 3.31–3.56 runtime or B01–B08 qualification suite was rerun.

## Deferred / next

L01–L03 and N01–N02 remain deferred; full A6 is NOT complete. Recommend 3.58 to
complete concrete trusted phase-gate bindings for L01–L03 first, then implement
and independently qualify a coherent slice. Native rows remain separate.

I-037 remains partial. Counts: **0 complete / 62 partial / 12 planned / 13 blocked**;
fullTasksCompleted=0; T-4 and the overall program are not done. Original remaining
acceptance/scope, user_version=9, restoreSnapshot, crypto/host/store/locks and
LICENSE.core are unchanged. No production roots, durable install, cross-namespace
import, production FTS/RAG, OS assistive-device, device/model/provider acceptance,
paid APIs, deploy, Mac/XS, main merge or force-push.
