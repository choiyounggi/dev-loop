# Task 01: Dedupe harvested insights against the processed store

## Objective

`hooks/harvest.js` seeds its dedupe set from both the session queue file and
`~/.dev-loop/queue/.processed.jsonl`, so a hash a previous knowledge-flush retired
is never re-appended — even when the session queue file is empty or absent.
`tests/harvest.bats` covers this and the behaviors it must not break.

## Wiki pages (read these first, only these)

- wiki/backend/common/jobs/idempotent-handlers.md — use for: why the handler must
  tolerate full re-execution (directive 1) and that the dedupe key is looked up in
  a **processed-messages store** before the append (directive 2, the
  "Increment or append that must remain" row). This is the row that decides D1.
- wiki/testing/quality/minimum-case-set.md — use for: which cases the test file
  must hold (directive 1: normal + error + boundary per behavior), what each test
  asserts (directive 2: observable outcome), and the red-first rule for a bug fix
  (directive 5).
- wiki/testing/quality/tests-that-cannot-fail.md — use for: judging that each new
  assertion can actually detect the defect; and D10 (never make a permanent skip).
- wiki/testing/data/test-data-and-isolation.md — use for: the "Filesystem / temp
  files" row (fresh per-test temp directory) and the "Global config / environment
  variables" row — how to point `HOME` at a per-test directory so the real
  `~/.dev-loop/queue` is never touched.

## Inputs

- `hooks/harvest.js` (existing, 193 lines). The site to change is the `seen`
  construction inside `main()` — the block that begins `const seen = new Set();`
  and ends just before `const repo = path.basename(cwd);`. Anchor by that symbol,
  not by line number.
- `hooks/harvest.js` helpers you must reuse, not re-implement: `safeJson(s)`
  (returns `{}` on parse failure) and the existing `queueDir` /`queueFile`
  computation.
- `tests/loop-gate.bats` — the style to match: `setup()` resolves the hook via
  `${BATS_TEST_DIRNAME}/../hooks/...`, work happens under `BATS_TEST_TMPDIR`, the
  payload is piped in with `printf`.
- Decisions that bind you: D1 (seed from both), D3 (`.processed.jsonl` in
  `queueDir`), D4 (read-only), D5 (existsSync + safeJson), D6 (HOME isolation),
  D7 (case set), D8 (red first), D9 (assert line count + hashes), D10 (no skip).

## Steps

1. Create `tests/harvest.bats`. In `setup()`:
   - `HARVEST="${BATS_TEST_DIRNAME}/../hooks/harvest.js"`
   - `export HOME="${BATS_TEST_TMPDIR}/home"`, `QDIR="$HOME/.dev-loop/queue"`,
     `mkdir -p "$QDIR"`
   - `WORK="${BATS_TEST_TMPDIR}/work"`, `mkdir -p "$WORK"` — this is the payload's
     `cwd` (it must NOT be under `$HOME/.dev-loop/repo`, which the hook skips).
   - Assert `node` is available and fail the test if not (D10):
     `command -v node >/dev/null || { echo "node is required for these tests"; return 1; }`
2. Add a helper that writes a transcript containing one ★ Insight block and runs
   the hook, so each test differs only in the queue/processed state:

   ```bash
   _mk_transcript() { # <file> <trigger-text>
     local body
     body="★ Insight ─────\ntrigger: $2\ndirective: seed the dedupe set from the processed store too\nwhy: the transcript is re-parsed on every Stop\nevidence: measured 46 duplicate rows\ndomain: testing\n─────"
     printf '{"message":{"role":"assistant","content":"%s"}}\n' "$body" > "$1"
   }

   _run_harvest() { # <transcript>
     printf '{"cwd":"%s","session_id":"s1","transcript_path":"%s"}' "$WORK" "$1" | node "$HARVEST"
   }
   ```

   The delimiter run must be U+2500 box-drawing characters (─), matching
   `BLOCK_RE` in `harvest.js`. Write the `\n` escapes so they land as real
   newlines inside the JSON string value.
3. Write these tests (each asserts the observable outcome per D9 — the queue
   file's line count and, where it matters, the hash it holds):

   | Case | Setup | Assert |
   |------|-------|--------|
   | normal — a new candidate is harvested | empty `$QDIR`, no `.processed.jsonl` | `s1.jsonl` has exactly 1 line, and its `hash` field is non-empty |
   | **regression** — a processed hash is not re-queued | run the hook once, capture `HASH` from `s1.jsonl`, then move that line into `.processed.jsonl` and truncate `s1.jsonl` (this is exactly what a flush does), then run the hook again | `s1.jsonl` has **0 lines** |
   | preserved — intra-session dedupe still works | run the hook twice with the same transcript and no flush in between | `s1.jsonl` has exactly 1 line |
   | error — corrupt line in the processed store | put `not json` plus the real processed row in `.processed.jsonl`, truncate `s1.jsonl`, run | hook exits 0 **and** `s1.jsonl` has 0 lines (the corrupt line is skipped, the valid one still dedupes) |
   | error — no `.processed.jsonl` at all | remove it, empty queue, run | `s1.jsonl` has exactly 1 line (absence must not throw) |
   | boundary — empty `.processed.jsonl` | `: > "$QDIR/.processed.jsonl"`, empty queue, run | `s1.jsonl` has exactly 1 line |
   | boundary — transcript holds no ★ block | transcript with a plain assistant line | no `s1.jsonl` is created (or it has 0 lines) |
   | preserved — recursion guard | payload `cwd` set to `$HOME/.dev-loop/repo` | no `s1.jsonl` is created |

4. Run `bats tests/harvest.bats` on the **unmodified** `hooks/harvest.js` and
   record the output. The regression row must FAIL and the others must pass
   (D8). If the regression row passes here, the test does not reproduce the bug —
   fix the test before touching the hook.
5. Edit `hooks/harvest.js`: replace the `seen` construction with a loop over both
   sources, keeping `safeJson` and the `existsSync` guard:

   ```js
   const processedFile = path.join(queueDir, '.processed.jsonl');
   const seen = new Set();
   for (const src of [queueFile, processedFile]) {
     if (!fs.existsSync(src)) continue;
     for (const line of fs.readFileSync(src, 'utf8').split('\n')) {
       const o = safeJson(line);
       if (o.hash) seen.add(o.hash);
     }
   }
   ```

   Do not change the append target (`queueFile`), the row shape, the recursion
   guard, or the top-level `try/catch`. Do not write to `processedFile` (D4).
6. Re-run `bats tests/harvest.bats` — all rows green — then `bats tests/` for the
   whole suite.

## Deliverables

- `tests/harvest.bats` (new)
- `hooks/harvest.js` (modified — only the `seen` construction inside `main()`)

## Verify

- `bats tests/harvest.bats` → all tests pass, and the run before step 5 showed the
  regression test failing (paste both outputs).
- `bats tests/` → the full suite passes with no new failures against the `91409d0`
  baseline.
- `git diff --stat` → exactly the two Deliverable files.

## Out of scope

- Pruning or rewriting `~/.dev-loop/queue/.processed.jsonl` (user data; follow-up
  in `plan.md`).
- `hooks/auto-flush.sh`, `hooks/harvest-insights.sh`, any other hook.
- `skills/knowledge-flush/SKILL.md` and any wiki page.
- The installed plugin copy under `~/.claude/plugins/cache/` — read-only, never edit.
