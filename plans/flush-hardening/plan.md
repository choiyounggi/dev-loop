# flush-hardening — close the dedup/bypass gaps tracked in #39

Goal: knowledge-flush must provably dedup against OPEN sibling PRs (not only
merged main), its INGEST_REPORT evidence must be machine-checkable (page ids
verifiable — the class of fabrication caught during the #17–#40 consolidation),
the gate's detection window must narrow, and harvest gets a runaway backstop +
empty-file cleanup. Acceptance: new bats tests red-first then green; full suite
green; SKILL/gate/prompt describe one consistent contract.

Stack: POSIX sh (hooks), Node CommonJS (harvest.js), bats, Markdown skill.
Baseline: main after #45 (7679241 lineage), clean tree, branch fix/flush-hardening.

## Decisions

| # | Decision | Choice | Wiki basis |
|---|----------|--------|------------|
| D1 | Open-PR dedup contract | New 4th REQUIRED section `## Open-PR check` in INGEST_REPORT: SKILL step 2b′ instructs `gh pr list --repo choiyounggi/dev-loop --state open --json headRefName --search "head:knowledge/"` then per-candidate diff vs those heads; verdicts: fold-into-existing-PR-branch / drop-as-pending-duplicate / new. Gate requires the header (same mechanism as the existing 3) | qa-document-verification-spec-document-gates (gates assert structure); evidence: two real dup incidents (#39 comments) |
| D2 | Machine-checkable evidence | Existing-layer check MUST contain a line `Pages read: <id>[, <id>…]` (≥1). Gate extracts ids (`[a-z0-9-]+`), resolves the wiki root as `<dirname(body-file)>/../wiki` (the report lives inside the flush checkout), and verifies each id via `grep -rq "^id: <id>$"`. Wiki root absent → skip id verification (global-install-safe, fail-open for THIS subcheck only); 0 ids parsed → deny | platforms-shells-command-text-inspected-before-execution step 8 (gate-author parsing rules); testing-quality-checks-that-cannot-pass (distinct outcomes: missing line vs unresolvable id vs no wiki) |
| D3 | Detection tightening | IS_FLUSH also fires on `--title` value containing `knowledge:` (quoted or not). Residual bypass (no markers at all) stays documented — text-only detection cannot close it | platforms-shells-command-text-inspected-before-execution (text-scoped gates match text, not intent) |
| D4 | Harvest runaway backstop | Cap the session queue file at 10 pending rows total (instruction stays 0–3; cap is a backstop, not policy). Append only up to the remaining budget, silently — consistent with harvest's never-surface-errors ethos | `[no-wiki]` — #39 item 3; magnitude chosen as >3 (no knowledge loss for legit sessions) and ≪ dozens (runaway) |
| D5 | Empty-file cleanup | harvest.js: when the session queue file exists with 0 non-blank lines and there is nothing to append, unlink it. SKILL step 5: after rewriting the session file, delete it when empty. No cross-session sweeps (single-writer per file) | `[no-wiki]` — #39 item 4; single-writer per harvest-dedupe plan D4 |
| D6 | Test discipline | Each new behavior gets a red-first bats case (observed failing on the pre-change code); assertions on observable outcomes (exit code + named section in stderr, queue line counts); per-test $HOME/tmp isolation | testing-quality-minimum-case-set; testing-quality-tests-that-cannot-fail; testing-data-test-data-and-isolation |
| D7 | Auto-flush prompt alignment | PROMPT adds: check open knowledge PRs for duplicates (amend that branch or drop), write the 4-section INGEST_REPORT incl. `Pages read:`, and always use `--body-file` with a literal path (never `--body`) | `[no-wiki]` — prompt must match the gate contract it triggers |

## Task order

| Task | Depends on | Parallel-ok |
|------|-----------|-------------|
| 01-harvest-cap-and-cleanup | — | parallel-ok with 02 |
| 02-gate-4th-section-pages-read-title-marker | — | parallel-ok with 01 |
| 03-skill-and-prompt-contract | 02 (contract fixed there) | — |
