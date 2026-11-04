# Knowledge flush — 7 insight(s)

7 queued rows claimed: 7 general insights, 4 new pages, 3 merged into existing pages, 0 dropped. One candidate claim was refuted during verification and corrected (see dad0a142c377a6f1).

This flush reuses the content of an earlier local commit (29a219b, same base `50a3af6`) that never reached GitHub, because the contributor has read-only access to this repo. Every page was reviewed again and four were corrected. The PR comes from the fork `jocenunes/dev-loop` for the same reason.

## Verified best-practice

**9f5c3a177b7d59b1: a markdown code span copied into a gate `CHECK:` line runs as command substitution.**
- Sources: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html (§2.6.3), https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html
- How verified: end-to-end on main `50a3af6`. `plan-gate.sh emit A` kept the backticks in `CHECK:`, and `gate-check.sh --run` recorded `baseline-tests-ran` UNMET with `exit=127`; the bare bullet recorded MET with `exit=0 matched: GATE_OK`. A code span printing `touch <path>` created the file, so the output really is executed.
- Confidence: verified.
- Owner note: `plan-gate.sh` lines 85 and 369 could strip the backticks. That is a skill change, so it is out of scope here.

**dad0a142c377a6f1: non-ASCII object keys fail in Convex at runtime.**
- Sources: https://docs.convex.dev/database/types, https://docs.convex.dev/production/state/limits, convex 1.46.0 and 1.47.0 `dist/esm/values/value.js` (`validateObjectField`).
- How verified: `convexToJson` threw for `16–30`, `preço` and an emoji, and passed `16-30`. Through `convexTest`, on convex 1.46.0 with convex-test 0.0.60 and on 1.47.0 with 0.0.62, `t.query` and `t.mutation` threw the same error, including for a nested key.
- Correction: the candidate said `convex-test` passes. That is false for a test that calls the registered function, so the page now says only helper-level tests miss it.
- Confidence: verified.

**064e6c85d3711615: parallel children patching one parent document exhaust write-conflict retries, and `convex-test` cannot show it.**
- Sources: https://docs.convex.dev/error, https://docs.convex.dev/testing/convex-test, convex-test 0.0.60 `dist/index.js` (`TransactionManager`), @convex-dev/workpool README and 0.4.13 `dist/component/complete.js`.
- How verified: docs give the error text and the data-model remedy. The convex-test source serializes top-level transactions, and a local run of 34 parallel read-and-patch mutations gave 0 rejections and a final count of 34. The docs page does not discuss concurrency, so that claim rests on source and reproduction. The failure on a real deployment is a field report (34 children, 281 mock tests green); it was not reproduced here.
- Correction: the earlier draft advised against throttling, but the Workpool README documents `maxParallelism: 1` as a fix, so it is now a table row. `onComplete` is inline only when `runOnCompleteInline` is set, and the page now says so.
- Confidence: verified.

**fb8f286a0d295bd3: an `apiSpec` timeout from `npx convex run` hides "Could not find function".**
- Sources: convex 1.46.0 `dist/esm/cli/lib/run.js` lines 52-56.
- How verified: source read: within `convex run`, `apiSpec` is queried only inside the `Could not find function` branch. The 1 s timeout is a field observation; no string for it exists in the npm package, so it comes from the server.
- Confidence: verified for the mechanism.

**ef1f9fc35666da7f: a target guard must resolve the environment in the CLI's own order.**
- Sources: https://docs.convex.dev/cli/reference/deploy, https://docs.convex.dev/production/project-configuration, convex 1.46.0 `dist/esm/cli/lib/deploymentSelection.js` lines 84-85 and `command.js`, `npx convex deploy --help`.
- How verified: source read plus a local dotenv 17.3.1 run: the same two `config` calls gave the file's value when unset and kept `dev:exported` when exported. `--help` confirms the production default and the `--dry-run` wording.
- Correction: added the flags that override the environment (`--prod`, `--deployment`, `--deployment-name`, `--preview-name`, `--url`, `--admin-key`), which the candidate and the earlier draft omitted.
- Confidence: verified.

**9e1f0d72258b768a: prove "identical to main" by running the base commit's code against the committed snapshots.**
- Sources: https://git-scm.com/docs/git-archive, https://jestjs.io/docs/cli (`--ci`), https://vitest.dev/guide/snapshot.
- How verified: the tools' behaviour is documented, and Vitest was added beside Jest. The method itself comes from one field review (3 of 3 green, checksums unchanged).
- Confidence: field-tested for the method.

