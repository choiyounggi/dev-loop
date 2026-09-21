---
id: qa-document-verification-editing-a-gated-document
domain: qa
category: document-verification
applies_to: [general]
confidence: field-tested
sources:
  - https://man7.org/linux/man-pages/man1/pgrep.1.html
  - https://docs.vale.sh/topics/scopes.md
  - https://docs.vale.sh/checks/existence
  - https://github.com/DavidAnson/markdownlint/blob/main/doc/md013.md
last_verified: 2026-08-14
related: [qa-process-acceptance-criteria, qa-process-regression-scope, testing-quality-tests-that-cannot-fail, qa-document-verification-model-coupled-guidance-aging-detector]
---

# Editing a Document That Automated Text Gates Check

## When this applies

You are adding to or rewording a document (RFC, spec, plan, audit record) that
grep/regex gates or a lint config run over; you are recording an audit result
*inside* the document the audit examined; or a check that passed before your edit
now fails on wording whose meaning did not change.

## Do this

1. **Inventory the anchors before editing.** Grep the gate definitions for patterns
   naming this file and treat every hit as a constraint on the edit. Anchors come in
   kinds that break differently:

| Anchor kind | Example | How an edit breaks it |
|-------------|---------|-----------------------|
| Phrase or vocabulary | a pattern requiring/forbidding certain verbs near a term | Reworded sentence stops matching, or starts matching a forbidden pattern |
| Line or row count | "file has 444 lines", "table has 5 rows" | Any insertion shifts the count |
| Substring | a section title, term, or phrase quoted verbatim | Retitling or translating the term silently drops it; reflowing a paragraph wraps the phrase across two physical lines, and a single-line pattern (`[[ … == *"phrase"* ]]`, `grep` without normalization) no longer matches |
| Quoted original | a check that requires an upstream sentence to appear verbatim | Paraphrasing removes it while preserving meaning |

2. **State facts about an upstream document as observations, not definitions.** A
   lexical gate that means "do not redefine the upstream contract" can only
   approximate that with vocabulary: Vale's `existence` check "looks for the
   'existence' of particular tokens" and evaluates no meaning. So a true, purely
   descriptive sentence trips it when it uses a defining verb. Write the observable
   shape instead — "the contract table has two rows, `arena` and `pool`, and no
   `heap` row" — which carries the same information and matches no definition
   pattern.

3. **Scope a check outside the region that quotes it.** When the document contains
   the check command or its regex, the pattern matches its own quotation. Bound the
   judgment to the normative region (`awk '/^### <audit heading>/{exit}'`, a line
   range, or a section selector) rather than running it over the whole file. This is
   standard practice in the tools themselves: Vale scopes are markup-aware and "Any
   scope prefaced with `~` is negated", and markdownlint rules take
   `code_blocks: false` to exclude quoted code from prose rules. `pgrep` hard-codes
   the same defense — "The running pgrep, pkill, or pidwait process will never
   report itself as a match."

4. **Record verdicts as scoped conditions, never as a global count.** Write "0
   matches outside §Audit" or "every match is inside a fenced block", not "1 match
   found". A fixed number is invalidated by the next edit — including the edit that
   quotes the finding — so a count-based verdict decays into a false statement while
   looking precise.

5. **Re-run the whole gate set after the edit and compare against the pre-edit
   pass count.** Your edit can break a check owned by a different section or a
   different task ([qa-process-regression-scope]). A baseline number (`60 → 61`) is
   what distinguishes "my change fixed one" from "my change fixed one and broke two".

## Edge cases

