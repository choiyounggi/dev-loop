---
id: frontend-design-interface-copy-for-actions-and-confirmations
domain: frontend
category: design
applies_to: [general]
confidence: unverified
sources:
  - https://github.com/jakubkrehel/skills/blob/8b254eb75dadf3615a6abce87aed28e1b6e4d77c/skills/better-writing/SKILL.md
  - https://github.com/jakubkrehel/skills/blob/8b254eb75dadf3615a6abce87aed28e1b6e4d77c/skills/better-writing/patterns.md
  - https://github.com/jakubkrehel/skills/blob/8b254eb75dadf3615a6abce87aed28e1b6e4d77c/skills/better-accessibility/focus-and-keyboard.md
  - https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html
last_verified: 2026-11-12
related: [frontend-design-ui-hardening-against-real-content, frontend-forms-validation-timing, frontend-data-fetching-async-ui-states, frontend-design-anti-slop-visual-design, frontend-design-polish-values-for-product-ui]
---

# Interface Copy for Buttons, Links, Toasts and Destructive Confirmations

## When this applies

You are writing or reviewing the words on controls and their results: button and
icon-button labels, link text, toggle labels, success toasts, and the dialog that
confirms a destructive action. Error messages beside a field belong to
[frontend-forms-validation-timing]; empty, loading and error views of a fetched list
belong to [frontend-data-fetching-async-ui-states].

## Do this

| Copy | Write |
|------|-------|
| Button label | A verb naming the action: "Send", "Save draft", "Delete project", "Send invite". Replace "OK!", "Submit", "Let's go!" |
| Icon-only button | An accessible name that names the action ("Delete project", "Close panel"), not the glyph ("Trash icon") |
| The same action in two places | One term everywhere: if the menu says "Archive", the toast says "archived", not "moved to storage" |
| Link text | The destination, readable out of context: "Read the billing docs". Suffix each "Learn more", since a bare one breaks as soon as two appear on a page: "Learn more about usage limits" |
| Toggle label | The ON state: "Send read receipts", not "Don't send read receipts" |
| Capitalization | One policy per element type; sentence case where the project has none |
| Success toast | The result, without "successfully" or "!": "Changes saved", "Kim Park removed". Use a toast only for an effect the screen does not already show ([frontend-design-anti-slop-visual-design]) |

For a destructive action, pick the pattern by reversibility:

| Case | Do |
|------|----|
| The action can be reversed and people do it often (archive, move, delete to trash) | Act at once and offer Undo in the result: "Project archived. Undo" |
| The action cannot be reversed, affects other people, or removes many items | Confirm first. Title names the action and the object: "Remove Sam Ortiz?". Body states what is lost and what cannot be recovered, with counts. Buttons are verb plus object and Cancel: "Remove member" / "Cancel" |
| The object is an account, a workspace or a repository | Also ask the person to type the object's name before the confirm button enables |

## Edge cases

| Case | Then |
|------|------|
| The confirm dialog uses `window.confirm` | Its buttons read OK / Cancel and cannot be relabelled; build a dialog (`<dialog>` with `showModal()`) when the action is irreversible, so the buttons can carry verb plus object |
| The product already has a voice (playful, formal) | Keep its voice; these rules govern what the copy says, not its tone |
| A label must fit a narrow control | Shorten the object, keep the verb: "Delete" with the object named in the dialog title |
| Translated UI | Keep the verb-first structure in each language and leave room for longer strings ([frontend-design-ui-hardening-against-real-content]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Title a dialog "Are you sure?" | Title it with the action and the object | The person can answer from the title alone |
| Label dialog buttons "Yes" / "No" | Use "Remove member" / "Cancel" | A verb button states the consequence at the moment of clicking |
| End a toast with "successfully!" | State the result: "Invite sent" | The word adds length and no information |

## Sources

- jakubkrehel/skills `better-writing` at 8b254eb (MIT): verb-first labels, icon-button
  names, one vocabulary, link text and suffixed "Learn more", ON-state toggles, one
  capitalization policy, "Undo beats confirmation", the destructive confirmation
  checklist (title, body, verb-plus-object buttons, type-the-name), "successfully" cut.
- jakubkrehel/skills `better-accessibility/focus-and-keyboard.md` at 8b254eb: native
  `<dialog>` with `showModal()` makes the page behind it inert and closes on Escape.
- WCAG 2.2 Understanding 2.4.4 Link Purpose (In Context): link text that makes sense
  for screen-reader users who navigate a list of links.
- Field context, 2026-11-12: a settings screen whose original copy was "OK!", "Are you
  sure?", "Invalid input", "No results." and "Saved successfully!"; all three
  redesigns rewrote it along these lines and passed the trial's copy check (no "OK!", "Are you sure?", "Invalid input", "No results." or "successfully" left).
