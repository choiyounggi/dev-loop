---
id: qa-document-verification-retiring-a-provisional-marker
domain: qa
category: document-verification
applies_to: [general]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html
  - https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
  - https://www.rfc-editor.org/rfc/rfc7322.html
last_verified: 2026-08-14
related: [qa-document-verification-editing-a-gated-document, qa-document-verification-spec-document-gates, qa-process-acceptance-criteria]
---

# Converting a Provisional Marker to a Settled Statement in a Reviewed Design Document

## When this applies

You are turning provisional markers — `[추정]`, TBD, "assumed", DRAFT — into
settled statements in an ADR, RFC, or spec that has been through review rounds, so
the document also carries a review checklist and a round history that refer to
those markers. Also when a coordinator's marker count and yours disagree while you
are both reading the same file.

Editing a document that automated grep/lint gates run over →
[qa-document-verification-editing-a-gated-document]; that page owns the machine
anchors, this one owns the document's references to itself.

## Do this

1. **Split the marker's hits into axes before editing, and treat each axis as a
   separate edit target.** The same grep returns all four mixed together, and only
   the first is what "resolve the open items" means:

| Hit class | What it is | What the conversion does to it |
|-----------|------------|--------------------------------|
| Body statement carrying the marker | An open item | Remove the marker and state the settled rule |
| Review-checklist row passed _because_ the marker exists (`- [x] … marked as [추정]`) | An assertion about the document's own text | Becomes false the moment the body marker goes — rewrite the row's condition in the same edit |
| Round-history entry recording that the item was provisional | A dated record | Keep the wording and append a resolution note |
| Prose that names the marker convention (a legend, a template quote) | Vocabulary, not an open item | Leave it |

2. **Report the count with the axis and the command that produced it.** POSIX
   `grep -c` writes "only a count of selected lines", so a line carrying two
   markers counts once and a bare mention of the word counts the same as a marked
   claim. Three different numbers over one file are all correct on their own axis;
   an unlabelled number is what makes a coordinator's baseline and yours disagree.

3. **Rewrite each checklist row that the marker's presence satisfied, in the same
   commit as the body edit.** The row asserted "the document flags this as
   provisional"; after the conversion the settled statement is what must be
   asserted. Leaving the `[x]` in place points the next round at a marking that no
   longer exists, and the round cannot tell which of the two texts is current
   ([qa-process-acceptance-criteria]).

4. **Annotate history entries rather than rewording them.** Append "→ resolved as
   settled in round N" and leave the original sentence intact. This is the ADR
   convention for the same reason: "If a later ADR changes or reverses a decision,
   it may be marked as 'deprecated' or 'superseded' with a reference to its
   replacement" — the record of what was open, and when, is what stops the same
   question from reopening.

5. **Re-run the axis counts after the edit and require the split, not a single
   zero**: the body axis at 0, the history axis unchanged or higher, the checklist
   axis with every row's condition matching text that exists. A single global zero
   means the history was erased along with the open items.

## Edge cases

| Case | Then |
|------|------|
| The checklist row lives in a different file (a task brief, a review log) | Grep the marker across the review artifacts too and fix the row there; the row is stale wherever it lives, and a cross-file row makes your edit look like someone else's regression |
| The settled rule contradicts what the provisional statement guessed | Record both: the settled rule in the body, and the superseded guess in the history entry with the evidence that decided it — a silent replacement reads as if the guess had been right |
| Only some of the marked items are settled this round | Convert those and leave the rest marked; report the body-axis count as the remaining number rather than zero, so partial progress is not read as completion |
| The marker also appears inside a fenced block quoting the checklist's own pattern | Scope the count to the normative region rather than the whole file ([qa-document-verification-editing-a-gated-document]) |
| A machine gate asserts the marker's presence | Update the gate and the document in the same commit and say so in the PR — a gate left asserting a retired marker fails forever on a correct document |
| The document has no round history section | Add the resolution note next to the settled statement instead, naming the round and the evidence; what step 4 requires is the note, not a section to hold it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Strip every marker hit the grep returned | Split the hits by axis and edit only the body and checklist axes | The history entries and the convention legend are correct uses; stripping them erases when the item was open and what the marker means |
| Report "17 markers remaining" from one grep | Report the number with its axis and command ("11 unresolved body items, `grep -n '\[추정\]'` over §3–§9") | `grep -c` counts selected lines, so word mentions, multi-marker lines, and marked claims give different totals — and the coordinator's baseline is one of the other axes |
| Leave the `- [x]` checklist row alone because the body is now more accurate | Rewrite the row's condition to assert the settled statement | The row's evidence was the marker; with the marker gone the row asserts text that does not exist, and the next round cannot tell which is normative |
| Reword the round-history entry to match the settled rule | Append a resolution note and keep the original sentence | The history is the answer to "why was this open?"; overwriting it invites the same question to be reopened from scratch |

## Sources

- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html — `-c`: "Write only a count of selected lines to standard output"; "By default, each selected input line shall be written to the standard output" — the count is per line, not per occurrence
- https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions — Nygard: "A decision may be 'proposed' if the project stakeholders haven't agreed with it yet, or 'accepted' once it is agreed"; "If a later ADR changes or reverses a decision, it may be marked as 'deprecated' or 'superseded' with a reference to its replacement"; and explicitly, "If a decision is reversed, we will keep the old one around, but mark it as superseded" — the record is retained rather than rewritten, which is the convention step 4 applies to a marker inside one document
- https://www.rfc-editor.org/rfc/rfc7322.html — the RFC Style Guide recommends _distinguishable_ placeholder tokens for exactly this reason: "It is helpful for authors to clearly identify where text should be updated to reflect the newly assigned values. For example, the use of 'TBD1', 'TBD2', etc., is recommended in the IANA Considerations section and in the body of the memo." Numbered tokens make the body axis in step 1 enumerable; an undifferentiated marker word does not
- Field measurement 2026-08-14 (rtb-unified, NEWRTB-2435 ADR, D6 sub-total rule): converting two `[추정]` body lines to settled statements left two checklist rows (L858, L860) that had been passed _because_ those lines carried the marker, both instantly stale. On the same file `grep -c "추정"` returned 19, `grep -n "\[추정\]"` returned 17 lines, and the actual unresolved body items numbered 11 — the coordinator reported 11 while the worker reported 17 and 19, and the two only reconciled after the axis was named
