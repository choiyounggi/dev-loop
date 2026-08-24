---
id: backend-common-llm-progressive-disclosure-artifacts
domain: backend
category: llm
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/virgiliojr94/book-to-skill
  - https://github.com/virgiliojr94/book-to-skill/blob/main/SKILL.md
last_verified: 2026-08-24
related: [backend-common-llm-binding-instructions-for-agents, backend-common-llm-context-window-budget]
---

# Splitting a Large Knowledge Artifact an Agent Loads On Demand

## When this applies

Authoring a skill or reference bundle that packages a large corpus (a book, a
product manual, a domain wiki) for an agent to consult; an always-loaded skill
file has grown past a few thousand tokens; an agent answers narrow questions by
Reading an entire large source file.

## Do this

1. **Two tiers: an always-loaded core and on-demand chunks.** The core file
   carries the mental model plus an index of chunks with per-chunk trigger
   lines (~4K tokens in book-to-skill); each chunk is a separate ~1K-token file
   loaded only when the task matches its trigger. This wiki's
   INDEX → domain index → page routing is the same pattern.
2. **Set the per-chunk token budget from a content-type × usage-depth matrix,
   not one fixed number.** book-to-skill sizes chapters 800–3,000 tokens by
   `BOOK_TYPE` (technical/text) × `DEPTH` (reference/study): reference lookups
   get tight chunks, study material gets room.
3. **Split auxiliary views into their own on-demand files** (glossary,
   patterns, cheatsheet) instead of inflating the core — each serves a
   different retrieval moment, so bundling them forces every load to pay for
   all of them.
4. **Access oversized originals by slicing, not whole-file Read.** For source
   text ≥50K tokens, locate with `grep -n` and read only the matched offsets
   (`sed -n 'A,Bp'`) — book-to-skill states this as a rule (its "REPL-style
   access", citing the Recursive Language Model pattern).

## Edge cases

| Case | Then |
|------|------|
| The whole corpus fits in ~4K tokens | Keep one file — splitting adds load hops with no budget win |
| The artifact is generated from a copyrighted source | Synthesize instead of reproducing long passages, and keep the generated artifact private — book-to-skill's copyright rule: redistributing a skill built from a third-party book can infringe |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Load the full corpus "for background" | Route through the core index and load matched chunks | Unmatched chunks are pure context cost every turn |
| Give every chunk the same fixed budget | Size by the type × depth matrix (step 2) | A reference chunk padded to a study chunk's budget wastes its slot; the reverse truncates |

## Sources

- https://github.com/virgiliojr94/book-to-skill — README "What it generates" (core + chapters + glossary/patterns/cheatsheet token sizes), copyright & fair-use rules
- https://github.com/virgiliojr94/book-to-skill/blob/main/SKILL.md — Step 7 BOOK_TYPE × DEPTH budget matrix; Step 2.6 grep/sed slice access for ≥50K-token originals
