# ADR 0243 — Execute the completed portable format-repair plan

## Status
Accepted for Increment 3.44, following ADR 0242 and the official s10e format-repair
v1 supplement. I-031 stays partial. No new runtime/provider/device is qualified.

## Implementation
- AgentHarness claims the public command/message once. FormatRepairGeneration
  makes at most two internal generate attempts and journals request/outcome
  phases with the specified SHA256 identities. Failed outcome stays recorded.
- LlmChunk adds optional finishReason only. Existing adapters that omit it do
  not gain automatic repair. The StreamAssembler class and frozen stream suite
  are byte-identical to the parent; they are not requalified by this increment.
- BudgetController meters cumulative input and visible text/tool-JSON tokenizer
  estimates. Duplicate chunks are not recharged; incomplete/rejected output is
  not refunded. Usage is NOT a provider receipt or exact sampled-token claim.
- Narrow structural classification requires explicit coherent completion. A
  diagnostic known-field projection is never executed; malformed or extra-key
  output must be regenerated and pass full validation. Semantic/permission,
  transport, timeout/cancel, drift, byte-bound and budget failures do not repair.
- Attempt two preserves the original prompt and adds the exact fixed suffix,
  halves the first request ceiling subject to remaining budget, and records its
  changed prompt/schema hashes. No constraints are silently dropped.
- Every repaired output, including a read-only tool call, is pending. Its fresh
  approvalCommandId is returned; an original command approval is insufficient.
  Apply rechecks model/registry/revision/cancellation/deadline. No handler is
  called before explicit approval. No third attempt or public-command replay.

## Evidence and limits
`packages/studio_agent/test/format_repair_test.dart`: 33 scripted interface
cases. Existing harness_loop_test and harness_timeout_queue_test: 12 regression
cases, not new qualification. No frozen StreamAssembler tests were run or edited.
Evidence is under `docs/implementation/evidence/i031-format-repair-runtime`.
The tests cover the documented path with in-process scripted adapters only;
there is no actual weight loading, provider finish event qualification, paid
submission, inference-quality evaluation, or persistent journal/outbox wiring.

The 3.43 documentation consistency test now checks its recorded runtime/status
hashes against that historical base, not against future executable files. Its
live capability-table/frozen stream-test preservation checks remain. The old
3.43 evidence/manifest is unchanged; no old product test assertion is weakened.

## Progress and exclusions
Only I-031 receives justified append-only acceptance/implementation notes;
original remainingScope is unchanged. No other task entry is rewritten or
completed. Counts remain 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0; T-4 and program remain unfinished.
Project user_version=9 and InversePatch=restoreSnapshot remain unchanged.
Signed-pack policy, production FTS/RAG, real model/video runtimes, quote/apply,
paid APIs, hardware ports and other standing exclusions remain unopened.

## Next
Do not repeat this repair qualification. Continue with another specified slice,
using t155u to complete a concrete exposed planning gap before implementation;
do not broaden this result into real model/provider/device acceptance.
