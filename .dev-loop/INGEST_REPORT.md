# Knowledge flush — 5 insight(s)

20 queue rows claimed (run `20261002-160812-98532`): 5 session insights ingested
(2 new pages, 3 amended pages), 15 plan-gap rows routed to the local layer and
retired. Lint after the edits: `wiki-structure-checks.js` → `pages: 357,
indexes: 13, findings: 0` (355 before); `wiki-lint-prohibitions.js` →
`violations: 0` (same as the untouched tree).

## Verified best-practice

1. **A multi-kilobyte prompt goes to a pane as a file pointer; check the pointer's
   first words arrived, then confirm consumption as usual** (queue `2912961001e20146`). Checked
   https://code.claude.com/docs/en/terminal-config ("Paste large content"): input
   over 800 characters or more than three lines collapses to a placeholder, "For
   very large inputs such as entire files or long logs, write the content to a file
   and ask Claude to read it instead of pasting", and one terminal "can also drop
   characters from very large pastes". The head-loss itself is a field observation
   (3,411-byte prompt, wrapper reported "submitted (confirmed)", pane showed the
   prompt starting mid-word, worker idle; a file pointer was delivered). The page
   states the loss as observed, not as a documented mechanism.
   Confidence: page stays `verified` (official recommendation + field observation).
2. **Hide every lookup source before trusting a "tool absent" reproduction**
   (queue `cd6eae14addede62`). Checked
   https://docs.python.org/3/library/shutil.html#shutil.which (`PATH`, falling back
   to `os.defpath` when unset; a `path=` argument searches other directories) and
   https://cmake.org/cmake/help/latest/command/find_program.html (search order
   continues past `PATH` to platform prefixes and hard-coded `PATHS`;
   `NO_DEFAULT_PATH`, `NO_SYSTEM_ENVIRONMENT_PATH`). Reproduced locally (Python
   3.14): a resolver with a fixed-prefix fallback still returned the tool with
   `PATH=/usr/bin:/bin` and the override variable pointed at an empty directory;
   `None` only after the prefix was replaced too. Also checked: `shutil.which("ls")`
   returns `/bin/ls` with `PATH` unset and `None` with `PATH=""`. Confidence: `verified`.
3. **Judge a patched load run against a band fixed from the unpatched arm**
   (queue `f519c20ea6a97a06`). Checked
   https://gernot-heiser.org/benchmarking-crimes.html ("Relative numbers only":
   "Always give complete result, not just ratios (unless the denominator is a
   standard figure)"; "No indication of significance of data"). Field numbers
   re-computed: patched worst interval 4.73 ms against its own ~2.3 ms first-window
   mean is ~2.05×, while it is ~1% of the unpatched 386 ms. Merged into a page that
   is already `verified`.
4. **A connection shared across request threads is checked out per request, not
   locked per call** (queue `ea4f4f5da9707f09`). Checked
   https://www.psycopg.org/psycopg3/docs/advanced/async.html ("Connection objects
   are thread-safe…"; "All the cursors that share the same connection will also
   share the same transaction"). Reproduced locally with `sqlite3`, 8 threads × 40
   requests: per-call lock → 236 of 320 failed with `cannot start a transaction
   within a transaction`; whole-request checkout through `queue.Queue` → 0 errors,
   320 rows. Merged into a page that is already `verified`.
5. **An extension package installed in the test environment changes results with
   no diff** (queue `b99fa9830c9d1689`). Checked
   https://packaging.python.org/en/latest/specifications/entry-points/ ("a mechanism
   for an installed distribution to advertise components…"; `entry_points.txt` in
   `*.dist-info`), https://docs.python.org/3/library/importlib.metadata.html#entry-points,
   and https://docs.pytest.org/en/stable/how-to/plugins.html ("If a plugin is
   installed, pytest automatically finds and integrates it"; `-p no:NAME`,
   `PYTEST_DISABLE_PLUGIN_AUTOLOAD`, `--disable-plugin-autoload` added in 8.4).
   Reproduced locally: `entry_points(group=…)` went `[]` → `['fake']` → `[]` as a
   metadata-only `dist-info` directory was added and removed; `.load()` raised
   `ModuleNotFoundError`. Confidence: `verified`.

