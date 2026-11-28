# Signed-import App acceptance fixture composition v1

Status: official planning supplement, Increment 3.54; NOT executable qualification.
Normative parent: [App v1](s8f-signed-import-app-v1.md), especially A2/A3/A4/A6;
ADRs 0248, 0250, 0251 and [0252](../../adr/0252-existing-app-signed-import-composition.md).
Base: `5220d66b0c00008f215efb9bbcdca0ec57d0f5f3`.

## P1 — concrete gap, not permission to enroll publishers

A6.4 allows isolated PUBLIC App-profile roots/time for positive acknowledgment.
The actual WebStudioApp currently constructs a private disabled policy at
`apps/studio_web/lib/main.dart:28–36` and a private snapshot with wall time, empty
grants and default false clock confidence at lines 149–168. There is NO actual-App
browser test-profile binding. The widget fixture in
`apps/studio_demo/test/skill_import_composition_test.dart` is not that binding.
Setting a URL/query flag, editing generated JS, replacing the App with a panel
facsimile, or claiming the needsReview default flow acknowledged would be wrong.
This supplement supplies the missing trusted test-root composition and observation
contract BEFORE implementation. It changes no crypto/privilege/installation API.

## P2 — test artifact, trusted constructor input, unchanged default entrypoint

Implement a separately selected Dart entrypoint under `apps/studio_web/test/`,
compiled with the same App package and dependency lock. It must mount the ACTUAL
WebStudioApp, real browser store and real SkillImportPanel/owner/session; not a
standalone panel harness or a copied App. Production `lib/main.dart` remains the
default entrypoint; default opt-in remains OFF, roots/grants empty, confidence
false. No test-key/time configuration is read from browser state or source bytes.

The minimal planned seam is an App-private typed immutable composition object
accepted ONLY through a named test constructor of that existing App. It is not a
shared editor/SDK API, serialized map, JS export, URL/localStorage parameter or
new enrollment control. Normal construction cannot select this object. The
fixture library and key material must not be imported by production `lib/` code.
The following fields/roles bind its behavior (names may follow local style):

- Policy factory: `(AppProfile, Namespace) -> BuildTimeSignaturePolicy`, invoked
  once after the REAL project opens. Inputs come from the existing App owner,
  not the selected pack. Keep returned profile/policy identities stable across
  ordinary rebuilds. No replacement backend/verifier/repository factory or action
  port is supplied by this object. Always use createWebSignedSkillRepository.
- Trusted fixture clock: integer seconds, confidence and rollback, all owned by
  that compiled test entrypoint; fixed deterministic initial time matching public
  signer validity/pack expiry. Wall time never becomes trusted production time.
- Grants: immutable installed/session/branch sets. Positive acknowledgment uses
  empty sets and a compatible pack, proving acknowledgment grants no execution.
  Negative cases may replace one explicitly identified set under P3.
- Optional TEST-ONLY phase gates/source fixtures: typed controlled readers using
  the existing bounded SkillSourceCapture contract, never a successful-verifier
  stub. Used ONLY by labeled late-state cases, never counted as real File/chooser
  acceptance. No pack/model/JS predicate supplies a liveness result.

The named test constructor is planned, not an assertion that it exists today.
Default release builds must show no test entrypoint import, root fixture, seed,
trusted-time sentinel, phase gate or harness control in their reachable code.
Record default and fixture build source digests and entrypoints separately; a
fixture binary is NOT a deployable production artifact. No production deployment.

## P3 — owner lifetime and controlled changes, no acknowledgment endpoint

Keep the report, repository and ImportUserActionPort private to the REAL panel.
The App composition owner needs only an App-private synchronous lifetime signal:
increment generation, synchronously retire the mounted panel/session and cancel
capture BEFORE publishing a known profile/policy/namespace/grant/clock-confidence/
rollback/owner replacement. Register/unregister that signal with panel lifetime;
it cannot carry a report, preview id, gesture, action port or consent function.
Do not change existing snapshot comparators or use equal scopeHash as identity.
An ABA return cannot revive a retired session or replace a still-pending source.
Normal forward trusted time is observed without treating every tick as retirement;
backward time, lost confidence or rollback retire BEFORE publication.

Fixture-controlled changes run from compiled test code after normal test-only
UI/lifecycle events, not JS calls into Dart consent or mutable browser globals.
Any test-only visible navigation/change controls belong to the existing App's
fixture composition and are absent from default builds. Gates cannot resolve to
a forged acknowledgment/backend success. UI acknowledgment always uses the
actual separate standard button and the actual repository. A read-only DOM/AX
trace may report case/phase/observations, but has no executable consent endpoint.
No private callback invocation, `explicitPreviewConsent` call, report rewriting
or synthetic `userConfirmed` is accepted as browser consent evidence.

