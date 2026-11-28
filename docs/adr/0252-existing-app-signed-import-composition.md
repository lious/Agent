# ADR 0252 — existing-App signed import selection / preview / consent

Status: accepted for the recorded opt-in DEV profiles in Increment 3.53; NOT full
A6/release acceptance. Base `2a36cc38f2ba54c4f04b1a1ea5a754dc7d325575` was clean on
feat/studio-foundation-20261125, tracking the identical origin tip before editing.
Normative: [App plan](../studio/spec/s8f-signed-import-app-v1.md), ADRs 0248/0250/0251.

## Concrete bindings completed first (t155u)

The appended 3.53 A3 subsection completes three implementation-exposed details:
1. A5's reading phase needs a source-selected observation; a returned byte Future
   alone cannot expose it. The optional App-only onSelected fires after liveness
   checks with the read deadline running, followed by another liveness check.
2. FoundationApp.initState at studio_editor_ui.dart:322–325 owns openDemo;
   StudioWorkspace.open has no current project yet. Native host mounts the
   UNCHANGED FoundationApp first, then constructs policy/session after its first
   frame. No second project opening, guessed widget method or SDK change.
3. Equal snapshot scope can hide a workspace/project switch. Pass actual Linux
   workspace identity / Web projectId into the private App panel; a synchronous
   widget update retires the old owner, keeps its source controller, and cannot
   revive it on an ABA switch back. No automatic successor before quiescence.

No frozen contract conflict, privilege rewrite or cryptographic change was found.

## Implementation

Both existing App mains have trusted build-time STUDIO_SIGNED_IMPORT_PREVIEW,
OFF by default. Linux's App-private SkillImportHost wraps the unchanged
FoundationApp; Web adds the private panel to its existing MaterialApp/ListView.
There is no shared editor/art-page widget API change or second product app.
App-private widgets own one internal pure-Dart AppImportSession (not exported by
studio_assets), one source controller, repository and private action port.

The live comparator checks identical immutable profile/policy objects, scopeHash,
clock confidence/rollback and non-backward observed time. Retirement increments
its generation BEFORE known state publication, cancels capture/discards preview
and is terminal. Actual App owner identity changes also retire the same session.
Startup is one-shot, failures publish no repository/fallback/queued selection.
Sources forward the live predicate and phase callback; picker stays synchronous.

The displayed report is the importer-owned immutable object, not an editable
clone. Literal Text, bounded scrolling, full namespace/hashes/key/permission
identities, <=32 descriptive snippets of <=256 Unicode scalars with visible
truncation, license warnings and non-authority text are explicit. Plain Text was
chosen after real browser AX inspection found empty SelectableText values in this
SDK/package profile; the final browser tests observe the actual identity labels.
No HTML/Markdown/URL activation or pack-derived button/accessibility labels.

Only the separate “Acknowledge preview only” standard control synchronously mints
one opaque gesture and acknowledges the retained target. Unknown/rollback clock,
needsReview and drift disable it. Re-entry is disabled before the call; success
retains only a non-authorizing summary; failure discards and requires fresh import.
No ApprovalReceipt, execution, project mutation, persistence or installation.
Web pagehide, hidden/paused/detached lifecycle, disposal and owner changes retire.
Transient inactive focus (including the actual native chooser) does NOT count as
navigation or teardown. Neither App has new scope/policy/clock provisioning UI.

Native trusted deployment path/hash use immutable build-time defines
STUDIO_SIGNED_IMPORT_SODIUM_PATH / STUDIO_SIGNED_IMPORT_SODIUM_SHA256; empty default
fails unavailable. No system-library search or picked-path backend. Web uses the
existing typed factory and exact integrity-locked bootstrap. The loopback test
host supplies the unchanged W2-preserving CSP/SRI/style-nonce profile; no production
host/deploy is introduced. Both production App policies have EMPTY roots; all
three tool sets are EMPTY and clockConfident remains false. Wall time is never
promoted to trusted confidence. Namespace remains studio_demo/local/default on
Linux and studio/local/web on Web.

## Independent combined evidence and honest boundary

[evidence](../implementation/evidence/signed-import-app-composition/README.md):
- 18 new actual-owner/widget cases using the real native repository, including
  typed drift, ABA, startup/retirement, invalid-signature refusal, literal bounded
  rendering, standard accessibility acknowledgment, all trust labels, cancellation
  and owner identity. Positive trusted-clock/root fixtures exist in TESTS ONLY.
- One actual existing Linux App + GTK selection + report/dismiss test compares
  project canonical bytes and database/WAL/CAS/shelf file bytes to the post-open
  baseline; transient SQLite SHM is explicitly excluded. Default needsReview and
  disabled acknowledgment are honest.
- Four fresh actual compiled WebStudioApp profiles: normal File/preview/dismiss,
  missing backend, CSP-blocked backend and SRI-tampered backend. Negative profiles
  assert actual Choose disabled, zero choosers, no unverified vendor execution.
  Normal checks real accessible identities, disabled acknowledgment, unchanged
  IndexedDB key/record and local/session snapshots, no observed new DB mutations,
  no source/network requests or CSP violations. CDP public File injection is only
  that browser boundary, not manual OS dialog/device qualification.

These are NEW composition tests, not reruns of previous source/fence/CSP/crypto/
format runtime qualifications. Existing backends are dependencies, not re-qualified.
The full cross-platform A6 edge matrix is NOT complete: actual-browser positive
trusted-test-profile acknowledgment, complete keyboard/navigation/pagehide and
late-state permutations still need independent combined evidence. Land the
implemented/default-profile-qualified composition rather than label every case
accepted. Recommended 3.54 finishes that bounded matrix; do not provision roots,
clocks/grants, installation or unrelated runtimes to make tests pass.

I-037 remains partial, counts 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0; T-4/program unfinished. Original remainingAcceptance and
remainingScope and the known acceptance-suite strict-equality failure are
unchanged. user_version=9; InversePatch=restoreSnapshot. No durable installation,
cross-namespace import, production roots/FTS/RAG, device/model/provider/paid API/
store release claims, user Mac/XS, main merge, force push or standing-exclusion work.

## Verification environment note

Late missing box development dependencies were restored and disposable Flutter
build caches regenerated. An unrelated tracked LICENSE.core deletion was left
untouched/excluded; static verification uses a detached same-repository worktree
with this increment's staged patch. Final native tests use the existing approved
SQLite dependency with its guard enabled. See evidence README/environment.json;
no unapproved runtime, policy relaxation or user computer was used.