An independent adversarial review (fresh context, read-only) re-fetched all eight
source URLs and found every quote present; its 10 findings (CMake search order
completed, unset-vs-empty `PATH` corrected, skip-count claim narrowed, band must be
fixed before the patched runs, pointer check ordered before consumption checks,
return-after-commit, and four wording fixes) are applied. Not verified: the exact
installer behaviour for a `dist-info` with no install record — the page states it
as a condition ("when the installer refuses"), not as a fact.

Nothing in this PR is `unverified`. Three pages were re-dated `last_verified:
2026-10-02` because their Sources sections were re-checked for the new rows only;
their older rows were not re-verified in this flush.

## Existing-layer check

Routed through `INDEX.md` → the infrastructure, platforms, debugging, backend,
testing and qa domain indexes, a keyword grep over all of `wiki/`, and one
`wiki_search` (k=5) per candidate plus one for the open-loop plan-gap.

Pages read: platforms-processes-driving-a-tui-in-a-tmux-pane, infrastructure-agent-orchestration-pane-delivery-confirmation, debugging-performance-attributing-a-benchmark-speedup, backend-common-concurrency-shared-state-and-pools, platforms-processes-non-interactive-cli-invocation, debugging-methodology-hypothesis-testing, debugging-performance-profile-before-optimizing, backend-common-orm-transaction-boundaries, testing-data-test-data-and-isolation, qa-environments-test-environment-parity, debugging-methodology-reproduce-first, testing-quality-harness-reverse-controls, testing-quality-tests-that-cannot-fail

The first four were read in full; the other nine were read for their trigger
section and frontmatter only.

- Insight 1: `driving-a-tui-in-a-tmux-pane` and `pane-delivery-confirmation` cover
  queued-vs-consumed input and the collapsed-paste placeholder; neither says to
  send a file pointer for a large payload or to confirm by the prompt's head.
  **Merged** as one edge case + one Instead-of row on `driving-a-tui-in-a-tmux-pane`.
  No conflict.
- Insight 2: `compiler-sysroot-on-macos` has the opposite case (tool off `PATH`
  → harness takes its absent branch by accident); `reproduce-first` is the generic
  entry point. No page covers deliberately hiding a tool. **New page.**
- Insight 3: `attributing-a-benchmark-speedup` step 5 covers run-to-run spread;
  `profile-before-optimizing` covers distributions. Neither covers a pass rule
  whose denominator the patch moves. **Merged** as one edge case + one Instead-of row.
- Insight 4: `shared-state-and-pools` covers pool sizing and nested acquisition;
  `transaction-boundaries` covers where a transaction starts and ends. Neither
  covers the unit of exclusivity for one shared connection. **Merged** into
  `shared-state-and-pools`.
- Insight 5: `test-data-and-isolation` covers state leaking between tests, not
  state installed into the environment;
  `environment-resync-removes-undeclared-packages` is the reverse direction.
  **New page**, back-link added on the resync page.
- Conflicts flagged: none.
- Noticed, not changed: `pane-delivery-confirmation` quotes the paste threshold as
  "more than two lines"; the vendor page now reads "more than three lines".
