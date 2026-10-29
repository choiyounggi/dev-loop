# Knowledge flush — 4 insight(s)

4 queue rows were claimed this run (`20261029-180005-48522`): all 4 ingested
(3 as edge rows on existing pages, 1 as a new page). Nothing was dropped,
nothing was folded into another open PR, nothing was released.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `8a67a97c4afd204c` — `grep -q` SIGPIPEs a runner mid-run before its own exit cleanup | testing | **ingested** — edge row in `testing-data-artifact-leakage-from-a-suite` (verified) |
| `f332524447ff2105` — a gates-ledger CHECK matches its own ledger file's recorded CHECK line | testing | **ingested** — edge row in `testing-quality-checks-that-cannot-pass` (verified) |
| `baac78b023efce53` — a failure-allowlist gate matches by test id alone, not by cause | testing | **ingested** — new page `testing-quality-id-only-failure-allowlist-gates` (field-tested) |
| `4067cf60d5d486f5` — a done-gate recounts a shared append-only log it keeps appending to itself | qa (routed to testing) | **ingested** — edge row in `testing-quality-completion-predicates` (field-tested) |

## Verified best-practice

**`8a67a97c4afd204c` — confidence: verified.** Claim: a verify/gate command
that pipes a test runner's output into `grep -q PATTERN` can get the runner
killed by `SIGPIPE` before the runner's own exit-time cleanup runs, because
`-q` exits as soon as it finds a match.
- https://www.gnu.org/software/grep/manual/grep.html — `-q`/`--quiet`/`--silent`:
  "Exit immediately with zero status if any match is found, even if an error
  was detected."
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html — POSIX
  `-q`: "the exit status shall be zero if an input line is selected, even if
  an error was detected" (confirms the early-exit contract independent of the
  rest of the input).
- https://man7.org/linux/man-pages/man7/pipe.7.html — "If all file descriptors
  referring to the read end of a pipe have been closed, then a write(2) will
  generate a SIGPIPE signal for the writing process." This is the mechanism
  that kills the runner: `grep -q`'s early exit closes the pipe's read end
  while the runner still has data to write.
- Field reproduction supplied with the candidate (vitest 4.1.12, Node 26.7.0):
  `bash -c 'npm test 2>&1 | grep -q …'` left 1 entry under `$TMPDIR`; the same
  command with `grep … >/dev/null` (reads to EOF) left 0; plain `npm test`
  left 0. I did not re-run this reproduction myself (no project checkout with
  this exact vitest config was available in this session); the POSIX/GNU
  citations independently establish the mechanism, so confidence is verified
  on the mechanism and field-evidenced on the specific vitest/temp-dir symptom.

**`f332524447ff2105` — confidence: verified.** Claim: a gates-ledger CHECK
that greps the repo for "no file still contains phrase X" can match the
ledger file itself, because the ledger records the CHECK's own command line
(which contains phrase X literally); and a hand-run verification of such a
CHECK from an interactive shell can disagree with the gate's real executor
because an interactive shell's `grep` can be a function or alias.
- The self-match half of this claim is a direct logical consequence of how
  the candidate's own gates ledger works (each row's `CHECK:` line is stored
  as literal text in a file under the scanned tree) — not something requiring
  an external citation beyond the already-wiki-documented ledger mechanism
  (`wiki/qa/process/scope-purity-checks.md` edge row on `.dev-loop/gates/`).
