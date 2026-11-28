# ADR 0259 — controlled-reader release transport and L02–L03

Status: accepted 3.60 witness bindings before implementation.
Base: e499a223995bf067edbf506bb8e45d681a5b8ad6, clean matching feature/origin.
Follow App late v1 C2/C4/C5/C7 and its 3.60 witness supplement under ADRs 0257–0258.
Narrow typed App-root arm/release controls operate only on the compiled entrypoint's
single controlled reader. The common capture/live predicate/selected callback and
all production source/repository/crypto code remain unchanged. Read-only observations
cannot supply outcomes or approval. Non-browser fault-watchdog tests are distinct
from the unchanged 15-second browser watchdog/30-second source deadline.
Implement/qualify G3 and ten new L02–L03 profiles; use L01 only as its existing frozen
dependency. No real File/GTK/device/OS AT/model/provider qualification from test
readers, no new roots/install/cross-namespace/FTS/RAG authority. N01–N02/full A6 and
I-037/T-4/program completion remain open. Record only independently verified scope.

Outcome: G3 controlled-reader transport and ten L02–L03 profiles passed in 3.60.
Each actual capture resolves naturally null, closes one resource exactly once and
retains busy until quiescence; cancellation/disposal/context changes cannot revive
preview or acknowledgment. L03 witnesses null before close completion.
Three fresh release builds/source maps prove fixture exclusion; six controller
unit tests and seven static preservation checks pass. L01 is frozen at e499a22,
not rerun. This is not combined G1–G5/full A6 acceptance. N01–N02 remain deferred.
Evidence: docs/implementation/evidence/signed-import-app-late-reader/.