- Back-links deferred because open PRs rewrite those `related:` lines:
  `reproduce-first` and `tests-that-cannot-fail` (#223), `path-resolution` and
  `compiler-sysroot-on-macos` (#227), `test-data-and-isolation` (#228).

## Open-PR check

Open `knowledge/*` heads listed with `gh pr list --search "head:knowledge/"`:
#223 (`…20260927-220735`), #225 (`…20260928-082803`), #226 (`…20260928-092831`),
#227 (`…20260928-103056`), #228 (`…20260928-134840`), #229 (`…20260928-145025`),
#230 (`…20260928-155239`), #231 (`…20260928-191901`), #233 (`…20261001-150222`).
Each head was diffed against `origin/main` under `wiki/`; added lines were
searched for the five candidates' terms (entry point, load test, open-loop, rps,
file pointer, fallback path, hardcoded, checkout pool, per-call lock, begin/commit,
own baseline, unpatched). Three lines matched across #233 and #225; all three are
unrelated uses of the words ("entry-points" in a mobile page id, "hardcoded-defaults
mutation").

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| 1 file pointer for a large prompt | none (#233 touches `non-interactive-cli-invocation` `related:` only) | new |
| 2 hiding a tool | none (#227 touches `compiler-sysroot-on-macos` and `path-resolution` `related:` only) | new |
| 3 unpatched-arm band | none (#223 touches `hypothesis-testing` `related:` only) | new |
| 4 per-request checkout | none | new |
| 5 installed extensions | none (#228 touches `test-data-and-isolation` `related:` only) | new |

No page this PR edits is edited by an open PR, so no merge conflict is expected.

## Routing decision

| Insight | Target | Action |
|---------|--------|--------|
| 1 | `platforms/processes/driving-a-tui-in-a-tmux-pane` | amend (+1 edge case, +1 Instead-of, +2 sources) |
| 2 | `debugging/methodology/hiding-a-tool-to-reproduce-its-absent-branch` | new page in an existing category |
| 3 | `debugging/performance/attributing-a-benchmark-speedup` | amend (+1 edge case, +1 Instead-of, +2 sources) |
| 4 | `backend/common/concurrency/shared-state-and-pools` | amend (+1 edge case, +1 Instead-of, +3 sources) |
| 5 | `testing/data/installed-extensions-discovered-at-test-time` | new page in an existing category |

No new category. Insight 1 arrived with domain hint `infrastructure`; it went to
`platforms/processes` because the page that owns "what to send into a pane"
lives there and the infrastructure page links to it. Insight 2 arrived with hint
`testing`; it went to `debugging/methodology` because the trigger is a
reproduction, next to `reproduce-first`. Index rows updated in the debugging,
testing, platforms and backend indexes; three `log.md` entries added.

## Local-layer candidates

All 15 `plan-gaps` rows come from planning sessions in one project (`linkly`).
Each directive names that repository's files, tests, RFC numbers or changelog
wording, so each is excluded here; run wiki-ingest inside that project.

| Queue row | Topic | Local target |
|-----------|-------|--------------|
| `6866747753c7e4aa` | load-generator model for one measurement task (open-loop, copied from a project script) | `wiki-local/debugging/performance/load-generator-model.md` |
| `b7a8e012231927ce` | two out-of-scope facts about refusal order in `build` vs `diff` | `wiki-local/backend/errors/refusal-order-build-vs-diff.md` |
| `ac72abe3592e8c3d` | no CHANGELOG change for one task | `wiki-local/qa/deliverables/changelog-scope.md` |
| `13c4f4667902016e` | placement of three tests in one test class | `wiki-local/testing/strategy/test-placement.md` |
| `08ba8d8df16ec44c` | keep a mutation anchor byte-for-byte | `wiki-local/testing/quality/mutation-anchors.md` |
| `c58794fe0de09ccd` | one docstring rewrite | `wiki-local/backend/errors/refusal-order-build-vs-diff.md` |
| `2fcb01dee7011c39` | wording of one changelog fragment | `wiki-local/qa/deliverables/changelog-scope.md` |
| `d8c87001c0b7f86e` | where one driver registers a bound row | `wiki-local/databases/transactions/optimistic-version-bookkeeping.md` |
| `c5b554c95fb311aa` | skip guard for one conformance case | `wiki-local/testing/strategy/test-placement.md` |
| `cfded4d7fa03a353` | which two test files hold two regression tests | `wiki-local/testing/strategy/test-placement.md` |
| `3b5049e0069fc012` | leave one method's logic unchanged | `wiki-local/databases/transactions/optimistic-version-bookkeeping.md` |
| `4bb305dc16e2750a` | text of one code comment | `wiki-local/databases/transactions/optimistic-version-bookkeeping.md` |
| `64a849b6ce6d90bd` | text of one docstring | `wiki-local/databases/transactions/optimistic-version-bookkeeping.md` |
| `ef0aa133530bafe9` | text of one docs paragraph | `wiki-local/databases/transactions/optimistic-version-bookkeeping.md` |
| `cbbc4d9c304207eb` | text of one docs paragraph | `wiki-local/databases/transactions/optimistic-version-bookkeeping.md` |

The first row also points at a real gap in the bundled wiki: no page covers
open-loop versus closed-loop load generators (`wiki_search` returned no matching
trigger). The queued row carries no evidence beyond "derived from a project
script", so it was not promoted; a general page needs its own sourced ingest.
