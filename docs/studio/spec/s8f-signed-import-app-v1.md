# 8F supplement — App selection and preview-consent composition v1

Status: official PLAN ONLY, Increment 3.49, under t155u. No UI, file picker,
source adapter or App host is implemented or qualified by this increment.
The [base signed-import plan](s8f-signed-import-v1.md), [Web composition
plan](s8f-signed-import-web-v1.md) and ADRs 0244–0247 remain normative. The
3.46 Linux backend and 3.48 Dart-JS browser profile are dependencies, NOT UI,
file-picker, App-host or production-root qualification. No crypto protocol changes.

## A1 — existing App owners, not a new product or widget protocol

Composition belongs to the existing `apps/studio_demo/lib/main.dart` Linux App
and `apps/studio_web/lib/main.dart` Web App. Current anchors:
- Linux main:7–27 constructs AppProfile/StudioWorkspace then FoundationApp;
  `packages/studio_editor_ui/lib/studio_editor_ui.dart`:23–27 is the existing
  FoundationApp API. Do NOT add guessed art-page widget methods/constructor slots.
- Web main:16–24,36–54,122–134 owns its App state, project and MaterialApp/ListView.
  Insert a private App-owned preview action/view there, not a new independent app.
- Linux's current inspection reader at studio_editor_ui.dart:56–80 is for project
  inspection and takes a typed path. It is NOT a skill picker or signed import;
  do not silently reuse its text field as a model-addressable skill source.
- App isolation/port direction is [s1](s1.md):35 and [s1a](s1a.md); explicit
  per-selection access, not broad album permissions, is [s12b](s12b.md):12–15.

Use ordinary existing Flutter/material_ui controls and private App state. On
Linux, an App-private owner around the unchanged FoundationApp may own a standard
MaterialApp/Navigator overlay/dialog; no new public editor-widget API is required.
Web uses its existing App MaterialApp. UI layout implementation is not specified
as an invented art-page API. Only choose, preview, acknowledge, dismiss and status
are in scope. No Run/Install/Add-to-library/approval, model tool, command handler,
MCP method, JS-message endpoint, drag/drop, paste-path, URL or filesystem browser.

Opt-in is trusted build-time App composition, default OFF. Linux imports only the
existing native opt-in entrypoint; Web only `studio_signed_skill_import_web.dart`.
Keep the shared studio_assets entrypoint and backend implementations unchanged.
Own one repository and one ImportUserActionPort per App preview-composition
lifetime; those objects are private, never serialized or passed to model tools.

## A2 — trusted policy, namespace, grants and readiness

AppProfile and Namespace come from the current App/workspace, not selected bytes:
Linux uses workspace.profile/current project's namespace; Web uses its current
project.namespace and a matching AppProfile. `studio_demo/local/default` and
`studio/local/web` are distinct existing scopes, NOT interchangeable test roots.
Do not rewrite signed namespaces or replace App identity to make a fixture pass.

BuildTimeSignaturePolicy.disabled(profile, namespace) is the shipped default:
EMPTY publisher roots. Tests can compile explicit PUBLIC fixture roots into an
isolated test App composition, never load them from a pack, localStorage, a model,
preferences, picker result or remote publisher. Production root provisioning
remains unopened. An actually unsigned valid pack may yield untrusted knowledge;
invalid signed input must fail, never be stripped/retried as unsigned.

Use the existing ImportAppSnapshot callback with the identical installed policy
object, namespace, profile, policy epoch, nowSeconds, clock confidence/rollback
and installedAllowlist/sessionGrant/branchScope. There is no authoritative tool-
grant store in these App shells: default all THREE sets to EMPTY, not features,
requiredTools or a hypothetical new service. Without a trusted clock source,
clockConfident remains false. Do not infer trust from DateTime.now alone or fake
confidence to enable the button. Controlled tests may supply trusted test clock/
grant state in App composition; that is not production clock/grant provisioning.

