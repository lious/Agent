# Signed import — actual App late-phase acceptance v1

Status: accepted planning supplement, Increment 3.58 / ADR 0257; NOT runtime acceptance.
Base: f42d46d30f9dc88f9a15106022ba34c3cea5d69b, clean matching feature/origin.
Dependencies: signed-import App acceptance v1 P2–P5, App v1 A2/A3/A4/A5/A6,
ADRs 0248/0250–0256. Existing matrix/remainingAcceptance wording is unchanged.

## C1 — concrete boundaries and gaps

These source citations describe existing code; they are NOT a new qualification:

- `packages/studio_assets/lib/studio_signed_skill_import_web.dart:11–17`: actual
  factory awaits SodiumVerifier.initialize and constructs FilmSkillRepository with
  the LIVE callback/private action port, not a pre-await snapshot.
- `.../craft/signed_import/sodium_verifier_web.dart:40–50`: strict real bridge
  promise and health checks. `packages/studio_assets/web/signed_import_bootstrap.js:46–100`
  owns its monotonic 10000 ms readiness deadline, verified script URL/SRI, self-tests
  and terminal pagehide failure. Never call healthy while loading: it fails terminally.
- `.../craft/signed_import/app_session.dart:59–78`: initialization completion is
  fenced before publishing ready; `:106–138` awaits select AND capture.quiescent
  before token/import. Widget disposal/context change must win over completion.
- `.../craft/signed_import/source_capture.dart:93–98`: ordinary cancel completes
  the nullable outcome with null without settling the ongoing operation.
  `:133–169` starts the selected-source deadline before length/lazy-open/read.
  `:175–203` awaits close, settles quiescence, THEN publishes successful bytes.
- `apps/studio_demo/lib/skill_source_linux.dart:27–69`: lazy same-handle opening
  occurs inside length, not the human picker wait. Controlled open tests model this
  port boundary, not GTK/OS/device opening. Web File has no native-FD open attestation.
- `apps/studio_web/lib/skill_import_panel.dart:48–99`: real session/factory/lifetime,
  pagehide and widget disposal; `import_fixture_composition.dart` currently has no
  late-phase factory observer or independent resource release controls.

Three gaps therefore require official gates: genuine real-factory completion
observation after retirement, bounded non-cancellable per-boundary reader gates,
and an early nullable result observed separately from quiescence. Replacing the
repository, shortening source/crypto deadlines, changing return ordering or using
old unit tests would not fill these gaps.

## C2 — immutable test composition / isolation

Use a NEW separately compiled Dart entrypoint under apps/studio_web/test mounting
the actual WebStudioApp.testImport, actual store/panel/owner/repository. Reuse public
fixture root/time derived from actual owner profile/namespace; initial now=1000,
confidence=true, rollback=false and empty grants. No production enrollment or
wall-clock trust. Default main remains opt-in OFF with empty roots/grants and an
unknown clock; ordinary opt-in retains those defaults too.

Only minimal typed TEST-ONLY source/release/observation configuration may be added.
It contains no repository/backend/verifier/snapshot/action-port replacement, success
value, consent callback, arbitrary JS predicate, browser parameter or source URL.
Transition/release lists and their sets must be immutable copies at construction
or demonstrably immutable supplied objects. Release actions are normal App-root
fixture buttons, reachable even after actual panel unmount, operating only on
that entrypoint's already-existing completers. They cannot select a second source,
advance clocks, recreate capacity, mint tokens or acknowledge. Repeat release is
idempotent, phase/owner-generation-bound, and cannot start another operation.

Use ONE late-phase fixture binary for all twelve profiles, not browser-selected
configuration or twelve hidden production modes. Its immutable typed source-gate
control list has explicit normal App-root Arm open/length/read/close buttons.
Arming changes only that entrypoint's local controlled-reader phase BEFORE the
first actual Choose; it starts no picker/open and is refused once any capture is
outstanding. It cannot change roots, policy, time, owner or repository. Record the
armed enum read-only. The host runner independently chooses whether to hold its
vendor response for L01; this is harness setup, never an App URL/storage parameter.
Thus G1 has exactly default, ordinary opt-in and one isolated fixture target.

Source fixtures use the EXISTING chooseSourceForTest typed capture/guard/selected
callback. It must pass the actual live predicate and selected callback into the
actual SkillSourceCapture.choose, and return its original result unchanged. No
four-byte source is represented as signed/verified success. Default and ordinary
opt-in artifacts must contain none of this entrypoint's public root fingerprint,
release/observer strings, gate markers or test imports/source-map entries. No
fixture artifact is deployable. No production code imports a /test/ library.

