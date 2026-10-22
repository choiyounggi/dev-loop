# Knowledge flush — 1 insight ingested (headless auto-flush run 20261012-150339-99224)

5 queue rows were claimed this run. 1 was ingested; 4 were released (one open-PR
duplicate, one plausible open-PR overlap, and two that could not be read in this
headless run). Nothing was folded into another branch — this run opens its own PR
only for the single verified insight.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `e94ff70e02df728b` — cap the test runner's workers so per-file Testcontainers DBs don't exhaust the Docker VM | testing | **ingested** (merged into `testing-flaky-diagnosing-flaky-tests`) |
| `ea0574d2686b0169` — tsx top-level `await` needs `.mts` / `type: module` | platforms | released — duplicate of open PR #274 |
| `2bf23658a4d1bc2e` — give fixtures distinct id/index/order values | testing | released — plausible overlap with open PR #270 |
| `61bc283a566a4780` — unread | unknown | released — unreadable in this run |
| `866175146dd2fc3b` — unread | unknown | released — unreadable in this run |

Note on the two unread rows: in this run the insight-queue directory
(`~/.dev-loop/queue`) cannot be listed or searched with any available tool (the
Bash sandbox confines `ls`/`find`/`grep`/`cat` to the task worktree, and the
`Read` tool needs an exact filename), so the two rows that live in queue files
whose names this run never learned could not be opened. An unreadable candidate
cannot be verified, so both were **released** (not retired) and will be offered
again to a future flush — the manual skill, run from an unsandboxed shell, can
read them.

## Verified best-practice

**`e94ff70e02df728b` — cap the runner's worker count to the Docker VM's memory so
per-file Testcontainers databases are not killed mid-run** — confidence:
**field-tested** (documented knob; one-machine failure mechanism).

Claim: when each DB-backed test file starts its own Testcontainers Postgres and
the test runner's default worker count scales with host CPU parallelism, a
many-core host starts many containers at once; a small Docker VM then kills some
containers mid-run, which looks like flaky tests (a different subset of files
fails each run) rather than a resource ceiling. Capping the runner's workers to
what the VM can hold fixes it without changing the test files or counts.

Sources checked:
- https://vitest.dev/config/maxworkers — the `maxWorkers` option caps concurrent
  worker processes; with watch mode off it defaults to the host's available
  parallelism (`os.availableParallelism()`) and is halved in watch mode, and it
  accepts a number or a percentage string. Confirmed via web search of the
  official docs page (the page itself could not be fetched in this run; only the
  documented default/knob is cited, not a verbatim quote).
- Docker Engine returns `HTTP 409 ... is not running` when an operation targets a
  container that has already stopped — consistent with the VM killing a container
  mid-run; corroborated by general search results, used only to read the error,
  not as the page's load-bearing citation.
- Field reproduction 2026-10-12 (linkly-invitation, Vitest 5 +
  `@testcontainers/postgresql` 12.2.0 on macOS Docker Desktop, `docker info` = 8
  CPUs / 4 GB): three `pnpm test` runs at one commit each failed only on DB-backed
  files, a different subset each time (2, then 1, then 4), with
  `HTTP code 409 ... is not running` and a 120 s `startTestDatabase` timeout;
  `pnpm test --maxWorkers=4` passed 126/126 files (1077 passed, 2 skipped) and
  every later full-suite gate passed with the same cap. This is the load-bearing
  evidence; the page is marked field-tested, not verified.

## Existing-layer check

Pages read: testing-flaky-diagnosing-flaky-tests, testing-data-testcontainers-reaper-on-docker-desktop-macos, testing-quality-expectation-sets-with-one-distinct-value, testing-quality-path-resolver-fixtures-with-coincident-cwd, testing-data-test-data-and-isolation

- **`testing-flaky-diagnosing-flaky-tests`** — the merge target. Its symptom table
  already carries a "fails only in parallel / only in CI → shared external
  resource" row, but that is resource *collision* (same schema/port/temp dir),
  whose fix is per-worker isolation. The `e94` case is resource *exhaustion* (too
  many containers for the VM's memory), whose fix is to *cap* the workers — a
  distinct symptom and a distinct fix, so it was added as a new symptom row, one
  edge-case row (the `409`/timeout signature → read it as a ceiling), and one
  Instead-of row (cap workers, don't retry). Added the vitest source and bumped
  `last_verified` to 2026-10-12.
- **`testing-data-testcontainers-reaper-on-docker-desktop-macos`** — adjacent but
  a different trigger (the Ryuk reaper cannot mount the Docker socket, so 0 tests
  run before any container starts). Not merged into; cross-linked both ways
  (`related:`) and named in the new edge-case row so a reader can tell the
  socket failure from the memory failure.
- **`testing-quality-expectation-sets-with-one-distinct-value`**,
  **`testing-quality-path-resolver-fixtures-with-coincident-cwd`**,
  **`testing-data-test-data-and-isolation`** — read while assessing the released
  `2bf2` candidate (coincident fixture values). They are the merged-wiki siblings
  of that lesson; `2bf2` was released for the manual flush rather than ingested
  here (see Open-PR check), so no edit was made to them.

No conflicting directive was found; no page was superseded.

## Open-PR check

Open `knowledge/*` heads at flush time (via
`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`):
#274, #273, #272, #271, #270, #269, #268, #266, #265. This headless run cannot
`git diff` their content, but it does have each PR's changed-file list (from
`gh pr list --json files`), so overlap was judged at the page/trigger level
against those file lists:

- **`e94` (Testcontainers / Docker memory / runner worker cap)** — verdict:
  **new**. No open PR touches a Testcontainers, Docker-memory, or worker-count
  page, and none edits `testing/flaky/diagnosing-flaky-tests.md`, so the merge
  does not collide with any branch in flight.
- **`ea0574d2686b0169` (tsx top-level await without `type: module`)** — verdict:
  **drop (duplicate)**. PR #274 adds
  `wiki/platforms/toolchains/tsx-top-level-await-without-type-module.md`, the exact
  same lesson (its EN/KO variants were the rows PR #274 ingested). Released.
- **`2bf23658a4d1bc2e` (distinct fixture id/index/order values)** — verdict:
  **drop (plausible overlap)**. PR #270 is actively adding several
  `testing/quality` fixture-and-mutation pages (`mutation-harness-file-custody`,
  `host-disguise-fixtures-for-url-allowlists`, `surviving-mutant-equivalence-triage`,
  `anchor-cases-for-allowlist-regexes`). This candidate is the same fixtures-for-
  mutation-detection theme; because this run cannot diff #270's content, it was
  released so the manual flush can decide between folding it into that cluster and
  opening it as a new sibling of the merged coincidental-correctness pages.
- **`61bc283a566a4780`, `866175146dd2fc3b`** — could not be read (see the note at
  the top), so overlap could not be assessed. Released.

## Routing decision

- `e94ff70e02df728b` → `testing` / `flaky` → merged into
  `wiki/testing/flaky/diagnosing-flaky-tests.md` (merge-before-create: an existing
  page owns the exact symptom, so no new page was created). Plumbing updated:
  `wiki/testing/index.md` "load when" line extended, `log.md` appended, `related:`
  links added both ways with `testing-data-testcontainers-reaper-on-docker-desktop-macos`.
- No new category was created.

## Local-layer candidates

none — the single ingested insight is a general runner/Testcontainers behavior,
not specific to one repository's files or infrastructure.
