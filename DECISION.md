# DECISION.md

This file records the design decisions behind significant changes to the
behavior-tracking system. Each entry explains *what* changed and, more
importantly, *why* — so future work can re-evaluate or extend the system
with the original tradeoffs in view.

Entries are listed newest-first.

---

## 2026-04-24 — Behavior tracker refactor (Pointer migration, page coords, naming standardization, expanded events)

This refactor was split into four commits to keep each change focused and
independently reviewable / revertible.

### Commit 1 — Rename DOM events to kebab-case and migrate mouse → pointer

**What changed**

- All DOM mouse event listeners switched to their Pointer Event equivalents:
  `mousemove → pointermove`, `mousedown → pointerdown`, `mouseup → pointerup`,
  `mouseover → pointerover`, `mouseout → pointerout`.
- All recorded `event.type` strings switched to kebab-case:
  - `mousemove → pointer-move`
  - `mousedown → pointer-down`
  - `mouseup   → pointer-up`
  - `mouseover → pointer-over`
  - `mouseout  → pointer-out`
  - `keydown   → key-down`
  - `slider    → slider-change`
- Each pointer event additionally records `pointerType` (`mouse` / `touch` /
  `pen`) so downstream analysis can filter by input device.
- Backend `VALID_EVENT_TYPES`, `BehaviorEventType` enum, route spec, and
  migration comment updated in lockstep.

**Why**

- **Pointer Events unify mouse / touch / pen** into a single API. Recording
  `pointerType` preserves the device distinction without forking handlers.
- **Kebab-case is the convention we want for *all* event-type strings** going
  forward (including the new event types added in Commit 3). Doing the rename
  in the same commit as the pointer migration avoids a round-trip on the
  backend `VALID_EVENT_TYPES` enum.
- **One atomic frontend + backend commit** prevents a window where the
  frontend sends `pointer-move` but the backend still rejects everything that
  isn't `mousemove`.

**Known tradeoffs**

- On touch devices, a single tap fires
  `pointer-over → pointer-down → pointer-up → pointer-out` in rapid
  succession. Hover-style analysis (`pointer-out.duration`) on touch will
  approach zero — filter by `pointerType !== 'touch'` if hover dwell time is
  the metric.
- `pointer-over` / `pointer-out` remain *delegated* to elements with a
  `data-track` attribute — recording every hover over every DOM node would
  swamp the queue.

---

### Commit 2 — Track absolute page coordinates instead of viewport coordinates

**What changed**

- All recorded `x` / `y` switched from `clientX` / `clientY` (viewport-relative)
  to `pageX` / `pageY` (document-relative, includes scroll offset).
- `highlight` event derives page coords by adding `window.scrollX/Y` to the
  selection's `getBoundingClientRect()` result.
- `key-down` event derives page coords from the focused element's bounding
  rect plus scroll offset (Commit 3 extends this to `key-up`).

**Why**

- The survey pages scroll. With viewport coords, the *same* on-page DOM target
  reports different `(x, y)` depending on scroll position, which makes
  post-hoc replay and heatmap analysis harder than it needs to be.
- Page coords are scroll-independent: a click on the "下一頁" button always
  reports the same `(x, y)` regardless of how the participant scrolled to it.
- Native Pointer Events expose `pageX/pageY` directly — no extra computation
  for the common case.

**Known tradeoffs**

- If a future analysis cares about "what was visible when the participant
  clicked," it needs to combine `pageY` with the recorded `scroll` event's
  `scrollY` to derive viewport position. We accept this because replay /
  heatmap is the more common need.

---

### Commit 3 — Add new event types and generic key tracking

**What changed**

- `key-down` no longer requires the target to match `ACTIVATABLE_SELECTOR`
  (button / link / checkbox / etc.). Every keypress is recorded.
- New event type `key-up` (mirror of `key-down`).
- Both `key-down` and `key-up` exclude `event.repeat = true` to suppress
  hold-to-repeat noise.
- New events recording window / page lifecycle:
  - `focus` and `blur` (window-level only)
  - `page-show` / `page-hide` (covers bfcache restore on mobile back-gesture)
  - `visibility-change` (recorded *as well as* the existing pause behavior)
