# Signed-import existing Linux App native acceptance v1

Status: official PLAN ONLY, Increment 3.61, under t155u. No N01/N02 runtime
qualification, native seam, fixture binary or observation transport is implemented
by this document. Base 7c616a4aab245505f3fdd9fac15095fd640f5e3b was clean and
matched origin/feat/studio-foundation-20261125 before editing.
Normative parents: App v1 A2–A6; acceptance v1 P2–P5; ADRs 0248–0259.

## N1 — concrete native gap and actual owner

The browser fixture constructor does not configure Linux. At this base,
apps/studio_demo/lib/skill_import_host.dart:11–12 has only normal construction;
:27–31 privately fixes a disabled policy; :44–54 builds the private panel with
wall time and unknown clock. skill_import_panel.dart:34–46 privately owns its
AppImportSession; :49–75 handles owner updates/lifecycle/disposal, but has no
App-root pre-publication fixture lifetime registration. The existing integration
case skill_import_app_test.dart:75–101 uses pointer selection and needsReview,
NOT a trusted positive native keyboard/standard-semantics acknowledgment. Its
:54–67/:105–107 snapshots are not continuous write/network observation.

Add only an App-private typed immutable native fixture configuration and named
SkillImportHost.testImport constructor in the EXISTING studio_demo App package.
Normal construction always stores null configuration. No new FoundationApp,
workspace, editor/art-page API, product navigation surface or SDK export. Mount
the unchanged FoundationApp first; it alone calls openDemo. After its first frame,
derive policy from the actual workspace.profile/current.namespace once, retain
identity across ordinary rebuilds, and retain the exact workspace as owner.
Do not call openDemo twice, replace the actual project or guess readiness APIs.

Compiled native test entrypoint owns policyForOwner, trusted nowSeconds=1000,
confidence=true, rollback=false, and immutable EMPTY installed/session/branch
sets. Public seed bytes 1..32, Ed25519 key
`ebVWLo/mVPlAeLES6KmLp5AfhTrmlb7X4OORC60ElmQ=`, fingerprint
`sha256:65b60673d6ed884bf01c2c222d82ada0740f29ac3355d6a925c81f17f47a27b8`,
threshold=1/epoch=1, signer validity [10,10000]. Namespace comes from actual
workspace (normal studio_demo/local/default), never from a selected pack. Use
existing public fixture helper to sign a compatible empty-requiredTools pack;
record exact envelope/payload/content/permission hashes and license facts before
baseline. No synthetic pack expiry or preview TTL. Seed/root/policy/time are
compiled test inputs, never environment/URL/path/source-byte enrollment. Environment
may locate isolated workspace/results/GTK helper, NOT supply roots, grants or time.

## N2 — real backend and private lifetime

Keep actual FilmSkillRepository + SodiumVerifier.loadTrusted with the existing
build-time STUDIO_SIGNED_IMPORT_SODIUM_PATH and STUDIO_SIGNED_IMPORT_SODIUM_SHA256.
Verify locked library bytes/length/hash before launch; no dynamic search, system
fallback, selected backend, fake readiness/success or repeated crypto vectors.
The fixture cannot supply a repository/verifier/action port/report/consent result.
Missing backend remains unavailable; default/ordinary opt-in keep disabled policy,
empty roots/grants and unknown confidence. Wall time never becomes trusted time.

Native App-private lifetime registration follows acceptance P3: synchronously
retire/cancel/discard before publishing fixture navigation or teardown; late
registration observes terminal generation, disposal unregisters, teardown suppresses
child repaint while still invalidating. Keep AppImportSession's comparator,
per-await fence and source controller unchanged. No successor/ABA revival or
replacement capacity until original capture.quiescent. Panel retains report,
repository, action port and opaque gesture privately; lifetime carries only void
retirement, never a report/id/gesture/ack function. This is an App-private seam,
not a shared public widget API. No native policy/grant transition service is opened.

## N3 — input and observation transport

Use a separately selected integration_test target mounting actual SkillImportHost
with real StudioWorkspace/FoundationApp and private panel. Isolated BOX Linux
x86_64 Xvfb, GTK_USE_PORTAL=0, actual registered file_selector_linux plugin and
normal GTK single-file picker. Record Flutter/engine/Dart, GTK/plugin, executable,
loaded library, test target and input-helper hashes. Do not use a user computer.

N01 keyboard cases use actual focused GTK App window and xdotool Tab/Return or
Space, not tester.tap or direct onPressed. Bound traversal and inspect the actual
focused standard control before activation. GTK helper fills the public fixture
path in the actual picker; that path is not an App import endpoint. Choose and
acknowledgment are separate physical event sequences. Record trusted native-input
method and chooser result; this is automated box testing, NOT manual OS dialog
or hardware qualification. If focus transport is unavailable, FAIL that case.

