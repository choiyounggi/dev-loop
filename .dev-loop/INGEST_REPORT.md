# Knowledge flush — 3 insight(s)

Queue drained: 3 pending candidates across 2 session files. **1 ingested here**,
1 folded onto open PR #47, 1 dropped as a pending duplicate. This PR therefore
carries a single new page.

## Verified best-practice

### C1 — one test per success-return site of a handler that applies one policy (ingested)

**Claim.** When a function applies the same policy at several of its own success
returns (a CLI handler computing an exit code and returning it from three
branches), enumerate those return sites first, write one test per site, and prove
each by reverting that specific call and requiring exactly its owning test to
redden. Testing only the most obvious branch leaves the others gated but
unverified — deleting the policy from them keeps the suite fully green.

**Sources checked this run (fetched, quotes taken verbatim):**

- `https://raw.githubusercontent.com/nedbat/coveragepy/master/doc/branch.rst` —
  coverage.py's own statement-vs-branch example: "Statement coverage would show
  all lines of the function as executed. But the `if` was never evaluated as
  false, so line 2 never jumps to line 4"; branch coverage "will flag this code
  as not fully covered because of the missing jump from line 2 to line 4. This is
  known as a partial branch." This grounds the *why*: a green line-coverage
  report is compatible with a return path never being taken.
- `https://pitest.org/quickstart/basic_concepts/` — "'Survived' means the
  mutation was not detected by the covering test"; "'No coverage' is the same as
  **Survived** except there were no tests that exercised the line of code where
  the mutation was created." These are the two distinct verdicts a per-site
  reversion separates, and they map to two different fixes (weak assertion vs.
  missing case).
- `https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/`
  — the Block Statement mutator "removes the content of every block statement",
  i.e. deleting the statement at one site is a standard mutation operator, not an
  ad-hoc edit invented for this procedure.
- Not cited: `https://pitest.org/quickstart/mutators/` was fetched to check
  whether PIT documents per-return-statement mutant placement; it documents the
  return-value mutator family (`EMPTY_RETURNS`, `FALSE_RETURNS`, `TRUE_RETURNS`,
  `NULL_RETURNS`, `PRIMITIVE_RETURNS`) but does **not** state that placement is
  per return statement, so no such claim was made. NIST SP 500-235 (basis-path
  testing) was fetched for the "one test per independent path" grounding and
  could not be read — the PDF did not extract on this machine (no
  poppler/pdftotext/pypdf) — so it is **not** cited rather than cited unread.

**Field verification (reproducible check).** linkly `impl/lnpl/cli.py`, `cmd_spec`
returns 0 from three branches (`-o` without `--run`, stdout dump, `--run` with all
cases passing). Reverting the two no-run `_strict_rc(...)` calls to bare
`return 0` left 10 tests passing and reddened exactly the 2 new path-specific
tests; before those tests existed the same reversion reddened nothing. The file
was restored from a pre-mutation copy with an identical `sha256`, and the suite
total rose 1272 → 1275 rather than dropping.

**Confidence: verified** — documented mechanism (coverage.py, PIT, Stryker) plus a
reproducible per-site mutation with a stated negative result.

### C2 — `worktree_escape` raising `ask` on read-only cross-worktree access (dropped)

Claim: the guardrail fires `ask` even for reads naming another worktree's absolute
path, stopping the coordinator's watch with exit 5. This was **not re-verified or
re-ingested**: open PR #47 already carries it, in the same page, with the same
evidence. See Open-PR check.

### C3 — dispatch-binding failure stages (folded onto PR #47)

Claim: before binding a next-phase task to an existing terminal, confirm the
preview shows the idle prompt, and branch on the reported failure stage —
`runtime_unavailable` (busy substrate → wait for idle, create a fresh task, the
consumed one cannot be retried) vs `agent_unconfigured` (the agent process died
though the terminal survives → close the terminal and create a new worker-mode
agent) — and always pass `--terminal` together with `--worktree`.