- Lifecycle events (`focus`, `blur`, `page-show`, `page-hide`,
  `visibility-change`) record `x: null, y: null` — they have no meaningful
  pointer coordinates.
- `key-down` / `key-up` record `x: null, y: null` when no element has
  meaningful focus (i.e. `document.activeElement` is `<body>`).
- Backend `VALID_EVENT_TYPES` and `BehaviorEventType` enum extended.

**Why**

- **Generic key tracking** captures Tab navigation, arrow-key slider
  adjustment, and modifier-key combinations — interactions that are invisible
  to the previous activatable-only filter but informative for behavior
  analysis.
- **`e.repeat` filter** — without it, holding an arrow key would flood the
  queue with hundreds of events per second.
- **`focus` / `blur` at window level** distinguishes "participant is thinking
  with the survey on screen" from "participant alt-tabbed away." Element-level
  focus would log every Tab between buttons, which is too noisy for the
  behavioral signal we want.
- **`page-show` / `page-hide`** captures the iOS / Android back-gesture
  bfcache transitions that `visibilitychange` alone misses.
- **Recording `visibility-change` as an event** (not just using it to pause)
  gives the analysis a precise timestamp for when the tab was hidden / shown,
  rather than having to infer it from gaps in the event stream.

**Known tradeoffs**

- Volume goes up — most notably when participants type. Survey pages have no
  free-text inputs, so privacy isn't a concern here, but if a future page
  adds a `<textarea>`, we should consider redacting `key` / `code` for that
  context.

---

### Commit 4 — Standardize `data-track` to `{prefix}-{role}` convention

**What changed**

- Every `data-track` attribute follows the pattern `{prefix}-{role}`:
  - `q1` (section wrapper) → `q1-element`
  - `label-q1` → `q1-label`
  - `slider-q1` → `q1-slider`
  - `confirm-q1` → `q1-confirm`
  - `pq1` → `pq1-element`, `confirm-pq1` → `pq1-confirm`
  - `practice-q1` → `practice-q1-element`,
    `confirm-practice` → `practice-q1-confirm`
- Page-chrome elements adopt a `page-` prefix:
  - `background → page-background`, `header → page-header`,
    `intro → page-intro`
- Action buttons get descriptive names tied to their flow:
  - `next-button → survey-next`, `next-to-survey → practice-next`,
    `postsurvey-submit-button → postsurvey-submit`
- `SliderBar.vue` gained a `trackPrefix` prop. The component renders
  `data-track="${trackPrefix}-slider"` and forwards the same value as the
  selector to `tracker.recordSlider`. Each consuming page passes its own
  prefix (`q1`, `pq1`, `practice-q1`, …).

**Why**

- The previous naming was a mix of three styles
  (`q1`, `label-q1`, `slider-q1`, `confirm-q1`) which made it impossible to
  group "all interactions on question 1" with a simple prefix match. With
  `{prefix}-{role}`, `startswith("q1-")` returns every element related to
  question 1.
- **`SliderBar.trackPrefix` prop** — the same component is reused across
  Survey, PostSurvey, and Practice pages. Hard-coding `slider-q${idx+1}` made
  the survey and post-survey sliders both emit `slider-q1`, with no way to
  tell them apart in the data. Driving the prefix from the parent fixes
  this without forking the component.
- **`page-` prefix for chrome** — keeps non-question elements out of the
  per-question namespace so prefix grouping remains clean.

**Known tradeoffs**

- This is a breaking change for any analysis script that hard-codes the
  previous `data-track` strings. All historical data uses the old names —
  analysis code reading both old and new sessions needs a translation table.

---

## How to add a new entry

1. Add a new section at the top of the file (newest-first).
2. Use the date in `YYYY-MM-DD` format.
3. For each commit (or logical change), record:
   - **What changed** — concrete, file-level summary.
   - **Why** — the reasoning, especially anything not obvious from the diff.
   - **Known tradeoffs** — anything we deliberately accepted as a cost.
4. Keep entries focused on *decisions*, not implementation walkthroughs —
   the diff already shows the *what*; this file is for the *why*.
