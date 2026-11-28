# 10E supplement — portable format repair v1

Status: official implementation plan, Increment 3.43, authorized by t155u.
This completes the five bindings exposed during implementation; it is NOT an
implemented repair path or new product qualification. Scope is the existing
`studio_agent` portable harness only. No real inference, provider request,
workspace schema, general coordinator or durable mailbox is introduced.

## Sources and precedence

- s10e:13: one format-only retry, smaller task, no unlimited self-repair.
- s10d:9–11: changed prompts invalidate approval; bounded side-effect-free format
  repair; global logical-call identity and canonical results.
- s10b:6–7: independent call per attempt, no terminal resurrection or budget reset.
- s10c:9,12: failed/repair/critic usage accumulates; ordinary Schema/permission
  failures are not transient retries; accepted/unknown paid submissions reconcile.
- s12a:38–45: maxPlanRepairs=1; pure plan JSON/parameters only, never retry accepted
  external/paid/delete operations. This v1 is deliberately narrower: it does not
  repair missing/wrong-type/range/enum/EntityRef or other semantic parameters.

## B1 — identity and attempt state

Keep TurnInput(sessionId, turnId, messageId, commandId) unchanged. Claim
MessageLog.requireFresh(commandId) and accept the user message once per runTurn,
BEFORE attempt 1. A duplicate public invocation remains DUPLICATE_COMMAND,
even if the original failed. Never call runTurn recursively or clear its claim.

A permitted format regeneration is an INTERNAL pure model retry, not a repair of
an accepted plan/Step. It remains within the same Turn and pinned Step; attempt
advances 1 -> 2, with independent model logical-call IDs. No third attempt.
Semantic repair of a committed/terminal Step still needs a new plan/Step as in
s10b:7 and is outside this path. No tool handler is invoked before classification.

For phase IDs use `fr1-` + lowercase SHA256 of UTF-8 compact JSON array:
["portable-format-repair-v1",sessionId,turnId,messageId,commandId,attempt,phase].
Strings use Dart jsonEncode escaping; attempt is integer 1 or 2; array order is
fixed (no object canonicalization ambiguity). phase is exactly `modelCall`,
`request`, or `outcome`. These are internal IDs, NOT extra user messages or
new public TurnInput command IDs. The modelCall ID supplies the future runtime
call correlation; it must not alias a tool invocation or an external Job.

## B2 — journal and terminal result

Use the existing JournalEntry fields, no new SQLite/event schema. Before each
generate, append kind=modelAttemptRequest, id=phase(request),
commandId=phase(request). After completion or failure append
kind=modelAttemptOutcome, id=phase(outcome), commandId=phase(outcome).
Payload keys are fixed for this plan:
- both: parentCommandId, turnId, messageId, attempt, modelCallId, policyVersion;
- request: promptHash, toolSchemaHash, maxOutputTokens;
- outcome: status(valid|repairEligible|failed), code(null|string),
  inputTokenCharge, textTokenCharge, toolJsonTokenCharge, metering=tokenizerEstimate,
  cumulativeInputTokens, cumulativeOutputTokens, nextAttempt(null|2).

The FAILED attempt is a model-attempt outcome, not a terminal turn. Preserve it
when attempt 2 runs. The existing final `turn` journal entry uses the original
commandId exactly once after valid output. On final refusal, preserve existing
`commandId-err` error entry and throw; do not append it for the intermediate
repairEligible outcome. No raw rejected output, prompt, private reasoning or
credentials are added to attempt records. Hashes are SHA256 of exact UTF-8 bytes.
The journal remains in-memory, not crash recovery. Duplicate journal phase IDs
are idempotent under the existing commandId deduplication.

## B3 — cumulative metering, with no fictional usage receipt

