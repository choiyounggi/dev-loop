---
id: frontend-design-ui-hardening-against-real-content
domain: frontend
category: design
applies_to: [css, javascript, general]
confidence: verified
sources:
  - https://www.w3.org/International/articles/article-text-size/
  - https://www.w3.org/TR/pointerevents/
  - https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_logical_properties_and_values
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/PluralRules
  - https://developer.mozilla.org/en-US/docs/Web/CSS/overflow-wrap
  - https://developer.mozilla.org/en-US/docs/Web/CSS/hyphens
  - https://developer.mozilla.org/en-US/docs/Web/CSS/-webkit-line-clamp
  - https://developer.mozilla.org/en-US/docs/Web/CSS/touch-action
  - https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/title
  - https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html
  - "https://github.com/pbakaus/impeccable/blob/114ea1d3838fca73b253af45f873b9c4f5f213c8/skill/reference/harden.md — Impeccable skill 4.x `harden` reference (extreme-input test set, interrupted-gesture rules, error-recovery copy); pinned to a commit because the repo restructures its reference paths between versions"
last_verified: 2026-09-29
related: [frontend-design-responsive-layout, frontend-data-fetching-async-ui-states, frontend-forms-validation-timing, frontend-accessibility-interactive-elements, frontend-design-product-ui-vs-brand-surface]
---

# Hardening a UI Against Real Content, Languages and Interrupted Input

## When this applies

A screen was built and checked only with short English placeholder data and is
about to ship; a UI is gaining translations or a right-to-left locale; a field,
list or label will show user-generated content; a custom drag, slider or
scrubber control is being written or reviewed; a diff sets fixed widths on
text containers or hard-codes English plurals and number formats.

## Do this

Run the extreme-input set first, then fix what it surfaces with the rows below:
100+ character names, empty and single-character values, emoji and CJK text,
numbers in the millions, 1000+ list items and 50+ options, zero items, and the
same screen at 200% zoom.

| Case | Do |
|------|----|
| Any text container that will be translated | Budget the expansion by source length (W3C / IBM figures for English → European languages, quoted as published — the 51–70 row is printed above the 31–50 row): ≤10 chars 200–300%, 11–20 180–200%, 21–30 160–180%, 31–50 140–160%, 51–70 151–170%, over 70 130%. Size buttons and labels by padding around the content, never by a fixed width |
| A long single value must stay on one line (a name in a row, a tab label) | `overflow: hidden; text-overflow: ellipsis; white-space: nowrap`, and expose the full value in a tooltip that opens on hover and on keyboard focus — a `title` attribute reaches neither keyboard nor touch users |
| A multi-line preview must stop at N lines | `display: -webkit-box; -webkit-line-clamp: N; -webkit-box-orient: vertical; overflow: hidden` |
| Free text that must wrap | `overflow-wrap: anywhere` — its break opportunities count toward the min-content size, so the flex/grid item can shrink; `break-word` breaks the same words but leaves min-content unchanged, so pair it with `min-width: 0` on the item ([frontend-design-responsive-layout]). Add `hyphens: auto` with the document `lang` set, because hyphenation rules are per language |
| Spacing, borders or icons that point along the reading direction | Logical properties: `margin-inline-start`, `padding-inline`, `border-inline-end`, `inset-inline-start`; flip directional glyphs under `[dir="rtl"]` with `transform: scaleX(-1)` |
| Dates, times, numbers, currency in the UI | `Intl.DateTimeFormat` / `Intl.NumberFormat` with the user's locale; the same value renders `1,234.56` in en-US and `1.234,56` in de-DE from one code path |
| Count-bearing copy ("3 items") | `Intl.PluralRules` or the i18n library's plural forms; a hand-rolled `count !== 1 ? 's' : ''` is wrong outside English |
| A custom drag, slider or scrub control | Set `touch-action: none` (or the axis you keep) on the control so the browser hands it the moves instead of panning; record the `pointerId` that started the drag and act only on that pointer's moves; on `pointercancel`, `lostpointercapture`, a `pointerup` outside the control, or window `blur`, clear the dragging state and release capture — the browser fires `pointercancel` when it takes the stream for a gesture `touch-action` still allows (pan, pinch, palm rejection) and implicitly releases capture with it |
| Confirming a gesture fix | Drive the input in the project's test runner when it can synthesize pointer events; state what produced the evidence (emulated viewport, synthesized touch, engine, or a physical device) and name what stayed untested |
| An error reaches the user | The message names the problem and the recovery, with a retry control; validation errors sit inline by the field and the user's input is preserved ([frontend-forms-validation-timing]) |
| A submit can fire twice | Disable the control while the request is pending and drive the disabled state from the request state, not from a click counter |
| A list can reach thousands of rows | Paginate or virtualize, and add search or filter — rendering all rows at once is the failure the extreme-input set exists to catch |

