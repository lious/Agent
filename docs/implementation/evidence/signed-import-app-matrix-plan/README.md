# Increment 3.54 — actual-App acceptance fixture plan only

Clean feature branch and matching origin confirmed at
5220d66b0c00008f215efb9bbcdca0ec57d0f5f3 before edits.

Concrete gap: A6 permits PUBLIC test roots/time, but actual WebStudioApp privately
fixes disabled policy and unknown clock (main.dart:28–36, 149–168). It has no
browser trusted-fixture composition binding. A separate widget fixture is not
actual-App browser acknowledgment. This increment supplies the official plan
before implementing a seam; it does not turn signed=true into proof or approval.

See ADR 0253 and s8f-signed-import-app-acceptance-v1.md. The supplement binds an
App-private named test constructor, a separate test entrypoint mounting the real
App, immutable owner-derived policy/config, synchronous pre-publication retirement,
no consent endpoint, test artifact isolation, real factory/crypto, exact host/CSP/
SRI and public fixture provenance, continuous no-write observations, and explicit
remaining browser/native case IDs. Default entrypoint and runtime are unchanged.

The new fixture seam, artifact exclusion proof and entire remaining matrix are
not a single already-qualified implementation. Land this coherent planning slice
only; recommend 3.55 implement the minimal seam and B01–B04, then the other explicit
rows. Do not ship an unqualified fixture hook or claim the remainder passed.

Validation: new plan/preservation static tests plus historical contract/evidence
static checks (no runtime requalification). Installed Flutter build help confirms
--target/--csp; docs.flutter.dev/reference/flutter-cli opened this turn. The
unchanged acceptance suite retains 5 passes / 1 historical strict-equality failure.
No Dart/runtime change, so no new browser, GTK, widget or inference qualification.
Static checks prove no apps/packages/native/fixture/lock changes and preserve the
tracked LICENSE.core bytes. No user Mac/XS, paid API, deploy, main merge or force push.

Counts unchanged: 0 complete / 62 partial / 12 planned / 13 blocked.
I-037 stays partial; fullTasksCompleted=0, full A6/T-4/program unfinished.
Original remainingAcceptance/remainingScope untouched; user_version=9 and
InversePatch restoreSnapshot unchanged. No installation, cross-namespace import,
production publisher roots, production FTS/RAG or device/model/provider claims.