Future BudgetController gains cumulative inputTokens/maxInputTokens;
maxInputTokens defaults to the configured contextTokens, NOT a fresh allowance
per attempt. Existing outputTokens/maxOutputTokens is cumulative across attempts.
The effective run limits must be snapshotted at Turn entry; repair never resets
these counters or toolSteps. A shared controller also charges later critic/model
calls to the same totals; this adds no critic runtime. Original s12a profile
figures are design defaults, not changed or measured by this supplement.

Before EACH generate, compute runtime.tokenize(exactPrompt).length input tokens.
Check the cumulative limit before atomically charging and dispatching. If it
would be exceeded, do not charge unsent input or generate: record a failed
budget outcome with inputTokenCharge=0, no second chance. Failed/cancelled output already
received stays charged. Request maxOutputTokens must not exceed the remaining
cumulative output allowance or model capability. There is no refund on repair.

A bounded metering wrapper (not a changed StreamAssembler) tracks distinct seq
and drains contiguous events in order. Ignore exact duplicate seq; conflicting
payload for an existing seq is a terminal stream error, never a repair trigger.
Meter full accumulated visible text and the current full toolCallJson snapshot
SEPARATELY. For each channel charge only increases of its tokenizer-count high
water mark; never refund when tokenization changes at a chunk boundary. The
same tool JSON snapshot is not charged twice. Enforce the existing stream byte
bounds before retaining data; exceeding bounds stops the stream, not a repair.
No done flag or JSON payload is interpreted as a provider usage receipt.

These charges are explicitly tokenizer estimates/high-water accounting units,
not exact sampled-token usage, provider billing or a performance measurement.
Tool JSON is never free. Exact upstream usage reconciliation remains outside
this portable interface. Every received incomplete buffer is charged before
its eventual validation error; an exception cannot erase its cost. On terminal
sequence-gap/conflict failure, charge each previously unmetered distinct
buffered text payload via its own tokenizer count, and raise the tool-JSON
high-water charge to cover received snapshots, before final failure. Never
execute or concatenate these orphan events into a repaired plan. Mark these
conservative fallback charges as estimates as well.

## B4 — completion evidence and narrow failure classifier

Extend LlmChunk with optional finishReason, allowed on its done event only:
`stop` or `length`. Existing chunks omit it and retain current behavior; absent
completion evidence is NOT inferred from braces, timeout or token counts.
Adapters must only set it from a trustworthy terminal event (Fake may declare
synthetic fixtures). No real adapter or runtime is introduced by this plan.

After frozen StreamAssembler finishes or throws, a separate classifier may
permit exactly one repair only if all hold: toolsEnabled, attempt==1, no tool
handler dispatched, no accepted/unknown external operation, budgets/deadline/
cancellation open, all sequence events contiguous, trustworthy done event, and
finishReason stop or length. The rejected tool JSON must be present and be:
(1) syntactically incomplete/invalid JSON, or (2) a JSON object differing from the
current closed tool schema ONLY by additional object keys. For case (2), all
known required fields, types, enum/range/EntityRef/tool permissions must already
validate; extra fields are not dropped, coerced or silently accepted.

For the repair-capable wrapper, the outer envelope has exactly id, name and
arguments, all required; id/name are nonempty strings and arguments is an
object. The existing ToolCallPlan.parse currently ignores extra outer keys,
so do not assume it already enforces this rule. Inspect the raw object in the
new wrapper, and reject rather than silently strip unknown fields. To classify
extra keys, validate the known-field projection using the current validators
ONLY for diagnosis; never execute that projection. The second response itself
must satisfy the closed envelope and argument schemas in full. This does not
change the frozen parser/assembler APIs or call their old behavior newly tested.

No repair for: no done, sequence gaps/conflicts, transport exception, timeout,
cancel, empty/absent tool call, unknown finish reason, unknown/forbidden tool,
missing fields, wrong types, invalid values, untrusted-instruction refusal,
permission/safety/approval/namespace/revision/epoch failure, byte-limit error,
budget exhaustion, or any attempt-2 failure. Do not treat generic
TOOL_SCHEMA_INVALID or PLAN_INVALID alone as evidence of eligibility.

