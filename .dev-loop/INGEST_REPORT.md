# Knowledge flush — 4 insight(s)

2 new pages, 2 pages amended, 2 back-link pairs, 14 plan-gaps retired as local-layer.

## Verified best-practice

1. **Absence assertions over output that carries generated names** (queue `9ba2e410cd60f318`) — when a test asserts a value is absent from text that also embeds a temp path, plant a long marker no generator can produce (`FAKE-SECRET-MARKER`), not a short number.
   - Sources: https://github.com/python/cpython/blob/main/Lib/tempfile.py (`_RandomNameSequence`: 8 chars from `abcdefghijklmnopqrstuvwxyz0123456789_`, private `_Random()`), https://docs.python.org/3/library/tempfile.html, https://github.com/pytest-dev/pytest/blob/main/doc/en/how-to/tmp_path.rst (line 154: "`{num}` is a number that is incremented with each test suite run"), https://github.com/coe0718/hermes-review-loop/issues/153 (independent incident: `assertNotIn("404", out)` failed on `tmp404ad9f3`).
   - Verified: re-ran on CPython 3.13.1 — 200,000 names, `42` in 0.55%, `7` in 19.6%, `192192192` in none; two `random.seed(0)` child runs printed different temp names; alphabet line and private RNG present in the installed source.
   - Confidence: **verified**.
2. **Testing that a call returns instead of blocking** (queue `f325971f5fede689`) — run the call in a daemon thread, `join(timeout)` + `is_alive()`, release the blocked call from the test thread (FIFO: open the opposite end with `O_NONBLOCK`), then fail.
   - Sources: https://docs.python.org/3/library/threading.html, https://github.com/python/cpython/blob/main/Lib/test/support/threading_helper.py (`join_thread`: `thread.join(timeout)`, default `support.SHORT_TIMEOUT`), https://pubs.opengroup.org/onlinepubs/9699919799/functions/open.html, https://man7.org/linux/man-pages/man7/fifo.7.html, https://github.com/torvalds/linux/blob/master/fs/pipe.c, https://docs.python.org/3/library/subprocess.html — all returned HTTP 200.
   - Verified: on CPython 3.13.1 / macOS — no-reader non-blocking writer open → `ENXIO`; reader blocked after `join(1.0)`; released by `O_WRONLY|O_NONBLOCK` once the reader existed; `Lock.release()` from another thread released a blocked `acquire`; child with a daemon thread stuck in FIFO `open()` exited in 0.04 s, non-daemon child still running at 5 s.
   - Confidence: **verified**.
3. **Several public entry methods calling one shared step** (queue `9d170e72c7079b74`) — one test per entry method, each proven by deleting only that method's call.
   - Sources: existing page's https://pitest.org/quickstart/basic_concepts/ ("No coverage" vs "Survived"), plus a reproduction.
   - Verified: isolated `git archive` copy of linkly `impl/` at HEAD a6bf247 — baseline 354 tests OK; replacing the `issue()` call to `_refresh_if_stale()` with `pass` reddened exactly `test_normal_issue_at_the_ttl_rereads_and_signs_with_the_new_key`; the `verify()` deletion reddened three verify-path tests; with that one issue-path test removed, the `issue()` deletion left all 353 tests green. File restored by copy (sha1 matched) and the scratch copy deleted.
   - Confidence: **verified**.
4. **Approving a text-gate escalation does not whitelist the text** (queue `f8128644e665efbf`) — when a keyword false positive on an inline script is approved, have the worker save the script to a project-local file and run it by path.
   - Sources: https://github.com/choiyounggi/groundwork/blob/main/plugins/guardrails/hooks/bash-guard.sh (identical to the installed 1.2.2 copy by `diff -q`): in escalation mode every `ask` becomes a recorded `deny`; the hook keeps no approval state. https://code.claude.com/docs/en/hooks (hook receives the unexecuted command string).
   - Verified: fed hook JSON straight to `bash-guard.sh` with `GROUNDWORK_ESCALATION_DIR` set — inline `node -e` with only a keyword label escalated on the first run and again on the identical re-run; the same script run by path passed; a keyword-free control passed; a real SQL statement still escalated (known-bad). Incidentally the live hook also blocked my own first reproduction command on the same keyword.
   - Confidence: **verified**.

Note: pages 1 and 2 were drafted by an earlier flush run that stopped before committing (untracked files left in the checkout at 02:09). I did not take them on trust: every measurable claim was re-run above and every cited URL was fetched.

## Existing-layer check

Pages read: testing-quality-tests-that-cannot-fail, testing-quality-source-text-wiring-assertions, testing-data-artifact-leakage-from-a-suite, security-data-masking-verification, testing-quality-policy-at-several-return-sites, testing-strategy-cross-layer-effect-tests, platforms-shells-command-text-inspected-before-execution, platforms-tools-agent-permission-classifier-denials, testing-strategy-signal-delivery-to-a-process-under-test