N01 semantics case may invoke the actual framework SemanticsOwner action on the
current enabled acknowledgment node after obtaining the real semantics tree.
Record node id/label/enabled flags and SemanticsAction.tap. This is labeled
framework-standard-semantics activation, NOT an OS assistive-device/screen-reader
claim. Never call a Dart consent callback, explicitPreviewConsent, onPressed,
acknowledge or a backend result stub from the harness. Real report rendering,
identity/permissions/license warnings and summary are inspected read-only.

Test-only App-root navigation control synchronously retires the mounted panel
BEFORE normal Navigator.push to a labeled fixture route. Pop/rebuild cannot revive
the old target, initialize a successor or reopen a source. A separate full host
unmount exercises actual disposal. These controls do not ship by default. During
held-read disposal, driver retains only the compiled test controller, not the
private owner/session. It may release its existing completer after host unmount.
No App consent/repository endpoint or public mutable browser-style globals.

## N4 — seven independently enumerated native profiles

Every profile has a fresh workspace/database/fixture owner, post-open baseline,
real backend and no-write/network observations through component teardown.

| Case | Exercise | Required observations |
| --- | --- | --- |
| N01-enter | Actual GTK signed File; Tab/Return Choose; separate Return acknowledgment | Exact verified report before action; no auto-ack; one non-authorizing summary |
| N01-space | Same fresh flow, separate Space acknowledgment | Actual focused standard control, one summary; repeat input cannot reuse gesture |
| N01-semantics | Same fresh signed File, standard framework semantics activation then repeat keyboard/pointer | No second summary, report/gesture revival, tool approval or writes |
| N02-preview-navigation | Actual signed File preview; fixture normal Navigator push/pop and ordinary rebuild | Synchronous retire before navigation; no restored report or ack; same project baseline |
| N02-preview-dispose | Actual signed File preview; unmount actual host | Actual session disposal; no late report/ack or import writes |
| N02-read-navigation | Controlled non-cancellable first read held; actual navigation/pop before release | Cancel/null, busy until close/quiescence, no next read/EOF/token/import/revival |
| N02-read-dispose | Same controlled first-read hold; unmount before release | One resource closes once; no replacement source, late rebuild or acknowledgment |

Controlled reader is a new native TEST-only port through existing bounded capture,
not real File/GTK evidence. Arm before Choose, use one <=4-byte source, forward
actual guard/onSelected and return ORIGINAL capture future. No cross-App Web test
library import. Hold only first read, expose passive immutable counts and phase
observations; release idempotently only that existing completer. Attempts to select
again while busy must not invoke the source. Assert one selection/open/length/read/
close, outcome=null, one quiescence, no EOF/subsequent read/bytes, original source
still busy before release and terminal owner after. Native selected-source deadline
stays 30000ms; independent 15-second fixture watchdog cancels then drains for
cleanup, and any watchdog fire FAILS qualification. Do not alter successful-byte
close-before-result ordering or invent an early-success runtime. Open/length/close
permutations remain frozen browser/source dependencies, not newly claimed here.

## N5 — continuous no-write and network witness gates

Use isolated project/database/CAS/shelf roots and isolated HOME/XDG directories;
fixture signing/helper results/traces live outside protected App persistence.
After actual first-frame project open and backend readiness, before selection,
record canonical project/revision and complete path/type/size/hash inventory plus
database/WAL bytes. Capture actual configured CAS/shelf roots, including absence:
no invented storage service, new CAS/shelf API or directory as an observation hack.
Register Directory.watch on every existing protected directory before baseline;
any new directory is itself a failing event. Observe create/modify/move/delete
continuously, drain through teardown before final snapshots. Only SQLite `-shm`
may be excluded from byte equality, explicitly as volatile lock bookkeeping;
DB/WAL/journal/CAS/shelf files and path additions/deletions are NOT excluded.
New fixture logs, screenshots or signatures cannot be written under protected roots.

Independently qualify watcher delivery with create/write/restore/rename/delete
canaries in a throwaway equivalent tree before any N case. Continuous write
events fail even if final bytes match. Overflow/drop/observer errors or unavailable
watch support fail the gate, never imply no writes. Compare before/after bytes
AND observed events through component unmount while workspace remains open.
Workspace.close/checkpoint/runner result writes are labeled harness cleanup after
that boundary, not import writes; collect separately rather than silently ignore.

