---
id: backend-common-errors-diagnostics-from-a-shared-code-path
domain: backend
category: errors
applies_to: [general]
confidence: verified
sources:
  - https://rustc-dev-guide.rust-lang.org/diagnostics.html
  - https://doc.rust-lang.org/stable/nightly-rustc/rustc_errors/enum.Applicability.html
  - https://www.nngroup.com/articles/error-message-guidelines/
last_verified: 2026-08-09
related: [backend-common-api-design-error-responses, backend-common-api-design-unenforced-declarations, backend-common-change-impact-call-site-enumeration, debugging-signals-reading-error-messages, backend-common-change-impact-sibling-validators-on-a-shared-node]
---

# A Rejection Message Emitted From a Code Path Two Constructs Share

## When this applies

You are writing or reviewing a rejection/validation message produced by one
function that more than one caller reaches — a reference checker shared by a
guard and an assignment, a validator shared by request and response, a policy
check shared by two config blocks — and the message names one caller's construct
in literal text, or tells the author what to write instead. Also when a user
reports a rejection whose wording names a construct they did not write.

## Do this

1. **Make the message's subject a parameter the caller supplies.** The shared
   function formats; each call site passes its own construct name. A construct
   name written literally inside a shared body is correct for exactly one caller
   and silently wrong for every other one.
2. **Verify each part of the message against the path that emits it**, because
   the parts fail with different visibility:

| Part the message carries | Verify by |
|--------------------------|-----------|
| The subject — the construct being rejected | Reading one emitted message per call path; a wrong subject is visible on first read |
| A named repair ("use `input.<field>` instead") | Executing the repair as written from each call path and requiring the result to be accepted |
| A pointer to another rule or section | Confirming that rule admits this caller's construct at all |

3. **Treat the repair as the part most likely to be wrong, and check it per
   path.** A repair is advice the author will follow literally; when it is
   illegal on one of the emitting paths, following it lands the author in a
   second, unrelated rejection. NN/g's rule is that the message must describe a
   solution sufficient to fix the problem — on the path the reader is on.
4. **Rate the repair by whether it holds on every path that can emit it.**
   Present it as *the* fix (and allow any auto-apply tooling to use it) only when
   it is valid on all of them; otherwise branch it. `rustc` encodes the same
   distinction as `Applicability` — `MachineApplicable` for a suggestion that can
   be applied mechanically, `MaybeIncorrect` for one that "may or may not be a
   good one" — and instructs authors to "be conservative when choosing the level".
5. **Assert the message once per emitting path, not once per message.** A single
   test on one caller leaves the other caller's subject and repair unasserted, so
   parameterizing the subject and breaking the other path's advice both stay
   green ([backend-common-change-impact-call-site-enumeration] enumerates the
   paths).
6. **When the repair differs by path, branch on the parameter that already
   distinguishes them** — pass the repair alongside the subject, so each caller
   states the fix that is legal for it.

## Edge cases

| Case | Then |
|------|------|
| The two callers reject for the same reason but repair differently | Pass the repair text as a second caller-supplied parameter; keep one rejection rule and two suggestions |
| The suggested form is legal at parse time but rejected by a later rule on this path | The advice is still wrong — run it end to end on that path, not just past the check that emitted it |
| Only one caller exists today | Parameterize the subject anyway when the function is named for the *check* rather than the construct; the second caller is what makes the literal wrong, and it arrives without touching this file |
| The message is localized or templated | Pass the subject as a named placeholder argument rather than concatenating it, so translators receive a slot instead of a sentence fragment |
| The shared function genuinely cannot know the subject | Have callers pass a context value carrying subject and repair together, so a new caller cannot compile without supplying both |
| A repair is valid everywhere except one rarely reached path | Branch it — a suggestion that is wrong on one path is `MaybeIncorrect` for all of them, and rating it that way costs the reader on every path |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write the construct's name into the shared function's message text | Take the subject as a parameter each call site fills | The literal is right for the caller you had in mind and misnames every other one |
| Fix the misnamed subject and ship | Also execute the repair from each emitting path and require acceptance | The subject is checked by reading; the repair is only checked by running, so it is the part that stays wrong |
| Soften the repair into something true on every path ("check the syntax") | Branch the repair on the parameter that distinguishes the callers | A repair that carries no action returns the reader to guessing, which is what the message existed to prevent |
| Assert the message text in one test and call the wording covered | Assert subject and repair once per emitting path | One assertion cannot distinguish "both paths right" from "one path never exercised" |

## Sources

- https://rustc-dev-guide.rust-lang.org/diagnostics.html — suggestions carry a confidence level and "Be conservative when choosing the level"; `MachineApplicable` = "Can be applied mechanically", `MaybeIncorrect` = "Cannot be applied mechanically because the suggestion may or may not be a good one", `Unspecified` = "we don't know which of the above cases it falls into"
- https://doc.rust-lang.org/stable/nightly-rustc/rustc_errors/enum.Applicability.html — the enum tools read to decide whether a suggestion is auto-applied or shown for review
- https://www.nngroup.com/articles/error-message-guidelines/ — an error message offers constructive advice: the described solution must be sufficient for the user to fix the problem
- Field incident 2026-08-09 (`linkly`, `impl/lnpl/lower.py`): `_Scope.check_reference` is called from both the guard path and the assignment path and hardcoded "guard condition" into three messages. The `set`-target rejection additionally advised writing `input.<field>`, which `_derive_assignment` rejects for `set` targets by a separate rule — an author following the advice hit a second, unrelated rejection. After threading subject/target through as parameters the suite went 1864 → 1872 (the 8 new per-path assertions, no other change), and an independent audit exercised each branch as its own mutation
