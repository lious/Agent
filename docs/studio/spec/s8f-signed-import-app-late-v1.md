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

## Increment 3.60 — controlled-reader witness details (before implementation)

C2/C4/C5 are implemented through a narrow App-private reader-control interface:
arm one typed open/length/read/close enum, or release the existing gate. It carries
no snapshot, liveness replacement, factory, token or consent. Normal App-root test
buttons invoke it; arming is refused after source start, including while cancelling.
A pure-Dart TEST controller owns one bounded four-byte reader, one gate and read-only
counter observations. A test-entrypoint DOM sink publishes only those observations.
Sink faults are recorded/test failures and cannot alter capture outcomes.

Record actual selected/open/length/data-read/EOF/close/outcome/quiescent events.
Logical open is memoized inside length, under the common existing source deadline;
close waits for that same open and never reopens it. Invalid open/length completion
permits no read; invalid first-read completion permits no second read/EOF. L03
finishes one four-byte chunk plus EOF before holding close, then observes actual
cancel(null), owner retirement and eventual single close/quiescence in that order.
The wrapper returns the ORIGINAL capture future and adds passive observations only.

The compiled browser controller uses the specified 15000 ms selected-source test
watchdog. It records failure, cancels the actual capture and releases only for
cleanup; it cannot count as manual success. Pure-controller non-browser fault
unit tests may use a shorter TEST watchdog to exercise that failure path without
changing the production 30000 ms deadline or browser crypto/source clocks. Actual
browser rows must finish before their unchanged watchdog/deadline. L01 remains a
frozen dependency, not a newly rerun profile. Native rows/full A6 remain deferred.


## Increment 3.64 — combined G1–G5 / late C2 same-binary binding (t155u)

Status: official PLAN/EVIDENCE ONLY. Combined G1–G5 and full A6 are not executed
or claimed. Base 79109119861569d1b32093f8ba2f0ad67f7ba58d was clean and matched
origin/feat/studio-foundation-20261125 before editing. Normative parents remain
C2:58–66, C6:169–182, C7:190–212, acceptance P5:150–154, App v1 A6.1–A6.7, the
3.61 audit, and ADRs 0257–0262.

The official late C2 same-binary condition is already specified and is not met.
C2 requires one late-phase fixture binary for all twelve C6 profiles, not
browser-selected configuration or a union of historical builds. The 3.61 audit
recorded two distinct late-fixture main hashes and remains authoritative:

- L01 (3.59, e499a223995bf067edbf506bb8e45d681a5b8ad6):
  `afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29`
- L02–L03 (3.60, 7c616a4aab245505f3fdd9fac15095fd640f5e3b):
  `935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb`

L01 observer methods being byte-identical across 3.59/3.60 still does not
establish binary equivalence. 3.59 and 3.60 contracts themselves leave
allLateRuntimeGatesComplete and full A6 false, and limit G1/G4/G5 to their
own profiles. Independently qualified G2 (3.59) and G3 (3.60) transports, and
the 3.62–3.63 native NG0–NG5 / N01–N02 rows, are reused as scoped dependencies.
They do not satisfy C2 or C7 combined evidence and must not be summed into a
combined G1–G5 or full A6 claim. Increments 3.59–3.63 are not that acceptance.
There is no contradictory frozen pass/fail that requires rerunning L01,
B01–B11, L02–L03, G3, or N01–N02 in this increment.

No studio_web late-fixture source has changed since 3.60, so the current
`test/import_late_phase_entrypoint.dart` already carries both the L01 pending-
factory and L02–L03 controlled-reader transports. That fact still does not
make either historical late main hash the one C2 binary.

The official combined G1–G5 run, reserved for the next increment, must:

1. Freeze input source SHA-256 at that increment's clean base (the late
   entrypoint, reader/factory test helpers, Web import composition, and the
   already-pinned vendor/lock/bootstrap set). Abort if those sources change
   during the build.
2. Perform a fresh G1 with a disposable compiler cache: three actual
   release/CSP/source-map builds (default, ordinary opt-in, and one isolated
   late fixture targeting `test/import_late_phase_entrypoint.dart`). Record
   exact input and output SHA-256. Default and ordinary opt-in must contain
   none of the late entrypoint's public root fingerprint, release/observer
   strings, gate markers, or test imports/source-map entries. The fixture
   artifact is not deployable. This new late main hash is the single C2
   binary; neither historical late hash may be reused as that binary.
3. Reuse the already-qualified G2 held-vendor / factory-observer transport and
   the G3 controlled-reader arm/release/natural-null transport already compiled
   into that fixture. Do not requalify 3.59/3.60 unit or canary suites, and do
   not rewrite those historical contracts.
4. Independently qualify G4: one fresh browser context/origin/store for every
   C6 row (L01-widget-dispose, L01-context, L02-open-cancel, L02-open-dispose,
   L02-open-context, L02-length-cancel, L02-length-dispose, L02-length-context,
   L02-read-cancel, L02-read-dispose, L02-read-context, L03-null-close-context)
   against that one fixture binary, with actual App/panel/factory/owner, the
   recorded input method, and per-phase order/count evidence. Do not borrow
   3.59/3.60 profile results or any B01–B11/N01–N02 runtime as those twelve
   combined rows.
