# Knowledge flush — 4 insight(s)

Claimed queue ids: `475884eefc1cdb16`, `4d7177433b8112d0`, `2552c5c6c0431371`, `f8015ebd7aa0489d`.
Outcome: 1 new page, 0 merges, 3 drops (project-specific plan-gap rows). Nothing is left `unverified`.

## Verified best-practice

**1. `475884eefc1cdb16` — a root resolver with a cwd fallback is unobserved while the fixture root is the test's cwd** (→ `confidence: verified`)

Claim: when a test harness `cd`s into its temp directory and builds the fixture project
there, the resolver's fallback (the working directory) returns the expected root, so
deleting the search leaves every test green. Separate the fixture root from the cwd
(`$WORK/proj` vs `$WORK/elsewhere`) and give each documented stage — start directory,
ancestor, fallback — its own case. "One mutant went red" does not establish that the
search is guarded.

How it was verified:

- **Reproducible check, run in this flush** (POSIX `sh`, macOS arm64; marker-walk resolver
  with a `$PWD` fallback; 3 mutants x 2 fixture layouts; known-good control = the
  unmutated resolver, green in both layouts):

  | Variant | Coincident layout (cwd is the root) | Separated layout (`proj` / `elsewhere`) |
  |---------|-------------------------------------|------------------------------------------|
  | original | GREEN | GREEN |
  | walk deleted | **GREEN** (blind) | RED — ancestor, start-directory |
  | walk starts at the parent | **GREEN** (blind) | RED — start-directory only |
  | overshoot (returns the found dir's parent) | RED | RED |

  This reproduces both halves of the claim: the deletion survives under the coincident
  layout *while another mutant reddens*, and under the separated layout the
  start-at-parent mutant is caught by exactly one stage case. A second check confirmed the
  page's nested-fixture edge row: with a marker on a directory above the scratch tree, the
  no-marker case returned that host directory instead of the `elsewhere` fallback.
- https://bats-core.readthedocs.io/en/stable/faq.html (fetched 2026-09-17) — "The working
  directory is simply the directory where you started when executing bats. If you want to
  enforce a specific directory, you can use cd in the setup_file/setup functions." The
  runner does not separate cwd from the fixture; the `cd` in `setup` is what creates the
  coincident layout.
- https://en.wikipedia.org/wiki/Mutation_testing (fetched 2026-09-17) — the kill
  conditions: reach the mutated statement, infect the state, and "The incorrect program
  state … must propagate to the program's output and be checked by the test." The
  coincident cwd is a propagation failure: the fallback maps the infected state back to
  the expected output.
- https://arxiv.org/abs/2410.21904 (fetched 2026-09-17) — Mirian-Hosseinabadi, "Formal
  Analysis of Reachability, Infection and Propagation Conditions in Mutation Testing";
  cited for the RIP terminology only. The abstract page does not define the three
  conditions individually, and the page quotes only the sentence that was actually there.
- Field evidence: the originating session's resolver (`project_root_for` in dev-loop
  `skills/wiki-plan/scripts/plan-gate.sh`, worktree commit `5afddde`) and its
  `elsewhere`-separated bats cases were read and confirmed to exist. **Its mutants were not
  re-run in this flush**; the page labels that bullet a field report and says so.

Not used: pytest's rootdir documentation was fetched as a candidate second resolver
example, but its fallback is "the already determined common ancestor", not plainly the
cwd, so it is not cited.

**2. `4d7177433b8112d0` — `--layer bundled|local` flag shape for wiki-structure-checks** → dropped.
**3. `2552c5c6c0431371` — the literal log.md entry text for t5-ref-impl** → dropped.
**4. `f8015ebd7aa0489d` — wiki-lint row 9 stays, README gains one tree line** → dropped.

All three are `plan-gap` rows whose trigger is "Planning <task>: deciding <one repo's
artifact>" and whose directive is that repo's design record (argv positions, a log line's
wording, a README tree entry). None has a situation a task in another repo could route on,
and the cited research URLs support the surrounding plan, not the directive. Row 2's
rejected alternative (inferring a mode from a path substring) is the only generalizable
fragment; it arrives with no evidence beyond the design doc, so it was not promoted.
These are recorded in the repo's own `plans/*/design.md`, which is where they belong.

## Existing-layer check

Routed via `INDEX.md` → `wiki/testing/index.md` → category `quality` (verifying that tests
can fail). A whole-wiki keyword sweep (`cwd|working director|project.root|ancestor|walk up|
upward|path.resol|fallback`) matched 42 files; the testing-domain and path-resolution hits
were opened.

