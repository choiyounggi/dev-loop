# Knowledge flush — 3 insight(s)

Drained 3 pending rows from `~/.dev-loop/queue` (2 session files: qa-t1-inventory-order ×1, qa-t4-rate-notify ×2). Result: **3 new pages under `wiki/qa/`, 4 reverse related-links, 0 dropped, all `confidence: verified`.** One candidate's stated evidence was corrected during verification (I-3: the runtime failure is an "EventEmit references undeclared event" error, not the "RunError" the queue row named — mechanism identical, wording fixed).

| # | Insight | Target page | Confidence |
|---|---------|-------------|-----------|
| 1 | `git status --porcelain` needs `-uall` before path-filtering for scope purity | `wiki/qa/process/scope-purity-checks.md` (new) | verified |
| 2 | Run a control pair before trusting a name-based value-override matrix | `wiki/qa/exploratory/override-control-pairs.md` (new) | verified |
| 3 | Execute every guard-true path once when static stages don't resolve references | `wiki/qa/exploratory/guard-true-path-coverage.md` (new) | verified |

## Verified best-practice

### 1 — Scope-purity checks over `git status` output need `-uall`

**Claim as queued:** default porcelain collapses an entirely-untracked directory to one `?? qa/` line, so a per-file path filter (`^?? qa/cases/...`) mis-matches and the purity gate reports a false violation; `-uall` expands to per-file lines.

