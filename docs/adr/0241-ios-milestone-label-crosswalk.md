# ADR 0241 — Distinguish portable-slice labels from original iOS milestones

## Status
Accepted for Increment 3.42. Honesty documentation only; no product capability or milestone is qualified. This supplements, and does not rewrite, ADR 0113 or the frozen Increment 2.14 capability table. No original Page or task remainingAcceptance/remainingScope is changed.

## Finding
The original private iOS Page's `native-milestones` section and the repository capability table use different N-number namespaces. The following rows juxtapose same-number labels to show the mismatch, NOT to assert feature equivalence or dependency mapping.

| Repository internal portable-slice label | Original Page milestone |
| --- | --- |
| N1-interfaces | N1 — real local editing loop |
| N2-llamacpp-binding | N2 — reliability and model lifecycle |
| N3-harness-tools | N3 — release foundations / image enhancement |
| N4-on-device-inference | N4 — video C1 |
| N5-ios-packaging | N5 — ASR / advanced C2 |
| N6-device-qualification | N6 — independent research |

Repository `N0-inventory` is a portable inventory, not evidence of the original N0 Mac audit or device/rights inventory. Accepted repository N1/N3 means only the portable contracts and harness interface tests described in their notes. It does not establish original-Page N1/N3 completion. In particular the original N1 requires actual model loading/inference and a real edit/undo/export loop on device; Fake-path tests cannot satisfy it.

## Evidence boundary
The machine-readable crosswalk is `docs/implementation/evidence/ios-milestone-crosswalk/mapping.json`, with the source Page URL/section and the unchanged capability-table hash. Original Page sharing is private (owner only); this document changes no sharing setting. The crosswalk describes nomenclature, not a new legal, device, model, runtime, store or performance determination.

`tools/tests/test_ios_milestone_crosswalk.py` checks this documentation contract and the frozen table hash only. Its passing results are NOT new product tests or qualification evidence. No model is loaded, no device used, no table label changed, no schema merged. Project user_version remains 9 and InversePatch remains restoreSnapshot.

## Progress
All task entries and counts remain unchanged: 0 complete / 62 partial / 12 planned / 13 blocked; fullTasksCompleted=0. T-4 and the overall program remain unfinished. I-016–I-019, I-055, I-059 and original iOS milestones are not declared complete.