## P4 — fixture / host / observation prerequisites

Use publicly documented deterministic signing seed/key solely in test sources;
record seed provenance, Ed25519 public key fingerprint, policy threshold/epoch,
fixed clock, expiry, namespace, exact envelope/payload/permission hashes and
expected tools/license facts. Build DSSE bytes with the existing fixture helper;
never substitute signed=true for a verified report. Production roots stay empty.
Neither fixture nor root enrollment is read from the selected pack.

For each new browser case, use a fresh browser context/origin/store. Build the
actual target Dart-to-JS release with trusted
`--dart-define=STUDIO_SIGNED_IMPORT_PREVIEW=true` and the installed SDK's `--target`, `--csp`,
`--no-web-resources-cdn` and existing main-realm self-hosted CanvasKit profile;
never Wasm-target/worker/CDN fallback. Record SDK/engine and executable digests.
Retain exact pinned vendor path/length/hash/SRI and verify BEFORE execution.
Use unchanged A5/W2 mandatory CSP plus response-specific style nonce; no inline/
eval/blob/data-script or network/certificate exception. Test scripts must not
weaken the host. Old CSP/crypto/adapter qualifications are dependencies, not rerun
or borrowed acceptance. A new combined case still records its own CSP/readiness.

Use trusted browser keyboard/pointer input and the real chooser boundary for
positive File flows. CDP public file injection is not manual OS-dialog/device
qualification. Standard accessibility activation means the actual button action,
not evaluating its Dart callback. Record input method per case. Pre-button
selection/import/rebuild must leave the actual acknowledgment summary absent.

Before import, establish the actual App's post-open baseline: project revision/
canonical bytes, IndexedDB database names/store keys/records, local/session
storage; record baseline startup requests separately. Observe mutations and
requests through the whole flow and teardown, not just summary documentWrites=0.
No import DB/CAS/shelf/project writes, publisher lookup, upload, analytics, tool/
approval calls or new storage. Fixture setup/signing happens before the baseline.
Record no-component-write observations separately from unrelated App startup.

## P5 — independently enumerated remaining matrix

Each row is a NEW combined case, not an old qualification rerun. Browser cases
use the actual compiled App; native rows use actual existing-App widgets/GTK
where specified. No row is marked passed by this plan. Split a row into explicit
case IDs for each listed alternative; do not report one case as every permutation.

| IDs | Required exercise | Expected observation |
| --- | --- | --- |
| B01 | Public pinned-root/fixed-clock signed File, keyboard Tab then Enter on Choose, separate Enter on acknowledgment | Verified identities exactly match fixture; no auto-ack; one summary with documentWrites=0/executionAuthority=false, report cleared |
| B02 | Same positive flow, Space activates separate acknowledgment | Actual standard control, one acknowledgment; no gesture reuse |
| B03 | Real accessibility activation, then repeated keyboard/pointer activation | No second acknowledgment, approval, writes or execution |
| B04 | Select/import, ordinary existing-App rebuild, message event with pack-shaped consent fields | Report unchanged, no acknowledgment; no script/Dart consent endpoint |
| B05 | Real chooser cancel/reset, same-file reselect; then discard and fresh reselect | One outstanding source, no automatic retry; fresh report, old target unusable |
| B06 | Preview -> navigation/dispose, browser reload, actual navigation away/back (separate cases) | No restored report/gesture; fresh realm starts baseline, no acknowledgment replay |
| B07 | Preview -> pagehide; reading -> pagehide (separate cases) | Retire/cancel; late completion never republishes report, chooser capacity not replaced |
| B08 | Visible/hidden/paused/detached transitions versus transient inactive focus | Teardown invalidates; transient chooser focus alone does not retire or auto-ack |
| B09 | Known profile identity, policy epoch/key removal, grant set, equal-scope project identity and ABA changes (each separately) | Synchronous retire BEFORE new state; no old report use, no cross-namespace import |
| B10 | Trusted forward time exceeds preview/pack validity | Actual repository refuses acknowledgment, clears target, requires fresh selection |
| B11 | Backward time, confidence loss, rollback flag (each separately) | Retirement; acknowledgment unavailable, no clock override |
| L01 | Pending real repository initialization completes after disposal/context change | No ready/Choose/report revival; never fake crypto readiness success |
| L02 | Controlled slow/non-cancellable source open or read; cancel, dispose or scope change before each completion (separate cases) | Existing fence checks each await; no late preview or queued/reopened source |
| L03 | Capture result returned while quiescence is pending, then owner change | No token/import/publication until safe; terminal invalidation and no replacement capacity |
| N01 | Existing Linux App keyboard/accessibility positive fixture acknowledgment | Same real owner/repository and private widget; no new native crypto qualification |
| N02 | Existing Linux App navigation/dispose and late controlled-source completion | Retire/no revival; compare actual project/database/CAS/shelf baseline |