## Edge cases

| Case | Then |
|------|------|
| The source language is Korean, Chinese or Japanese and the target is English | Expansion runs the other way (W3C measured Korean "views" at 0.8× English) and CJK breaks between any two characters — check both the longest and the shortest locale, and read the CJK pill rule in [frontend-design-responsive-layout] |
| An input's font-size is under 16px on iOS | [frontend-design-responsive-layout] owns that fix (raise the input to 16px rather than adding `maximum-scale`) |
| The screen has zero items after the extreme-input pass | The empty, loading and error states belong to [frontend-data-fetching-async-ui-states]; this page owns what happens when data is present but hostile |
| A second finger or pointer lands mid-drag | The first drag keeps its `pointerId` or ends cleanly; it never jumps to the new pointer. After any of the cancel paths above, the next tap or drag works without a reload — test that explicitly |
| Text at 200% browser zoom overflows its container | The container must grow with the text; a fixed height or width on a text box fails WCAG 1.4.4 (text must resize to 200% without loss of content or function) even when the 100% render passed |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `width: 6rem` (or `w-24`) on a button so it lines up | Padding-based sizing and a flex/grid row that aligns the buttons | German or Portuguese labels run 1.4–3× the English width and overflow the box |
| `margin-left` / `padding-right` / `border-right` on layout that follows the text direction | `margin-inline-start` / `padding-inline-end` / `border-inline-end` | Physical properties stay put under `dir="rtl"`, so every offset lands on the wrong side |
| Concatenating a number with a locale-specific separator by hand | `Intl.NumberFormat(locale, options).format(value)` | Grouping and decimal separators swap between locales; one code path covers all of them |
| Clearing drag state only on `pointerup` | Clear it on `pointercancel`, `lostpointercapture`, out-of-bounds `pointerup` and window `blur` too | A scroll or a palm touch ends the stream with `pointercancel`, and `pointerup` never arrives — the control stays stuck "dragging" until reload |
| Shipping a generic "Something went wrong" | Name the failure and the recovery, with a retry control | A message without a next action leaves the user at a dead end, which reads as a broken product |

## Sources

- https://www.w3.org/International/articles/article-text-size/ — Flickr "views" ratios by language (Korean 0.8, German 2.8, Italian 3.0); IBM average expansion table by English source length (≤10 chars 200–300% … over 70 chars 130%); "the smaller the source message, the higher the likely translation length"
- https://www.w3.org/TR/pointerevents/ — `pointercancel` definition: the user agent MUST fire it when it detects a scenario to suppress a pointer event stream; the "suppress a pointer event stream" steps fire `pointercancel`, `pointerout`, `pointerleave` and implicitly release pointer capture; `lostpointercapture` fires on release; `pointerId` identifies each active pointer
- https://developer.mozilla.org/en-US/docs/Web/CSS/touch-action — "By default, panning (scrolling) and pinching gestures are handled exclusively by the browser. An application using Pointer events will receive a pointercancel event when the browser starts handling a touch gesture"; declaring which gestures the browser keeps is what lets the control receive the moves
- https://developer.mozilla.org/en-US/docs/Web/CSS/overflow-wrap — `anywhere`: soft wrap opportunities introduced by the word break "are considered when calculating min-content intrinsic sizes"; `break-word`: the same breaks, but they "are NOT considered when calculating min-content intrinsic sizes"
- https://developer.mozilla.org/en-US/docs/Web/CSS/hyphens — "Hyphenation rules are language-specific. In HTML, the language is determined by the lang attribute. Browsers will only hyphenate if this attribute is present"
- https://developer.mozilla.org/en-US/docs/Web/CSS/-webkit-line-clamp — requires `display: -webkit-box` and `-webkit-box-orient: vertical`
- https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/title — "Use of the title attribute is highly problematic for: People using touch-only devices, People navigating with keyboards, People navigating with assistive technology"
- https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html — SC 1.4.4: text resizes to 200% without loss of content or functionality
- https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_logical_properties_and_values — logical properties are defined relative to the content's writing direction rather than a physical side; Hebrew and Arabic are right-to-left
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl — locale-sensitive number, date and time formatting
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/PluralRules — plural categories are selected per locale, which is why an English `count !== 1` rule is wrong elsewhere
- https://github.com/pbakaus/impeccable/blob/114ea1d3838fca73b253af45f873b9c4f5f213c8/skill/reference/harden.md — the extreme-input test set, truncate / line-clamp / wrap CSS, `min-width: 0` on flex and grid items, interrupted-gesture handling (second pointer, `pointercancel`, `lostpointercapture`, release outside, `blur`), evidence-naming rule for gesture tests, error copy with recovery, double-submission guard
