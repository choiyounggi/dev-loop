---
id: frontend-forms-dropzone-copy-without-drop-handlers
domain: frontend
category: forms
applies_to: [html, general]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API/File_drag_and_drop
last_verified: 2026-09-03
related: [frontend-accessibility-interactive-elements, frontend-forms-validation-timing]
---

# "Drag and Drop" Copy on a Styled File-Upload Dropzone

## When this applies

Building or restyling a file-upload control where `<input type="file">` is
visually hidden (sr-only / clip) and a `<label>` or wrapper is styled as a
dropzone; the copy or the visual design tells the user files can be dragged
onto it; reviewing such a diff for whether the advertised affordance exists.

## Do this

1. Decide the copy from the handlers, not from the styling. Nothing makes an
   element a drop target except `dragover` and `drop` listeners that each call
   `preventDefault()`; MDN: an unhandled file drop is processed by the browser
   "by default (such as opening or downloading the file) even when the file is
   not dropped into a valid drop target."

| Case | Do |
|------|----|
| The visible dropzone element has `dragover` and `drop` listeners, each calling `preventDefault()`, and `drop` reads `event.dataTransfer.files` | Ship the "drag and drop" copy — the affordance is real |
| No `dragover`/`drop` listener exists on the dropzone (grep the component for `onDrop` / `addEventListener('drop'`) | Ship copy that matches the control ("Click to choose a file"); add the drag copy in the same commit that adds the handlers |
| Adding drag-and-drop support | Attach both listeners to the visible dropzone element (label/wrapper), not to the hidden input, and forward `dataTransfer.files` into the same upload path the input's `change` event uses |
| Any page that accepts drops somewhere | Add a window-level `dragover`/`drop` pair calling `preventDefault()`, so a drop that misses the zone stays on the page instead of opening the file |

2. Keep the hidden input as the keyboard and screen-reader path: the label's
   `for` / wrapping keeps click-to-choose working, and the styled zone is the
   pointer path ([frontend-accessibility-interactive-elements]).

## Edge cases

| Case | Then |
|------|------|
| Handlers exist but are attached to the hidden `<input>` | Move them to the element the pointer is over; a 1px clipped input has no drop surface |
| Drop support is planned for a later ticket | The copy tracks the shipped capability; a review that greps for the handlers is the gate for changing it |
| The framework wraps DnD (react-dropzone and equivalents) | The wrapper's root props carry the listeners — confirm they are spread onto the visible zone, then the copy is honest |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write "Drag and drop files here" because the box now looks like a dropzone | Grep for `drop`/`dragover` handlers on the zone; write the drag copy only when both exist with `preventDefault()` | The default action for an unhandled drop opens or downloads the file, so the copy advertises a path that navigates the user away |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API/File_drag_and_drop — "the browser may process them by default (such as opening or downloading the file) even when the file is not dropped into a valid drop target"; "In order for the `drop` event to fire, the element must also cancel the `dragover` event"; "we also need to listen for the `drop` event on `window` and cancel it"
- Field evidence 2026-08-30 (auto-naver-blog, review t3-upload-progress-r1 F1): a restyle hid the file input as sr-only and styled the label as a dropzone with "drag and drop" copy; the reviewer's grep found no `onDrop`/`onDragOver`; the copy was corrected and the re-audit passed