Native loadTrusted uses only trusted immutable App binary path/hash deployment
configuration, never a picked path. Missing/mismatched deployment -> unavailable.
The recorded 3.46 DEV library pin is not production packaging. Web awaits the
existing concrete factory and its exact artifact/SRI/CSP/self-tests, retaining a
LIVE current-App callback. Re-sample after every source-read await and at import;
acknowledgment rechecks current App state through the backend as already specified.

Choose remains disabled until backend readiness; no token queue during init and
no delayed programmatic picker after awaiting readiness (browser user activation
would be lost). Failure publishes no repository or unsigned fallback. A known
App profile/namespace/policy change retires the composition, invalidates all
source generations and discards pending previews; recreate only from current
trusted composition. No actor may turn ready/signed=true into cryptographic
verification, consent or tool approval.

## A3 — one explicit, bounded source capture

Only a trusted App Choose action starts ONE single-file selection. Cancel is a
normal UI outcome, no import. No multi-select, directory enumeration, recent-file
reopening, copied OS path bookmarks or background selection. Filename/extension/
MIME are UNTRUSTED display hints, not verification. No content sniffing to execute
code or render a pack-supplied image/HTML. Exact raw envelope bytes go once into
SkillReadToken.capture; do not decode/re-encode JSON before importPack.

### Linux source binding

Select the maintained Flutter Linux plugin `file_selector_linux` **0.9.4+1**,
using `FileSelectorLinux().openFile(acceptedTypeGroups: const []) -> XFile?`.
The verified source returns null for cancel and XFile(paths.first), not an opened
FD or a cryptographic token. Source-only archive pins, compatible transitive
candidates and code hashes are in `evidence/signed-import-app-plan-v1/sources.json`.
Do not adopt latest/floating packages; implementation must resolve the exact
candidate versions into pubspec.lock and preserve unrelated locked dependencies.
No plugin was installed, built or executed in this planning increment.

Only the App source adapter may consume the selected XFile.path, never a path
entered by a model or a widget text field. Open it once with dart:io File.open in
read-only mode; use that SAME RandomAccessFile for length/read/close. Reject an
observed final symlink, directory or non-regular source before opening. This is
NOT an atomic no-follow/inode-attestation API: the picker returns a path and the
host filesystem can change it before open. Do not claim race-free OS capability
security, authenticated filename, immutable source inode or protection against a
compromised App/host. Trust/consent binds captured bytes and hashes, not the path.
If a future requirement demands an atomic selected FD, a separate official port
plan is required; do not fabricate one from lstat/stat or reopen the pathname.

Read chunks of at most 65536 bytes, accumulating at most 4194305 bytes (cap plus
ONE sentinel); never readAsBytes/readAsString or rely on pre-read file length.
Reject length >4194304, growth past the cap, read error or inconsistent completion;
close in finally, including late completion after cancellation. Reads of a growing
file cannot loop without a byte/time bound. No writing, copying to CAS/temp/shelf,
symlink traversal retry or filename-based signature decision. OS-mounted file
providers are not remote-source/backend qualification; the App does not fetch URLs.

### Web source binding

Use the ALREADY locked package:web **1.1.2**, not file_selector_web and not XFile's
potential eager materialization. A private HTMLInputElement with type=file,
multiple=false is activated synchronously from Choose after readiness. Handle its
trusted change/cancel events; empty FileList is cancel, not error. Model messages,
DOM synthetic events and assignments to input.value do not mint user consent.
Browser test-driver file injection is permitted ONLY in tests and must be labeled.

Take exactly one browser File object; use File.size and File.slice(start,end).
Read each <=65536-byte Blob slice through arrayBuffer into a copied Uint8List,
checking declared size <=4194304 BEFORE the first arrayBuffer allocation and
checking actual counts, cumulative cap and generation after each await. Require
successful completion matching the selected File's reported size. Do not turn
File.name or input.value/fakepath into a URL or dart:io path. Do not fetch a blob
URL, use FileReader.readAsDataURL, persist handles, transfer File/bytes to workers,
upload or reopen source after preview. No pack-derived executable/dependency URL.
Detach listeners and remove/reset the input on completion/disposal so selecting
the SAME file again works. Retain no File/blob handle once capture finishes.