- The interactive-shell-vs-`sh -c` half is independently verified on this
  wiki already: `wiki/platforms/tools/search-evidence-from-a-wrapped-grep.md`
  states, with its own primary sources (Claude Code tools-reference docs,
  the ugrep binary's own `--help` output, and a 2026-10-08 local reproduction)
  that Claude Code's interactive Bash-tool shell defines `grep` as a shell
  function wrapping `ugrep` with different ignore-file/complexity behavior,
  and that "Child shells do not inherit it: `bash -c`/`sh -c` and the scripts
  you run resolve `grep` to `/usr/bin/grep`." I treated that already-verified
  page as the source for this half rather than re-deriving it, and
  cross-linked the two pages.
- Field reproduction supplied with the candidate (dev-loop orchestration,
  task `orch-prereq-1026-t268c`): under `sh -c` the search matched
  `./.dev-loop/gates/t268c-03.md` and the gate stayed UNMET; `type grep` in
  the authoring zsh session printed "grep is a shell function"; adding
  `--exclude-dir=.dev-loop` returned the gate to MET.

**`baac78b023efce53` — confidence: field-tested.** Claim: a gate that allows
a changed test suite's new failures by matching each failure's test id (or
module) against an allowlist, with nothing else checked, will pass any new
failure whose id happens to be on that list — including one with an
unrelated cause — so a real regression can slip through as "expected".
- I searched for an official/primary source specifically establishing this
  pattern (flaky-test and known-failure allowlisting literature) and did not
  find one precise enough to cite without overstating it — general flaky-test
  guidance (Google Testing Blog, Datadog, and others) discusses allowlisting
  masking real bugs in general terms, but I could not pin a quotable sentence
  to this specific id-vs-cause distinction, so I did not cite any of them.
  This stays `confidence: field-tested` on the candidate's own reproduction,
  not `verified`.
- Field reproduction supplied with the candidate (dev-loop orchestration,
  task `orch-r268-t5`): `classify_failures.py` printed `CLASSIFY_OK` on the
  real run; two planted bad outputs under `.claude/tmp/t5/classify-neg/` (an
  unrelated failing test, and an allowed id with its cause text removed) each
  produced exactly one `UNCLASSIFIED` line.

**`4067cf60d5d486f5` — confidence: field-tested.** Claim: a done-gate that
counts lines in a shared append-only log by re-running `grep -c` against the
live file, when the same worker whose artifact the gate is checking keeps
appending unrelated entries to that same log after the artifact was built,
will go red purely from those later appends, with the artifact itself
unchanged.
- This is a direct consequence of two already-verified wiki facts combined:
  POSIX `O_APPEND` write semantics (`wiki/infrastructure/agent-orchestration/concurrent-blackboard-append-file.md`,
  sourced to POSIX `write()`) guarantee the log keeps growing from concurrent
  appends, and `wiki/testing/quality/completion-predicates.md`'s own
  "decide completion by counting" directive assumes the count is stable
  unless the counted set changes for a real reason. I treated this as a
  field-tested edge case of that existing directive rather than a new
  verified claim, since no official doc states the "gate vs. own-later-writes"
  combination directly.
- Field reproduction supplied with the candidate (dev-loop orchestration,
  task `orch-r268-t9`): done-gate F8 went red after three `[t9] finding:`
  lines were appended to a shared log (216 lines vs. the 213 recorded when
  the gated artifact was built); filtering out the `[t9]`-tagged lines gave
  source=213 again, and `cmp` on the artifact body showed it unchanged.

## Existing-layer check

Pages read: testing-data-artifact-leakage-from-a-suite, testing-quality-checks-that-cannot-pass, testing-quality-gate-parsing-vs-command-execution, testing-quality-unchanged-function-gates, testing-quality-guard-shape-vs-consequence, testing-quality-completion-predicates, qa-process-scope-purity-checks, qa-process-completion-claims, infrastructure-agent-orchestration-gate-evidence-exit-code-class, infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-concurrent-blackboard-append-file, platforms-tools-search-evidence-from-a-wrapped-grep, debugging-network-epipe-write-ordering, testing-quality-harness-reverse-controls, testing-quality-surviving-mutant-equivalence-triage

- **testing-data-artifact-leakage-from-a-suite** — merge target for `8a67`. Its
  edge-case table already enumerates several distinct causes of a suite
  leaving temp dirs behind (async task abort, crashed/killed runs, subprocess
  output). The `grep -q`/SIGPIPE cause is a sibling in the same table, so it
  was added as one edge row + one Instead-of row, not a new page.
  `debugging-network-epipe-write-ordering` was read first because it is the
  only existing page mentioning SIGPIPE, but it is about TCP socket writes
  after a peer closes (a different mechanism) — no edit there, no link added
  (different domain, not genuinely adjacent).
- **testing-quality-checks-that-cannot-pass** — merge target for `f332`. It
  already has an edge row about `grep -q` masking a missing target across
  multiple glob paths (a different `grep -q` pitfall: exit-0-on-any-match
  across several file operands). The self-match-on-the-ledger case is a
  distinct edge case of the same "authoring/validating a gate check" page, so
  it was added as a new edge row + Instead-of row, cross-linked both ways with
  `platforms-tools-search-evidence-from-a-wrapped-grep` (read in full; it
  already states the `sh -c` vs. interactive-shell-function fact this
  candidate's second half relies on — reused rather than re-derived).
  `testing-quality-gate-parsing-vs-command-execution` and
  `testing-quality-unchanged-function-gates` were read as adjacent
  gate-authoring pages; neither's trigger matches this candidate closely
  enough to merge into (parser/executor trust separation; AST-diff gates).
  `testing-quality-guard-shape-vs-consequence` was read for "a repo-wide guard
  firing on a legitimate artifact" — it is about a shape-only guard needing a
  consequence check, not about a guard matching its own evidence record; not
  a merge target.
- **testing-quality-completion-predicates** — merge target for `4067`. Its
  "When this applies"/edge-case table is specifically about counting-based
  completion predicates; the append-only self-growth case is a new edge row +
  Instead-of row there, cross-linked (added) to
  `infrastructure-agent-orchestration-concurrent-blackboard-append-file` (the
  append-only shared-log mechanics this case depends on) and
  `qa-process-completion-claims` (general completion-claim evidence, already
  linked the other way). `infrastructure-agent-orchestration-session-completion-gates`
  and `infrastructure-agent-orchestration-gate-evidence-exit-code-class` were
  read as the closest infra-side gate pages; both are about phase/exit-code
  classification, not counting, so no edit there.
- **testing-quality-id-only-failure-allowlist-gates** — no existing page
  covers "allow a failure by test id/module alone"; `qa-process-scope-purity-checks`
  (read for its "planted bad input" proof pattern),
  `testing-quality-harness-reverse-controls` and
  `testing-quality-surviving-mutant-equivalence-triage` were read as the
  closest adjacent pages (two-sided proof via planted/mutated negative
  controls) and are linked from the new page's `related:`, but none shares
  this candidate's specific trigger (id-only failure allowlisting), so a new
  page was created rather than merged.

No conflicting directive was found on any page and no page was superseded.

## Open-PR check

Open `knowledge/*` PR heads at flush time (`gh pr list --repo choiyounggi/dev-loop
--state open --json number,headRefName,title --search "head:knowledge/"`): #315,
#310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293 (13 total).
I diffed the four whose titles plausibly overlapped by keyword against
`origin/main -- wiki/`:

- **#299** (`knowledge/dch0202-rsquare-20261023-143208`, fork
  `dch0202-rsquare/dev-loop`, title mentions "grep pitfalls") — touches
  `platforms/tools/bsd-vs-gnu-cli.md` (`grep -Z`/`--decompress` vs GNU `-Z`),
  `platforms/tools/search-evidence-from-a-wrapped-grep.md` (a `$`-anchor
  pattern reading 0 through the wrapper), and adds `gh-api-paginate-with-jq.md`.
  None of these are the SIGPIPE-on-`-q`, self-match-ledger, id-allowlist, or
  append-only-log mechanisms. Verdict: **new** for `8a67` and `f332`.
- **#304** (`knowledge/autoflush-20261027-110722-74636`, "a done-gate must
  count TAP results against the plan, not just zero failures") — edits
  `qa/process/completion-claims.md` to add a row about a gate reading a
  *still-running/backgrounded* test run's TAP output (plan line printed before
  all results, so "0 failures so far" looks done at 55/1731). This is a
  different mechanism from `4067`'s case (a *finished* run's own worker
  appending unrelated later entries to a shared log after the artifact was
  built) — one is "run not finished yet", the other is "run finished, but the
  log it's judged against keeps growing from something else". Verdict:
  **new**, not folded; noted as adjacent in the merged page's edge table via
  the existing (unedited) row left in place.