- `wiki_search` top hits per candidate: (1) tests-that-cannot-fail, artifact-leakage-from-a-suite, assertion-scanner-false-positive-on-unittest-convention, autouse-fixture-shadows-function-under-test, path-valued-config — none covers choosing an absence marker; (2) parsing-cli-structured-output, java threads-and-memory, command-text-inspected-before-execution, non-interactive-cli-invocation, control-signals-vs-primary-artifacts — none covers a deadline for a blocking call in a test; (3) orm transaction-boundaries, dict-subclass-attribute-loss-on-copy, unchanged-function-gates, surviving-mutant-equivalence-triage, java coroutines — none; grep found `policy-at-several-return-sites` as the same pattern (one test per site, proven by per-site reversion); (4) agent-permission-classifier-denials, deny-rules-under-bypassed-permissions, unset-versus-empty-parameters, tool-diagnostics-without-a-failing-exit-code, command-text-inspected-before-execution.
- Merged: (3) into `testing-quality-policy-at-several-return-sites` (trigger sentence widened, one edge row, one field-measurement source); (4) into `platforms-shells-command-text-inspected-before-execution` (one edge row, field context, groundwork source). That page is at 120 body lines.
- Created: `testing-quality-absence-assertions-over-generated-output`, `testing-strategy-calls-that-must-not-block`.
- Conflicts: none. `agent-permission-classifier-denials` says "retry once" for the Claude Code auto-mode classifier, which judges the action; the new row covers a text-matching hook that re-matches identical text, so the two do not contradict.
- Back-links added: masking-verification → absence page; signal-delivery-to-a-process-under-test → calls page; policy-at-several-return-sites ↔ cross-layer-effect-tests. Deferred (an open PR rewrites that `related:` line): tests-that-cannot-fail → absence page (#223), async-testing → calls page (#226).
- Deferred index edit: the `wiki/platforms/index.md` load-when line for `command-text-inspected-before-execution` should gain "an approved keyword false positive on an inline script escalates again on re-run"; #223 inserts a row directly after that line, so the edit waits until #223 lands.
- Independent review (feature-dev:code-reviewer, adversarial brief): one major finding fixed (the row now says to write the scratch file with a non-shell tool, since a heredoc carries the keyword in its command text), plus minor fixes: FIFO release scoped to Linux source + macOS measurement, the field line no longer says "4 tests" next to `failures=5`, the row scoped to keyword-matching hooks and cross-referenced to the classifier page.
- Lint: `node scripts/wiki-structure-checks.js wiki/` → "pages: 361, indexes: 13, findings: 0"; `node scripts/wiki-lint-prohibitions.js wiki/` → 80/80 directives compliant, 0 violations.

## Open-PR check

Open `knowledge/*` heads listed: #223, #225–#231, #233–#239, #241, #244, #249, #253, #254, #255 (21 PRs). Each head was fetched and its `wiki/` diff searched for `fifo`, `O_NONBLOCK`, `is_alive`, `tempfile`, `assertNotIn`, `entry method`, `public method`, `false positive`, `scratch file`, `run it by path`.

| Candidate | Overlapping heads | Verdict |
|-----------|-------------------|---------|
| 1 absence assertions | none (no hits for tempfile/assertNotIn) | new |
| 2 calls that must not block | #225 hit `fifo` only as "a FIFO queue or mutex" for request serialization — unrelated | new |
| 3 entry methods sharing a step | #238 hit `entry method` only in a transaction-boundary row — unrelated | new (merge into existing page) |
| 4 approval does not whitelist text | `false positive` hits in #249/#226/#225/#223 are about review findings and an assertion scanner — unrelated | new (merge into existing page) |

To avoid conflicts: #230 rewrites the `related:` line of `command-text-inspected-before-execution`, so this PR leaves that page's `last_verified` line (adjacent to `related:`) unchanged and only inserts the source above it.

## Routing decision

| Insight | Target |
|---------|--------|
| 1 | `testing/quality/absence-assertions-over-generated-output.md` (new page; quality = assertion design) |
| 2 | `testing/strategy/calls-that-must-not-block.md` (new page; strategy, next to signal-delivery-to-a-process-under-test) |
| 3 | `testing/quality/policy-at-several-return-sites.md` (merged edge case; same mechanism: one test per site, proven by per-site deletion) |
| 4 | `platforms/shells/command-text-inspected-before-execution.md` (merged edge case; the page already owns "gate reads raw command text") |

No new category.

## Local-layer candidates

All 14 `plan-gaps.jsonl` rows are linkly plan decisions (t196 `kb/cloud/*` documents, frontmatter, index triggers, changelog, scope; t195 `docs/gunicorn-load-measurement.md` structure). They name one repository's own files and conventions, so they are excluded and retired:

- `4c4b70c3be1c329a`, `8538da78fff694a2`, `a8da0e5e2d3a4818`, `35d60b29dfc8425d`, `fb33a53b95677a01`, `bb2eb5af940043fc`, `5992b207b903f52a`, `6257cd01bd6e28dd`, `ed71370ab17aa81a`, `210301df51f2bcd1`, `64f13d0e8f0c4053`, `76f675e77de1ddeb`, `59774840d750d38e` → linkly t196 → `wiki-local/infrastructure/cloud/kb-cloud-documents.md` (run wiki-ingest inside that project)
- `12ee112143e36140` → linkly t195 → `wiki-local/qa/performance/gunicorn-load-measurement-doc.md` (run wiki-ingest inside that project)

Separately for the owner: `skills/orchestrate/SKILL.md` (around line 580) tells the coordinator to answer an approved escalation with `"approved — re-run: <cmd>"`. For a keyword false positive that instruction loops (insight 4). That wording may be worth changing in a code PR.