For independent native network and filesystem syscall witness, qualify a loopback
harness tracer (planned strace -ff -ttt -yy with network and file-mutation syscalls)
against a disposable canary process before App execution. Record tool path/version/
hash, actual target PID/descendants and trace-loss diagnostics. Strace is not
currently installed on this box; its reviewed test-tool installation/qualification
is a pending implementation gate, not evidence already obtained. Do not bypass a
ptrace/security refusal or replace this with a zero-request summary. A missing
tracer leaves NG3/N01–N02 pending. Enumerate baseline VM-service/GTK/X11 local IPC
endpoints explicitly; only recorded harness/display channels are allowed after
baseline. No remote network, upload, publisher lookup, analytics, approval/tool
calls or new storage. Separate chooser toolkit incidental operations and normal
startup from component effects with exact path/PID/endpoint allowlists, never an
unbounded directory/process/network exclusion. Trace data are test artifacts, not
App persistence; no credentials/user files in canary or trace inputs. No security,
certificate, CSP or network policy disable. CSP/SRI are browser-only inherited
obligations, NOT a native emulation claim; native library integrity is mandatory.

## N6 — prerequisite gates before row acceptance

- NG0 source/owner preflight: exact actual-host anchors and unchanged shared core;
  immutable trusted constructor inputs, no duplicate project open or policy drift.
- NG1 fixture isolation: fresh source-frozen default and ordinary opt-in Linux
  release builds plus separate native fixture release artifact; record target,
  source/lock/toolchain/library and binary hashes. Production import graph cannot
  reach fixture/root/seed/control code. Scan UTF-8/UTF-16 constants/sentinels in
  all three artifacts with fixture-positive controls. Negative scan alone is not
  proof. Keep normal defaults unchanged. Fixture artifact is never deployable.
- NG2 transport: independent unit/target checks for actual keyboard focus/input,
  standard semantics, private retirement registration/unregistration, actual
  capture guard/selected/original future, busy/close/quiescence/watchdog ordering.
  No standard action or crypto/factory success stub; tests label controlled sources.
- NG3 observations: watcher and syscall/network canaries pass; no errors/loss;
  baseline rules in N5 and exact startup/harness allowlists recorded before flow.
- NG4 seven profiles: compile/run actual Linux integration target, record tested
  executable hash separately from release exclusion artifacts (debug integration
  is not release/runtime/store qualification). One fresh workspace per N4 case;
  verify literal exact identities/warnings, acknowledgment one-shot/no-authority,
  per-phase input/retirement/resource order and full no-write/network evidence.
- NG5 preservation: analyze/format changed Dart, actual native target compile,
  focused seam/widget/integration tests, harness/static/syntax/diff checks. Keep
  historical acceptance suite unchanged at 5 pass / 1 known failure. Do not rerun
  previous runtime qualifications or borrow their pass counts as new acceptance.

All NG gates are PENDING in 3.61. Implementation can land only independently
qualified planned subsets; no fixture hook alone qualifies N01/N02. Retain raw
failures and hashes, never mark a skipped row passed. No new plugin/SDK/runtime,
policy, DSSE/Ed25519 semantics or production root provisioning is needed.

## N7 — cumulative evidence and slice boundary

See docs/implementation/evidence/signed-import-app-native-plan/audit.json and
README.md: 39 recorded browser profiles across five frozen commits, not 39 new
runtime executions. The 12 late profiles use two fixture binary hashes. C2/C7
same-binary/combined conditions are not established by summing prior results or
by byte-identical passive observer methods. Do not relax C2, promote combined
G1–G5/full A6, or automatically rerun L01. No contradictory frozen pass/fail or
source-hash evidence was found; aggregate consolidation is an open obligation,
not grounds to invent a new runtime or relabel old tests.

3.61 lands audit plus completed native fixture/observation bindings ONLY. Native
trusted host seam, private lifetime, independent observation transport, artifact
proof and seven new native cases form substantial unqualified work; implementing
only the constructor would not be a coherent accepted slice. Recommended 3.62
implements/qualifies NG0–NG3 first, then N4/NG4–NG5 if coherent, otherwise only its
independently qualified subset. N01/N02/combined G1–G5/full A6/I-037/T-4/program
remain unfinished. Counts 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0. user_version=9, InversePatch=restoreSnapshot. Preserve every
original remainingAcceptance/remainingScope. No durable installation, cross-
namespace import, production roots/FTS/RAG, device/model/provider/OS assistive-
device/paid API/store release acceptance, Mac/XS, main merge or force push.


## Increment 3.62 — independently qualified native prerequisites

