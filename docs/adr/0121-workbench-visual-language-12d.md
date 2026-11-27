# ADR 0121 — 12D workbench visual language constraints

## Status

Accepted for Increment 2.22 as the leftover art-plan workbench visual-language slice. I-025 stays partial; its remaining acceptance is not rewritten. `fullTaskComplete` stays false. This is not V-003, not I-055, and not a claim that FoundationApp is finished product UI.

## Decision

`docs/addenda/workbench-visual-language-12d.md` is the missing 12D visual-language constraint chapter. Layout hierarchy follows §1: persistent session sidebar, then Brief/script, Storyboard/candidates, Image canvas/multi-track timeline, Export/archive. The Linux command workbench is a command surface in the timeline and export zones, not the finished four-zone chrome.

`WorkbenchVisualAuditor` officializes the 12D numbers as Linux/Web unit tests: touch targets start at 48 logical pixels; text contrast is WCAG AA 4.5:1 (large-text 3:1 exception retained); type scale up to 200% must leave Confirm and Cancel independently hittable; errors require a messageKey or error code and cannot be color-only; reduced motion stops autoplay and flicker preview and must not strip authored program motion; progress is announced by phase, not per token; a late Agent result must not steal focus.

This is an audit contract, not a UI token or component API, and not a rewrite of FoundationApp. The official command-workbench catalog records required presentation obligations. Material default button sizes in the existing widget tree are not claimed to already measure 48 logical pixels. Real-device screen-reader and usability testing remain human tests per 12D.

I-025 remaining acceptance stays: restore the last durable edit; export through I-024.

## Consequences

87-task counts stay 0 complete / 35 partial / 39 planned / 13 blocked. `fullTasksCompleted` stays 0. Official new suite: 8 tests. Analyzer exit 0.

## Evidence

`docs/implementation/evidence/workbench-visual-language-12d/`.

## Follow-up

I-055 (multilingual / RTL / a11y alternatives), real-device screen-reader qualification, and FoundationApp chrome alignment to the 48lu obligation remain open. Next honest Linux/Web increments include further play-protocol software tests without physical two-device E2E or schema v10 / XD-010 claims.