| Case | Then |
|------|------|
| The quoted pattern must stay in the document (it is the audit record) | Keep the quote and narrow the check's scope; the document's job is to be readable, the check's job is to be scoped |
| Fixing the report by quoting the offending match adds another match | Stop counting globally and switch to the scoped condition in step 4 — each quote-to-fix round otherwise raises the count and re-falsifies the statement |
| Gate anchors on a line count you must change | Update the gate and the document in the same commit, and say so in the PR ([qa-process-acceptance-criteria]) |
| The failure surfaces in another task's or another agent's check log | Attribute before repairing: identify which file the failing pattern targets, since a cross-file gate makes your edit look like their regression |
| The gate is genuinely wrong (it forbids a correct sentence with no replacement available) | Change the gate, with a control proving it still catches the defect it owns — do not reword a correct document into a worse one |
| The gate is green on your machine and red only in CI after a prose edit (macOS-authored bats suites) | Treat the anchor inventory of step 1 as the authoritative local signal, not the test run: under bash ≤4.0 (macOS system bash 3.2) a failing mid-test `[[ ]]` does not fail the test, so the broken anchor passes silently on your platform ([testing-quality-tests-that-cannot-fail]) |
| You are authoring the gate rather than the document | This page covers the author's side; gate construction and its controls are a separate concern → [testing-quality-tests-that-cannot-fail]. For a phrase anchor specifically, compare whitespace-normalized text (collapse runs of whitespace, then `grep -qF`) so legitimate reflow of the document cannot break the gate |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Edit a gated document and run only the check you were fixing | Grep the gates for anchors on that file first, then re-run the full set against a baseline count | Line-count and substring anchors break silently, and the breakage lands in a check you never looked at |
| Write "X defines/mandates two variants" when describing an upstream contract | Write the observable shape: "the table has two rows and no Y row" | A vocabulary gate cannot separate describing from redefining, so the defining verb fails a sentence whose content is correct |
| Run an audit pattern over the whole document that quotes it | Bound it to the normative region by heading range or line range | The quotation is a match, so the whole-file run measures the document's prose about itself |
| Record "grep found 0 hits" as the audit result | Record the scoped condition that must hold ("no hits outside §Audit") | The bare count is true only for the file revision that produced it and silently becomes false on the next edit |
| Reflow or rewrap a paragraph a gate quotes as a phrase | Keep each asserted phrase on one physical line, or switch that gate to whitespace-normalized comparison in the same commit | A single-line substring anchor breaks at any wrap point inside the phrase, and on macOS bats the breakage is locally invisible (bash ≤4.0 `[[ ]]` gap) |

## Sources

- https://docs.vale.sh/checks/existence — the check "looks for the 'existence' of particular tokens", transformed into a word-bounded non-capturing group: a lexical gate matches patterns, not intent
- https://docs.vale.sh/topics/scopes.md — scopes restrict where a rule applies via markup-aware selectors; "Any scope prefaced with `~` is negated" and scopes can be chained, so checks can be kept off regions like code examples
- https://github.com/DavidAnson/markdownlint/blob/main/doc/md013.md — rules expose `code_blocks`, `tables`, `headings` booleans (default `true`) so quoted code can be excluded from a prose rule
- https://man7.org/linux/man-pages/man1/pgrep.1.html — "The running pgrep, pkill, or pidwait process will never report itself as a match" — self-exclusion is designed in because self-matching is the expected failure
- Measured 2026-08-14 (macOS bash 3.2.57): `[[ "$s" == *"return to step 1"* ]]` does not match when `$s` carries the phrase split across a newline — the wrap genuinely breaks the anchor on every platform; and `set -e; [[ 1 -eq 2 ]]; echo REACHED` prints, so the broken mid-test anchor is invisible under macOS bats while bash ≥4.2 CI fails it
- Field reproduction ×2 (dev-loop): PR #94 §O3 and PR #102 — reflowing SKILL.md prose split `return to step 1 of the dispatch` across two lines; `tests/orchestrate-review-pass.bats` asserted it as a single-line substring, CI red on ubuntu only, fixed by reflowing the phrase onto one physical line (commit 9cbc065)

## Field context

Distilled from 2026-07 RFC/plan-authoring sessions in this repo. A vague-word audit
of `docs/ROADMAP.md` reported 1 global hit — the audit command's own quoted pattern —
and quoting the finding to fix it raised the count to 3, while an `awk`-scoped run
over the normative region reported 0; the same self-reference appeared twice more
(a negative-control example that always matched, and a `docs/*.md` glob matching its
own document 45 times). Separately, adding the sentence "defines only the two
variants arena and pool" to an RFC failed a sibling task's vocabulary gate
(`(arena|pool)…(재정의|정의한다|규정한다)`); rephrasing to "the contract table has
two rows and no heap row" restored the suite from 60 to 61 passing, and a pre-edit
anchor survey of that file found three further anchors — a line count, a section
substring, and a verbatim upstream sentence — all preserved by the same edit.