Confidence: **field-tested** — three measurements in one dev-loop/Orca run (i43
busy-terminal dispatch consumed its task; i45 `agent_unconfigured` recovered by
closing the terminal and recreating the agent, that worker then finishing with
1284 tests passing; `terminal_worktree_mismatch` resolved by pairing
`--worktree`). No external documentation exists for these vendor-specific status
strings, so it is not claimed as `verified`. PR #47 already covers the
`runtime_unavailable` third of it; the remaining two stages were posted to that PR
rather than ingested here (see Open-PR check).

## Existing-layer check

Routed C1 via `INDEX.md` → testing ("writing or structuring automated tests:
level choice, cases/assertions…") → `wiki/testing/index.md`, quality category.
Routed C2/C3 via `INDEX.md` → infrastructure ("multi-agent orchestration (worker
liveness signals, shared run state, tmux pane delivery, completion gates,
worktree-isolated workers)") → `wiki/infrastructure/index.md`, agent-orchestration.

Pages read: testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, testing-quality-harness-reverse-controls, infrastructure-agent-orchestration-worktree-isolated-workers, backend-common-change-impact-call-site-enumeration

Also read (index/plumbing, not pages): `INDEX.md`, `wiki/testing/index.md`,
`wiki/infrastructure/index.md`, `templates/page.md`, `log.md`. Plus the three
unmerged pages proposed by open PR #49 (`unasserted-return-fields`,
`value-preserving-refactor-assertions`, `stale-artifact-baselines`), fetched from
that PR's head — they are not in this checkout and so are deliberately absent from
the `Pages read:` line above.

**Overlaps found, and why C1 is a new page rather than an append:**

- `tests-that-cannot-fail` is the closest neighbour and already covers the *proof
  technique* — "Seed one mutation per assertion, not one per file, and require
  exactly the test that owns that assertion to redden", plus the restore-by-copy
  and confirm-by-suite-total steps that C1's evidence exercised. C1's contribution
  is a different axis: an enumeration of the *production code's* return sites
  performed **before** any test exists. That page's granularity is per existing
  assertion; a handler with three returns and one test has nothing at two of the
  sites to be granular about. Appending would have buried a case-selection rule
  inside a page whose load-when is "reviewing tests that always pass".
- `minimum-case-set` owns case selection but organises it by behaviour and input
  boundary. Two return sites can share every input class and differ only in which
  branch ran, so the exit-path axis is not derivable from its tables. The new page
  states this relationship explicitly rather than restating the normal/error/
  boundary rule.
- `harness-reverse-controls` governs citing a harness's aggregate score; C1's step
  5 (cite sites, not percentages) points at it in spirit, but the trigger differs —
  no harness is involved here, only hand-seeded reversions.
- `backend-common-change-impact-call-site-enumeration` is the same *method*
  (enumerate the sites in the code before acting) applied to callers rather than
  returns. Genuinely adjacent → linked both ways.

**Conflicts flagged:** none. No existing page gives a directive C1 contradicts.

**Related-links added:** forward links from the new page to
`testing-quality-tests-that-cannot-fail`, `testing-quality-minimum-case-set`,
`testing-quality-harness-reverse-controls`,
`backend-common-change-impact-call-site-enumeration`; back-link added on
`call-site-enumeration`.

