# Knowledge flush — 3 insight(s): 1 ingested, 2 dropped as in-flight duplicates

## Verified best-practice

**1. SIGINT delivery to `&`-backgrounded processes in non-interactive shells (INGESTED)**

Claim: a test harness that starts a program with `cmd &` from a shell script and
sends `kill -INT "$pid"` never delivers an effective SIGINT — POSIX requires
job-control-disabled shells to start asynchronous-list commands with SIGINT and
SIGQUIT set to SIG_IGN, so the kill succeeds and the child discards the signal;
`wait` then hangs to the harness timeout and the failure reads like a product
bug. Deliver the signal from a subprocess driver instead (e.g.
`subprocess.Popen` + `send_signal(SIGINT)`), or `set -m` in the script, or use
SIGTERM when the contract is generic shutdown.

Sources checked:
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html —
  §2.11 Signals and Error Handling, verbatim: "If job control is disabled …
  when the shell executes an asynchronous list, the commands in the list shall
  inherit from the shell a signal action of ignored (SIG_IGN) for the SIGINT
  and SIGQUIT signals." (fetched and grepped the spec text directly)
- https://www.gnu.org/software/bash/manual/bash.html#Signals — §3.7.6, verbatim:
  "When job control is not in effect, asynchronous commands ignore SIGINT and
  SIGQUIT in addition to these inherited handlers."
- https://docs.python.org/3/library/subprocess.html#subprocess.Popen.send_signal —
  anchor existence verified by fetch.

Local reproduction (2026-08-07, macOS): `sh|bash|zsh -c '<print SIGINT
disposition> & wait'` all report SIG_IGN for the background child and the
default handler in the foreground; with `set -m` the background child reports
the default handler; SIGTERM reports SIG_DFL in both. Matches the harvested
field case (server binary: rc 143 timeout under `kill -INT`+`wait`, immediate
rc 0 under Popen+send_signal).

Confidence: **verified**.

**2. worktree_escape guardrail escalation budgeting (DROPPED — in-flight duplicate)**

Claim: the worktree_escape guardrail escalates read-shaped cross-worktree
access, so orchestration briefs referencing other worktrees must budget the
escalation round trip. Not re-verified here — open PR #51 already carries this
exact insight with a stronger local reproduction (see Open-PR check).

**3. Orca terminal bind-failure stage branching (DROPPED — in-flight duplicate)**

Claim: check for the idle prompt before binding the next unit to a worker's
terminal; branch on the failure stage (runtime_unavailable → wait and rebind,
agent_unconfigured → replace the agent; always pass --worktree with
--terminal). Not re-verified here — open PR #51 already carries all four rows
with the same field evidence.

## Existing-layer check

Routed via INDEX.md → testing domain. Read the full testing domain index (all
"load when" lines) — no existing page covers signal delivery or process
lifecycle in tests; nearest neighbors (diagnosing-flaky-tests, async-testing,
test-level-choice) have non-overlapping triggers. Checked platforms as the
alternative home: background-services covers process persistence (nohup/launchd/
systemd), non-interactive-cli-invocation covers prompt-capable CLIs hanging —
neither covers signal dispositions of `&` jobs, so this is a new trigger →
new page (merge-before-create satisfied: nothing to merge into). Repo-wide
`grep -ril sigint wiki/` confirmed no page mentions the mechanism.

Created: `wiki/testing/strategy/signal-delivery-to-a-process-under-test.md`
(confidence verified, 3 sources + local repro). Updated `wiki/testing/index.md`
(strategy table row) and `log.md`. Related-links added both ways with
platforms-processes-non-interactive-cli-invocation (same interactive-vs-
automation divergence family). No conflicts with existing directives.

Pages read: platforms-processes-background-services, platforms-processes-non-interactive-cli-invocation, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-worktree-isolated-workers

## Open-PR check

Open `knowledge/*` heads listed via `gh pr list` and each diffed against main
(`git diff origin/main origin/<head> -- wiki/`; fork heads #52/#49 fetched via
`pull/<n>/head`):

- #56 (choiyounggi-20260807-153857), #55 (choiyounggi-20260807-144058),
  #50 (dch0202-20260806-172420), #47 (dch0202-20260806-130040),
  #52 (dch0202-rsquare-20260807-100149), #49 (dch0202-rsquare-20260806-142309):
  no overlap with any of the 3 candidates (testing-quality, ML, platforms
  pages; nothing touches signals or the two orchestration insights).
- #51 (dch0202-20260806-183029): **overlaps candidates 2 and 3 completely.**
  Its worktree-isolated-workers.md diff contains the read-only escalation
  budgeting row verbatim ("Budget the round trip … state in the worker's first
  brief that reads are approved") plus a stronger reproduction showing pure
  reads pass and ask fires only when a write verb/absolute redirect co-occurs
  — a correction that supersedes candidate 2's broader claim. Its
  pane-delivery-confirmation.md diff contains all of candidate 3: idle-prompt
  check before binding, runtime-unavailable → wait, agent-unconfigured →
  replace agent, pane/worktree mismatch → pass worktree, same i43/i45 field
  evidence.

Verdicts: candidate 1 → **new** (ingested here); candidate 2 → **drop**
(pending duplicate of #51, nothing unique to fold); candidate 3 → **drop**
(pending duplicate of #51, nothing unique to fold). No sibling duplicate PR
opened.

## Routing decision

- Candidate 1 → `testing/strategy/signal-delivery-to-a-process-under-test`.
  Domain: the trigger is test-harness-shaped (harvester hint: testing) and the
  testing INDEX line "writing or structuring automated tests" matches; category
  `strategy` because the directive chooses the harness/driver structure, not an
  assertion. No new category needed. The shell mechanism is cross-referenced to
  platforms via the related-link rather than a second page (one case, one page).
- Candidates 2–3 → no routing; retired as pending duplicates of open PR #51.