- **#309** (`knowledge/autoflush-20261029-124846-54962`, "bats fd 3 hang from
  long-lived processes; tmux server environment copied at start") — touches
  `platforms/processes/tmux-server-environment-at-start.md` and
  `testing/strategy/long-lived-processes-under-bats.md`; no overlap with any
  of the four candidates. Verdict: **new** (trivially, no shared ground).
- **#310** (`knowledge/autoflush-20261029-135519-11504`, "checker that reads
  the builder's own manifest; missing-name red for a brand-new function") —
  adds `testing/quality/checker-sharing-the-builders-input.md`: a checker
  that re-reads the SAME manifest/ledger the builder used to assemble a
  document, so a wrong value in the input reads as faithful (the oracle-
  coupling problem). This is a different mechanism from `f332`'s case, which
  is a literal substring self-match (the ledger's recorded CHECK text
  contains the phrase the CHECK searches for) rather than a shared/coupled
  oracle input. Verdict: **new**, not folded; I did not add a `related:` link
  to that page's id since it is not yet merged into `origin/main` (an
  unmerged id would fail link resolution).

All four candidates: **new**. Nothing was pushed to another branch and
nothing from this flush needs recording there.

## Routing decision

- `8a67a97c4afd204c` → `testing` / `data` → edge row + Instead-of row in
  `wiki/testing/data/artifact-leakage-from-a-suite.md`; `testing/index.md`
  "load when" line extended.
