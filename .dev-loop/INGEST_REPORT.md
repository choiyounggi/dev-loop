# Knowledge flush — 11 insight(s)

Drained 9 queue files (11 candidate rows) from `~/.dev-loop/queue/`. 5 candidates
were exact duplicates of knowledge already ingested by the #42–#46 consolidation
and were retired without edits; 6 were merged into existing pages (merge-before-create
— no new pages, no new categories). Open-PR dedup check: `gh pr list --label
dev-loop:knowledge --state open` returned zero open PRs, so nothing here overlaps
an in-flight review.

## Verified best-practice

**1. Bats assertions as `[[ ]]` mid-test are decoration on bash 3.2 → `verified`.**
Claim: under bats on macOS system bash (3.2.57), a false `[[ ]]` that is not the
test's last command does not fail the test; `[ ]` and `grep -qF` pipelines fail at
any position. Verified this session by fresh local reproduction (Bats 1.14.0, GNU
bash 3.2.57, arm64): 4-test probe file gave `ok` for mid-test false `[[ ]]`,
`not ok` for mid-test `[ ]`, mid-test grep, and last-line `[[ ]]`. Mechanism
isolated outside bats: `bash -ec '[[ … ]]; echo survived'` exits 0 while the `[ ]`
form aborts — a pre-4.0 errexit semantic, not a bats defect. Sources:
https://tiswww.case.edu/php/chet/bash/COMPAT (bash-4.0 changed `set -e` to exit on
compound-command failure), https://bats-core.readthedocs.io/en/stable/gotchas.html
and https://www.shellcheck.net/wiki/SC2314 (the documented same-shape gotcha for
negated `!` commands: they "can never fail when used in the middle of a test").