## C3 — L01 genuine pending readiness transport

Hold ONLY the HTTP response body for the EXISTING pinned sodium vendor request,
after Python has checked its locked path/size/SHA-256/SRI before serving/execution.
Do not hold Flutter startup or substitute a JS bridge/promise/onload callback.
Actual App shell/fixture controls must render while the real factory is pending.
The host's release channel is test-runner IPC/state, NOT an App fetch endpoint,
pack URL, JS configuration export or production service. Release identical bytes
under unchanged mandatory CSP/SRI and a fresh response-specific style nonce.

A minimal App-INTERNAL passive observer may count start/completed/failed events
around the call to createWebSignedSkillRepository. It always invokes that actual
factory immediately and returns/rethrows its actual result unchanged; no factory
or repository result is supplied by the configuration. Events may carry only a
phase/generation/count, never a repository, action port, snapshot or consent.
Observer faults fail the TEST and must neither fake readiness nor replace/suppress
backend failures. App-root read-only UI/DOM facts can outlive PANEL disposal to
record the real future's eventual success; they cannot republish it to the panel.
Do not add a public SDK runtime observer or a general plugin/factory API.

Required order: actual factory started -> pinned request held -> Choose disabled /
no report -> trusted standard fixture control retires/unmounts -> release exact
vendor bytes -> actual factory completed successfully -> no ready/Choose/report/
ack revival after event-loop settlement and ordinary App rebuild. For disposal,
assert the panel is actually absent, not just hidden; root remains for observation.
For context change, use an actual existing known owner transition, not a gate flag.

The hold has an 8000 ms MAXIMUM test watchdog from request receipt, leaves margin
inside the UNCHANGED bootstrap 10000 ms deadline, and fails if actual ready/completed
is not observed within that real deadline. Watchdog releases only for cleanup and
marks the case failed; timeout/error is NOT successful late completion. Never freeze
or monkey-patch performance.now/timers, disable health checks, call healthy while
pending, or synthesize bootstrap success. Real document pagehide terminally fails
the bootstrap and therefore is NOT substituted for successful late widget disposal.

## C4 — L02 bounded controlled reader gates

Use a four-byte controlled TEST source, not real File/GTK/OS qualification. Select
one reader synchronously via the existing source seam. The selected-reader future
resolves normally; logical non-cancellable lazy open is inside length AFTER the
real common deadline starts. Provide independent open, length and first-read gate
variants. Open/length are separate recorded phases even though length awaits lazy
open. No shortened/replaced 30000 ms deadline or unlimited fake stream.

Each gate uses a local completer owned by the compiled test entrypoint. Record
selection count, selected/read phase, open/length/read start/completion, close start/
completion, outcome kind, busy and quiescence. These are read-only facts, not JS
commands. After actual Choose reaches the held boundary, use separately actual
Cancel source capture, panel unmount, or existing scope/owner transition BEFORE
releasing it. A non-cancellable gate remains pending despite ordinary cancel or
terminal dispose; test cleanup/release eventually resolves it once.

Require no additional read after invalidity, no token/report/ack publication, and
exactly one close for each eventually selected reader. A late open must close its
one eventual resource without another open. Ordinary cancel/context change cannot
pretend the selection.dispose hook ran; terminal widget disposal may run that
cleanup hook exactly once without claiming kernel abort. No new Choose/capacity
while the actual operation/close is pending; repeated standard activation starts
no second picker/open/read. After release, require actual quiescence and terminal
no-revival for disposed/context owners. Plain cancel may become ready ONLY after
quiescence and only for a new explicit selection, never an automatic retry.

A 15000 ms selected-source TEST watchdog releases all gates in finally and fails
the row; it is not a new runtime timeout. Finish ordinary cases before the existing
30000 ms source deadline so its timeout cannot masquerade as tested invalidation.
Failed/hung phases, missing cleanup or missing observations are failures, not skips.

## C5 — L03 early result versus close/quiescence

Do NOT manufacture successful bytes before close: the current source contract
publishes successful non-null bytes only AFTER close/quiescence. Never change that
ordering, fork the capture controller, start a second capture, or inject a token
just to make this row observable.

Natural supported case: actual bounded four-byte reader finishes reads/EOF, enters
its HELD close; capture.busy=true and quiescence is pending. Actual standard Cancel
source capture completes the original nullable choose result with null while close
remains pending. A passive typed source wrapper observes and returns that same null
unchanged. Require outcome=null observed BEFORE close completion; now apply a known
owner change BEFORE releasing close. Require Choose/ack disabled, no token/report/
publication, no replacement source and no revival after actual close/quiescence.
Counters must show one selection, one open, bounded reads/EOF and one eventual close.
App session must still await capture.quiescent before ANY token/import path; G0
pins that ordering independently of the natural-null browser observation.

