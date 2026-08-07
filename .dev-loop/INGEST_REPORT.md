# Knowledge flush — 3 insight(s): 1 ingested, 2 dropped as in-flight duplicates

Queue drained: `~/.dev-loop/queue/7947837a-…jsonl` (1 row), `~/.dev-loop/queue/f1a3ae46-…jsonl` (2 rows).

## Verified best-practice

### C1 — Bound a new rejection rule with a corpus sweep before writing production code (INGESTED)

**Claim.** When adding a rule to a compiler/linter/parser/validator that will
start rejecting input the tool has been accepting silently, implement the
accept/reject predicate first as a throwaway script, run it over the entire
corpus, and record the reject count *and the rejected-path list* in the plan.
The rule is only settled when that list equals the set already known to be
defective.

**Sources checked (all fetched this session):**

- <https://github.com/AriPerkkio/eslint-remote-tester> — the tool exists to answer
  "Does the rule report the intended patterns? Does the rule falsely mark valid
  patterns as errors?", because "the AST of Javascript and Typescript can cause
  very unexpected results it is not enough to test the rule only against unit
  tests and a small amount of repositories". Comparison mode reports "the exact
  changes in ESLint reports their code changes introduced".
- <https://github.com/rust-lang/rust-clippy/blob/master/lintcheck/README.md> —
  lintcheck "Runs Clippy on a fixed set of crates read from
  `lintcheck/lintcheck_crates.toml` and saves logs of the lint warnings into the
  repo. We can then check the diff and spot new or disappearing warnings."
  (fetched via `raw.githubusercontent.com`; the cited `blob/` URL is the same file.)
- <https://github.com/rust-lang/crater> — "Crater is a tool to run experiments
  across parts of the Rust ecosystem. Its primary purpose is to detect regressions
  in the Rust compiler, and it does this by building a large number of crates,
  running their test suites and comparing the results between two versions of the
  Rust compiler." Used specifically to measure the extent of breakage of a
  potentially breaking change (e.g. a lint becoming deny-by-default) before it lands.

**How verified / what is *not* sourced.** Three independent ecosystem tools
implement the same method — sweep the corpus, record verdicts, diff them — which
establishes the core directive. What the three tools do *not* establish is the
candidate's ordering refinement: they implement the rule in the production tree
first and then sweep. The "throwaway predicate *before* production code, and the
reject list must match the known-defective set" part rests on the session's own
reproducible field run (linkly #53: 148 sources swept — 40 `.lnpl` files + 108
triple-quoted inline programs in tests — 2 rejects, both the QA probes the issue
named; one false positive in the first draft rule caught at plan time, where the
guard legitimately owned its block). The page's Sources section says this in a
final bullet rather than implying the ordering is doc-backed.

**Confidence: `verified`** — method sourced to official tool docs, ordering
refinement backed by a reproducible measurement. Nothing was upgraded on the
strength of assertion alone.

The candidate's own honest limitation is preserved as an edge-case row: the text
sweep could not index fixtures assembled with `.replace()`, so those 5 sites were
verified by hand. That partial-index failure is the same shape as the existing
`call-site-enumeration` page's keyword-search blind spot, which is why the two
are cross-linked.

### C2 — guardrail `worktree_escape` fires on read-only cross-worktree access (DROPPED)

Not ingested; superseded in flight (see Open-PR check). Verification note for the
record: the candidate's premise is **partially wrong**. PR #51 carries a local
reproduction (guardrails 1.2.0, macOS) showing that a pure read of a sibling
worktree passes — `grep`, `awk`, `cat`, `git -C … status` all returned clean —
and that `ask` fires only when a main-root mention survives the strip *and* a
write verb (`rm|mv|cp|tee|mkdir|touch|install|dd`) or a redirect to an absolute
path appears anywhere in the same command string. Ingesting this candidate as
written would have contradicted a better-evidenced page.

### C3 — pane/dispatch binding failure taxonomy (DROPPED)

Not ingested; superseded in flight. PR #51's
`infrastructure/agent-orchestration/pane-delivery-confirmation.md` already carries
all four of this candidate's rows (check for the idle prompt before binding; the
runtime-unavailable stage → wait and bind a fresh unit; the agent-unconfigured
stage → close the pane and create a new worker-mode agent; always pass the
worktree alongside the pane), plus an `Instead of` row for branching on the stage,
sourced to the same three field dispatches this candidate cites and corroborated
against the shipped `orca-worker-start.sh` comment.

## Existing-layer check

