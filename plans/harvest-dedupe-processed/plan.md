# harvest-dedupe-processed

Goal: `hooks/harvest.js` must not re-queue an ★ Insight candidate that a previous
knowledge-flush already retired to `~/.dev-loop/queue/.processed.jsonl`. Today the
dedupe set is seeded only from the session's own queue file, so once a flush
empties that file the next Stop event re-parses the unchanged transcript and
re-appends the same hash.

Acceptance criteria:
1. A hash present in `.processed.jsonl` is not appended to the session queue file,
   even when that queue file is empty or absent.
2. Existing behavior is preserved: intra-file dedupe, normal harvesting of new
   candidates, the `~/.dev-loop/repo` recursion guard, silent exit when there is
   no transcript, and no error ever surfacing to the user.
3. `bats tests/` passes on the full suite.

Stack: Node.js (CommonJS, no dependencies — `fs`/`path`/`os`/`crypto` only) for the
hook; bats for tests; CI runs `bats tests/` on ubuntu-latest and macos-latest
(`.github/workflows/test.yml`).

Baseline: branch `fix/harvest-dedupe-processed` at HEAD `91409d0`, working tree clean.

## Decisions

| # | Decision | Choice | Wiki basis |
|---|----------|--------|------------|
| D1 | Where the dedupe set comes from | Seed `seen` from **both** the session queue file and `~/.dev-loop/queue/.processed.jsonl` | backend-common-jobs-idempotent-handlers — "Increment or append that must remain" row: a **processed-messages store keyed by message id**; a hit means already processed → skip. `.processed.jsonl` is that store; `hash` is the id |
| D2 | Why a re-read is required at all | Treat every Stop as a full re-execution of the same input; the handler must tolerate it | backend-common-jobs-idempotent-handlers directive 1 — "Every handler must tolerate full re-execution from any point it can crash at" |
| D3 | Processed-store path | `path.join(queueDir, '.processed.jsonl')` — same directory as the session queue files, resolved from `os.homedir()` exactly as `queueDir` already is (`harvest.js:150`) | `[no-wiki]` — fixed by the existing knowledge-flush contract (skills/knowledge-flush/SKILL.md step 5 writes there) |
| D4 | Hook's access mode to the processed store | **Read-only.** The hook never creates, writes, or prunes `.processed.jsonl`; only knowledge-flush moves rows there | `[no-wiki]` — single-writer keeps the flush the sole owner of retirement |
| D5 | Corrupt / missing store behavior | Each source is guarded by `fs.existsSync`, and every line goes through the existing `safeJson` (returns `{}` on parse failure) so a corrupt line is skipped, not fatal | backend-common-jobs-idempotent-handlers directive 1 (tolerate re-execution) + the file's existing `safeJson` + top-level `try/catch` convention (`harvest.js:34-40`, `189-193`) |
| D6 | Test isolation | `HOME="$BATS_TEST_TMPDIR/home"` per test (Node's `os.homedir()` reads `$HOME` on POSIX); transcript and payload files under `BATS_TEST_TMPDIR`; nothing written into the repo or the real `~/.dev-loop` | testing-data-test-data-and-isolation — "Filesystem / temp files" row (fresh per-test temp directory) and "Global config / environment variables" row (set in setup) |
| D7 | Case set | One normal, one error, and one boundary case per behavior; the bug gets a regression test | testing-quality-minimum-case-set directive 1 and directive 5 |
| D8 | Red before green | The regression test is written first and **observed failing** on unmodified `harvest.js`; that output is the evidence the test guards the bug | testing-quality-minimum-case-set directive 5 — "first write a regression test that reproduces the bug and fails on the current code" |
| D9 | What each test asserts | The observable outcome: the **number of lines** in the session queue file and **which hashes** it contains — never "the hook exited 0" alone, since the hook exits 0 unconditionally | testing-quality-minimum-case-set directive 2 + testing-quality-tests-that-cannot-fail (an assertion that cannot detect the defect is not a test) |
| D10 | Missing `node` in the test environment | Fail the test loudly in `setup()` rather than `skip` — a permanent skip is a test that cannot fail | testing-quality-tests-that-cannot-fail |
| D11 | Pruning `.processed.jsonl` | **Out of scope**, recorded as follow-up | backend-common-jobs-idempotent-handlers edge case "Dedupe table grows unbounded → prune rows older than the redelivery horizon" — real, but it is user data and the user deferred it |

## Task order

| Task | Depends on | Parallel-ok |
|------|-----------|-------------|
| 01-dedupe-against-processed-store | — | — |

One task: the fix and its regression test are one concern (2 files, 4 wiki pages),
and splitting them would leave a task whose Verify is "the suite is red".

## Follow-up (not in this branch)

- Prune duplicate rows already in `~/.dev-loop/queue/.processed.jsonl` (103 rows /
  57 unique hashes as measured 2026-08-05). User data — separate, consented pass.
- Consider a retention horizon for `.processed.jsonl` per D11's wiki edge case.