**Back-links deliberately deferred** on `tests-that-cannot-fail`,
`minimum-case-set` and `harness-reverse-controls`: both open PRs (#47 and #49)
already modify those files' `related:`/`last_verified` lines, and a third
same-line edit would produce a merge conflict for no routing benefit — the forward
links already work, and `wiki/testing/index.md` (which this PR does edit, one row)
is the routing surface. Add the three back-links in a follow-up once #47/#49 land.
`wiki/testing/index.md` may still conflict trivially with #49's quality-table
additions; the resolution is to keep all added rows.

## Open-PR check

Open `knowledge/*` heads listed with
`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`:

| PR | Head | Touches |
|----|------|---------|
| #47 | `knowledge/dch0202-20260806-130040` | `infrastructure/agent-orchestration/{control-signals-vs-primary-artifacts,worktree-isolated-workers}`, `platforms/filesystems/permissions-and-exec-bits`, `testing/quality/{guard-shape-vs-consequence,tests-that-cannot-fail}`, both indexes |
| #49 | `knowledge/dch0202-rsquare-20260806-142309` (fork `dch0202-rsquare`) | `testing/quality/` — 3 new pages (`unasserted-return-fields`, `value-preserving-refactor-assertions`, `stale-artifact-baselines`) + 5 modified, `testing/index.md`, `log.md` |

Diffed both against `origin/main` before ingesting (#47 via `git diff`; #49's head
lives on a fork, so its files were read through
`gh api …/contents/…?ref=refs/pull/49/head`).

**Per-candidate verdicts:**

- **C1 → new.** No overlap with either PR. #49's three new testing/quality pages
  are about unread return *fields* of a composite value, value-preserving refactor
  assertions, and stale "before" baselines — none concerns which return *site*
  executed. #47's `tests-that-cannot-fail` edit is unrelated (its usage-limit and
  dispatch-timing rows land in the infrastructure pages).
- **C2 → drop.** #47 already adds to `worktree-isolated-workers.md` the edge-case
  row "A read-only command (`ls`, `grep`, `awk`, `git status`) naming the main
  checkout's or another worktree's absolute path raises an `ask` escalation
  anyway, halting the watch", with the version-dependence caveat, the
  read-probe-before-fan-out instruction, the escalation round-trip budget, and the
  "state pre-approved reads in the first briefing" advice — plus a source line
  carrying the identical exit-5 field evidence. The candidate adds nothing. Worth
  recording: that row **contradicts the 2026-08-05 reproduction already in the
  same page's Do-this table** (bare `cat`/`ls`/`grep` passed under guardrails
  1.0.0). #47 resolves it as version-dependence rather than overwriting, which is
  the right call, so no new conflict is raised here.
- **C3 → fold.** #47's new `control-signals-vs-primary-artifacts` row covers the
  `runtime_unavailable` stage (done-signal ≠ substrate release, wait for
  `tui-idle`, consumed task must be re-created). The `agent_unconfigured` stage,
  the `--terminal`/`--worktree` pairing, and the idle-prompt precheck are not in
  it. Those unique additions were posted to PR #47 as a suggested edge-case row
  with their field evidence
  (`https://github.com/choiyounggi/dev-loop/pull/47#issuecomment-5202279174`)
  rather than pushed to that branch — #47 is already under review, and both halves
  belong in one table row its author should merge deliberately. Not re-ingested
  here; doing so would have meant a second edit to the same table and a certain
  conflict.

## Routing decision

| Insight | Target | Action |
|---------|--------|--------|
| C1 | `testing` / `quality` / `policy-at-several-return-sites` (id `testing-quality-policy-at-several-return-sites`) | **New page.** Registered in `wiki/testing/index.md` under quality; `log.md` appended; back-link added on `backend-common-change-impact-call-site-enumeration` |
| C2 | `infrastructure` / `agent-orchestration` / `worktree-isolated-workers` | **No change** — already carried by open PR #47 |
| C3 | `infrastructure` / `agent-orchestration` / `control-signals-vs-primary-artifacts` | **No change here** — unique half folded onto open PR #47 as a review comment |

No new category was needed: `testing/quality` already holds case-selection and
test-provability pages, and C1 is both. No new domain, no `INDEX.md` change.

**Queue disposition.** All 3 rows retired to `~/.dev-loop/queue/.processed.jsonl`
— the ingested one, the folded one, and the dropped duplicate — so none re-crosses
the auto-flush threshold.
