# Knowledge flush — 4 insight(s)

Claimed queue ids: `c6c76b1cb2d35bf9`, `028fcf4648303397`, `1c4620e3aadaf0b7`, `56f4dbc8fb5997f8`.
All four were handled (2 new pages, 3 amended pages); none dropped.

## Verified best-practice

**1. `c6c76b1cb2d35bf9` — precedence tests must stage the competing condition at the deciding iteration** (→ `confidence: verified`)

Claim: a test asserting that exit condition A wins over B must make B become true in
the same poll/iteration in which A reaches its threshold; a B staged earlier makes the
assertion hold under either ordering of the checks.

- https://arxiv.org/abs/1909.04770 (Vera-Pérez, Danglot, Monperrus, Baudry, 2019) — fetched
  this session. An undetected mutant has three causes, the first being that "the test
  inputs are not sufficient to infect the state of the program". That is exactly this
  failure: if B fires before A can activate, the reordering mutant is never reached in a
  state where it can infect the outcome.
- https://pitest.org/quickstart/basic_concepts/ — a surviving mutant means no test
  distinguishes the mutated program; a kill is attributed to the covering test, which is
  why the precedence test itself (not merely the file) must redden.
- https://testing.googleblog.com/2021/04/mutation-testing.html — detection is measured by
  inserting the fault and requiring failure, not by branch coverage.
- Field measurement (dev-loop `watch-status.sh`, three "R6 precedence" bats cases): moving
  the exit-8 block above the failed/done check left all three green. Re-staging the
  competing status transition to the same tmux-stub capture count that confirms the
  two-poll witness made the same swap red.

**2. `028fcf4648303397` — never confirm a pane witness from a capture taken in the same iteration as a key-send** (→ merged as `verified` material into an existing `verified` page)

Claim: when a poll loop both sends keys (auto-recover `Enter`, resend) and reads a state
witness from the pane, it must skip the capture entirely on the iteration that sent keys.

- Reproduced locally this session (tmux, macOS, `sh` pane): with the newest status line
  reading `STATE=BLOCKED`, sending a command that worked 0.4s before printing left the
  same-iteration `capture-pane` still showing `STATE=BLOCKED`; the next poll showed
  `STATE=RUNNING`. The same sequence with an instantly-printing command had already
  repainted within the same iteration — so the check's outcome is set by the target's work
  time, which is why the gate belongs on "did this iteration send keys", not on a delay.
- Mechanism already sourced on the target page: https://man7.org/linux/man-pages/man1/tmux.1.html
  (`send-keys` writes keys into the pane; `capture-pane` copies visible contents — neither
  reports consumption) and https://man7.org/linux/man-pages/man3/termios.3.html.
- Field evidence: dev-loop code review of task `t3-blocked-consume`, finding F1 — the exit-8
  "still blocked" witness was confirmed from a same-poll capture, so a just-repaired worker
  could be escalated; gating on the recovery flag fixed it, and removing the gate under
  mutation woke the witness one poll early.

**3. `1c4620e3aadaf0b7` — graphify's installed hooks miss the `git pull` path** (→ `verified`)

Claim: `graphify hook install` covers `post-commit` and `post-checkout` only, while the
"PR merged upstream → `git pull`" path fires `post-merge`, so the graph goes stale while
`hook status` reports installed.

- https://git-scm.com/docs/githooks — fetched this session: `post-commit` "is invoked by
  git-commit"; `post-merge` "is invoked by git-merge, which happens when a `git` `pull` is
  done on a local repository"; `post-checkout` "is also run after git-clone, unless the
  `--no-checkout` (`-n`) option is used".
- Local reproduction (git 2.50.1, macOS): in a clone carrying all three hooks, a
  fast-forward `git pull` fired `post-merge 0` alone; a divergent `git pull` that created a
  merge commit also fired `post-merge 0` and **no** `post-commit`; a fresh `git clone` of
  that repository carried no non-sample hooks.
- Source read: `graphifyy 0.4.23` `hooks.py:186-187` installs `"post-commit"` and
  `"post-checkout"` only; `grep -c post-merge hooks.py` → 0.
- **Correction applied to the candidate's stated reasoning:** the submitted note said git
  "does not run hooks on clone". Per the docs and the reproduction, `git clone` *does* run
  `post-checkout` — the reason a clone gets no graph is that hooks are not copied by clone,
  so none exist to run. The page carries the corrected reason.

**4. `56f4dbc8fb5997f8` — a grounding gate's escape hatch must emit a gap record at the point it grants the pass** (→ `confidence: field-tested`)

Claim: an escape hatch (`[no-wiki]`, a suppression comment) is the most valuable signal a
knowledge base gets, and a gate that only decides pass/fail destroys it; the record must be
emitted by the gate, not requested in prose.

- https://docs.github.com/en/code-security/code-scanning/managing-code-scanning-alerts/resolving-code-scanning-alerts
  — fetched this session: dismissing an alert requires choosing a reason, "the dismissal
  comment is added to the alert timeline", it is readable as `dismissed_comment` on the
  alerts API, and dismissed alerts stay in the Closed list for review. This is the canonical
  shape of a *recorded* escape hatch.
- https://github.blog/changelog/2025-07-01-delegated-alert-dismissal-for-code-scanning-is-now-generally-available/
  — each dismissal request carries a mandatory rationale, visible on the timeline, in the
  audit log, and via REST API and webhooks.
- Local field measurement (this repo, 1.22.0): `skills/wiki-plan/scripts/plan-gate.sh:166`
  passes an ungrounded decision with `[ "$basis" = "[no-wiki]" ] && continue` and records
  nothing, while `skills/wiki-plan/SKILL.md:135` asks in prose for the decision to be "noted
  as an ingest candidate". Against 276 non-index wiki pages, `log.md` carries exactly one
  `gap` entry (2026-07-11).
