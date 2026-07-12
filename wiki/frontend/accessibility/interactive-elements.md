---
id: frontend-accessibility-interactive-elements
domain: frontend
category: accessibility
applies_to: [general, react]
confidence: verified
sources:
  - https://www.w3.org/TR/using-aria/
  - https://www.w3.org/WAI/ARIA/apg/patterns/
last_verified: 2026-07-10
related: [frontend-forms-validation-timing]
---

# Building Clickable and Keyboard-Operable UI

## When this applies

Building or reviewing any interactive UI element — buttons, links, toggles,
menus, dialogs, or a custom widget — including "make this div clickable" requests.

## Do this

1. Pick the native element by behavior (first rule of ARIA: use the native HTML
   element when one with the required semantics and behavior exists):

| The control… | Use |
|--------------|-----|
| Navigates to a URL/route | `<a href>` — real href, so open-in-new-tab, copy link, and middle-click work |
| Performs an action in place | `<button type="button">` |
| Submits the enclosing form | `<button type="submit">` |
| Toggles a binary state | `<button aria-pressed>` (pressed toggle) or `<input type="checkbox">` (checked setting) |
| Picks one of a fixed set | `<input type="radio">` group or `<select>` |

Native elements ship focusability, keyboard activation (Enter/Space), and
semantics for free; a styled `div` ships none of them.

2. Reach for an ARIA role only when no native element expresses the widget
   (combobox, tree, tabs, menu). Then implement the full APG pattern contract for
   that role — the role, its required states/properties, and the complete keyboard
   interaction (arrow keys, Home/End, Escape) from the matching pattern at
   w3.org/WAI/ARIA/apg/patterns. A role without its keyboard contract announces
   capabilities the widget does not have.
3. Verify every interactive element is reachable and operable with keyboard
   alone: Tab to reach it, Enter/Space (per pattern) to operate it. Tab order
   follows DOM order — when tab order feels wrong, reorder the DOM. Use
   `tabindex="0"` to include a custom widget and `tabindex="-1"` for
   script-focus-only targets; never a positive `tabindex`.
4. Dialogs and menus manage focus explicitly: move focus into the surface on
   open, keep Tab cycling inside while open, restore focus to the triggering
   element on close, and close on Escape. Native `<dialog>` +
   `showModal()` provides the trap and Escape behavior.
5. Give icon-only controls an accessible name via `aria-label` (or visually
   hidden text); an icon glyph is not a name for a screen reader.

## Edge cases

| Case | Then |
|------|------|
| Design wants a link that looks like a button (or vice versa) | Keep the element that matches the behavior; restyle with CSS — navigation stays `<a href>` |
| Action triggered from within a link/card that is itself clickable | Do not nest interactive elements; place the action button as a sibling positioned over the card |
| Element must be shown but not currently operable | Use `disabled` (or `aria-disabled="true"` when it must stay focusable so its state is discoverable) — do not just style it grey |
| Hover-revealed actions | Also reveal on `:focus-within` and keep them tab-reachable — keyboard users have no hover |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `div` / `span` with `onClick` | `<button>` (restyled) | Button gives focus, Enter/Space activation, and role for free; the div needs all of it re-implemented |
| `tabindex="3"` to fix focus order | Reorder the DOM so visual order = DOM order | Positive tabindex hijacks the page-wide tab sequence and breaks as content changes |
| `<a onClick={...}>` without `href` for an action | `<button type="button">` | An anchor without href is not keyboard-focusable and announces as a link that goes nowhere |
| Adding `role="button"` to make a div accessible | Native `<button>`; when truly impossible, implement the full APG keyboard contract with the role | The role alone changes the announcement, not the behavior |

## Sources

- https://www.w3.org/TR/using-aria/ — first rule of ARIA: prefer native HTML elements
- https://www.w3.org/WAI/ARIA/apg/patterns/ — per-widget roles, states, and keyboard interaction contracts (button, dialog, menu, etc.)
