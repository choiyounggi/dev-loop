# Knowledge flush — 1 insight(s)

A review's "also assert X" fix that edits an existing test block can delete the assertion other mutants depended on, and re-running only the named mutant hides that. **1 page amended (new step 6), 0 new pages, 1 back-link. 7 plan-gaps retired as local-layer, 0 dropped.**

Claimed 8 queue rows (run `20261008-124951-26572`): 1 harvested ★ Insight (`4614be6ce89cc5c5`) and 7 wiki-plan `[no-wiki]` plan-gap rows from linkly task t216.

## Verified best-practice

**`4614be6ce89cc5c5` — keep the block's assertions, then re-run every mutant it covers** (confidence: **verified**)

Claim: when a review's "also assert X" fix lands in an existing test block, put the new assertion beside the block's existing ones (a different input or environment gets its own case), diff the block's assertion lines before and after, and re-run every mutant the block covers, comparing each verdict with the pre-edit run. Re-running only the named mutant cannot see the mutants that an assertion removed by the edit used to kill.

Sources — each quote compared character-for-character against the raw page with `curl` + `/usr/bin/grep` on 2026-10-08:

- https://stryker-mutator.io/docs/stryker-js/incremental/ (raw source: `docs/incremental.md` in stryker-js) — "Reuse is possible when: A mutant was "Killed"; the culprit test still exists, and it didn't change." The runner table decides whether a test edit is seen at all: Jest, Vitest, CucumberJS "Full"; Mocha, Tap "Stryker assumes all tests inside a file changed when that file changed"; Jasmine, Karma "Stryker will only see test changes for tests that are added or removed"; Command "will only detect changes in mutants, not their tests"; "Static mutants don't have test coverage; thus, Stryker won't detect test changes for them"; `--force` reruns "all mutants in scope, regardless of the incremental file".
- https://pitest.org/quickstart/incremental_analysis/ — "If a mutation was killed in the last run and neither the class under test or the killing test has changed, then it can be assumed that this mutation is still killed."; for a changed killing test, "it is likely that the last killing test will still kill it and it should therefore be prioritised above others."

Both tools keep a "Killed" verdict only while its killing test is unchanged. Step 6 applies that rule by hand, and the new edge row covers the Stryker runners that cannot see an in-place edit.

Local reproduction (Node 26.7.0, `node:test`; one fresh directory per test variant × mutant; each `sed` mutation checked as applied with `cmp`):

| Test block | Unmutated | N0 no-op control | N1 `'debug'`→`'info'` | N2 `42`→`0` | A21 `=== 'production'`→`=== 'prod'` (named mutant) |
|---|---|---|---|---|---|
| Before the fix | pass | survived | killed | killed | survived |
| Fix that rewrites the block for `'production'` | pass | survived | **survived** | **survived** | killed |
| Fix that adds the `'production'` assertions beside the old ones | pass | survived | killed | killed | killed |

The before/after assertion-line diff named both lines the rewrite removed (`assert.equal(c.logLevel, 'debug')`, `assert.equal(c.seed, 42)`) and none for the additive fix. The scratch directory was deleted after the run.

Field evidence (originating session, linkly-invitation task t2 Task 06 attempt 4; not re-run here): swapping the block's `NODE_ENV=test` assertion for a production one killed A9 and A21 while N1–N3 survived with 4/4 tests passing; re-adding the two removed lines killed them.

**7 plan-gap rows (t216)** — not researched as general practice: every directive names linkly's own modules (`impl/lnpl/lower.py`, `spec._check_given`, the `CODES`/`SEVERITY_OF`/`HINTS` registry, RFC numbering), so all seven fail the layer test. No confidence is claimed for them.

## Existing-layer check

Route: `INDEX.md` → testing ("cases/assertions", "verifying tests can actually fail") → `wiki/testing/index.md` → quality; qa ("acting on code-review feedback") checked as well.

Pages read: testing-quality-surviving-mutant-equivalence-triage, testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, testing-quality-mutation-harness-file-custody, qa-process-evaluating-review-feedback, testing-quality-policy-at-several-return-sites, testing-mocking-captured-call-arguments, testing-quality-minimum-case-set, testing-quality-expectation-sets-with-one-distinct-value, backend-common-errors-diagnostics-from-a-shared-code-path