- No external source states the general rule as a directive, so this stays **field-tested**
  rather than verified; the GitHub precedent supports the mechanism, not the general claim.

## Existing-layer check

Routed via `INDEX.md` → domain `index.md` → every page whose "load when" overlapped.

Pages read: testing-quality-tests-that-cannot-fail, testing-quality-policy-at-several-return-sites, testing-quality-completion-predicates, testing-quality-surviving-mutant-equivalence-triage, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-code-graph-as-orientation-layer, platforms-processes-driving-a-tui-in-a-tmux-pane, qa-document-verification-spec-document-gates, infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-autonomous-decision-rulings

(Directory-level scans of `wiki/testing/quality/`, `wiki/platforms/processes/`,
`wiki/infrastructure/agent-orchestration/` plus keyword sweeps for `no-wiki`, `post-merge`,
`capture-pane`/`send-keys`, and `precedence` over the whole wiki preceded these reads.)

| Insight | Overlap found | Outcome |
|---------|---------------|---------|
| 1 precedence | `tests-that-cannot-fail` carries a co-occurring-writer edge case (two writers of one flag) and `policy-at-several-return-sites` carries per-site mutation — both are about *coverage of one site*, neither about *which of two live conditions wins* | **New page**, cross-linked to both; no conflicting directive |
| 2 pane witness | `pane-delivery-confirmation` already rules that a pane *diff* is not delivery evidence (echo direction). The new rule is the opposite direction — a stale capture *falsely confirming* a witness | **Merged** into that page (Do-this #6, 1 edge row, 1 Instead-of row, 2 sources); 1 pointer row added to `driving-a-tui-in-a-tmux-pane` |
| 3 graphify hooks | `code-graph-as-orientation-layer` already gates on freshness and its Sources line already names `hook install` post-commit/post-checkout — the hook-coverage consequence was missing | **Merged** into that page (2 edge rows, 2 sources, 1 clause on directive 1) |
| 4 escape hatch | `session-completion-gates` and `spec-document-gates` cover gate *authoring*; none covers what a gate does with its own exemptions. Keyword sweep for `no-wiki`/`escape hatch`/`knowledge gap` returned no owning page | **New page** in the existing `agent-orchestration` category |

Conflicts flagged: none — no existing directive is contradicted.
Related links added both ways: `tests-that-cannot-fail`, `policy-at-several-return-sites`,
`completion-predicates` ↔ the new precedence page; `session-completion-gates`,
`autonomous-decision-rulings`, `spec-document-gates` ↔ the new escape-hatch page.

Lint after the edits: `wiki-structure-checks.js` → **278 pages, 13 indexes, 0 findings**;
`wiki-lint-prohibitions.js` → no findings on any touched page (the 2 repo-wide violations it
reports are pre-existing, in `plans/` and `tests/fixtures/`). New pages are 67 and 69 body
lines; amended pages are 92, 92 and 65 — all under the 120-line cap.

## Open-PR check

Listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` —
12 open heads: #191, #190, #189, #188, #187, #186, #185, #183, #182, #181, #180, #179.
Each head was fetched and its **added** wiki lines (`git diff <merge-base> pr-N -- wiki/`)
grepped for `post-merge|graphify|graph.json|no-wiki|capture-pane|send-keys|precedence|knowledge gap`.

| Candidate | Overlapping open head | Verdict |
|-----------|----------------------|---------|
| 1 precedence | none — #189's `proving-a-critical-section-is-lock-protected` and `sequential-dispatch-assumption-under-concurrency` are concurrency-window tests, not exit-condition ordering; its only `precedence` hits are Gradle property precedence (#179) | **new** |
| 2 pane witness | none — #183's single `send-keys` hit is a pointer row in a stdin-vs-send-keys edge case | **new** |
| 3 graphify hooks | #185 edits the *same page* but adds an unrelated row (`update` exits 1 on a >5,000-node HTML viz); #186 only mentions this page in an INGEST_REPORT dedup note | **new** (no content overlap; noted below as a textual merge risk) |
| 4 escape hatch | none — #189's `gate-evidence-exit-code-class` is about a gate's own exit-code classes, not about recording exemptions | **new** |

Merge-risk note for the reviewer: **#185 and this PR both append to
`wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md`** (different
edge-case rows and different source bullets). Whichever lands second may need a one-hunk
textual merge; the content does not conflict semantically.

## Routing decision

| Insight | Target | New category? |
|---------|--------|---------------|
| 1 | `testing/quality/precedence-between-competing-exit-conditions.md` (**new page**) | No — `testing/quality` already owns "can this test actually fail" |
| 2 | `infrastructure/agent-orchestration/pane-delivery-confirmation.md` (**merge**), + 1 pointer row in `platforms/processes/driving-a-tui-in-a-tmux-pane.md` | No |
| 3 | `infrastructure/agent-orchestration/code-graph-as-orientation-layer.md` (**merge**) | No |
| 4 | `infrastructure/agent-orchestration/escape-hatch-uses-as-a-knowledge-gap-signal.md` (**new page**) | No — `agent-orchestration` already carries the gate-authoring pages (`session-completion-gates`, `autonomous-decision-rulings`); a `knowledge-base` category would hold one page and split gate knowledge across two places |

Plumbing: `wiki/testing/index.md` +1 row; `wiki/infrastructure/index.md` +1 row and two
extended "load when" lines (pane-delivery-confirmation, code-graph-as-orientation-layer);
`log.md` +1 `ingest` entry.
