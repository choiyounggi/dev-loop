# Knowledge flush — 1 insight(s)

Headless autoflush run, 2026-11-04. Claimed 4 candidates; ingested 1, released 3 (2 pending-duplicate against open PRs, 1 unreadable in this run).

## Verified best-practice

**df1515d721c90d64 — size a gate's per-CHECK timeout for N full-suite passes** (ingested)

- Claim: when one gate CHECK runs the full test suite N times (once per env variant) under a fixed per-check timeout, set the timeout to measured single-pass time × N plus margin before running; an `exit=142 timeout` there is a budget failure, not a test failure.
- Sources checked:
  - https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html — "When a command terminates on a fatal signal whose number is N, Bash uses the value 128+N as the exit status" (SIGALRM 14 → 142).
  - Local read of dev-loop 1.34.5 `skills/loop-implement/scripts/gate-check.sh`: `run_check()` sets one perl `alarm` of `GATE_CHECK_TIMEOUT` seconds (default 120), then `exec`s `/bin/bash -c "<CHECK>"`. So every pass inside one CHECK shares one budget, and exit 124/142 is recorded as `exit=<code> timeout after <T>s`.
  - Field reproduction from the source session: `exit=142 timeout after 900s` on a 2× bats CHECK (~229 cases per pass), then MET 229/229 in both passes with `GATE_CHECK_TIMEOUT=2400`.
  - Corroborating search hit, not fetched (this run has no WebFetch): third-party CI guidance (WarpBuild on GitHub Actions `timeout-minutes`) recommends setting a timeout from observed duration plus headroom. It is not cited on the page.
- Confidence: **verified** for the mechanism (code read + bash manual). The × N sizing rule follows directly from that single-alarm mechanism and was reproduced in the field.

**b5863e2d758c98fb — Claude Code behind a gateway still sends bootstrap requests with a leftover claude.ai OAuth login** (released, not verified in this run)

**126503dbe78559da — claude-code-action: `--allowedTools` does not remove `Agent`; deny it with `--disallowedTools`** (released, not verified in this run)

**fc76dc4dfa08ecde** (released): this headless run could not list `~/.dev-loop/queue`, so the row's file was never found or read. Left for a later run.

## Existing-layer check

Pages read: infrastructure-agent-orchestration-gate-evidence-exit-code-class

- `wiki_search` for "verification check timeout when a gate runs the full test suite multiple times" returned `infrastructure-agent-orchestration-gate-evidence-exit-code-class` as the top match. Its exit-code table and edge-case table both named `exit=124`/`exit=142` as a timeout but said "this page does not cover that case". The candidate fills exactly that gap, so I **merged** it into the page instead of creating a new one.
- Other hits (`qa-process-completion-claims`, `qa-process-release-gates`) cover running a subset versus the full suite. They do not cover timeout sizing. No conflict.
- Also read `wiki/infrastructure/index.md` to update the page's load-when line.
- Changes: 124/142 table row (now says to size the budget and not edit the artifact; adds 142 = 128 + SIGALRM); the edge row it replaced, plus one new edge row for N-pass CHECKs; "When this applies" now covers timeout evidence; 2 new source bullets; `last_verified` set to 2026-11-04; index load-when extended; `log.md` revise entry appended. No new `related:` links needed, because the page already links testing-quality-checks-that-cannot-pass and qa-process-completion-claims.

## Open-PR check

19 open `knowledge/*` PRs: #329, #328, #324, #319, #318, #317, #315, #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. Their changed-file lists came from `gh pr list --json files`. This headless run cannot fetch or diff their content.

- **df1515d721c90d64 → new.** No open PR touches `wiki/infrastructure/agent-orchestration/gate-evidence-exit-code-class.md`. Nearby open edits are on different pages: #300 `verify-command-in-a-worker-brief.md` (about approved-command secrets and worktree pre-push), #307 `autonomous-decision-rulings.md`, #317/#304 completion and done-gate pages. None of them is about timeout budgets.
- **b5863e2d758c98fb → released as a pending duplicate.** #328 edits `platforms/processes/spawning-an-agent-cli-from-a-server.md` with `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` gateway rows. #298 adds `backend/common/llm/gateway-model-alias-resolution.md`. Same domain and trigger (Claude Code behind a gateway).
- **126503dbe78559da → released as a pending duplicate.** #300 edits `platforms/tools/deny-rules-under-bypassed-permissions.md` (Claude Code allow/deny rule semantics). #328 edits `platforms/tools/per-call-subagent-effort.md` (subagent behaviour). Both plausibly overlap `--allowedTools`/`--disallowedTools` and `Agent`.
- **fc76dc4dfa08ecde → released.** Its content could not be read, so overlap could not be judged.

## Routing decision

- df1515d721c90d64 → `infrastructure/agent-orchestration/gate-evidence-exit-code-class.md` (merge). The candidate's domain hint was `testing`, but the existing page that owns gate-runner exit codes (including `GATE_CHECK_TIMEOUT`) lives in infrastructure/agent-orchestration. Merge-before-create puts it there. The directive is general (any shell-out gate runner with one per-CHECK timeout), not specific to one project.
- No new category.

## Local-layer candidates

none
