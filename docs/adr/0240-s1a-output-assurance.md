# ADR 0240 — s1a output assurances

## Status
Accepted, Increment 3.41, DEV-PURE only. I-013 remains partial (no dedicated s1a work item); its existing remainingAcceptance is preserved and appended. No task is completed.

## Source and decision
`docs/studio/spec/s1a.md`, common obligations row: 输出不保证独占/可版权/不侵权. This is a distinct leftover explicitly left unofficial in ADR 0234. The validator admits an output disclosure only when none of these three guarantees is asserted; each guarantee has a separate refusal code. Unknown kind is refused before interpreting claims. All eight combinations are tested, including unknown-kind precedence.

Official entry: `packages/studio_output_assurance_probe/lib/studio_output_assurance_probe.dart`. This validates a public assurance, not the actual legal status of any work. It neither declares an output unlawful nor determines copyrightability in any jurisdiction.

## Boundaries
This does not assess or confer a license grant (I-033), change execution policy (3.32), validate provenance (3.35), alter release qualification (I-058), redistribute fonts, collect/download models, or change allow_with_warning. No runtime, provider call, UI, grant writeback or payment is added. No existing qualification is repeated. I-033/I-058/I-053/I-004/I-005/I-029/I-040 and other task entries remain unchanged. Existing I-013 acceptance labels remain intact; job archival is still unofficial. Project user_version stays 9; schema v10 stays unopened; InversePatch stays restoreSnapshot.

## Evidence and consequence
`docs/implementation/evidence/s1a-output-assurance/`: analyzer, unit-test and post-format source hashes. Only the new package is analyzed/tested, not a product or device runtime. Counts remain 0 complete / 62 partial / 12 planned / 13 blocked; fullTasksCompleted=0. T-4 and the program remain not done.

## Follow-up
Select a distinct genuinely unimplemented bound from the four planning documents. Do not repeat this disclosure validation or prior admissions. The AppProfile role-downgrade sentence remains unofficial and must not be taken if it repeats the 3.35 trusted-role bound or I-001. Do not manufacture runtime evidence, introduce deferred runtime surfaces, or claim completion from protocol tests.