P4 no-write/network/CSP/identity observations apply to EVERY applicable row,
including negative/lifecycle rows. For navigation teardown, collect observations
before and after old-realm destruction via browser-owned instrumentation rather
than losing the old result. For pagehide, distinguish a real navigation-generated
PageTransitionEvent from a labeled synthetic handler-only test; synthetic dispatch
cannot stand in for actual navigation/BFCache acceptance. If BFCache is not used,
record reload behavior honestly; never assert that a persisted page was exercised.

A phase/boundary not controllable through these trusted fixture seams stays
unqualified with an exact reason; never call a historical unit result combined
App acceptance. Audit row coverage and outstanding A6.1–A6.7 obligations before
setting fullA6AcceptanceComplete=true. Completing these rows still does NOT close
I-037 installation/publisher/other remaining product acceptance.

## P6 — increment boundary and sources

3.54 lands this planning supplement ONLY. The actual-App fixture constructor,
private pre-publication lifetime bridge, separate artifact proof and the browser/
native matrix require implementation and fresh combined qualification together;
none exists merely because a policy factory is written in this document. Do not
smuggle a partial fixture hook into production and call the matrix complete.
Recommended 3.55 implements the minimal fixture seam and B01–B04 with independent
combined evidence, then schedules the remaining explicit rows without pretending
all A6 is done. No original remainingAcceptance wording is changed.

Sources checked 2026-11-28 Asia/Shanghai:
- Existing source anchors in P1, and AppImportSession in
  packages/studio_assets/lib/craft/signed_import/app_session.dart:16–231.
- Existing snapshot/policy contracts in importer.dart:44–114; no new signaturePolicy.
- App plan A2/A3/A4/A6 and ADR 0252:68–101 (explicitly incomplete matrix).
- https://docs.flutter.dev/reference/flutter-cli (analyze/test/build commands).
- Installed `flutter build web --help`: --target is the main entrypoint file;
  --csp disables generated dynamic code. Help is recorded with this plan.

No runtime/vector/host/source/owner-widget qualification was rerun in this planning
increment. Project user_version=9, InversePatch=restoreSnapshot; counts remain
0 complete / 62 partial / 12 planned / 13 blocked, fullTasksCompleted=0.
I-037, T-4 and program remain unfinished. No device/model/provider/paid API/store
release acceptance; no durable install, cross-namespace import, production roots/
FTS/RAG, user Mac/XS, main merge, force push or standing-exclusion runtime.

## Increment 3.55 — browser semantics action observation

For B03, activate the actual browser semantics DOM button's standard click action
and observe the real engine-to-widget/repository result. This is a browser
semantics-action boundary test, NOT an OS screen-reader/assistive-device claim.
B01/B02 independently require trusted keyboard input; a DOM click cannot substitute
for either keyboard case. Never invoke a private Dart callback or JS consent export.
B04 may use a fixture-only normal App-root rebuild control (allowed by P3), with
read-only rebuild count, to prove cached policy/profile identity survives rebuild.
That control and counter must be absent from default artifacts along with roots/time.

## Increment 3.56 — lifecycle transport and reading-gate bindings (t155u)

B05 must distinguish actual Chrome/GTK Escape on the box display (trusted cancel)
from empty CDP File injection, which does not dispatch cancellation in this Chrome
profile. Never forge isTrusted. App cancellation/reselection and real File input
reset are observed in the ACTUAL compiled App, not the old adapter harness.

B06/B07 must observe old-realm pagehide/pageshow via a browser-owned read-only CDP
trace before destruction, recording isTrusted/persisted and realm identity. Real
reload and away/back are separate cases. If BFCache is not used, record fresh-realm
reload behavior, not BFCache restoration. A fixture-only normal App control may
synchronously invalidate-before-unmounting its import panel, without closing or
editing the project; this separately exercises actual widget disposal.

The minimal B07 reading seam is an OPTIONAL typed TEST-ONLY capture selector on
AppImportFixtureConfiguration, callable only from the actual App Choose action.
Its signature carries SkillSourceCapture, the existing live predicate and selected
phase observation, returning Future<Uint8List?>. It cannot supply a repository,
verifier, snapshot, action port or success result. The isolated reading entrypoint
selects this seam only at compile time. A bounded four-byte controlled reader holds
one read until pagehide, then releases once after the normal panel handler. These
bytes MUST NEVER reach import after invalidation; this is not File/crypto success
qualification. Read/open/close/completion counters are read-only DOM trace data,
not JS command callbacks. No source reopen, capacity replacement or token queue.
Use both real reading navigation and a separately labeled synthetic handler-only
pagehide/late-completion case; the latter is not navigation/BFCache evidence.

