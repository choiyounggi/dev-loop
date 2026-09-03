# Task 02: Document the verified_model field in the schema layer

## Objective
AGENTS.md's frontmatter schema and templates/page.md both document the optional
`verified_model` field, and the live corpus still passes structure checks
unchanged.

## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for:
  inventorying grep/test anchors on AGENTS.md and templates/page.md BEFORE
  editing, and re-running the gate set after.

## Inputs
- AGENTS.md — the `### Frontmatter` section (yaml block around lines 116-134
  at HEAD 300e4be) and the `confidence` meanings paragraph after it.
- templates/page.md — the frontmatter block (lines 1-11).
- Decisions that bind you: D2 (field name/format/optionality), D8 (AGENTS.md is
  the schema authority; template carries a YAML comment line).

## Steps
1. Anchor inventory (record the outputs): `grep -rn "last_verified" tests/`
   and `grep -rln "templates/page.md\|### Frontmatter" tests/ hooks/ scripts/`
   — confirm no test pins the yaml block's exact line count or content; if a
   pin exists, STOP and report BLOCKED (plan defect) rather than editing
   around it.
2. In AGENTS.md's `### Frontmatter` yaml block, add after the
   `last_verified: YYYY-MM-DD` line:
   `verified_model: <model-id>            # optional`
3. After the `confidence` meanings paragraph, add one sentence:
   "`verified_model` (optional) names the model generation the page's guidance
   was verified against (e.g. `claude-fable-5`); model-coupled pages missing
   it, or carrying an outdated one, are surfaced by lint as re-verification
   candidates — see `scripts/wiki-lint-model-era.js`."
4. In templates/page.md, add after the `last_verified: YYYY-MM-DD` line:
   `# optional: verified_model: <model-id the guidance was verified against>`
5. Re-run the gates the inventory found plus the structure baseline.

## Deliverables
- AGENTS.md (modified: frontmatter block + one sentence)
- templates/page.md (modified: one comment line)

## Verify
- `grep -c verified_model AGENTS.md` → 2; `grep -c verified_model templates/page.md` → 1.
- `node scripts/wiki-structure-checks.js wiki` → exit 0 (live corpus
  untouched, no new required key enforced).
- `bats tests/wiki-agent-gate.bats` → rc=0 (nearest AGENTS.md-adjacent suite
  still green).
- covers: R1
## Out of scope
- Editing any wiki/ page to add the field (retroactive stamping is explicitly
  out of the feature's scope).
- scripts/wiki-structure-checks.js REQUIRED_KEYS (must stay 8 keys).
- skills/wiki-lint/SKILL.md (task 03).
