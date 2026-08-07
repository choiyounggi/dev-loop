# Knowledge flush — 3 insight(s): 1 ingested, 2 dropped as in-flight duplicates

## Verified best-practice

**1. Warnings-as-errors gates vs intentional-warning features (INGESTED, confidence: verified).**
Claim: before adopting a `-Werror`/`--strict`-style promotion, run the gate against a
*valid* input that legitimately warns (deprecation, accept-and-warn declaration) — the
usual two-way check (catches a bad file / passes a clean file) cannot see this third
input class, and when the platform's diagnostics have no severity tiers the gate and
the feature are mutually exclusive; record that as a platform defect.
Sources checked:
- https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html — fetched this session;
  `-Werror=<w>`/`-Wno-error=<w>` per-warning promotion/exemption exists precisely so
  specific warnings can be exempted from a blanket error gate ("more specific options
  have priority over less specific ones").
- https://rust-unofficial.github.io/patterns/anti_patterns/deny-warnings.html — fetched
  this session; blanket `#![deny(warnings)]` is an anti-pattern because "APIs get
  deprecated, so their use will emit a warning where before there was none"; the
  recommended alternative is explicit lint selection deliberately excluding `deprecated`.
- Field reproduction (lnpl 0.2.0 QA re-measurement, 2026-08-05→07, evidence file
  `qa/rerun/cases/batch-report/evidence/08-diag-channel.log` in the linkly repo):
  unknown-verb → `--strict` rc=2 (caught); clean file → rc=0 (no false positive);
  legitimate `on schedule` declaration → rc=2 anyway, via the accept-and-warn
  "declared, not enforced" diagnostic. Mechanism doc-verified + locally reproduced →
  **verified**.

**2. worktree_escape read-only escalation round-trip (DROPPED — pending duplicate).**
Not re-verified here; the identical insight *with the same session evidence* (Wave 2
worker's upstream-FINDINGS `awk`/`grep` verification and `git status` check each raising
`ask`/exit 5) is already carried by open PRs #47 and #51 on
`worktree-isolated-workers` — #51's version is strictly better (it names the actual rule
mechanism: main-root mention and write-verb/redirect matched independently over the
whole command string). Nothing unique remained to fold.

**3. Orca dispatch-binding stage taxonomy (DROPPED — pending duplicate).**
Idle-prompt check before binding; `runtime_unavailable` → wait and bind a fresh unit;
`agent_unconfigured` → replace the agent; always pass `--worktree` with `--terminal`.
Open PR #51 already carries all four rows on `pane-delivery-confirmation`, including the
same three field observations (busy-bind pending→failed, dead-agent recovery, worktree
mismatch). Nothing unique remained to fold.

## Existing-layer check

Pages read: platforms-processes-tool-diagnostics-without-a-failing-exit-code, backend-common-api-design-unenforced-declarations, qa-process-release-gates, infrastructure-ci-cd-pipeline-structure, qa-exploratory-lowered-declaration-survival, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-pane-delivery-confirmation

- Routing candidates for insight 1 were qa/process (release-gates: release checklists —
  wrong altitude), infrastructure/ci-cd (pipeline-structure: stage ordering — wrong
  concern), and platforms/processes. `tool-diagnostics-without-a-failing-exit-code`
  already owns this exact gate: its Do-5 recommends the `-Werror`/`--strict` promotion
  and Do-6 proves three states (warning/clean/error). The insight is the missing fourth
  state of that same adoption check → **merged** there (Do-5 caution + Do-6 fourth
  control input + 1 edge-case row + 1 Instead-of row + 3 sources), no new page.
- No conflicts: the page's existing directives stand; the merge narrows when the
  promotion switch is safe rather than contradicting it.
- Related-links added both ways with `backend-common-api-design-unenforced-declarations`
  — its "accept and warn" shape is exactly the intentional diagnostic that collides
  with a blanket gate. Platforms domain index "load when" line extended accordingly.
- Insights 2 and 3 were checked against `worktree-isolated-workers` and
  `pane-delivery-confirmation` (merged state + open-PR diffs) — covered there, see
  Open-PR check.

## Open-PR check

Open `knowledge/*` heads listed via `gh pr list` at flush time:
#55 (choiyounggi-20260807-144058), #52 (dch0202-rsquare-20260807-100149),
#51 (dch0202-20260806-183029), #50 (dch0202-20260806-172420),
#49 (dch0202-rsquare-20260806-142309), #47 (dch0202-20260806-130040).

- Insight 1 (warnings-as-errors): diffed #51 and #47 fully; file lists of #55/#52/#50/#49
  checked via `git diff --name-only` / `gh api pulls/N/files` — none touches
  `wiki/platforms/processes/tool-diagnostics-without-a-failing-exit-code.md` or carries
  an overlapping trigger. Verdict: **new** (ingested).
- Insight 2 (worktree_escape read-only escalation): #47 adds the same directive and the
  same session evidence to `worktree-isolated-workers`; #51 adds a refined version (rule
  mechanism + budget-the-round-trip row). Verdict: **drop**.
- Insight 3 (dispatch-binding taxonomy): #51 adds all four rows + the same three field
  observations to `pane-delivery-confirmation`. Verdict: **drop**.

Note for review ordering: #47 and #51 both amend `worktree-isolated-workers`'s Do-this
table near the same rows — whichever merges second will need a trivial conflict
resolution (both versions are compatible; #51's is the more precise).

## Routing decision

- Insight 1 → `platforms/processes/tool-diagnostics-without-a-failing-exit-code`
  (merge, no new page, no new category). The harvested `domain: qa` hint was re-routed:
  the merged wiki already holds the owning page for this gate under platforms/processes,
  and merge-before-create outranks the hint (precedent: 2026-08-04 keg-only re-route in
  log.md). qa/process/release-gates covers release checklists, not diagnostic-gate
  adoption mechanics, so no qa page was created.
- Insights 2, 3 → no target; retired from the queue as pending duplicates of open PRs
  #47/#51 (their would-have-been targets are the two agent-orchestration pages named
  above, where the content already sits).