This qualifies only the existing nullable early-cancellation path. Successful
non-null-before-quiescence is structurally unavailable under this capture API and
is NOT claimed as a dynamic browser permutation. Deadline/error variants are not
silently counted; changing production ordering or inventing an adversarial adapter
would require a separate official contract decision, not this implementation.

## C6 — enumerated profiles (all runtime rows PENDING)

| Case ID | Held phase | Standard action before release | Mandatory oracle |
| --- | --- | --- | --- |
| L01-widget-dispose | Actual vendor/factory promise | Actual panel unmount | Real factory success later; panel stays absent |
| L01-context | Actual vendor/factory promise | Known owner transition | Real factory success later; owner stays retired |
| L02-open-cancel | Lazy open inside length | Cancel source capture | No read; eventual single-resource close |
| L02-open-dispose | Lazy open inside length | Panel unmount | No read; close once; terminal cleanup |
| L02-open-context | Lazy open inside length | Known owner transition | No read; close once; no revival |
| L02-length-cancel | Selected resource length | Cancel source capture | No read after invalidation; close once |
| L02-length-dispose | Selected resource length | Panel unmount | No read; close once; terminal cleanup |
| L02-length-context | Selected resource length | Known owner transition | No read; close once; no revival |
| L02-read-cancel | First non-cancellable read | Cancel source capture | Late chunk discarded; no second read |
| L02-read-dispose | First non-cancellable read | Panel unmount | Late chunk discarded; close once |
| L02-read-context | First non-cancellable read | Known owner transition | Late chunk discarded; close once; no revival |
| L03-null-close-context | Close with null outcome pending quiescence | Cancel, observe null, owner change | No token/capacity before actual quiescence |

## C7 — prerequisite gates and evidence decision

- **G0 source-contract preflight**: executable static checks bind cited actual
  factory/bridge, private session ordering, lazy-open/deadline, close-before-success
  and early nullable cancel behavior; source SHA-256 and runtime delta are pinned.
  Passing this is planning evidence ONLY, not executable App acceptance.
- **G1 artifact isolation**: fresh disposable compiler cache; three actual release/
  CSP/source-map builds (default, ordinary opt-in, late fixture); exact frozen input
  and output SHA-256; verify all gate/control/root sentinels before browser execution.
  Source edits during build abort; no unverified stale incremental artifact reuse.
- **G2 real pending readiness transport**: independently demonstrate held verified
  request and actual factory start/completion counts inside unmodified deadline;
  establish read-only observer cannot supply readiness/consent/repository values.
- **G3 reader transport**: independently demonstrate each selected/open/length/read/
  close release phase, real capture busy/outcome/quiescence order, bounds, once-only
  cleanup and watchdog failure behavior. This is controlled-port evidence, not File.
- **G4 combined profiles**: twelve FRESH contexts/stores, actual App/panel/factory/
  owner, input method and per-phase order/count evidence for EVERY C6 row; no borrowed
  B01–B11/old runtime result. Standard controls only; no Dart consent invocation.
- **G5 preservation/audit**: per-row actual CSP/readiness/vendor SRI and startup vs
  component requests, continuous IDB/CAS/shelf/project/local/session mutation
  observation and full storage snapshots through teardown. Harness IPC/files are
  separate from App persistence. Keep raw failures and environment/entrypoint/input/
  executable digests; no silently omitted branch or inferred completion. Static,
  format/analyzer/syntax checks for changed implementation sources are mandatory.
  Do not invent CAS/shelf APIs to instrument absent services: prove no such
  capability/path is supplied and no new store is created. Use phase order and
  monotonic durations within their own clock domains, not mixed host/browser
  wall-clock timestamps.

G0 alone is executable now. G1–G5 are NOT implemented or qualified by Increment
3.58. Implement/qualify new transports before counting combined rows; if time or
coherence does not allow all phases, land ONLY independently qualified work and
leave other rows pending with exact IDs. This increment deliberately lands the
completed official plan/preflight rather than bundling two unqualified transport
mechanisms and twelve combined profiles into a false completion claim.

N01–N02/full A6/I-037/T-4/program remain unfinished. No production roots, installation,
cross-namespace import, FTS/RAG, device/model/provider/OS assistive-device acceptance,
paid APIs, deploy, Mac/XS, main merge or force-push. user_version=9 and restoreSnapshot
remain unchanged; fullTasksCompleted=0 and counts stay 0/62/12/13. No original
remainingAcceptance/remainingScope wording is rewritten.
