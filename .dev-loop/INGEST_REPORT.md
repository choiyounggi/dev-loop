# Knowledge flush — 8 insight(s)

Claimed 10 queue rows (run `20261009-222550-75928`): 8 harvested ★ Insights and 2 wiki-plan plan-gap rows (linkly-invitation t6).

- **5 new pages:**
  - `backend-common-integrations-wrapping-quotes-in-a-frontmatter-value`
  - `infrastructure-ci-cd-chaining-workflows-past-a-github-token-event`
  - `qa-process-blind-llm-judgment-of-a-visual-rule`
  - `platforms-tools-search-evidence-from-a-wrapped-grep`
  - `infrastructure-agent-orchestration-review-diff-base-after-a-sibling-merge`
- **4 amended pages:** `platforms-tools-per-call-subagent-effort` (step 5), `qa-process-scope-purity-checks` (Do #3), `backend-common-change-impact-corpus-sweep-before-a-rejection-rule` (edge row) and `infrastructure-ci-cd-workflow-authored-pull-requests` (revised for a GitHub docs change).
- **2 plan-gap rows** retired as local-layer.

**Recovered work.** A flush on 2026-10-08 13:57 wrote drafts for 4 of these candidates (grep wrapper, diff base, gate token, effort floor) and died before committing. Its staged diff was saved to a patch and re-applied on top of current `main`. The 9 files that conflicted were each a one-line insertion (`related:` id, index phrase, log line), and each was re-inserted by hand. Every claim and URL in the drafts was then re-checked (see below).

The draft said the effort-floor insight had been pushed to #241's branch. It never was: no ref contains it, and #241 merged without it. So it is ingested here.

## Verified best-practice

### 1. Search evidence from Claude Code's wrapped `grep` (`1ded49b00eff54c6`)

- **Claim:** in Claude Code's Bash tool, `grep` is a function that runs the bundled ugrep with `--ignore-files`. A recursive search skips gitignored files, and a pattern too complex for ugrep exits 2 with empty stdout. Evidence searches use `/usr/bin/grep -r` or `git grep` and check the exit status.
- **Sources:** code.claude.com `tools-reference`, Claude Code CHANGELOG 2.1.117, anthropics/claude-code#69736 (open), Genivia/ugrep PR #556, POSIX `grep` and `command`.
- **How verified:**
  - An independent agent re-fetched every URL (all HTTP 200) and matched each quote.
  - It re-ran the probe this session: `type grep` gave a shell function, and in a dir whose `.gitignore` lists `hidden.txt` the wrapper listed only `shown.txt` while `/usr/bin/grep -rl` listed both.
- **Fixes made this run:**
  - The #69736 title had been quoted without its last words; the full title is now quoted.
  - The page said no setting turns the function off. It now adds the maintainer comment of 2026-08-17 on #69736: naming the tools (`--allowedTools Grep,Glob`) brings them back and stops the shadowing.
  - The "every file" row now passes `--exclude-dir=.git -I`, so `/usr/bin/grep` skips the same `.git/` and binary files the wrapper skips.
- **Confidence:** verified.

### 2. Diff base for reviewing a parallel task after a sibling merged (`d32b7f2d828fa120`)

- **Claim:** review a task's worktree with `git diff --merge-base <integ>`, not the integration tip.
- **Sources:** git-scm pages for `git-diff` (`--merge-base`; present in 2.30.0, absent in 2.29.0), `git-merge-tree`, `git-merge` and `git-worktree`, plus RelNotes 2.38.0. Every quote was re-matched.
- **How verified:** re-run on git 2.50.1. `git diff integ` showed the sibling's `sib.txt` as deleted, while `git diff --merge-base integ` showed only the task's own file.
- **Confidence:** verified.

### 3. A multi-condition gate's pass token (`1a7d6c33f7409531`)

- **Claim:** the pass token must depend on every condition, and the control must feed the bad input into that same gate.
- **Sources:** GNU Bash manual, *Lists*. Its three quotes were re-matched.
- **How verified:** the 2026-10-08 local reproduction. The chained one-liner printed the violating path and `SCOPE_OK` with exit 0; the single script printed `bad=[src/styles/x.css]` with exit 1.
- **Fixes made this run:**
  - The new row cited `portable-shell-scripts`, which does not support it; it now points at the Bash manual.
  - An existing `git-status` quote on the same page was corrected from "Shows" to "Show".
- **Confidence:** verified.

### 4. Paths that bypass an effort/model floor (`dfcdfaaba94e1bad`)

- **Claim:** a floor written in agent frontmatter has three bypass paths:
  - the variant generator's step-down rule;
  - `CLAUDE_CODE_EFFORT_LEVEL` on the parent session;
  - a 429/overload retry list (or `fallbackModel`) that names a cheaper model.
- **Sources:** code.claude.com raw `.md` pages, all re-fetched 2026-10-09:
  - `env-vars`: "Takes precedence over `--effort`, `/effort`, and the `modelSettings` and `effortLevel` settings";
  - `sub-agents` `effort` row: "Overrides the session effort level, but not the `CLAUDE_CODE_EFFORT_LEVEL` environment variable". The wording on `main` was older and has been updated;
  - `settings-reference#fallbackmodel`.
- **How verified:**
  - dev-loop PR #262 (`5c9bddb`): read `VARIANTS` and the "never below high" rule in `scripts/gen-agent-tier-variants.sh`, and the "whichever of `opus` and `fable` the 429 does not name … never below Opus" text in `skills/orchestrate/SKILL.md` and `agents/*.md`.
  - Reproduced in a scratch clone: `tests/agent-model-pin.bats` plus `tests/agent-tier-variants.bats` gave 21 ok / 0 not ok on `main`. With `task-reviewer:medium` regenerated, test 5 "meets the opus-5.5-high floor" failed (rc 1).
- **Correction to the candidate:** its "429 fallback chain" is a hand-written retry rule. Claude Code's `fallbackModel` is a separate list, so the page names both.
- **Confidence:** verified.

### 5. Removing wrapping quotes from a frontmatter value (`b81d88806614c826`, Korean)

- **Claim:** `replace(/^["']|["']$/g, "")` strips each end on its own, so a value quoted at only one end keeps an unpaired quote. Read the value with a YAML parser, or strip a matching pair only.
- **Sources:**
  - YAML 1.2.2 §7.3.3: "Plain scalars must not begin with most indicators"; §7.3.2 and §7.3.1 on escapes.
  - gray-matter README: it uses js-yaml by default.
- **How verified:** Node 26.7.0, PyYAML 6.0.3 and js-yaml 5.4.3 on nine values. I re-ran the key cells myself.
- **Extensions beyond the candidate:**
  - The candidate's own example, `title: "인용구" — 부제`, is invalid YAML: both parsers raise an error, so the page says to fix the source.
  - The paired regex still mis-strips `"a" and "b"`.
  - A trailing `# comment` defeats the paired regex.
- **Confidence:** verified.

### 6. A Release made with `GITHUB_TOKEN` must start another workflow (`c82505cfaeffcc30`)

- **Claim:** events created with `GITHUB_TOKEN` start no new workflow runs. Chain by a same-workflow job or `workflow_call`, by explicit dispatch, or with an App token or PAT.
- **Sources (raw pages fetched 2026-10-09 and grepped):**
  - docs.github.com `concepts/security/github_token`;
  - `reusable-workflows`;
  - the REST `create-a-workflow-dispatch-event` page: fine-grained "'Actions' repository permissions (write)";
  - `events-that-trigger-workflows`: the `workflow_run` three-level limit, and the default-branch note on `workflow_run`, `workflow_dispatch` and `repository_dispatch`;
  - the release-please-action README.
- **Correction found:** the token page now lists a second exception that the candidate and an existing page both missed. A PR opened or updated with the token gets `pull_request` runs "in an approval-required state".
  - `workflow-authored-pull-requests` was revised for this; the log records it as `revise`.
  - Its directive is unchanged (use a PAT or App token). Its 2026-08-25 field record of zero check runs is kept.
- **Not covered by the docs:** whether `workflow_run` fires after a `GITHUB_TOKEN` event. The page says to prove it with one run.
- **Confidence:** verified.

### 7. Blind LLM judgment of a measurable visual rule (`11d73c443f7a0fdf`, Korean)

- **Claim:**
  - brief the judge blind;
  - ask for reasoning before the verdict;
  - read every pair line;
  - use three judges and fail any split;
  - set per-cue and whole-image thresholds.
- **Sources:**
  - Sharma et al. 2023, arXiv 2310.13548 §3.3: "The user suggesting an incorrect answer can reduce accuracy by up to 27%";
  - Anthropic `develop-tests`: "Use a grader model with thinking on, so that it reasons before it produces an evaluation score";
  - Zheng et al. 2023, arXiv 2306.05685 (judge biases);
  - Verga et al. 2024, arXiv 2404.18796 (a panel of judges);
  - Turpin et al. 2023, arXiv 2305.04388 (stated reasoning can be unfaithful).
  - Each quote was grepped in the fetched abstract or full text.
- **Not sourced:** "read every line" (step 3) and the per-cue overstatement (step 5, 76 vs 39 cells) are field-only. No general source was found for step 5.
- **Confidence:** field-tested.

### 8. Measure a received rule on the named failures before implementing (`5ab0888e4a52c7e6`, Korean)

- **Claim:** score a new rule on the pairs the judges named before implementing it. As worded, the rule would have passed 5 of 6 named pairs.
- **Sources:** this is the existing page's method (eslint-remote-tester, clippy lintcheck, crater). The new row adds field evidence only.
- **Confidence:** the page stays `verified`; the new row is field evidence.

## Existing-layer check

Pages read: infrastructure-ci-cd-workflow-authored-pull-requests, backend-common-change-impact-corpus-sweep-before-a-rejection-rule, platforms-tools-per-call-subagent-effort, qa-process-llm-review-pipelines, qa-process-fresh-context-code-review, testing-quality-anchor-cases-for-allowlist-regexes, qa-process-scope-purity-checks, platforms-tools-search-evidence-from-a-wrapped-grep, platforms-environment-path-resolution, platforms-tools-harness-mediated-tool-results, debugging-methodology-reproduce-first, testing-quality-checks-that-cannot-pass, platforms-shells-portable-shell-scripts, infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge, infrastructure-agent-orchestration-ours-resolution-on-a-mixed-content-conflict, infrastructure-agent-orchestration-worktree-isolated-workers

- **Searches run:**
  - Keyword search over all of `wiki/` with `/usr/bin/grep -rliE` for `GITHUB_TOKEN`, `repository_dispatch`, `workflow_run`, `frontmatter`, quote stripping, `blind`, `judge`, `perceptual`, `calibrat`, `EFFORT_LEVEL` and `fallbackModel`.
  - `wiki_search` (k=5) on each new trigger.
- **The last seven ids above were read by the 2026-10-08 run that drafted candidates 1–3.** This run re-checked only their `related:` lines and the drafts' claims.
- **Per candidate:**
  - **1, 2, 3:** see the draft's original check. No new overlap appeared on `main` since then: the 27 PRs it compared against are now merged, and none adds a page on grep wrappers, review diff bases or gate tokens.
  - **4:** `per-call-subagent-effort` already covered bypass path 2 as an edge row. Same trigger, compatible directive → merged as step 5 plus one `Instead of` row.
  - **5:** no page on frontmatter quote handling. The nearest hits were shell quoting pages (`portable-shell-scripts`, `escapes-in-shell-string-literals`), a different trigger → new page. Back-link from `anchor-cases-for-allowlist-regexes`, another regex-anchoring trap.
  - **6:** `workflow-authored-pull-requests` states the token rule for a bot that opens its own PR. A Release → publish chain is a different trigger → new page, with links both ways. The existing page was revised where the docs change refutes "zero check runs" as a general statement.
  - **7:** no page on LLM judges for visual criteria. `llm-review-pipelines` and `fresh-context-code-review` cover code review → new page, back-linked from `fresh-context-code-review`.
  - **8:** `corpus-sweep-before-a-rejection-rule` steps 1–3 are the same practice → merged as one edge row, back-linked to page 7.
- **Conflicts with existing directives:** none. The `workflow-authored-pull-requests` change is a fact update; its directive is unchanged.

## Open-PR check

- **Open `knowledge/*` heads:** none.
  - `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` returned `[]`.
  - The backlog #223–#261 was merged on 2026-10-09 between 13:02 and 13:21 UTC (`gh pr list --state merged`).
- **Verdicts:** all 8 candidates are **new** relative to open PRs.
- **#241:** the earlier draft's "fold into #241" was never pushed, and #241 is merged without it, so candidate 4 is ingested here instead.

## Routing decision

| Candidate | Target |
|---|---|
| 1 | `platforms/tools/search-evidence-from-a-wrapped-grep.md` (new) |
| 2 | `infrastructure/agent-orchestration/review-diff-base-after-a-sibling-merge.md` (new) |
| 3 | `qa/process/scope-purity-checks.md` (amend Do #3) |
| 4 | `platforms/tools/per-call-subagent-effort.md` (amend step 5) |
| 5 | `backend/common/integrations/wrapping-quotes-in-a-frontmatter-value.md` (new). `integrations` holds the pages on consuming formats other tools write (`json-parse-of-a-no-body-response`, `checksum-restored-identifiers`) |
| 6 | `infrastructure/ci-cd/chaining-workflows-past-a-github-token-event.md` (new), plus a revision of `workflow-authored-pull-requests.md` |
| 7 | `qa/process/blind-llm-judgment-of-a-visual-rule.md` (new), next to `llm-review-pipelines` and `fresh-context-code-review` |
| 8 | `backend/common/change-impact/corpus-sweep-before-a-rejection-rule.md` (edge row) |

- No new category.
- The `INDEX.md` rows gain phrases for: the wrapped `grep`, the review diff base, hand-parsed frontmatter values and blind LLM judgments.

**Review:** an adversarial reviewer (`feature-dev:code-reviewer`) read the staged diff before the commit and reported 3 blockers and 11 minor findings.
- **Fixed:**
  - two misquoted lines on the token page;
  - the approval-path wording on `workflow-authored-pull-requests` and its index row;
  - a `--effort` remedy that the env var outranks;
  - the dispatch default-branch rule;
  - the release-please row;
  - the Sharma claim, now narrowed;
  - "several judges", now three;
  - the grep page's tool-naming escape and its `.git/` and binary-file note;
  - the scope-purity link;
  - the YAML `# comment` row;
  - the generator wording.
- **Not changed:**
  - the CHANGELOG 2.1.117 quote: the reviewer's fetch was cut off, and an independent re-fetch matched it exactly;
  - `last_verified` on `workflow-authored-pull-requests` and `corpus-sweep`: their other claims were not re-verified.
- **Lint:** `wiki-structure-checks.js` reports 431 pages, 0 findings. `wiki-lint-prohibitions.js` reports no violations in any changed page; its remaining hits are the 3 already on `main` and copies under the ignored `.claude/tmp/`.

## Local-layer candidates

| Row | Target | Project |
|---|---|---|
| `53963e04e573a487` "Planning t6: deciding Thinking and output budget" | `wiki-local/backend/llm/thinking-and-output-budget.md` | linkly-invitation (run wiki-ingest inside that project) |
| `b3423a63c28655e7` "Planning t6: deciding Prompt" | `wiki-local/backend/llm/vision-analyze-prompt.md` | linkly-invitation (run wiki-ingest inside that project) |

Both are wiki-plan Phase B decisions that name that repo's own files (`src/server/vision/prompt.ts`, `plans/t6/design.md`). They were retired, not ingested here.
