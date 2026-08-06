# Task 03: SKILL + auto-flush prompt aligned to the new gate contract

## Objective
skills/knowledge-flush/SKILL.md documents the 4-section report (Open-PR check),
the open-PR dedup step (2b′), the `Pages read:` requirement, and empty-session-
file deletion in step 5; hooks/auto-flush.sh PROMPT names the same contract and
forbids `--body`.

## Wiki pages (read these first, only these)
- wiki/platforms/shells/command-text-inspected-before-execution.md — the
  body-file/literal-path constraints the prompt must keep honoring

## Inputs
- skills/knowledge-flush/SKILL.md (sites: step 2b, step 3 report template,
  step 5, guardrails), hooks/auto-flush.sh (PROMPT= line)
- Decisions: D1, D2, D5, D7

## Steps
1. SKILL step 2b′ (after 2b): list open knowledge/* PR heads; per candidate diff
   against them; verdict fold/drop/new; record in `## Open-PR check`.
2. Step 3 template: add `## Open-PR check` section + `Pages read:` line inside
   Existing-layer check with format note.
3. Step 5: delete the session file when the rewrite leaves it empty.
4. auto-flush.sh PROMPT: add the open-PR dedup + 4-section report + `--body-file`
   with a literal path (never `--body`).

## Deliverables
- skills/knowledge-flush/SKILL.md, hooks/auto-flush.sh

## Verify
- bats tests/ (gate + harvest suites) still green; `grep -c 'Open-PR check'
  skills/knowledge-flush/SKILL.md` ≥ 2 (step + template); PROMPT mentions
  body-file and Open-PR.

## Out of scope
- Any wiki page edits; gate/harvest code (tasks 01/02).
