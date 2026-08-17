# Knowledge flush — 3 insight(s)

## Verified best-practice

**1. Guard placement vs. actual execution order (dev-loop t106).**
Claim: when a plan inserts a precondition guard into an existing script, verify the
insertion point against the target file's real line order — an earlier unconditional
default/auto-create side effect makes a later guard dead code, even when the plan's
underlying decision is correct.
Verification: mechanism is precondition doctrine — checked against the Eiffel Design
by Contract documentation (https://www.eiffel.org/doc/eiffel/ET-_Design_by_Contract_(tm)%2C_Assertions_and_Exceptions),
which states preconditions are monitored "on routine entry", i.e. before any body
statement runs. Session evidence is a concrete reproduction: `status-update.sh:19`
unconditionally created the status file before the plan's proposed guard position;
the revised placement (between lines 18–19) made the BATS case "rework with no
status file → exit 4, no file created" pass. Confidence: **field-tested**
(doctrine-backed mechanism, field reproduction; no single official doc states the
whole directive).

**2. Coordinator status reset must precede prompt re-delivery (linkly iss0817 t60).**
Claim: in multi-session orchestration, resetting a task's status file *after*
re-sending the worker prompt races the worker's first progress signal; the file is
last-write-wins, so the coordinator's late reset erases `plan_ready` and deadlocks
the watch.
Verification: the mechanism is an uncoordinated-writers file race — checked against
https://en.wikipedia.org/wiki/Race_condition (programs colliding on a shared file
produce order-dependent results; coordination or a single writer is required).
Session evidence: timestamps show worker `plan_ready` (12:53:0x) overwritten by the
coordinator's `pending` re-seed (12:53:07); the tmux pane recorded "status set to
plan_ready" while the file read `pending`. Confidence: **field-tested**.

**3. Bash-hook write guards do not cover native Edit/Write tools (linkly run).**
Claim: a worktree-isolation guard implemented as a Bash-command hook is silently
bypassed when the agent edits files via its native Edit/Write tools; isolation
needs a relative-paths-only brief instruction plus a pre-merge `git status` of the
protected tree.
Verification: checked against the official Claude Code hooks documentation
(https://code.claude.com/docs/en/hooks) — tool-event matchers filter on the tool
name; "`Bash` matches only the Bash tool", so a Bash-matcher hook never fires on
Edit/Write calls. Session evidence: a worker under a `worktree_escape` guard
modified two `examples/*.lnpl` files in the main checkout via the Edit tool with
no block and no log; found only when `git pull` failed. Confidence: **verified**
(doc-backed mechanism + field observation).

## Existing-layer check

Pages read: infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, testing-quality-guard-shape-vs-consequence, qa-exploratory-guard-true-path-coverage, backend-common-change-impact-call-site-enumeration

Also read: root `INDEX.md`, `wiki/infrastructure/index.md`, `wiki/debugging/index.md`,
`wiki/backend/index.md` (routing tables).

- Insight 1: no existing page covers plan-prose-vs-line-order guard placement.
  `guard-shape-vs-consequence` (repo-wide guard *tests*) and
  `guard-true-path-coverage` (branch coverage of guarded steps) share the "guard
  that never actually protects" theme but have different triggers → **new page**,
  cross-linked to `call-site-enumeration` (same category) and
  `guard-true-path-coverage` (both ways).
- Insight 2: `shared-run-state` owns file-based coordination but had nothing on
  coordinator/worker write ordering during re-delivery → **merged** (+1 edge case,
  +1 Instead-of, +2 sources, related += pane-delivery-confirmation). No conflict
  with existing directives.
- Insight 3: `control-signals-vs-primary-artifacts` already has the worker-side
  edge ("An editor/Write tool succeeds where Bash was refused — do not route
  around, report it"). The candidate adds the *coordinator/guard-designer* side:
  the escape happens innocently with no log, and the mitigations (brief wording +
  pre-merge `git status`) were absent → **merged into
  `worktree-isolated-workers`** (the brief-authoring page), related +=
  control-signals-vs-primary-artifacts so both sides link. Flagged, not a
  conflict: the two pages now cover the same mechanism from opposite roles.
  (One-way link only — control-signals' `related:` line is concurrently edited by
  open PRs #101/#64/#47; adding a third edit there would guarantee a conflict.)

## Open-PR check

Listed 30 open `knowledge/*` heads (#47–#104). Diffed the ones touching
overlapping pages against merge-base (three-dot semantics; two-dot lists were
polluted by main-side #108 additions): #103 (shared-run-state — related-link only),
#101 (control-signals — related-link only), #92 (worktree-isolated-workers —
gitignored-path edge), #80 (pane-delivery — pasted-text delivery), #79
(dispatching-after-a-completion-report), #64 (control-signals/shared-run-state/
pane-delivery — related-links + new pages), #51 (worktree-isolated-workers —
cross-worktree read edges), #47 (control-signals usage-limit edge,
worktree-isolated-workers version-dependent read escalation, guard-shape widening
edge), #86 via `gh pr diff` (session-completion-gates). Fork PRs #91/#104 touch
unrelated Java/DB/QA pages.

Per-candidate verdicts:
- Insight 1 (guard placement): no open head touches this trigger → **new**.
- Insight 2 (reset-before-send): no open head carries the reset-ordering race;
  #80's pane-delivery change is about paste-submission confirmation, a different
  failure in the same re-delivery flow → **new**.
- Insight 3 (Edit/Write bypass): #92/#51/#47 amend the same page's edge table with
  *different* guardrail edges (gitignored paths, cross-worktree reads, read
  escalations); none covers the native-tool bypass or the pre-merge git-status
  check → **new** (merge conflicts among sibling amendments are line-adjacent but
  content-disjoint).

## Routing decision

- Insight 1 → **backend/common/change-impact** (existing category), new page
  `inserting-a-guard-before-an-existing-side-effect`. The harvested `domain:
  debugging` hint was re-routed: debugging is scoped to diagnosing failures,
  while this is pre-change impact verification — exactly what change-impact holds
  (precedent: call-site-enumeration, and in-flight #51/#58 additions to the same
  category). backend/index.md gained the row.
- Insight 2 → **infrastructure/agent-orchestration/shared-run-state** (merge; the
  page owns coordination through shared files). infrastructure/index.md load-when
  extended with the reset-during-re-delivery trigger.
- Insight 3 → **infrastructure/agent-orchestration/worktree-isolated-workers**
  (merge; the page owns brief authoring + guardrail direction). The harvested
  `domain: security` hint was re-routed: the wiki's security domain is
  application trust boundaries; agent-guardrail semantics live in
  agent-orchestration, where the sibling worker-side edge already sits.
  infrastructure/index.md load-when extended with the Bash-hook-vs-native-tools
  trigger. Sources gained the official hooks doc.

No new categories. log.md updated with the ingest entry.