**Verified two ways:**
- **Official docs** — [git-status](https://git-scm.com/docs/git-status): mode `normal` "Show untracked files and directories", mode `all` "Also show individual files in untracked directories"; the default equals `normal` and is user-configurable via `status.showUntrackedFiles`. The config point yields an addition the candidate lacked: a checkout with `showUntrackedFiles=no` hides untracked files entirely, turning the same gate into a **false pass** — so scripts must pass `-uall` explicitly, never rely on the ambient default. Also doc-verified for the page's edge cases: porcelain v1 rename lines are `R <orig-path> -> <path>` (two paths, one line), special-character paths are C-string-quoted unless `-z`, and ignored files are omitted unless `--ignored=matching`.
- **Local reproduction** (git 2.50.1 Apple Git-155, scratch repo, 2026-08-05): default porcelain printed exactly `?? qa/` and the per-file filter left it as a "violation" line (grep exit 0); `-uall` printed the three real file paths and the filter passed (grep exit 1). Matches the t1 session evidence (14 files proven in scope only after `-uall`).

→ `confidence: verified`.

### 2 — A control pair before trusting a value-override matrix

**Claim as queued:** when a CLI takes name-based runtime value injection (`--field key=value`) and ignores unknown keys, run a control pair that flips an observable before trusting any value matrix; uniform output across variants means "key silently ignored", not "behavior stable".

**Verified:**
- **Session reproduction with archived raw output** (lnpl 0.2.0, qa-t4-rate-notify, `qa/cases/rate-notify/evidence/05-modeB.md` + `evidence/raw/modeB-b*.txt`): five runs with bare names (`--field value=150/50/100...`) produced effectively identical step traces — guarded create step never fired, until-loop always hit its 16-round cap — with **exit 0 and zero warnings**. The tool's own help documents the policy: "Fields the workflow does not compare on are ignored; omitted ones default to 0." Switching to the canonical dotted name (`--field measurement.value=150`) flipped the guarded step, proving the lever, after which the matrix produced differentiated, meaningful rows.
- **Mechanism prevalence** — [pydantic models docs](https://pydantic.dev/docs/validation/latest/concepts/models/): "By default, Pydantic models won't error when you provide extra data, and these values will simply be ignored"; `ConfigDict(extra=...)` = `ignore` (default) / `allow` / `forbid`. This grounds the page's directive to prefer strict/forbid modes for measurement runs.
- **Citation dropped, not approximated:** I attempted to add Kohavi's A/A-test literature as a third source; the candidate URL (kdd.org PDF) could not be content-verified by fetch, so it is **not cited**. The in-repo page [testing-quality-harness-reverse-controls] (mutation-testing-sourced) carries the same "prove the instrument discriminates" principle and is linked instead.

→ `confidence: verified` (reproducible measurement with archived raw traces + official docs for the ignore-unknown mechanism).

### 3 — Guard-true path coverage when static stages skip reference resolution

**Claim as queued:** steps behind guards must be executed with the guard true at least once, because a pipeline whose compile/validation doesn't resolve cross-node references defers those errors to runtime, and guard-false runs return rc=0 forever.

**Verified:**
- **Session reproduction** (qa-t4-rate-notify, `qa/cases/rate-notify/evidence/04-modeA.md`): an `emit` referencing an undeclared event passed compile (0 errors) and IR validation (PASS); 6 of 7 runtime runs failed at the emit step with "EventEmit references undeclared event 'event.notification'"; the single run where a presence guard skipped emit exited 0. **Correction to the queue row:** the failure text is the above, not "RunError" — the page and this report quote the actual error. The same evidence file's bidirectional guard table (guard.1/2/3, true and false runs each, all three discriminating) is the template for the page's contrast-table directive, and its guard.3 zero-round observation (0-iteration `until` absent from the skipped list) became the "assert on executed steps, not skip markers" directive.
- **External grounding** — [ISTQB glossary, branch coverage](https://istqb-glossary.page/branch-coverage/): "The percentage of branches that have been exercised by a test suite. 100% branch coverage implies both 100% decision coverage and 100% statement coverage." The page applies this at whole-program QA level: a guard is a branch; N green runs down one side accumulate no evidence about the other.

→ `confidence: verified`.

## Existing-layer check

**Read:** root `INDEX.md`; `wiki/qa/index.md` (all 5 categories); `wiki/qa/exploratory/exploratory-sessions.md` (full); `wiki/testing/index.md`; `wiki/testing/quality/harness-reverse-controls.md`; `wiki/testing/quality/minimum-case-set.md` (full); `wiki/testing/quality/checks-that-cannot-pass.md` (trigger sections); plus repo-wide greps for `porcelain|untracked|-uall`, `control`, `branch coverage|guard|unknown key`.

**Overlaps found, all resolved as adjacency (cross-link), not duplication:**
- I-1 vs [testing-quality-checks-that-cannot-pass] — that page validates a check against known-good input; I-1 is a specific gate whose false verdict comes from git's output mode, and its directive 3 routes to that page for the both-ways control. Linked both ways. No existing page mentions porcelain/untracked mechanics (grep confirmed).
- I-2 vs [testing-quality-harness-reverse-controls] — same principle ("uniform verdict is a property of the instrument; run a control"), different situation: that page is about citing a *scoring harness's* verdict, I-2 about a *measurement matrix* through value injection. Kept separate, linked both ways.
- I-3 vs [testing-quality-minimum-case-set] — that page selects cases for automated tests of a function; I-3 covers runtime QA of guarded whole-program paths. Its "guarded upstream" edge row is about not forcing unreachable inputs — I-3's unreachable-guard row records the gap instead. Linked both ways.
- I-2/I-3 are siblings from the same probing activity — cross-linked to each other; I-3 also linked from [qa-exploratory-exploratory-sessions].

**Open-PR overlap scan (13 open `dev-loop:knowledge` PRs checked by title, closest three by body):** none covers these three insights. Flagged as *cousins, not duplicates*: PR #32's `infrastructure/config/keys-ahead-of-their-consumer` (unknown-key-ignoring consumers — mechanism shared with I-2, situation different: pre-declaring keys vs trusting a probe matrix); PR #24's `testing/quality/polling-completion-predicates` and PR #22's completion-predicate work (predicate controls — same control-run spirit as I-2, different artifact); PR #23's `guard-shape-vs-consequence` (artifact guards in tests, unrelated to runtime `when`/`until` guards). If #32/#24 merge first, a follow-up `related:` link from their pages to I-2's page is worth adding; no content conflict either way.

**Conflicts flagged:** none — no existing directive contradicts any of the three.

## Routing decision

- **I-1 → `qa/process/scope-purity-checks`.** Queue hint `qa` confirmed: the artifact is a release/session gate ("did this run stay in its lane"), owned by qa/process alongside release-gates and post-release-verification. Not `platforms` (no OS variance — git behaves identically everywhere) and not `testing` (nothing here writes test code); the git mechanics are the page's evidence, not its owner.
- **I-2 → `qa/exploratory/override-control-pairs`.** Queue hint `qa` confirmed: the situation is probing a live system's behavior during exploratory QA. The alternative home — `testing/quality` next to harness-reverse-controls — was rejected because that category's pages govern authoring/citing automated checks, while this page governs how to *measure* a system by hand; the shared principle is carried by the two-way `related:` link instead.
- **I-3 → `qa/exploratory/guard-true-path-coverage`.** Same category as I-2 (same probing activity, sibling pages). `testing/quality` rejected for the same reason as I-2.
- **No new categories.** All three landed in existing qa categories; `qa/exploratory` grows from one page to three, which matches its charter (manual/exploratory probing techniques).
- **Plumbing:** `wiki/qa/index.md` +3 "load when" rows; reverse `related:` added to `checks-that-cannot-pass`, `harness-reverse-controls`, `minimum-case-set`, `exploratory-sessions`; `log.md` +1 ingest entry.

**Invariants (checked mechanically):** body lines 53/53/56 (≤120) · id matches path 3/3 · all `related:` ids resolve · 0 banned vague qualifiers · every Instead-of row pairs prohibition with replacement · new pages listed in domain index 3/3.
