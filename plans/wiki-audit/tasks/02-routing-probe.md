# Task 02: Semantic routing probe — 15 implementation scenarios

## Objective
`plans/wiki-audit/findings/routing.md` containing 15 probe scenarios (one per
domain + 3 two-domain/cross-domain + 2 deliberately out-of-charter), each traced
INDEX.md → domain index → page, with verdict UNIQUE / AMBIGUOUS / MISS and, for
each non-UNIQUE probe, which index line or trigger wording caused it.

## Wiki pages (read these first, only these)
- (none — the wiki itself is the audit object; the routing protocol under test is
  AGENTS.md "Routing protocol" steps 1–6)

## Inputs
- plans/wiki-audit/findings/structure.md (task 01 — inventory of pages per domain)
- INDEX.md, all 10 wiki/<domain>/index.md files
- Decisions that bind you: D2 (probe method + verdict definitions), D4 (findings routing)

## Steps
1. Author the 15 probes as realistic first-person implementation intents (e.g.
   "add cursor pagination to a listing endpoint", "my session cookie works locally
   but not in prod", "schedule a nightly cleanup job on a VM"). Cover all 10
   domains; 3 probes must legitimately touch ≥2 domains; 2 probes must be
   out-of-charter (e.g. "write a game shader") to test that routing FAILS cleanly
   (MISS is the correct verdict there — record whether the reader can tell).
2. For each probe, quote the exact "route here when" / "load when" text that
   matched or tied; verdict + cause for AMBIGUOUS/MISS.
3. Summarize: routing precision (UNIQUE / applicable probes), the specific index
   lines needing rewording, and pages whose "When this applies" contradicts their
   index line (AGENTS.md drift).

## Deliverables
- plans/wiki-audit/findings/routing.md

## Verify
- findings/routing.md has exactly 15 probes, every one carries a verdict and a
  quoted matched line; `grep -c '^### Probe' plans/wiki-audit/findings/routing.md` → 15.

## Out of scope
- Fixing index wording (fold into task 06 issue list or task 01-style direct fix
  only if the reword is purely mechanical); category gaps (task 03).