### Common lifecycle/resource bound

Only one picker/read may be outstanding; no queued or concurrent source reads.
After a file is selected, use a **30000 ms monotonic** read deadline (not wall
clock); it does not time-limit the human's OS dialog. On cancel, dispose, scope
change or deadline, invalidate the operation generation immediately. Late async
completions cannot replace a new screen/report, import or mint a gesture. Release
references and close any eventual native handle, even if the open completed late.
A Dart timeout is not OS cancellation: until a non-cancellable picker/open/read
settles, keep new Choose disabled in a cancelling/quiescing state. Do not allow
repeated timeouts to accumulate background I/O or claim instant kernel abort.
Process/realm teardown releases process resources; no durable queue is introduced.

Keep at most ONE pending preview per UI composition (stricter than backend's 16).
Dismiss/discard the previous preview BEFORE a new selection; cancel never silently
restores an old consent target. No secure-memory-erasure claim: clear references,
call repository.discard and let platform GC reclaim bytes. No content/path/name,
private file token or pack URL goes to logs, analytics, prompts or audit storage.

### Increment 3.51 implementation-exposed ownership binding (t155u)

The bounded capture controller is an App-lifetime source helper, not a new
FileToken, loader, approval or widget API. Keep it outside project/preview-route
lifetimes. Scope changes cancel/invalidate its generation and await quiescence;
they do not replace a still-busy controller with another. Source selection returns
a pending selected-reader future plus a terminal-disposal cleanup hook. Readers
open lazily AFTER the common 30000 ms deadline starts, so native open/length awaits
cannot escape the read deadline. Shared pure-Dart byte/lifecycle logic may live in
an opt-in internal studio_assets library; platform pickers remain App-owned files
and are never exported from the shared studio_assets entrypoint.

Ordinary cancel completes the caller outcome immediately but retains at most one
pending picker completion until the OS/browser returns. Terminal App disposal
also removes Web input listeners/element. HTMLInputElement has no abort/settled
Promise API: after terminal disposal of an unresolved browser chooser, quiescence
may remain pending until realm teardown. This is intentional fail-closed retirement,
not proof the dialog closed. Do not construct a successor controller in that realm
while the old one is outstanding. Native late-returned readers are closed without
opening/reading after invalidation. No source reads or nonce/consent are queued.
These rules make the existing one-outstanding-operation and detach-on-disposal
requirements concrete; no claim of OS cancellation or new execution authority.

## A4 — immutable presentation and separate explicit acknowledgment

Render ONLY the importer-owned immutable SkillVerificationReport, never an
editable UI clone used for acknowledgment. Retain the concrete report and its
opaque previewId privately; widgets cannot submit replacement report hashes,
signed booleans, namespace or arbitrary IDs. Show:
- exact trustState: verified means only the configured pinned threshold verified;
  unsignedUntrusted means untrusted knowledge; needsReview is NOT verified;
- namespace, policyEpoch, complete envelope/payload/content hashes and verified
  key fingerprints, without a misleading trusted/safe/publisher-identity badge;
- requiredTools and permissionDiff including missingTools (list all via bounded
  scrolling/pagination, no silent omitted permissions or grant toggles);
- declared license facts, unverified-evidence/risk warnings and the unchanged
  allow_with_warning behavior; declarations are not a license grant;
- explicit text: preview only, documentWrites=0, executionAuthority=false,
  acknowledgment installs nothing and does not approve tool execution.

Use literal Text/SelectableText with no Markdown/HTML/URL activation, remote
images or rich embeds. Bound each untrusted descriptive snippet to 256 Unicode
scalars with visible truncation, at most 32 descriptive snippets; never truncate
hash/namespace/permission identity silently or change the retained signed bytes.
No pack-provided title may become the button label or an accessibility action.

Choose/selection, successful verification and rendering do NOT acknowledge.
Only a SEPARATE explicit App UI action labeled "Acknowledge preview only" may
synchronously mint ImportUserActionPort.explicitPreviewConsent(report.previewId)
and call repository.acknowledge(gesture) in the same callback without an await.
Support normal keyboard/accessibility activation; do not expose that callback
as a model/API/JS message function. Disable re-entry immediately. The gesture is
opaque, App-owned and one-use, not an ID echo, userConfirmed, approval receipt or
signed=true. Never auto-acknowledge on file selection, init, import, rebuild,
restored state, message event or checkbox copied from a pack.

Disable acknowledgment for needsReview and whenever current clock confidence is
absent/rollback detected (also for an unsigned preview). Known scope/policy/grant
changes invalidate the screen. Backend acknowledgment remains final authority
for expiry/revocation/hash/scope drift: stale/failure clears the target and requires
fresh import, not a second click on modified data. No clock override button. On
success retain only the non-authorizing acknowledgment summary; discard the
preview, clear capture/gesture references and keep no reusable approval. Pending
UI is realm-local; pagehide, reload, navigation/dispose and App/workspace switches
invalidate it. No state restoration, IndexedDB/localStorage, shelf or project edit.

## A5 — state machine, errors and Web App host contract

Private App state transitions:
`initializing -> ready | unavailable`; ready -> picking -> reading -> checking ->
preview -> acknowledged | ready; cancellation/error -> ready ONLY after source
quiescence; any in-flight dispose/scope change -> invalidated. Generation and
mounted/lifetime checks guard every async continuation. At most one pending report
and one outstanding source operation, no token queue, no ack in non-preview state.
Backend terminal failure requires fresh explicit trusted composition, not unsigned
fallback or automatic retry. Selecting another source first discards the old target.

Keep existing SKILL_IMPORT_* diagnostic meanings/codes untouched. Display only
safe code/reason summaries, not exception paths, raw source bytes or stack traces.
Selection cancellation, source unreadability/deadline and backend-unavailable are
local UI outcomes, not new StudioException enum members, license denials or
verified success. Failed import never gets a confirmation/override path.

The existing Web index.html:1 contains `<base href=...>` and a generic Flutter
bootstrap; it is NOT a W2-qualified App host. Do NOT change base-uri 'none' to
'self' to keep that template. Planned host build removes the base tag, serves at
a fixed App-owned root with absolute entrypoint/asset/CanvasKit URLs, and uses an
App-owned EXTERNAL custom Flutter bootstrap, SRI'd/hashed before execution.
Choose Dart-to-JS with main-realm CanvasKit, self-hosted renderer/font assets
(`--no-web-resources-cdn`), no Wasm-target/worker/service-worker/CDN fallback.
Bind Flutter loader assetBase/entrypointBaseUrl/canvasKitBaseUrl explicitly to
those same-origin roots and renderer='canvaskit'. Record the actual SDK/engine
build and every executable asset digest; do not claim old crypto evidence proves
this Flutter host can run. Preserve the exact locked sodium bytes/path/SRI.

Mandatory inherited CSP directives remain UNCHANGED: default-src 'none';
script-src 'self' plus approved sodium hash and 'wasm-unsafe-eval'; connect-src
'self'; object-src 'none'; base-uri 'none'. No unsafe-eval, unsafe-inline, blob/data
scripts or certificate/network security disable. For App-owned renderer assets
only, add font-src 'self', img-src 'self', and style-src 'self' plus a response-specific
>=128-bit CSPRNG style nonce passed through documented Flutter engine
initialization `nonce`. The nonce is NOT a script-src bypass; scripts remain
App-owned/same-origin/locked as above. Also set worker-src 'none', form-action
'none', frame-ancestors 'none'. The loopback test host owns nonce/header injection;
this does NOT implement a production server or deployment. No pack data enters
nonce/config/CSP. If the actual Flutter engine cannot run under these bindings,
FAIL the App-host qualification and report the exact conflict; never relax policy,
claim UI acceptance from the old standalone harness, or invent another app shell.

## A6 — independent composition acceptance, never old qualification reruns

Implementation must first lock/install the selected source dependency graph and
qualify bounded source adapters and the actual Flutter host CSP, THEN connect the
App preview controls. Required NEW acceptance groups:
1. Actual Linux GTK single-file chooser open/cancel, same-file reselection and
   regular fixture capture on the BOX test display; separate from unit mocks.
   Record toolkit/plugin/App versions. No user Mac/XS or hardware-port claim.
2. Actual compiled Web App: real trusted Choose activation/chooser event, selected
   File size/slices, cancel/reset/reselect, no URL fetch, actual W2-preserving CSP
   and SRI, missing asset/CSP/backend failure disables Choose. CDP-selected public
   test files establish only that browser boundary, not manual OS-dialog testing.
3. Fake source streams in TESTS ONLY: cap-1/cap/cap+1, lying length/growth, partial
   reads, failures, slow/non-cancellable open/read, exact monotonic deadline,
   dispose/scope changes and late completion; one outstanding operation/capacity.
   Test every async boundary and prove no path/token queue or source reopen.
4. Actual App widgets and standard accessibility controls: literal escaped title/
   link text, bounded display, exact report hashes/tools/license warnings,
   verified/unsigned/needsReview labels. Empty roots and unknown clock are honest
   defaults. Use isolated PUBLIC App-profile fixture roots/time only for positive
   acknowledgment tests; do not ship enrollment controls or test roots by default.
5. Selection/import/rebuild cannot acknowledge; explicit separate action produces
   one opaque gesture, double activation cannot reuse it, no model echo/message,
   stale scope/epoch/grants/time, revocation, discard/reselect/navigation. Mint no
   ApprovalReceipt; successful ack has zero document writes/execution authority.
6. Compare project revision/database/CAS/shelf state before/after the import flow;
   no new writes, uploads, publisher lookups, approval/tool calls, analytics or
   storage APIs from this component. Existing App project opening is a baseline,
   not falsely attributed to this component. Record observed allowed startup
   requests separately from selected source; CSP and network assertions stay on.
7. Analyze/format and compile the actual App targets, plus widget/adapter tests
   and the independent host integration tests above. No skip, fake backend-success
   fallback or old Linux/Web crypto/vector/format-repair rerun as UI evidence.

## A7 — sources and landing boundary

Sources read 2026-11-28 Asia/Shanghai, with local anchors above:
- https://pub.dev/api/packages/file_selector_linux/versions/0.9.4%2B1
- https://pub.dev/documentation/file_selector_linux/0.9.4+1/file_selector_linux/FileSelectorLinux/openFile.html
- https://pub.dev/documentation/web/1.1.2/web/HTMLInputElement-class.html
- https://pub.dev/documentation/web/1.1.2/web/Blob/slice.html
- https://pub.dev/documentation/web/1.1.2/web/Blob/arrayBuffer.html
- https://api.dart.dev/dart-io/RandomAccessFile/read.html
- https://docs.flutter.dev/platform-integration/web/initialization
- https://docs.flutter.dev/deployment/web

Source archive pins/code inspection are NOT source-adapter runtime evidence.
This increment lands PLAN ONLY: cross-App UI ownership, bounded platform capture
and actual Flutter-host CSP/chooser integration are the next coherent executable
slice; implementing/testing them is not folded into these plan checks. No frozen
protocol conflict was found. The current base tag mismatch has an explicit
non-relaxing planned host correction, not permission to weaken W2 or claim success.

No durable installation, cross-namespace import, production publisher roots,
production FTS/RAG, real-device/model/provider/paid-API/store qualification,
art-page widget APIs, deferred runtimes or excluded hardware tasks open here.
I-037/T-4/program stay unfinished; fullTasksCompleted=0; Project user_version=9,
InversePatch=restoreSnapshot. Increment 3.50 implements/qualifies this composition
only after its source/host gates pass, or reports an exact contract conflict.
