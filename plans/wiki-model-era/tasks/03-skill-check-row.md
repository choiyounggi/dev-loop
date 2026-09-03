# Task 03: Wire the model-era check into wiki-lint's report + score

## Objective
skills/wiki-lint/SKILL.md carries the new re-verification-candidate check
(info severity, check #12), its Phase 0 baseline command, a consistent health
score (`total_weight = 25`), and a fix-protocol rule; the prose pins in
tests/wiki-lint-score.bats are bumped to match and the whole suite is green.

## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: anchor
  inventory on SKILL.md before editing; re-run the pinning suite after and
  compare pass counts.
- wiki/testing/quality/checks-that-cannot-pass.md — use for: keeping the check
  row's wording aligned with the script's real exit contract (report-only,
  distinct exit codes).

## Inputs
- scripts/wiki-lint-model-era.js — from task 01 (the row must name this exact
  path and its real behavior).
- skills/wiki-lint/SKILL.md — Phase 0, Checks table (rows 1-11), Health score
  section, Fix protocol.
- tests/wiki-lint-score.bats — the 5 prose-pin tests.
- Decisions that bind you: D5 (report-only, not CI-blocking), D6 (info
  severity, #12, total_weight 25, pins bumped same task).

## Steps
1. Anchor inventory: `grep -n "total_weight\|three read-only\|10–11\|10-11" tests/wiki-lint-score.bats skills/wiki-lint/SKILL.md` — record hits.
2. SKILL.md Phase 0: add a fourth baseline command bullet:
   `node scripts/wiki-lint-model-era.js wiki` (re-verification candidates).
3. SKILL.md Checks table: add row
   `| 12 | Model-coupled page (body references model/LLM behavior) whose \`verified_model\` is absent or outside the current generation — re-verification candidate, report-only; detected by \`node scripts/wiki-lint-model-era.js\` (override the current set with \`--current\` or \`DEV_LOOP_CURRENT_MODELS\`) | info |`
4. Health score section: info row checks become `10–12`; replace
   `total_weight = 24` with `total_weight = 25` and the formula
   `(4×3 + 5×2 + 2×1)` with `(4×3 + 5×2 + 3×1)`.
5. Fix protocol: add
   `- For 12: report-only — never stamp \`verified_model\` without actually re-verifying the page's directives against a current-generation model; after re-verifying, update \`verified_model\` + \`last_verified\` together, or rewrite/retire the guidance that no longer applies.`
6. tests/wiki-lint-score.bats: bump the `total_weight = 24` assertion to
   `total_weight = 25`; extend the Phase 0 test's final compound with
   `&& [[ "$section" == *"wiki-lint-model-era.js"* ]]` and update its @test
   name from "three" to "four" command families.
7. Re-run the pinning suite and compare pass counts with the pre-edit run
   (5 tests before, 5 after — no silently skipped test).

## Deliverables
- skills/wiki-lint/SKILL.md (modified)
- tests/wiki-lint-score.bats (modified — the declared pin bump)

## Verify
- `bats tests/wiki-lint-score.bats` → rc=0 (5 tests).
- `bats tests/wiki-lint-model-era.bats tests/wiki-lint-prohibitions.bats tests/wiki-structure-checks.bats` → rc=0.
- `git diff --stat .github/ wiki/` → empty (CI wiring and corpus untouched).
- covers: R4, R6
## Out of scope
- Adding the script to .github/workflows/test.yml's blocking step (permanent
  red by design — the check is report-only).
- Editing the script itself (task 01 owns it).
- Retroactively stamping any wiki page.
