# Knowledge flush — 3 insight(s)

Queue drained: 3 pending candidates from 3 sessions. Outcome: **1 merged into an
existing page** (this PR), **1 folded into open PR #76**, **1 dropped as a
same-day duplicate of the merged one**. No new page was created.

## Verified best-practice

### A. `05d9b2c2` — the remediation diff is itself an unreviewed defect surface (qa)

**Claim.** When a review-fix diff is handed to the next round, the edit's own
shape opens defect classes the review never named: a widened fetch opens
unbounded results, an added output line opens an unguarded path, a newly
persisted record opens an orphan, a literal replaced by a placeholder opens
unvalidated assembly.

**Sources checked.** The general claim ("a fix is more defect-prone than the code
it replaces") is already sourced on the target page to Yin et al., *How do fixes
become bugs?*, ESEC/FSE 2011 — https://dl.acm.org/doi/10.1145/2025113.2025121 and
https://www.eecg.utoronto.ca/~yuan/papers/incorrect_fix_abstract.html ("at least
14.8% to 24.4% of sampled fixes for post-release bugs in these large OSes are
incorrect"). The four-shape taxonomy is **field evidence**, not literature: PR
#327 bot review rounds 13→14, where 4 of round 14's 7 warnings were defects
introduced by round 13's own remediation, one per shape.

**Confidence:** `verified` for the underlying claim (published study, quoted from
the abstract page I opened); the four-shape table is recorded on the page as a
dated **field observation**, distinguished from the cited study.

### B/C. `269b1dad` + `df361a8b` — the receiving side of a completion gate (infrastructure)

These two rows are the same insight harvested twice on 2026-08-12 (same trigger,
same directive, different wording). Treated as one.

**Claim.** When a Stop/completion gate repeats "verification loop incomplete" at a
pause the worker's own prompt instructed, the worker holds its phase and reports
the gate-vs-prompt mismatch; it does not advance the phase to a terminal value to
silence the gate.

**Verified by reproduction in this checkout at `fa89dc2`** (not from the
installed plugin copy the candidates cited):

| Check | Result |
|-------|--------|
| `hooks/loop-gate.sh:55` terminal set | `done\|approved\|merged\|failed\|""` — `impl_done` and `plan_ready` absent |
| `skills/orchestrate/scripts/status-update.sh:6` phase vocabulary | `pending\|planning\|plan_ready\|implementing\|impl_done\|approved\|merged\|done\|failed` — `impl_done` is first-class |
| `skills/orchestrate/templates/session-prompt.md:75,79` | instructs the worker to record `impl_done` "and wait" / "END YOUR TURN" |
| `skills/orchestrate/scripts/ready-set.sh:74` | `satisfied()` = `approved\|merged\|done` — exactly the three values that would silence the gate |
| `skills/orchestrate/scripts/ready-set.sh:28-30` | states the rule a fabricated phase breaks: "A dependency counts as satisfied only at `approved` or higher, NOT at impl_done" |

So the harm is concrete and checkable, not rhetorical: the only phases that stop
the nudge are the ones the scheduler reads as "reviewed", and writing one
dispatches dependents against an unreviewed interface.

**External source for the principle** — NIST SP 800-53 r5 AC-5, opened and quoted
verbatim from https://csf.tools/reference/nist-sp-800-53/r5/ac/ac-5/ :
"Separation of duties addresses the potential for abuse of authorized privileges
and helps to reduce the risk of malevolent activity without collusion. Separation
of duties includes dividing mission or business functions and support functions
among different individuals or roles". The phase recording a review verdict
belongs to the reviewing role; the reviewed party writing it is the same actor
initiating and approving.

**Confidence:** `verified` — reproducible in-repo at a named commit, plus a cited
standard for the principle. The page's existing `confidence: verified` is
unchanged; `last_verified` moved to 2026-08-13.

## Existing-layer check

Routed via `INDEX.md` → `wiki/infrastructure/index.md` (agent-orchestration) and
`wiki/qa/index.md` (process). Read every page in both categories whose "load when"
overlapped, plus the qa page the fold targets.

Pages read: infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-pane-delivery-confirmation, qa-process-regression-scope, qa-process-release-gates

**B/C — overlap found, merged rather than created.**
`session-completion-gates` already covers this situation from the **gate author's**
side: its own table classifies "instructed pause awaiting an external actor
(`plan_ready` awaiting approval, `impl_done` awaiting review)" as terminal, and it
cites the same `loop-gate.sh:55` line from a 2026-08-05 reproduction at `95cf947`.
Its "When this applies" already says "when such a gate fires on a worker that did
exactly what its own prompt told it to do".

What it did **not** carry is the receiving side — what that worker should do while
the gate is firing on it, and which phase values its role may write. That is the
delta merged in:
- "When this applies" extended to the worker's vantage point.
- New **Do this** step 6 with a phase-authorship table (worker: `plan_ready`,
  `impl_done`, and `done` only after approval; coordinator only: `approved`,
  `merged`).
- Two **Edge cases** rows (repeating nudge = mismatch not skipped work; cite both
  file:line in the report) and one **Instead of** row (advance the phase → hold it
  and report).
- Two sources added: NIST AC-5, and the `fa89dc2` reproduction including the
  `ready-set.sh:74` consequence the 2026-08-05 entry did not have.

**No conflict.** The addition is consistent with the page's existing direction —
the page tells gate authors to make instructed pauses terminal; the new step tells
the worker not to route around the gap while it exists. Body 73 → 82 lines
(limit 120). No banned qualifiers.

**Related links.** No new `related:` entries: the four adjacent
agent-orchestration pages were read and none is the counterpart of this delta
(`control-signals-vs-primary-artifacts` is the orchestrator reading a worker's
signals; `shared-run-state` is the file layout; `worktree-isolated-workers` is the
brief contract; `pane-delivery-confirmation` is input delivery). The existing
three-way `related:` set is already correct.

**A — no page on main covers it; the fold target lives only in an open PR** (see
below). `qa-process-regression-scope` is the nearest merged page and is a
different axis (what to re-test for a *release*, by blast ring, not what a
*remediation edit* opens). It was left untouched.

## Open-PR check

Listed 22 open `knowledge/*` heads (`gh pr list --search "head:knowledge/"`):
#80 #79 #78 #76 #74 #73 #72 #69 #68 #66 #64 #62 #61 #58 #57 #56 #55 #52 #51 #50
#49 #47. Pulled every one's diff (`gh pr diff N`) and grepped the added lines for
each candidate's concepts.

| Candidate | Overlapping open PR | Verdict |
|-----------|--------------------|---------|
| A — remediation diff as defect surface | **#76**, which adds `wiki/qa/process/defect-class-resweep-after-review.md`; its step 5 is "Read the remediation diff as unreviewed code", and its "Instead of" table already rebuts "treat the previous round's approval as covering the fix" | **fold** |
| B/C — worker side of a completion gate | none. Only #79 touches `session-completion-gates.md`, and only to append one id to `related:`; #47/#51/#64/#80 merely name the page id in their reports or index rows. A grep of all 22 diffs' added lines for `impl_done`, self-approval, phase-fabrication and "advance the phase" returned no match (the only `forge` hits are #51's git-forge email page) | **new** (merged into the existing page here) |
| C alone | duplicate of B — same trigger, same directive, harvested twice on 2026-08-12 | **drop** |

**Fold executed, not deferred.** Pushed commit `4e9b0a1` to
`dch0202-rsquare:knowledge/dch0202-rsquare-20260812-100014` (PR #76's head),
adding a step 6 to that page — the four remediation shapes and the check each
calls for — plus the PR #327 field-observation source. Explained on the PR:
choiyounggi/dev-loop#76 (issuecomment-5274743196). That page stays at 80 body
lines. **No sibling page was created here for candidate A.**

## Routing decision

| # | Insight | Target | New category? |
|---|---------|--------|---------------|
| B/C | Worker side of a completion gate | `infrastructure/agent-orchestration/session-completion-gates.md` (**merged into existing page**) + `wiki/infrastructure/index.md` load-when extended + `log.md` | no — `agent-orchestration` owns worker/orchestrator protocol, and this page owns this exact situation from the other side |
| A | Defect classes a remediation's own shape opens | `qa/process/defect-class-resweep-after-review.md` **on PR #76's branch** | no — routed to an in-flight page rather than duplicated |
| C | (duplicate of B) | none — retired | — |

Files changed in this PR: `wiki/infrastructure/agent-orchestration/session-completion-gates.md`,
`wiki/infrastructure/index.md`, `log.md`, this report. No new page, no new category.

Cross-Check: every URL cited here was opened in this session (the NIST AC-5 quote
was fetched and quoted verbatim; the two Yin et al. URLs are pre-existing sources
on PR #76's page and are quoted only as that page already quotes them). The
in-repo file:line claims were re-run against this checkout at `fa89dc2` rather
than inherited from the candidates' text, which cited the installed plugin copy.
