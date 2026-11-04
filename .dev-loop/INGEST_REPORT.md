# Knowledge flush — 1 insight(s)

This headless autoflush claimed 3 candidates. 1 is ingested here; 2 were released back to `pending` (see Open-PR check).

## Verified best-practice

**126503dbe78559da — limit a CI agent runner's tools with `--disallowedTools "Agent"`, not with `--allowedTools` alone**

- Claim: `--allowedTools` only pre-approves calls. `Agent` needs no permission, so it stays available. A runner that must not delegate removes it with a bare-name `--disallowedTools "Agent"` (or with `--tools`), and pins its argument list in a test.
- Sources checked (WebSearch, 2026-11-04):
  - https://code.claude.com/docs/en/tools-reference — the "Permission required" column lists `Agent` as No.
  - https://code.claude.com/docs/en/agent-sdk/permissions — a tool not in `allowed_tools` is still available. A call that needs no approval runs whether or not you list it. A bare name in `disallowed_tools` hides the tool.
  - https://code.claude.com/docs/en/permissions — a bare name removes the tool from context, and a scoped rule only denies matching calls. The page also says "To leave a tool out, use --tools instead of a deny rule".
  - https://code.claude.com/docs/en/sub-agents — the `--disallowedTools "Agent(Explore)"` form, and a sub-agent's tools come from its own definition.
  - https://code.claude.com/docs/en/headless — the run stays open for background sub-agents.
- Not verified externally: the claim that claude-code-action reads the first `result` message and cuts off background sub-agents. It rests only on the session's field incident (PR #272 log, empty `examined.files`, exit 3). Third-party issue reports about `claude -p` stopping background agents point the same way. The page labels this as a field incident, not a documented fact.
- Confidence: **verified** for the directive (official docs); the cut-off mechanism is field-observed.

## Existing-layer check

Pages read: infrastructure-ci-cd-secret-needing-gate-on-fork-prs, infrastructure-ci-cd-review-bot-adopted-as-a-blocking-gate, platforms-tools-deny-rules-under-bypassed-permissions, testing-quality-checks-that-cannot-pass, testing-quality-tests-that-cannot-fail, infrastructure-ci-cd-changed-files-only-gates

- `wiki_search` over the candidate's trigger returned `platforms-tools-deny-rules-under-bypassed-permissions` as the closest page. That page covers deny rules for bypass-mode workers. It does not cover `--allowedTools` leaving permission-free tools such as `Agent` available.
- `infrastructure-ci-cd-secret-needing-gate-on-fork-prs` covers agent-run CI gates (secrets, fail closed), not tool limits. `infrastructure-ci-cd-review-bot-adopted-as-a-blocking-gate` covers exit codes of review CLIs.
- No page covers this, so it is a **new page**: `wiki/infrastructure/ci-cd/tool-restriction-for-a-ci-agent-runner.md`.
- Related links added: the new page links to secret-needing-gate-on-fork-prs, review-bot-adopted-as-a-blocking-gate, deny-rules-under-bypassed-permissions, changed-files-only-gates and tests-that-cannot-fail. A back-link was added to secret-needing-gate-on-fork-prs `related:`.
- Conflicts: none. The new page agrees with deny-rules-under-bypassed-permissions: allow rules are inert in bypass mode, and deny rules hold.
- Index row added in `wiki/infrastructure/index.md` (ci-cd), plus a `log.md` entry.

## Open-PR check

Open `knowledge/*` heads listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`: #331, #330, #329, #328, #324, #319, #318, #317, #315, #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. This headless run cannot git-diff them, so overlap was judged from PR titles and touched file paths (`--json files`).

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| 126503dbe78559da (CI agent runner, `--allowedTools` vs `Agent`) | None. No open PR touches `infrastructure/ci-cd/secret-needing-gate-on-fork-prs.md`, `review-bot-adopted-as-a-blocking-gate.md` or the new path. #300 edits `platforms/tools/deny-rules-under-bypassed-permissions.md`, but its title items are Gradle filters, HMAC, a Slack probe, command secrets, .env targets and worktree pre-push. Tool availability under `--allowedTools` is not among them, and this run does not edit that page. | **new** |
| b5863e2d758c98fb (gateway `ANTHROPIC_BASE_URL` with a claude.ai login still present sends bootstrap/penguin_mode to api.anthropic.com) | #328 (child claude hooks/env, gateway proxy) edits `platforms/processes/spawning-an-agent-cli-from-a-server.md` with `ANTHROPIC_BASE_URL`/`ANTHROPIC_AUTH_TOKEN` gateway rows from the same session | pending duplicate. Claim **released**, not ingested |
| fc76dc4dfa08ecde | Not determined. This run's permissions cannot list `~/.dev-loop/queue/`, and the row's session file was not among the session ids found in `~/.claude/history.jsonl` | Claim **released** for a manual `/dev-loop:knowledge-flush` run |

## Routing decision

- 126503dbe78559da → `infrastructure` / `ci-cd` / new page `tool-restriction-for-a-ci-agent-runner.md`. It goes under ci-cd, not platforms/tools, because the trigger is a CI job's agent runner (claude-code-action `claude_args`) and the failure is a vacuous green gate, which sits next to the existing agent-run gate pages in ci-cd. The page links to `platforms-tools-deny-rules-under-bypassed-permissions` for the permission-rule details. No new category.

## Local-layer candidates

none