**2. Widened scan surface turning old tests red → triage as first true positive → `field-tested`.**
Claim: when a leak/masking detector gains a previously unscanned output channel and
an existing test reddens, diff what the new surface saw against what the fixture
declares, and fix the fixture's smuggled data rather than the detector. Evidence is
the session reproduction (linkly #43: `result.bindings` widening reddened
`test_when_guard_removed_diverges`; fixture carried an undeclared `password` key;
narrowing to declared fields → 1218 green). No independent external source claims
this exact triage order, so it stays field-tested; it is consistent with the page's
existing sourced principle (change-detector tests / "the guard reddens on a genuine
S-and-C artifact means the guard is working").

**3. Worker usage-limit pause looks alive → check pane tail for the limit marker → `field-tested`.**
Claim: simultaneous quiet workers with green liveness are a usage-limit pause;
find the `You've hit your session limit · resets HH:MM` marker, then after reset
send a resume prompt ordering state-recheck → remaining DoD → completion signal.
Evidence: 2026-08-06 run, three workers paused on one reset with identical markers;
the structured resume prompt recovered all three at their exact interruption point.
Vendor docs do not document the marker string, so no external citation is possible —
kept field-tested with the context described on the page.

**4. Dispatch after `worker_done` needs a substrate-idle wait; a failed dispatch consumes the task → `field-tested`.**
Evidence: reproduced twice in the 2026-08-06 run (immediate dispatch →
`runtime_unavailable` + task consumed; dispatch after `orca terminal wait --for
tui-idle` succeeded first try). Orca is an internal tool; no external source exists.

**5. Guardrail `worktree_escape` can escalate on read-only cross-worktree access → `field-tested`.**
Evidence: two read-only commands (`awk`/`grep` over an upstream FINDINGS file,
`git status`) each raised `ask` and stopped the watch with exit 5; both approved
after review. This **conflicts** with the existing page's 1.0.0 reproduction where
reads passed — handled as a condition-dependent (rule-version) edge case, not an
overwrite (see below).

**6. `sh "$SCRIPT"` stub seam under EDR — second reproduction → enriches existing `field-tested` row.**
Directive already on the page from the #42–#43 reconciliation; this flush adds the
independent second reproduction (8 stall-handler stubs injected without any
`chmod`, bats suite 331/331 green under SentinelOne).

**Dropped as exact duplicates (no edit, retired from queue):** gate quoting-form
parsing (already `command-text-inspected-before-execution` step 8 + Instead-of row
+ field context citing the same bats tests 12–13), stderr-warnings-with-exit-0
capture incl. redirection order (already the whole of
`tool-diagnostics-without-a-failing-exit-code`), Homebrew clang `-isysroot
$(xcrun --show-sdk-path)` (already the whole of `compiler-sysroot-on-macos`, incl.
the same 69-failure repro), temp-artifact prefix counting + AST-rule enforcement +
RED-first guard (already `artifact-leakage-from-a-suite` steps 1/4/5), and
vacuously-green pre-implementation usage-error test proven by guard mutation
(already a `checks-that-cannot-pass` edge row describing the identical
unknown-subcommand/exit-1 case).

## Existing-layer check

Read before deciding: root `INDEX.md`; domain indexes for testing, platforms,
infrastructure; and the nine candidate-overlapping pages
(`command-text-inspected-before-execution`,
`tool-diagnostics-without-a-failing-exit-code`, `compiler-sysroot-on-macos`,
`artifact-leakage-from-a-suite`, `worktree-isolated-workers`,
`tests-that-cannot-fail`, `checks-that-cannot-pass`, `guard-shape-vs-consequence`,
`control-signals-vs-primary-artifacts`, `permissions-and-exec-bits`,
`destructive-operations-on-shared-daemons`).

- **Merged, not created:** all 6 surviving insights landed as edge-case/table rows
  and evidence on existing pages. No new page, no new category.
- **Conflict flagged and resolved as condition-dependent:**
  `worktree-isolated-workers` states reads pass the guardrail (1.0.0 repro); the
  new observation shows a rule version escalating on reads. Added as an edge row
  ("guardrail rules differ by version — probe one read before fanning out") and
  noted in the log entry; the Do-this table was not overwritten.
- **Duplicates:** the 5 dropped candidates matched existing pages
  trigger-for-trigger and directive-for-directive (the #42–#46 reconciliation had
  already ingested earlier harvests of the same sessions' insights).
- **Related-links:** no new cross-links needed — every edited page already links
  the pages the new rows reference (e.g. `tests-that-cannot-fail` ↔
  `checks-that-cannot-pass`, `control-signals` ↔ `worktree-isolated-workers` via
  the agent-orchestration index).

## Routing decision

| Insight | Target (existing page) | Why this page |
|---------|------------------------|---------------|
| bats/bash-3.2 mid-test `[[ ]]` | `testing/quality/tests-that-cannot-fail` — new never-fails-pattern row + sources | The page owns "assertions that cannot detect a defect"; this is a shell-level instance of that exact class |
| widened-scan-surface red | `testing/quality/guard-shape-vs-consequence` — When-this-applies clause + edge row + field evidence | The page owns guard-red triage; existing edge row already covered "guard reddens on genuine S-and-C"; this adds the widened-surface trigger and fixture-diff triage |
| usage-limit worker stall | `infrastructure/agent-orchestration/control-signals-vs-primary-artifacts` — edge row + field evidence | The page owns done/alive/stalled/dead verdicts; this is a new stalled-state cause with recovery protocol |
| dispatch-after-done timing | same page — edge row | "Done signal ≠ substrate release" is precisely the page's signal-vs-artifact distinction |
| read-only guardrail escalation | `infrastructure/agent-orchestration/worktree-isolated-workers` — edge row (condition-dependent conflict) | The page owns the guardrail's read/write asymmetry; the conflicting observation must sit next to the claim it qualifies |
| EDR stub second repro | `platforms/filesystems/permissions-and-exec-bits` — evidence sentence | Directive already lives there; only evidence strengthened |

Domain hints from the queue were respected except where a page already owned the
case: the "testing"-hinted EDR-stub insight routes to platforms (the page that owns
exec-bit/EDR invocation style), and the "platforms"-hinted orchestration insights
route to infrastructure/agent-orchestration (dedicated category), consistent with
prior flushes. Index "load when" lines updated for the four pages whose routing
surface grew.