Preserve frozen StreamAssembler exception codes and paths verbatim. In
particular TOOL_SCHEMA_INVALID/truncated and PLAN_INVALID/truncated-stream
assertions are not rewritten. The classifier uses structured observations
alongside them, not new meanings for their strings. s10d's format exception is
not s10c's ordinary transient Schema retry. Return the original error if no
repair is eligible; final second-attempt errors keep their original code/path.

## B5 — smaller task, prompt identity and approval

Attempt 2 uses the exact original built prompt (all safety/context constraints
unchanged) plus this fixed UTF-8 suffix (decode this JSON string exactly once; all escapes below denote LF):

    "\n[portable-format-repair-v1]\nReturn exactly one complete JSON tool-call object for the SAME user task and current allowed tool schema. No prose, no additional keys, no new task or tool, and no tool execution.\n"

Do not append the rejected output or model-authored repair instructions. This
is a smaller OUTPUT task (one object, no narrative), not permission to strip
context or alter the user's intended task. Set toolsEnabled unchanged (true).
Set maxOutputTokens=min(floor(firstRequestMaxOutputTokens/2), remaining output
allowance, model output limit). If less than 1, refuse with budget exhaustion.
Recheck context capacity with the complete repaired prompt plus reserved output;
if it does not fit, refuse CONTEXT_BUDGET_EXCEEDED, never drop constraints.
Hash the exact new prompt and record it before generation. Freeze the tool
catalog/schema identity and RegisteredTool object references for both attempts;
require identical registry lookup objects again before retry and apply; capability/model/catalog drift aborts
rather than silently reroutes. Canonical toolSchemaHash is SHA256 of compact
JSON: tools sorted by name; each includes name, sideEffect.name, requiresApproval,
and arguments sorted by name with name,kind,required,maxLength,allowed (null or
sorted strings). This reflects the existing RegisteredTool contract, not a new
installed tool or permission system.

A valid repaired object still passes the full PlanValidator and existing gates.
It is NEVER automatically dispatched, including read-only handlers: return an
existing-style pending preview. Add optional approvalCommandId to TurnResult.
For repaired output only, derive that ID as `fra1-` + SHA256(jsonEncode array
[original commandId,2,repairPromptHash,toolSchemaHash,validatedOutputHash])).
Store pendingPlans/pendingText under THAT ID. The caller must explicitly
approve/applyApproved with that ID; original-command approvals cannot authorize
it. The old TurnInput stays claimed. Recheck the captured revision, model/schema
identity and cancellation before applying. Any change invalidates the pending
proposal; no hidden re-generation. This is local pending-preview binding, not
production ApprovalReceipt persistence, quote/apply or external-job retry.

## Implementation and acceptance boundary

Implementation is deferred to Increment 3.44 so the five-binding plan can be
reviewed as one coherent prerequisite. No existing runtime or capability is
claimed implemented by this supplement. Future implementation tests must cover:
public duplicate suppression; two distinct attempt IDs/records; first-failure
retention; all failed/repair input and text/tool-JSON charges; exhaustion before
retry; complete classification negatives; smaller cap and prompt hash; fresh
repair approval ID; no handler before explicit approval; no third attempt;
cancel/deadline/drift stopping retry/apply. Frozen suites remain unchanged.

This increment's Python checks are documentation consistency/static checks
only. They do not execute repair or qualify I-030, I-031, a model or device.
Project user_version=9, InversePatch=restoreSnapshot, fullTasksCompleted=0;
all original task remainingAcceptance/remainingScope and counts stay unchanged.

## Implementation record (Increment 3.44)

The portable implementation now lives in studio_agent AgentHarness and
format_repair.dart. See ADR 0243 and evidence/i031-format-repair-runtime for
scripted interface tests. The preceding plan-only status and deferral describe
Increment 3.43 historically; no real inference/provider qualification follows.