Routed C1 via `INDEX.md` → `backend` ("language-agnostic `common/`: … call-site
enumeration before a contract change"), then `wiki/backend/index.md` →
`change-impact`. Cross-checked `testing` and `qa` indexes before settling, since
the harvested hint said `testing`.

Pages read: backend-common-change-impact-call-site-enumeration, testing-quality-guard-shape-vs-consequence, qa-process-regression-scope, backend-common-api-design-unenforced-declarations, testing-quality-checks-that-cannot-pass, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-pane-delivery-confirmation

Index "load when" lines were read for every page in `wiki/testing/index.md`,
`wiki/qa/index.md` and `wiki/backend/index.md`; the pages above are the ones whose
lines overlapped and were opened in full.

**Overlaps found, and why none of them absorbed C1:**

| Page | Overlap | Verdict |
|------|---------|---------|
| `backend-common-change-impact-call-site-enumeration` | Same category and the same "state the method next to the count / treat a search as a partial index / re-run after the edit" discipline — but its trigger is a *callee contract* change and its unit is a call site | Distinct trigger (input corpus vs call sites) → new page, cross-linked both ways |
| `testing-quality-guard-shape-vs-consequence` | Both concern a rule going red on a legitimate artifact | Its trigger is a guard that is **already red**; C1's is a rule that does not exist yet. Linked one-way from C1's "When this applies" and from the exemption-list `Instead of` row |
| `qa-process-regression-scope` | Both bound the blast radius of a change | That page picks what to *re-test* for a release; C1 sizes a rule before it is written. Linked both ways |
| `backend-common-api-design-unenforced-declarations` | Adjacent decision — whether unimplemented declarative input should reject/warn/ignore | C1 starts *after* "reject" was chosen. Linked one-way (that page is edited by two open PRs; no reciprocal edit, to avoid a third conflicting hunk) |
| `testing-quality-checks-that-cannot-pass` | Cited for the "sweep rejects zero inputs" edge case | Reference only |

**Conflicts flagged:** none. No merged page carries this trigger — a grep over
`wiki/` for `corpus sweep|previously-accepted|tightening a validator|rejection
rule` returned nothing.

**Merged vs created:** created 1 new page (no existing page shares the trigger,
so merge-before-create does not apply). No new category — `change-impact` already
exists and its scope covers this.

**Related links added:** `call-site-enumeration` ← → new page;
`regression-scope` ← → new page.

**Conflict note for the reviewer:** `wiki/backend/index.md` is also touched by open
PR #51 (which adds a `widening-a-closed-value-table` row to the same
`change-impact` table). Expect a small table-level conflict if both land; the two
rows are independent.

## Open-PR check

Listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`,
then fetched each as `pull/<n>/head` and diffed `origin/main..pr<n> -- wiki/`.

Open heads: **#57, #56, #55, #52, #51, #50, #49, #47.**

| Candidate | Overlapping head(s) | Verdict |
|-----------|--------------------|---------|
| C1 corpus sweep before a rejection rule | none — additive-line scan for `corpus\|sweep\|reject\|previously-accepted\|lint rule\|new rule\|throwaway\|tighten` across all 8 heads matched only unrelated contexts (#52: a `subprocess` encoding row and a mutant-triage line; #51: a pane-bind row, a README number sweep, and the `widening-a-closed-value-table` index line) | **new** — ingested here |
| C2 guardrail read-only escalation | **#51** — `wiki/infrastructure/agent-orchestration/worktree-isolated-workers.md` adds the row "The escalation is read-only in substance and the coordinator must clear it → Budget the round trip (read the recorded escalation → approve → clear `escalations/` → restart the watcher) and state in the worker's first brief that reads are approved and only writes outside the worktree are refused", plus three rows and a reproduction that correct the candidate's premise | **drop** — pending duplicate with nothing unique to fold; the open PR's form is strictly better (it fixes the read-vs-write claim) |
| C3 pane binding failure taxonomy | **#51** — `wiki/infrastructure/agent-orchestration/pane-delivery-confirmation.md` adds all four rows plus an `Instead of` row and a field-observation source line covering the same three dispatches | **drop** — pending duplicate, nothing unique to fold |

No sibling duplicate PR was opened, and nothing was pushed to #51's branch (it
already carries the content in equal-or-better form, so there was nothing to add).

## Routing decision

| Insight | Target | New category? |
|---------|--------|---------------|
| C1 | `backend` / `change-impact` / [`corpus-sweep-before-a-rejection-rule`](../wiki/backend/common/change-impact/corpus-sweep-before-a-rejection-rule.md) — id `backend-common-change-impact-corpus-sweep-before-a-rejection-rule` | No. `change-impact` already means "enumerate the affected set before changing a contract"; a validator that starts rejecting previously-accepted input is a narrowing of that contract, and the corpus is the affected set. `testing` (the harvested hint) was rejected — that domain is for writing automated tests, and this is a plan-time measurement; `qa/process` was rejected — its regression scoping decides what to *re-test*, not how to bound a rule that has not been written |
| C2 | — | dropped (in-flight duplicate of #51) |
| C3 | — | dropped (in-flight duplicate of #51) |

Files changed: `wiki/backend/common/change-impact/corpus-sweep-before-a-rejection-rule.md` (new, 75 body lines),
`wiki/backend/index.md` (+1 routing row), `wiki/backend/common/change-impact/call-site-enumeration.md`
(+1 `related:` id), `wiki/qa/process/regression-scope.md` (+1 `related:` id), `log.md` (+1 entry).

All three queue rows are retired — the ingested one and both drops — so nothing
re-crosses the auto-flush threshold.