- `wiki_search` (k=5) on the candidate's trigger: policy-at-several-return-sites 0.768, surviving-mutant-equivalence-triage 0.763 and 0.725, captured-call-arguments 0.737, minimum-case-set 0.735. Only surviving-mutant-equivalence-triage shares the trigger — its "When this applies" already names "a reviewer asks for a test to cover a specific surviving mutant".
- Whole-wiki search (`/usr/bin/grep` over every page): 46 pages mention mutants; none covers an edit that removes an assertion other mutants depended on. Three pages direct re-running the targeted mutant after adding a case or assertion (tests-that-cannot-fail, expectation-sets-with-one-distinct-value, policy-at-several-return-sites); none of them covers an edit that removes an existing assertion, so step 6 extends them and contradicts none. They are left unchanged to keep this diff small.
- **Merged, not created**: surviving-mutant-equivalence-triage gains step 6 with a verdict table, 4 edge rows (Stryker incremental reuse by runner, a hand-rolled mutation script, a deliberate replacement, a survivor whose kill does not reproduce on the pre-edit block), 1 Instead-of row, 4 Sources lines, a "When this applies" clause and a step-1 pointer. Body: 115 lines (117 once #226 merges; limit 120 — the next addition to this page needs a split).
- Related: added testing-quality-mutation-harness-file-custody (its step 6, "re-run the whole matrix" after a custody fix, is the same principle; it already links back, so the link is now two-way). The evaluating-review-feedback ↔ this-page link is already in open PR #226 and is not duplicated here.
- Conflicts with existing directives: none flagged.
- `wiki/testing/index.md`: the page's "load when" row now names the new use case (maintenance invariant 1).
- `last_verified` stays 2026-08-07: open PR #226 bumps that exact line, and a second bump would add a merge conflict; the new claims carry dated sources.
- Checks on this branch: `node scripts/wiki-structure-checks.js wiki` → `pages: 359, indexes: 13, findings: 0`; `node scripts/wiki-lint-prohibitions.js wiki` → `violations: 0` (1 pre-existing info line, in infrastructure/config/keys-ahead-of-their-consumer.md); no banned vague qualifier in any added line.

## Open-PR check

26 open `knowledge/*` heads (#223, #225–#231, #233–#239, #241, #244, #249, #253–#260), listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`. For each head, the added lines of `git diff origin/main...origin/<head> -- wiki/` were scanned for the candidate's concepts (removed or replaced assertions, re-running all mutants, reviewer/auditor fixes, "also assert"), and every added line mentioning mutants was read.

| Candidate | Overlapping open PR | Verdict |
|---|---|---|
| 4614be6ce89cc5c5 | None carries it. #226 edits the same page for a different situation (a survivor reported inside a PASS audit); #258 (additive mutants vs presence checks) and #259 (schema key coverage) are different situations | **new** |
| 7 × t216 plan-gaps | No open PR body mentions t216 (all 26 bodies searched) | **new** → local layer |

Merge check (`git merge-tree --write-tree`, this branch against each head): no wiki page conflicts, including #226, whose four hunks on the shared page were avoided. Every head conflicts on `log.md` and the older ones also on this report file — the same two files the open PRs already conflict on with each other (#260 vs #259 and #255 vs #254 checked).

## Routing decision

| Candidate | Layer | Target | Action |
|---|---|---|---|
| 4614be6ce89cc5c5 | bundled | `testing/quality/surviving-mutant-equivalence-triage.md` | merged as step 6 |
| 7 × t216 plan-gaps | local (linkly) | see Local-layer candidates | excluded from this PR, retired from the queue |

No new category: testing/quality already holds the mutation-testing pages, and the target page's trigger covers this situation.

## Independent review

A fresh-context adversarial reviewer (a separate subagent, read-only on this checkout) re-fetched both sources, rebuilt the reproduction from its description (same matrix observed on Node 26.7.0) and re-ran both lint scripts. Verdict: CHANGES_REQUESTED, resolved before this PR:

| Finding | Resolution |
|---|---|
| Step 6 said a "Killed" result is reused "only while its killing test is unchanged", dropping conditions both tools state (Stryker: the culprit test still exists; PIT: the class under test is unchanged too) | Fixed: "With the source untouched, PIT and Stryker apply the same rule: they reuse a "Killed" result only while its killing test still exists unchanged." |
| The log line understated #226's overlap — it also edits this page's related list, Edge table and Sources, so merging it would need reconciliation in four places | Checked and not reproduced: `git merge-tree --write-tree` of this branch with #226 conflicts only in `log.md` and this report file, and the merged page carries 0 conflict markers. The log line now names #226's other three hunks and records that they merge cleanly |
| Gap: a flaky mutant reads as lost coverage in step 6's table | Added an edge row: when a previously killed mutant survives while the assertion diff shows nothing removed, re-run it against the pre-edit block first; surviving there too marks a flaky verdict (testing-flaky-diagnosing-flaky-tests) |

Kept: the reviewer's routing note (step 6's hygiene theme also sits near tests-that-cannot-fail) — the merge target stays, because this page's trigger already owns "a reviewer asks for a test to cover a specific surviving mutant" and the step-1 table now points into step 6.

## Local-layer candidates

| Row | Project | Target |
|---|---|---|
| Planning t216: deciding Where the check runs | linkly (linkly-dartfish worktree) | wiki-local/backend/common/errors/t216-spec-result-reads-input-check-site.md — run wiki-ingest inside that project |
| Planning t216: deciding Which names an expect line asserts on | linkly (linkly-dartfish worktree) | wiki-local/testing/quality/t216-expect-result-candidate-names.md — run wiki-ingest inside that project |
| Planning t216: deciding Condition (a): the bare name is a respond field | linkly (linkly-dartfish worktree) | wiki-local/testing/quality/t216-respond-field-condition.md — run wiki-ingest inside that project |
| Planning t216: deciding Condition (b): a same-name respond term wins | linkly (linkly-dartfish worktree) | wiki-local/testing/quality/t216-respond-term-precedence.md — run wiki-ingest inside that project |
| Planning t216: deciding Condition (c): given did not set the input | linkly (linkly-dartfish worktree) | wiki-local/testing/quality/t216-given-setter-suppression.md — run wiki-ingest inside that project |
| Planning t216: deciding Severity, registry position, hint | linkly (linkly-dartfish worktree) | wiki-local/backend/common/errors/t216-diagnostic-code-registration.md — run wiki-ingest inside that project |
| Planning t216: deciding RFC | linkly (linkly-dartfish worktree) | wiki-local/qa/document-verification/t216-no-rfc-for-warning-only-code.md — run wiki-ingest inside that project |

All seven are wiki-plan Phase B decisions naming linkly's own modules; they are excluded from this PR and retired from the queue.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