**b68aa8912bbe777d: three Templater toggles live in device local storage, not `data.json`.**
- Sources: https://raw.githubusercontent.com/SilentVoid13/Templater/master/src/settings/LocalSettings.ts, https://raw.githubusercontent.com/SilentVoid13/Templater/master/src/settings/Settings.ts, https://raw.githubusercontent.com/SilentVoid13/Templater/master/src/main.ts, https://raw.githubusercontent.com/obsidianmd/obsidian-api/master/obsidian.d.ts
- How verified: read current source on master, which matches the installed 2.26.0. `test/specs/migration.e2e.ts` asserts these keys are not migrated.
- Correction: added the reset notice for old `data.json` values, and the vault scope of `App.loadLocalStorage`.
- Confidence: verified.

All 13 cited URLs returned HTTP 200 on 2026-11-04.

## Existing-layer check

Pages read: infrastructure-agent-orchestration-gate-evidence-exit-code-class, testing-quality-key-order-in-serialized-goldens, testing-quality-value-preserving-refactor-assertions, testing-quality-stale-artifact-baselines, debugging-signals-reading-error-messages, databases-transactions-optimistic-vs-pessimistic-locking

- `wiki_search` ran on all 7 triggers. Top hits considered: 9f5c → `qa-process-completion-claims`, `platforms-shells-heredoc-body-expansion-with-backtick-prose`, `infrastructure-agent-orchestration-gate-evidence-exit-code-class`, `platforms-shells-command-text-inspected-before-execution`. 9e1f → `testing-quality-key-order-in-serialized-goldens`, `testing-quality-behavior-not-implementation`. The Convex, guard and Templater triggers returned only unrelated pages (best scores about 0.75).
- `grep -i convex` and `grep -i 'obsidian|templater'` over `wiki/` returned nothing on main.
- Merged: 9f5c into `gate-evidence-exit-code-class` (new step, edge rows, sources); fb8f into `reading-error-messages` (edge row, source); 9e1f into `stale-artifact-baselines` (edge row, sources).
- Created: the four pages listed under Routing decision.
- Conflicts: none flagged. The docs/code gap on ASCII field names is recorded as an edge row.
- `related:` links added both ways: `backend-node-boundaries-runtime-validation`, `databases-transactions-optimistic-vs-pessimistic-locking`, `infrastructure-config-environment-config`, `backend-node-runtime-env-files-with-process-loadenvfile`.
- Checks: `node scripts/wiki-structure-checks.js wiki` reports 472 pages, 0 findings; `wiki-lint-prohibitions.js` reports 0 violations.

## Open-PR check

Listed 22 open `knowledge/*` heads: #293, #298-#301, #304-#310, #315, #317-#319, #324, #328-#332. Diffed the 19 same-repo heads through `origin/<head>`, and the 3 fork heads (#298, #299, #300) through `pull/<n>/head`, for Convex, Templater, Obsidian, `git archive`, workpool, `.env`, backtick, snapshot and command substitution. A title and body search for Convex or Templater returned nothing.

- All 7 candidates: **new**. Keyword hits in #299, #309, #317 and #329 are unrelated uses of "snapshot" or "command substitution".
- Adjacent, not duplicate: #301 covers UTF-8 byte bounds for client JSON keys, which is a different trigger from Convex field names. #300 edits `environment-config.md`, which this PR touches only in `related:`, so a trivial merge conflict is possible.

## Routing decision

| Insight | Target | Action |
|---------|--------|--------|
| 9f5c3a177b7d59b1 | infrastructure/agent-orchestration/gate-evidence-exit-code-class | merge |
| dad0a142c377a6f1 | backend/node/convex/ascii-keys-in-returned-objects | new page |
| 064e6c85d3711615 | backend/node/convex/parallel-children-writing-one-parent-document | new page |
| fb8f286a0d295bd3 | debugging/signals/reading-error-messages | merge |
| ef1f9fc35666da7f | infrastructure/deploy/effective-target-guard-for-a-deploy-cli | new page |
| 9e1f0d72258b768a | testing/quality/stale-artifact-baselines | merge |
| b68aa8912bbe777d | platforms/tools/templater-device-local-settings | new page |

New category `backend/node/convex`: no existing node category (runtime, async, boundaries, language) fits a hosted backend's value rules and transaction model, and two pages share it.

## Local-layer candidates

none

🤖 Generated with [Claude Code](https://claude.com/claude-code)
