# Workbench visual language constraints (12D)

This addendum is the missing product visual-language constraint chapter called for by the art-design plan. It binds the Linux/Web command workbench to [12D](../studio/spec/s12d.md) and to the four collaboration zones in [§1](../studio/spec/s1.md). It is a design-constraint contract, not a UI token or component API, not I-055, and not a claim that FoundationApp is finished product chrome.

I-025 remaining acceptance (restore last durable edit; export through I-024) is unchanged. Touch, keyboard, and screen-reader qualification on a real device still require human testing per 12D and are not claimed here.

## Layout hierarchy

Persistent session sidebar, then in order:

1. Brief / script
2. Storyboard / media candidates
3. Image canvas / multi-track timeline
4. Export / project archive

The current FoundationApp is a Linux command workbench that can issue already-admitted commands. It sits in the timeline and export zones. It is not the finished four-zone product UI.

## Contrast and touch

- Touch targets start at least **48 logical pixels**.
- Text contrast meets **WCAG AA 4.5:1** (large text may use the 3:1 exception).
- Type scale up to **200%**: Confirm and Cancel remain independently hittable; long labels must not hide those actions.
- Errors are never conveyed by color alone (not red/green only). A machine-readable `messageKey` or error code, and/or plain language, must stay visible. The existing FoundationApp error line already shows the exception code as text; that channel is required.

## Reduced motion and flicker preview

When reduced motion is on:

- Autoplay stops.
- Flicker / flash previews stop.
- Progress is announced by **phase**, not by streaming every token.

Reduced-motion UI must **not** delete in-program motion already authored on the timeline (opacity, transform, Ken Burns, or other admitted keyframes). UI chrome animation is not the same as program motion.

## Focus and semantics (12D EditorSemantics)

- Keyboard focus returns to the originating control after cancel or completion.
- A late Agent or model result must not steal focus.
- Clip and layer alternatives exist without requiring pinch-drag (12D). This addendum does not invent a new semantic-tree widget API.

## Locale

UI strings use stable `messageKey` plus typed args. English and Simplified Chinese are the first copy sets; additional market languages are a separate I-055 acceptance and are not opened here. Date and currency localization must not rewrite Q timestamps or original facts.

## Audit

`WorkbenchVisualAuditor` in `packages/studio_editor_ui` officializes these clauses as Linux/Web unit tests. Passing the auditor on a declared chrome catalog is not a real-device screen-reader pass and not V-003 GPU qualification.