B08 must distinguish real browser visibility/focus transitions from controlled
Flutter framework lifecycle notifications. Actual tab hide/show is observed via
visibilitychange. Inactive/hidden/paused/detached injections use standard fixture-
only UI controls and WidgetsBinding.handleAppLifecycleStateChanged, followed by a
fixture timer returning to resumed so frames can render the result. They qualify
only that framework observer boundary, NOT OS lifecycle/device delivery. Inactive
must preserve the report/source capability; hidden/paused/detached must retire it
and resuming cannot revive it. Native chooser focus observations are recorded, not
assumed from CDP chooser interception. Test controls/gates are absent from default
and ordinary opt-in artifacts and expose no consent/clock/publisher endpoint.

Every variant keeps actual App/store/strict host/SRI/readiness and continuous
no-write observation. Navigation startup requests are separated from import
requests; browser-side trace transport is read-only and creates no App persistence.
These bindings do not qualify B09–B11/L01–L03/N01–N02 or complete full A6.

Old-realm transport refinement: use capture-phase window observers as recommended
by Chrome's Page Lifecycle API. Primitive User Timing marks from the observer may
be collected by the documented CDP Tracing.start/end/dataCollected/tracingComplete
transport across renderer/context destruction; require dataLossOccurred=false.
Console delivery alone is not accepted when a destruction-time notification is
missing. Only public native event/realm/write/reader counters enter marks, never
source bytes, consent functions or App persistence. No event synthesis, handler
skipping, debugger termination, network trace upload or security relaxation.
Wait for actual main-frame navigation commit before inspecting the new/restored
App. Missing observations are failures, not proof of a callback. Sources checked
2026-11-28 Asia/Shanghai: developer.chrome.com/docs/web-platform/page-lifecycle-api,
developer.mozilla.org/en-US/docs/Web/API/Window/pagehide_event, and the public
ChromeDevTools/devtools-protocol json/browser_protocol.json Tracing schema.

## Increment 3.57 — typed late-state publication and time transport (t155u)

The immutable fixture configuration currently cannot express individual owner,
grant or clock changes: replacing it always retires, while the App snapshot uses
hardcoded profile/grants. Complete that concrete transport gap BEFORE implementation.
An optional immutable list of named typed transition sequences may be supplied
ONLY by the separately compiled test entrypoint. Each step carries only optional
owner-derived profile/policy factories, an in-memory project identity, immutable
installed/session/branch sets, and trusted integer time/confidence/rollback.
No repository, verifier, snapshot, action port, consent callback, serialized map,
JS endpoint, URL parameter or browser-persisted configuration is accepted.

The actual App owns private active overrides, renders normal fixture-only buttons,
and applies steps synchronously. It MUST signal its existing private lifetime
before publishing any profile/policy/grant/owner change, backward time, confidence
loss or rollback. Owner identity changes replace the actual in-memory project
pointer in the same namespace, NOT the store record. No edit/save follows in these
cases. Profile identity uses a distinct AppProfile with equal fields. Policy epoch
and key removal are separate owner-derived policy factories. Grants change each
of the three sets separately. ABA is explicitly empty session grant -> one tool
-> empty, within ONE synchronous UI transition: restored equal scope cannot revive
the retired panel. Existing source/owner comparators are unchanged.

Forward trusted ticks alone MUST NOT signal retirement or replace profile/policy
identity. B10 first advances within key validity and retains the exact report, then
advances to the bundled signer's exclusive notAfter boundary and uses the actual
separate acknowledgment button. The real repository must refuse, clear the target
and require fresh selection. 'preview/pack validity' in B10 refers to existing
signature-policy eligibility at acknowledgment (signed-import v1 key interval and
policy/time recheck), NOT a new pack expiry field, preview TTL, wall-clock trust or
new importer protocol. No missing schema field/runtime is invented.

B09 has eight independent fresh profiles (profile identity, epoch, key removal,
installed/session/branch grants, equal-namespace project identity, session-grant
ABA). B10 has its own fresh profile and actual acknowledgment refusal, NOT a fake
clock-induced retirement. B11 has three independent profiles (backward seconds,
confidence loss, rollback flag). UI/AX trace names applied steps; no private consent
callback is invoked. Retired cases cannot acknowledge/reselect or revive on rebuild.
All cases keep actual App/store/File/factory/readiness, baseline snapshots and
continuous no-write/network/CSP observation. Default and ordinary opt-in release
artifacts exclude every new fixture control, fixture key/time and entrypoint.
L01–L03/N01–N02 and full A6 remain deferred. Prior rows are NOT rerun.
