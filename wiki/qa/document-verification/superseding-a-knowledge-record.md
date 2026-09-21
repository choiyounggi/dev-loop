---
id: qa-document-verification-superseding-a-knowledge-record
domain: qa
category: document-verification
applies_to: [general, adr, agent-wiki]
confidence: verified
sources:
  - https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
  - https://adr.github.io/madr/
  - https://www.rfc-editor.org/rfc/rfc2223.txt
  - https://www.rfc-editor.org/faq/
last_verified: 2026-09-17
related: [qa-document-verification-retiring-a-provisional-marker, qa-document-verification-spec-document-gates, infrastructure-agent-orchestration-escape-hatch-uses-as-a-knowledge-gap-signal]
---

# Superseding a Knowledge Record That Turned Out Wrong

## When this applies

A record in a curated set other documents cite by id or path — an ADR, a wiki
page, a runbook, a spec section — is refuted or replaced by a newer finding,
and you are deciding between editing it in place, deleting it, or replacing
it; or you are adding a lifecycle field (`status`, `superseded_by`) to such a
set's schema.

## Do this

1. **Pick the operation from how much of the old record survives.**

| The new finding | Do |
|-----------------|----|
| Adds a case or a source; the old directive still holds | Amend the old record in place (the RFC series calls this *Updates*: the addition "cannot stand on its own") |
| Refutes the old directive as a whole | Write a new record that stands alone, then mark the old one superseded (*Obsoletes*: the new document "can be used alone, without reference to the older document") |
| Refutes it and nothing replaces it | Mark the old record retired, with the reason and date in the change log |

2. **Keep the superseded file at its path and id.** Set its status and a
   pointer to the successor's id; leave the body as it was. Plans, reviews,
   and commit messages that cited the old id keep resolving, and a reader
   learns that it *was* the rule and what replaced it.
3. **Move navigation to the successor in the same change.** The index or
   routing row now names the new record only, so a reader routing by
   situation lands on current guidance; the old record stays reachable by id
   and through the successor's back-link.
4. **Make the successor pointer resolvable, and check it.** `superseded_by`
   holds a live record id; the link check that already covers `related:`-style
   fields covers it too, and `status: superseded` without a pointer is a lint
   finding.
5. **Keep validity separate from evidence strength.** `status` answers "is
   this still the rule"; a confidence or review field answers "how well was it
   supported when written". A record that was verified against official docs
   and later superseded carries both values unchanged.
6. **Let the absent field mean the default state.** Add `status` as an
   optional key whose absence means active, and show it in the template as a
   commented line. Existing records need no backfill, and a lint for the
   field has only the exceptional states to validate.
7. **Log the transition with the vocabulary the log already has** — a
   `revise`-class entry reading `<old id> superseded by <new id> — <why>` —
   when nothing parses the verb set mechanically. Add a verb only when a
   consumer needs to select these entries by verb.

## Edge cases

| Case | Then |
|------|------|
| Only one directive of a multi-directive record is refuted | Amend that directive in place and log the revision; superseding is for a record wrong as a whole |
| The successor is itself superseded later | Point each record at its direct successor; a reader follows the chain, and the lint checks each hop resolves |
| A tool loads records by glob, not through the index | Filter on the status field in that tool, or superseded guidance is loaded as current |
| The old record's id encodes a category the successor does not share | Keep the old id as is; ids are citation targets, and the pointer carries the move |
| Two records supersede one (a split) | Hold a list of successor ids, and state in each successor which part it took over |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Delete the refuted record and create the new one | Mark it superseded, point at the successor, keep the file | Every plan or review that cited the old path becomes a dead link, and the reason for the change is lost |
| Overwrite the record's body with the opposite directive under the same id | Create the successor under a new id | Citations made under the old directive now silently assert the new one |
| Add `superseded` as one more confidence value | Add a separate status field | Confidence describes the evidence at writing time; folding validity into it erases how well the old claim was supported |
| Write `status: active` into every existing record | Treat absence as active | A key that is identical on every record carries no information and makes the migration diff the size of the corpus |

## Sources

- https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions — Nygard's ADR definition: "If a decision is reversed, we will keep the old one around, but mark it as superseded. (It's still relevant to know that it *was* the decision, but is *no longer* the decision.)"; a changed decision "may be marked as 'deprecated' or 'superseded' with a reference to its replacement"
- https://adr.github.io/madr/ — the MADR template carries status as optional front matter with the value form `superseded by ADR-0123` ("These are optional elements. Feel free to remove any of them.")
- https://www.rfc-editor.org/rfc/rfc2223.txt — §12 "Relation to other RFCs": *Updates* marks a supplement that "cannot stand on its own"; *Obsoletes* marks a document that "can be used alone, without reference to the older document"
- https://www.rfc-editor.org/faq/ — "the status of an RFC can change" after publication, and the status is published on the RFC's info page and a list of status changes, apart from the document text
- Field context 2026-09-17 (dev-loop issue #195): a 276-page agent wiki had no status field, so a refuted page could only be deleted, which broke the page paths recorded in earlier plan documents