- `f332524447ff2105` → `testing` / `quality` → edge row + Instead-of row in
  `wiki/testing/quality/checks-that-cannot-pass.md`; `testing/index.md`
  "load when" line extended; bidirectional `related:` link added with
  `platforms-tools-search-evidence-from-a-wrapped-grep`.
- `baac78b023efce53` → `testing` / `quality` → new page
  `wiki/testing/quality/id-only-failure-allowlist-gates.md` (field-tested; no
  existing category fit, and `quality` already holds the sibling
  gate-authoring pages this one cross-links). `testing/index.md` row added.
- `4067cf60d5d486f5` → tagged `qa` by the candidate, re-routed to `testing` /
  `quality` → edge row + Instead-of row in
  `wiki/testing/quality/completion-predicates.md` (the exact existing page for
  counting-based completion predicates; `qa-process-completion-claims` is
  linked from it but is the wrong merge target — it is about claim evidence in
  general, not the counting mechanism). `testing/index.md` "load when" line
  extended.
- `log.md` has one entry appended for this run.
- `node scripts/wiki-lint-prohibitions.js wiki` → `directives: 86, compliant:
  86, violations: 0, info: 1` (the pre-existing info row is unrelated to this
  flush) — directive count unchanged from the pinned 86 in
  `tests/wiki-lint-prohibitions.bats`, so no bats edit was needed; re-ran that
  bats file and `tests/wiki-structure-checks.bats` to confirm (both fully
  green, including the "real wiki" cases).
- `node scripts/wiki-structure-checks.js wiki` → `pages: 469, indexes: 13,
  findings: 0`.

## Local-layer candidates

None of the 4 candidates this run claimed and ingested (`8a67a97c4afd204c`,
`f332524447ff2105`, `baac78b023efce53`, `4067cf60d5d486f5`) are local-layer:
all four are general gate/test-design patterns (grep pipeline signal
behavior, self-referential gate scans, failure-allowlist design,
counting-predicate design) that would apply unchanged in any codebase — none
names a specific repository's own files, modules, services, or
infrastructure as part of its directive.

The coordinator separately pre-excluded 12 plan-gap rows from two other
projects' plans before this run started (not claimed by this run, not read
or verified by it — listed here only because the brief asked this report to
record them):

| Row(s) | Repo / source | Target | Note |
|--------|---------------|--------|------|
| `317f31de7391fb88`, `0e06c969dce06eea`, `b84f3ab68e8acb52` | `shag` t9 RFC document layout/particles/status line | `wiki-local/qa/spec-process/rfc-document-layout-and-status-line.md` | decision record, no reusable page |
| `3c450e1290bde401`, `779a9b14ce2223b7`, `6bed879751fcd0d5`, `9c14c5f3508ba9f2`, `3981ae1aaf6aa5b3` | `shag` t4 metrics design | `wiki-local/backend/common/t4-metrics-design.md` | run wiki-ingest inside that project |
| `c9ee2d512241c394`, `456e3a9a6887de25`, `bf42e19276041954` | `shag` t6 sqlite backup command | `wiki-local/infrastructure/backup/sqlite-backup-command.md` | run wiki-ingest inside that project |
| `fe43fe37689f80de` | `bream` t2-api-root dependency floor spec | `wiki-local/testing/quality/api-root-dependency-floor-spec.md` | run wiki-ingest inside that project |

These 12 rows were not read in full by this run (only the one-line
descriptions in the task brief) — the domain/category targets above are my
best placement from those descriptions, to be confirmed by whoever runs
wiki-ingest inside `shag`/`bream`, not a verified routing decision.