Implemented the official native seam and independently qualified NG0–NG3 only.
SkillImportHost.testImport, App-private lifetime, first-read controlled port,
and a separately compiled fixture entrypoint now exist. Three Linux release
artifacts and UTF-8/UTF-16 sentinel scans prove default and ordinary opt-in
payloads exclude public root/fingerprint/fixture path constants; those appear
only in the fixture libapp.so. Source comments are not compiled sentinels.
Watcher, strace, and xdotool/Flutter keyboard canaries passed. Isolated
--smoke-test startup allowlists for default and opt-in recorded local UNIX
X11/Wayland/session-bus endpoints only, with no remote network. The seven
N01–N02 profiles, combined G1–G5, and full A6 remain unqualified. L01 was not
rerun. See ADR 0261 and evidence/signed-import-app-native-prereq/.


## Increment 3.63 — N01–N02 observation wiring (t155u)

The 3.61 profile table and 3.62 NG0–NG3 transports are sufficient for
owner/policy/input methods. This supplement only binds how those transports
attach to the seven debug-integration profiles; it does not reopen NG0–NG3,
relax N5, or invent a product navigation surface.

Protected App roots are the isolated workspace directory actually used by
StudioWorkspace (the SQLite database path and its `-wal`/`-journal` siblings,
and any actually configured CAS/shelf/media root). Absence of CAS/shelf is
recorded; no directory is created as an observation hack. Harness roots are
outside that tree: Flutter build/test caches, fixture signing output, result
JSON, strace logs, Xvfb, xdotool, and the GTK helper. Inherited box
XDG_RUNTIME_DIR plus the 3.62 UNIX X11/Wayland/session-bus endpoints, and
loopback VM-service ports used by `flutter test`, are harness/display channels.
A new remote inet endpoint, or a create/modify/move/delete (or path add/delete)
under a protected root other than SQLite `-shm`, fails the case even if final
bytes later match.

Each profile: fresh workspace; sign the public empty-requiredTools pack before
baseline; wait for first frame and actual backend readiness; then snapshot
canonical project/revision, path/type/size/hash inventory, and database/WAL
bytes; then start Directory.watch on every existing protected directory.
Input, retirement, and teardown run after that baseline. Drain the watcher and
compare inventory before workspace.close. Runner result writes are labeled
harness cleanup.

N01 trusted input remains xdotool Tab/Return or Space on the actual focused
Flutter/GTK App window, plus the existing GTK helper for the Open File path.
The integration test inspects the focused standard control through Flutter
Focus/Semantics (key and label) immediately before activation. That is not OS
assistive-device qualification. N01-semantics uses SemanticsAction.tap on the
enabled acknowledgment node, then a repeat keyboard/pointer activation of the
actual control. The harness never calls acknowledge(), onPressed, or
explicitPreviewConsent.

N02 chrome (navigate/rebuild/unmount) lives only in the test shell, not in
default or ordinary opt-in construction. Navigate must call
invalidateBeforePublication synchronously, then a normal Navigator.push to a
labeled fixture route. The host may be embedded in that shell without wrapping
a second MaterialApp. The test shell owns the lifetime and the first-read
controller; after host unmount it may release only that existing completer.

Do not requalify 3.62 canaries, release-artifact hashes, or older browser rows.
Debug integration executables are recorded separately and are not release
qualification. Combined G1–G5/full A6 remain unclaimed.

Frozen film_schema still requires steps minItems=1 and each step toolId to be a
member of requiredTools (film_schema.dart:79-86 and importer.dart:622-631). A
literal empty-requiredTools filmCraft pack therefore cannot be valid. The official
native pack uses the existing public fixture helper with one admitted
media.analyze step, requiredTools=["media.analyze"], namespace from the actual
workspace, and the compiled empty App installed/session/branch sets. The verified
report records missingTools=["media.analyze"] under that empty grant.
Acknowledgment remains preview-only and does not approve tool execution or grant
tools. This is a plan completion, not a schema, grant, or execution change.

Fixture-mode FocusScope around the import panel, plus ExcludeFocus on
FoundationApp only when importFixture != null, bounds N01 Tab traversal to the
actual import controls. That bounding is fixture construction only.

Strace of each `flutter test` invocation includes Flutter/Dart tooling, the
debug compiler, and the App. Protected-root create/modify/unlink is judged only
inside the recorded baseline..observationEnd window (after first-frame readiness
and pack signing, before workspace.close). SQLite open/journal/WAL during
workspace.open or labeled close cleanup stay outside that window and are not
import writes. Directory.watch still covers the same window.

Remote inet is a failure if the App/workspace process (any PID that opens the
protected sqlite) connects off-loopback, or if any process uses an endpoint
outside the recorded flutter-test harness set. On this box that harness set is
UDP/53 to the inherited resolv.conf nameserver 10.0.0.2, plus Flutter tool
probes to 169.254.169.254:80 and 198.18.0.1:443. Those probes are tooling, not
App import networking. Loopback VM-service and local UNIX X11/session sockets
remain harness/display channels. Each profile uses a fresh Xvfb.
