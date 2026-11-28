# ADR 0250 — bounded App-owned signed-import source adapters

- Status: Accepted for Increment 3.51's adapter-only DEV slice, not full UI acceptance.
- Base: `1c74633c7c03207ee99bae15fef44ed2d9ede86c` on
  `feat/studio-foundation-20261125`, clean and tracking the identical origin tip
  before editing. No main merge or force push.
- Normative: [App plan A3/A6](../studio/spec/s8f-signed-import-app-v1.md),
  [ADR 0248](0248-signed-import-app-composition-plan.md),
  [ADR 0249](0249-signed-import-app-host-csp.md).

## Planning gap completed before code (t155u)

A3's one-operation/invalidation rule needed a concrete owner across project/route
changes and an open-inclusive deadline. The new A3 subsection binds one
App-lifetime capture controller, lazy native open after the 30000ms monotonic
clock starts, immediate caller cancellation but eventual I/O quiescence, and
terminal browser retirement. An HTML input offers no abort/settled Promise;
removing observers on terminal disposal cannot prove its chooser settled.
A successor must not bypass the still-busy controller. No contract conflict,
new FileToken, protocol error enum, widget API or execution authority is invented.

## Decision and bounded implementation

`source_capture.dart` is an opt-in internal library, not a shared entrypoint
export. App-owned `skill_source_linux.dart` / `skill_source_web.dart` provide only
raw copied immutable bytes (or cancel/error); neither verifies, imports, renders,
acknowledges nor installs. They are NOT wired to either App's product controls.

Resolve the exact A3 candidate graph: file_selector_linux 0.9.4+1, interface 2.7.0,
cross_file 0.3.5+5, http 1.6.0; all pre-existing lock records stay byte-identical.
HTTP is an unused interface dependency, not URL-source permission. Web uses the
unchanged locked package:web 1.1.2. Native uses the actual GTK plugin and one
read-only RandomAccessFile; observed final non-regular/symlink paths are refused.
As A3 explicitly states, path selection is NOT atomic no-follow inode attestation.

Both adapters share <=65536-byte sequential reads, 4194304-byte acceptance cap,
cap+1 sentinel, declared/actual/EOF checks and a 30000ms monotonic selected-source
deadline including length/open/read/close. Human picker time is not a read timeout.
Cancellation/deadline never masquerades as OS abort or frees capacity before
pending I/O closes. Late selected readers are closed unopened. Successful bytes
are returned only after close; the helper clears its completed outcome reference.
There is no queue, persistence, fetch, URL conversion, path input or model endpoint.

## Independent new evidence only

[evidence](../implementation/evidence/signed-import-source-adapters/README.md):
24 pure-Dart boundary/fault/lifecycle cases; one Linux integration test exercising
five actual GTK selections (including cancel/reselect/cap/cap+1); 13 compiled-Dart
Web browser boundary cases. Chrome uses trusted CDP Choose/File injection for
public fixtures, plus a separately automated actual Chrome GTK Escape cancellation.
Untrusted DOM events are ignored. Empty CDP injection did NOT emit cancel: the test
asserts pending/busy and drains via App cancellation plus trusted late selection,
not a forged isTrusted flag. Terminal unresolved chooser retirement is tested.

GTK 3.24.49 / GTK_USE_PORTAL=0 on isolated box Xvfb and Chrome 156.0.8078.47 are the
recorded profiles. No desktop portal, manual OS-dialog, user hardware, real model,
provider, paid API or store acceptance. The standalone Web adapter test host has
its own restrictive CSP; it does NOT qualify A6.2's combined actual App host/UI.
Existing Linux/Web verifier/importer and 3.50 host results are not rerun or counted.

The old plan-preservation lint now compares its historical plan tree, matching
its already-historical source-tree check. Otherwise its pubspec.lock assertion
would prohibit the exact future plugin installation A3 mandates. The acceptance
suite itself and all original acceptance/remainingScope wording stay unchanged;
its known historical strict-equality failure remains reported, never repaired here.

## Landing boundary and next increment

Adapter-only qualification is one coherent slice. Full existing-App selection /
readiness / immutable preview / separate non-authorizing acknowledgment and
combined actual-App CSP/picker/widget/accessibility/storage acceptance remain for
3.52 under A1–A6. Do not infer them from source-only tests or repeated backend tests.
Default roots stay empty. signed=true is not verification, consent or tool approval;
invalid signatures must never downgrade. No DSSE/Ed25519/policy change, durable
installation, cross-namespace import, publisher enrollment or production FTS/RAG.
I-037 remains partial; fullTasksCompleted=0; T-4/program unfinished; user_version=9,
InversePatch=restoreSnapshot; standing exclusions unchanged.