5. Independently qualify G5 for each of those twelve combined rows: actual
   CSP/readiness/vendor SRI, startup versus component requests, continuous
   IDB/CAS/shelf/project/local/session observation and full snapshots through
   teardown. Prove CAS/shelf absence rather than inventing APIs. Keep raw
   failures and environment/entrypoint/input/executable digests.

A passing combined G1–G5 run still does not, by itself, set
fullA6AcceptanceComplete. Full A6 additionally requires the P5 audit of
outstanding A6.1–A6.7 obligations against recorded evidence, and still does
not close I-037 installation, production publisher roots, cross-namespace
import, or production FTS/RAG. Independently qualified B01–B11 and N01–N02
rows remain scoped historical/native evidence; they are not rerun unless a
genuine frozen-evidence conflict appears, and a browser row's name still
cannot stand for a native alternative. N01-semantics remains
framework-standard-semantics, not OS assistive-device qualification.

This increment lands only the completed official binding. Recommended next
increment executes the combined G1–G5 run specified above, then stops short of
full A6 unless that A6.1–A6.7 audit is honestly complete in the same coherent
verified slice.

## Increment 3.65 — official combined G1–G5 run

Status: official combined G1–G5 COMPLETE against one fresh late C2 binary.
fullA6AcceptanceComplete remains false. Base
113ea94fd84106d5d624f9885fe3dc530a2c8d15 was clean and matched
origin/feat/studio-foundation-20261125 before editing. Normative parents remain
C2:58–66, C6:169–182, C7:190–212, the 3.64 supplement, acceptance P5,
App v1 A6.1–A6.7, and ADRs 0257–0264.

The official combined run bound in Increment 3.64 was executed:

1. Input SHA-256 was frozen at this clean base (late entrypoint, reader helper,
   Web import composition, pinned vendor/lock/bootstrap, and LICENSE.core as a
   recorded unchanged file). Those sources did not change during the build.
2. A fresh G1 used a disposable compiler cache and produced three actual
   release/CSP/source-map builds (default, ordinary opt-in, and one isolated
   late fixture targeting `test/import_late_phase_entrypoint.dart`). Exact
   input and output SHA-256 are in the 3.65 `artifacts.json`. Default and
   ordinary opt-in contain none of the late public root fingerprint,
   release/observer strings, gate markers, or test imports/source-map entries.
   The fixture artifact is not deployable. The fresh late main hash is
   `935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb`. That
   digest is byte-identical to the historical 3.60 L02–L03 late hash because
   no studio_web source has changed since 3.60 and the compiler reproduced the
   same bytes. This is not reuse of the historical 3.60 artifact path as the
   C2 binary; the C2 binary is the newly built
   `/workspace/skill-import-app-365/late-phase-app/main.dart.js`. The digest
   is not the historical 3.59 L01 hash
   `afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29`.
3. Already-qualified G2 and G3 transports compiled into that fixture were
   reused. The 3.59/3.60 unit or canary suites were not requalified, and those
   historical contracts were not rewritten.
4. G4 independently qualified all twelve C6 rows in fresh browser
   contexts/stores against that one fresh late main hash, with actual
   App/panel/factory/owner, trusted CDP Tab/Enter input, and per-phase
   order/count evidence. 3.59/3.60 profile results and B01–B11/N01–N02
   runtimes were not borrowed as those combined rows. This is combined G4 of
   the C6 rows, not a rewrite of the frozen 3.59 L01 qualification.
5. G5 independently recorded, for each of those twelve rows, actual CSP,
   vendor SRI, startup versus component requests (request count unchanged
   after composition start; recorded requests are document/startup/vendor
   only), and IDB/localStorage/sessionStorage snapshots through teardown, with
   zero component writes. CAS/shelf absence is proven by no such API or path
   being supplied. Raw results and environment/executable digests are kept.
   The reused drivers still emit historical `scope` labels; those labels are
   not this increment's acceptance claim.

A passing combined G1–G5 run still does not, by itself, set
fullA6AcceptanceComplete. Full A6 additionally requires the P5 audit of
outstanding A6.1–A6.7 obligations against recorded evidence, and still does
not close I-037 installation, production publisher roots, cross-namespace
import, or production FTS/RAG. Independently qualified B01–B11 and N01–N02
rows remain scoped historical/native evidence and were not rerun. N01-semantics
remains framework-standard-semantics, not OS assistive-device qualification.

Recommended next increment is that official P5 A6.1–A6.7 audit. Do not set
fullA6AcceptanceComplete unless the audit is honestly complete.

## Increment 3.66 — official P5 A6.1–A6.7 audit

Status: official P5 / A6.1–A6.7 audit COMPLETE against recorded evidence.
fullA6AcceptanceComplete is set true in the 3.66 contract only. Base
0d1c66a8dacafc085681f47bdecb56fce7b206c2 was clean and matched
origin/feat/studio-foundation-20261125 before editing. A passing combined
G1–G5 run still does not, by itself, set that flag; Increments 3.59–3.65
remain historically not full A6 acceptance. This increment does not rerun
the combined G1–G5 profiles or rewrite the frozen 3.65 contract, which
stays fullA6AcceptanceComplete=false. I-037 installation, production
publisher roots, cross-namespace import, and production FTS/RAG stay open.
