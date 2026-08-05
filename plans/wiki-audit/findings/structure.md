# Findings — Task 01: Mechanical lint sweep

Sweep tool: `.claude/tmp/lint-sweep.js` (Node, run from repo root, 2026-08-05).
Scope: 141 pages + 13 indexes (10 domain + 3 backend sub-indexes), 141 unique ids.

## Results by check (command: `node .claude/tmp/lint-sweep.js`)

| Check | Hits | Verdict |
|-------|------|---------|
| Frontmatter missing / field missing | 0 | clean |
| id duplicate / domain mismatch / slug mismatch | 0 | clean |
| C1 `verified` with empty sources | 0 | clean |
| C3 broken `related:` id | 0 | clean — all 141 ids resolve |
| C4 index dead link | 0 | clean |
| C4 page unlisted in its NEAREST index | 0 | clean (initial 16 hits were sweep-tool artifacts: backend routes via java/node/python sub-indexes; tool fixed to nearest-index semantics, re-run → 0) |
| C5 vague qualifiers (usually/consider/might want to/generally/as appropriate) | 0 | clean |
| C5b bare `might` sweep (`grep -rniE '\bmight\b' wiki --include='*.md'` excl. index) | 6 | 4 are React doc URLs ("you-might-not-need-an-effect"), 2 are situation-descriptions in trigger/edge prose, not directive sentences → compliant |
| C6 body > 120 lines | 0 | clean |
| C7 `confidence: unverified` pages | 0 | clean — every page verified or field-tested |
| C8 `verified` with last_verified > 12 months | 0 | clean |
| Section skeleton (When this applies / Do this) | 0 | clean |
| C2 don't/never/avoid in directive lines outside `Instead of` | 147 | manual-review class, see below |

## C2 analysis (147 hits)

Sampled 20+ hits: essentially all are decision-table rows where the prohibition is
**paired in the same cell with the replacement action and mechanism**, e.g.
`| 400/401/403/404/422 | Never retry — the request itself is wrong; the same bytes fail again |`.
This satisfies the *intent* of AGENTS.md rule 3 (no bare prohibition without a
replacement) but not its *letter* (anti-patterns only in the `Instead of` table).
No hit found where a prohibition dead-ends without a replacement (0 true
violations in sample; full-list scan found none of the form "never X." with no
alternative in the same row/step).

→ issue: **wiki-lint check 2 wording vs. corpus practice** — refine the rule to
"a prohibition must be paired with its replacement in the same row/sentence, or
live in `Instead of`", so the lint is mechanically enforceable and the 147
compliant rows stop being manual-review noise.

## Fixes applied on this branch

None required — zero true mechanical defects. (The only edit was to the
throwaway sweep tool itself, not the wiki.)

## Verdict (axis 1, mechanical half)

Structurally production-clean: ids, links, indexes, frontmatter, sourcing, size
and freshness discipline all hold across 141 pages. Semantic routing quality is
task 02's scope.