Pages read: testing-quality-tests-that-cannot-fail, testing-quality-default-values-under-test, testing-quality-surviving-mutant-equivalence-triage, testing-quality-harness-reverse-controls, testing-data-test-data-and-isolation

- `tests-that-cannot-fail` — owns the general "break it and require red" procedure and the
  "another writer sets the same observable" row. Adjacent mechanism, different trigger: it
  has no row for a fallback path that coincides with the expected value, and at its size a
  new section would not fit the 120-line budget. → linked, not merged.
- `default-values-under-test` — closest sibling: a mechanism-test fixture that repeats the
  shipped default makes the dropped-lookup mutant unkillable. Same shape (defect in the
  input, not the assertion), different subject (a numeric default vs. a filesystem search
  and its cwd). → new page cross-references it; reciprocal `related:` added.
- `test-data-and-isolation` — covers temp directories and env isolation; nothing on cwd vs
  fixture root in the merged copy (the open-PR copy is discussed below).
- `surviving-mutant-equivalence-triage`, `harness-reverse-controls` — linked for the
  "deletion survives although cwd is separate" edge; no overlap.

Created: `wiki/testing/quality/path-resolver-fixtures-with-coincident-cwd.md` (72 body lines).
Updated: `wiki/testing/index.md` (+1 row), `default-values-under-test.md` (+1 related id), `log.md` (+1 entry).
Conflicts flagged: none. One deliberate asymmetry: `tests-that-cannot-fail` is linked from
the new page only — three open PRs (#179, #188, #191) each rewrite its single-line
`related:` list (a fourth, #186, edits the file elsewhere), and another edit of that line
would conflict with each of them.
Checks: `wiki-structure-checks.js wiki` — baseline 278 pages / 0 findings → 279 pages / 0
findings; `wiki-lint-prohibitions.js wiki` — 0 violations before and after.

## Open-PR check

Listed 16 open `knowledge/*` heads and fetched all 16: #179, #180, #181, #182, #183, #185,
#186, #187, #188, #189, #190, #191, #205, #207, #208, #209. For each head, the added lines
of every changed `wiki/` file were searched for the same overlap keywords.

- **#179** (`knowledge/choiyounggi-20260903-172728`) adds a row to `test-data-and-isolation`:
  tests that never `cd` into their temp directory read a real sandbox config through the
  code's upward walk, so "make every such test `cd "$BATS_TEST_TMPDIR"`". This is the
  **inverse** failure, and its remedy is the precondition for the one here — after that
  `cd`, a fixture built at `.` is the coincident layout. No shared directive. The new page
  points at `test-data-and-isolation` for that case. Verdict for candidate 1: **new**.
- Other keyword hits, each read: #188 `real-cli-spot-check-for-new-execution-paths` (a
  never-created spawn cwd → ENOENT), #179 `path-valued-config` (an empty `--out` resolving to
  the CWD), #183 `unix-domain-socket-path-length` (socket paths derived from the project
  root), #180 `portable-shell-scripts` (zsh word-splitting giving sessions one shared cwd),
  #208 `project-local-layer-over-shared-guidance` (where a local guidance layer lives —
  same originating feature, a design rule, nothing about testing the resolver). The
  `path-resolution.md` hits in #179/#181/#189 were the file path matching the pattern, not
  content. No overlap with testing a resolver.
- No open head touches `default-values-under-test.md` or creates a page on resolver tests.
- Candidates 2–4: #207 and #208 carry plan-gap batches from the same repo. Their added
  `wiki/` lines, and #209's, were searched for `--layer`, `reference_impl`,
  `wiki-contradiction`, `README`, `argv`, `positional`, `infer`: 0 hits in #207 and #208; 2
  in #209, both an unrelated `grep -qF … README.md` quoting example. They are dropped as
  project-specific, not as pending duplicates. Verdict: **drop**.

Expected merge friction: `wiki/testing/index.md` and `log.md` are edited by most open
heads, so this PR will need the usual one-row rebase there.

## Routing decision

| Candidate | Target | Decision |
|-----------|--------|----------|
| `475884eefc1cdb16` | `testing/quality/path-resolver-fixtures-with-coincident-cwd` (new page, existing category) | The harvested hint `domain: testing` holds. `quality` rather than `data`: the subject is whether a test can detect a defect (mutation-proven), which is what `quality` owns; `data` owns fixture creation and isolation, and receives the cross-link for the inverse case. No new category. |
| `4d7177433b8112d0` | — | Dropped: one repo's CLI argument spec. |
| `2552c5c6c0431371` | — | Dropped: one repo's log line. |
| `f8015ebd7aa0489d` | — | Dropped: one repo's README/skill-row decision. |
