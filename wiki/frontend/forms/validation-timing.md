---
id: frontend-forms-validation-timing
domain: frontend
category: forms
applies_to: [general, react]
confidence: verified
sources:
  - https://www.nngroup.com/articles/errors-forms-design-guidelines/
  - https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Form_validation
last_verified: 2026-07-10
related: [frontend-state-derived-state]
---

# When to Validate Form Fields and Show Errors

## When this applies

Implementing form validation and deciding when each check runs and when its error
becomes visible; or reworking a form users abandon because errors appear too
early, too late, or without explanation.

## Do this

1. Apply the timing table (principle: acknowledge valid input early, surface
   errors only after the user has finished with the field):

| Moment | Do |
|--------|-----|
| Typing in a field not yet visited/errored | Run no visible validation — flagging half-typed input punishes users mid-thought |
| Field blur (user finishes the field) | Validate the field; show its error inline, adjacent to the field |
| Change in a field already marked invalid | Re-validate on every change so the error clears the moment the fix lands |
| Submit | Validate the whole form regardless of per-field history; when invalid, focus the first errored field and show all field errors at once |
| Server response contains validation errors | Map each error to its field and render it in the same inline slot; render unmappable errors in a form-level error region above the submit button |
| Async/uniqueness check (email taken, name available) | Run on blur with a debounce; treat the client result as advisory and re-check on submit — the server's answer is the real gate |

2. Keep the submit button enabled while the form is invalid; disable it only
   while submission is in flight. A submit disabled for invisible reasons strands
   the user — an enabled submit runs validation and reveals exactly what to fix.
3. Write error copy that states what to do ("Enter the expiry as MM/YY"), placed
   next to the field it concerns; a message that only says what is wrong makes
   the user guess the fix.
4. Treat all client-side validation as UX assistance only: the server re-validates
   every submission, because client checks are trivially bypassed. Build the field
   mapping for server errors (row above) from day one.

## Edge cases

| Case | Then |
|------|------|
| Multi-field rule (start date < end date) | Validate when the later of the involved fields blurs, and always on submit; attach the error to the field the user edits to fix it |
| Blur fires because the user clicked Cancel/another tab | Suppress the on-blur error when the blur target abandons the form — validating a form being abandoned is noise |
| Async check still in flight at submit time | Block submission until it settles (spinner on the field), then proceed or surface the error — submitting alongside an unresolved check double-fires |
| Error text placement for screen readers | Link message to input with `aria-describedby` and set `aria-invalid` on the invalid field, so the error is announced with the field |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Validate every field on every keystroke from first focus | Validate on blur first, then per-change only once the field is marked invalid | Premature errors interrupt users who were about to finish correctly |
| Disable submit until the form is valid | Keep submit enabled; on invalid submit, focus first error and show all errors | Disabled-with-no-reason gives no path forward |
| Show one generic "form has errors" banner only | Inline per-field errors + focus the first one (banner as summary at most) | Users cannot fix what they cannot locate |

## Sources

- https://www.nngroup.com/articles/errors-forms-design-guidelines/ — inline adjacent errors; validate after the user finishes a field
- https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Form_validation — client-side validation mechanics; server must always re-validate
