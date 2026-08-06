# Knowledge flush — 7 insight(s): 6 ingested (1 new page, 5 merges), 1 dropped

## Verified best-practice

**1. Policy gates must parse all three shell quoting forms and expand only resolvable prefixes** (`d3ef0214`, from dev-loop)
Claim: a PreToolUse/policy gate extracting an argument from raw command text must accept bare, single-quoted, and double-quoted forms and expand `~`/`$HOME`/`${HOME}` itself; a bare-token regex denies well-formed commands with a misleading "argument missing" error.
Sources checked: https://code.claude.com/docs/en/hooks (hook receives the unexecuted `tool_input.command` string), https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html (2.2 Quoting defines exactly escape/single/double-quote forms; expansion happens only when the shell processes the line).
Verification: re-ran the repo's own regression suite this session — `bats tests/pre-flush-pr-gate.bats` tests 12 (double-quoted `--body-file` recognized) and 13 (`$HOME` path expanded) pass on current main. **Confidence: verified.**

**2. Invoke helper scripts via `sh "$SCRIPT"` so test stubs need no exec bit (EDR-safe seam)** (`cc8801d1`, from dev-loop t1)
Claim: designing production code to call external scripts through the interpreter lets tests inject stubs as plain read-only files — no `chmod +x`, which EDR agents (SentinelOne) flag on temp/test paths — and survives mode-stripping distribution paths (plugin cache).
Sources checked: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sh.html — command_file "need not be executable" (stated for both slash and no-slash pathnames).
Verification: local reproduction 2026-08-06 — a mode-644 script ran via `sh file` (exit 0) and failed direct exec with permission denied (exit 126). Original field evidence: 8 stubs injected without chmod, 331/331 bats green. **Confidence: verified** (mechanism doc-backed + reproduced; EDR angle annotated as field practice).

**3. Gate warnings by captured stderr, not exit code; redirection order `2>&1 >/dev/null`** (`e3b04b0e`, from linkly)
Claim: warning-emitting tools exit 0, so a feedback hook must capture stderr (`OUT=$(tool "$F" 2>&1 >/dev/null)`) and, in a Claude Code PostToolUse hook, forward non-empty output via exit 2.
Sources checked: https://code.claude.com/docs/en/hooks — PostToolUse "Shows stderr to Claude; the tool already ran" on exit 2; exit-0 stderr "goes to the debug log only, never the transcript". https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — 2.7 Redirection: "the order of evaluation is from beginning to end". (gnu.org bash manual returned HTTP 429 repeatedly; POSIX covers the same semantics and is cited instead.)
Verification: local reproduction 2026-08-06 — `cc -Wall` on unused-variable code: exit 0 with 157 bytes on stderr; correct order captured the 156-char diagnostic, reversed order captured 0 chars. **Confidence: verified.**

**4. Attribute temp-artifact leaks by prefix histogram before fixing; then a static cleanup guard observed red first** (`a61dfd51`, from linkly)
Claim: histogram surviving temp names by prefix and match against `mkdtemp` call sites — the distribution pinpoints the few offending sites; enforce the cleanup convention with an AST/lint guard proven red on pre-fix code.
Sources checked: https://docs.python.org/3/library/tempfile.html — "The user of mkdtemp() is responsible for deleting the temporary directory and its contents when done with it."
Verification: field measurement (998 leaked dirs = 686+306 under two prefixes, exactly the 2/6 call-site files without cleanup; post-fix suite temp delta 0, 72 MB → 3.3 MB). The histogram-attribution method itself has no external source. **Confidence: field-tested** (cleanup-responsibility claim doc-backed).

**5. A pre-implementation test that cannot go red: record vacuous green, prove later by guard mutation** (`d245e299`, from dev-loop t2)
Claim: when a usage-error test expects the exit code the unimplemented path already produces, red-first silently fails; mark it vacuously green and after implementation mutate the specific guard, require red, restore.
Sources checked: existing page sources apply directly — James Shore AoAD2 TDD ("predict *how* it will fail") and https://testing.googleblog.com/2021/04/mutation-testing.html (already cited on the two target pages; both live-verified in prior flushes).
Verification: session reproduction — `sed` mutation of the arg-count guard (`-ge 2`→`-ge 1`) flipped the test to `not ok`; restore flipped it back. **Confidence: verified.**

**6. Client-side throttles must count token/auth issuance requests and stamp at actual send** (`58d7e79d`, from auto-trading-bot/stock-trader)
Claim: auth refresh inside `_headers()`/interceptors bypasses a throttle layered above it; token POST + first API GET land in the same second, deterministically exceeding a 2-req/s cap only on cold-token days — presenting as intermittent failure.
Sources checked: searched for an official cross-provider statement that token-endpoint calls count toward rate limits; Auth0/Okta rate-limit docs confirm token endpoints are themselves rate-limited but state no general counting rule, so no external URL is cited for the directive itself.
Verification: provider-log evidence from the field incident (token POST :00.354 → issuance :00.495 → rate-limited API call :00.543 on both token-issuance days; cache-valid days clean). **Confidence: field-tested** — the merged row is annotated as such inside the otherwise-verified page, following the existing `permissions-and-exec-bits` mixed-provenance precedent.

**7. dev-loop orchestrate `worktree_escape` fires on read-only cross-worktree access — budget escalation round-trips** (`28fd6dfe`) — **DROPPED** (see Routing decision).

## Existing-layer check

Pages read: `INDEX.md`; domain indexes for platforms, testing, backend, infrastructure; full pages `command-text-inspected-before-execution`, `portable-shell-scripts` (headings), `permissions-and-exec-bits`, `tests-that-cannot-fail`, `checks-that-cannot-pass`, `test-data-and-isolation`, `what-to-mock` (index line), `timeouts-and-retries`. Grepped the whole wiki for guardrail/escalation/orchestrate coverage (none).

- Insight 1 overlaps `command-text-inspected-before-execution` — that page covered the **caller** side only; merged the **gate-author** side as new step 6 + one Instead-of row + field context. No conflict: caller-side rows ("a gate that excludes quote characters cannot receive a quoted path") remain correct defensive guidance against naive gates.
- Insight 2 overlaps `permissions-and-exec-bits`, which already had "invoke through the interpreter" as a mode-stripping workaround; merged the EDR/test-seam design angle as one edge-case row + one Instead-of row + POSIX source. No conflict.
- Insight 3 had no owning page (checked `portable-shell-scripts` — portability scope, wrong home; `command-text-…` — PreToolUse command inspection, different mechanism). Created a new sibling page; `related:` linked both ways to `command-text-inspected-before-execution` and `portable-shell-scripts`.
- Insight 4 overlaps `test-data-and-isolation` ("Filesystem / temp files" row existed but only as per-test practice); merged the attribution/enforcement case as one edge-case row with an inline sanctioned hop to `checks-that-cannot-pass` (guard-red-first). Frontmatter `related` not cross-added — adjacency is one directive, not page-level.
- Insight 5 fit both `tests-that-cannot-fail` (mutation proof) and `checks-that-cannot-pass` (target-does-not-exist scope). Merged into `checks-that-cannot-pass` — its existing "test for behavior you are about to implement" row is the exact parent case — with an inline link to `tests-that-cannot-fail` for the mutation mechanics. The two pages already `related:`-link each other.
- Insight 6 had no rate-limiting page; `timeouts-and-retries` owns outbound-call discipline and already handles 429s — merged as one edge-case row + field-incident source line rather than creating a single-row `client-rate-limiting` page.

## Routing decision

| # | Target | Decision |
|---|--------|----------|
| 1 | platforms/shells/command-text-inspected-before-execution | Merge (gate-author side of the same case) |
| 2 | platforms/filesystems/permissions-and-exec-bits | Merge (harvest hinted `testing`; the mechanism — exec-bit semantics of invocation style — is owned by this platforms page, and the testing route now reaches it via the updated index line) |
| 3 | platforms/shells/warning-only-diagnostics | **New page** (harvest hinted `testing`; the case is shell-stream/hook-protocol mechanics, not test design — placed beside the other hook-engineering page in platforms/shells; no new category needed) |
| 4 | testing/data/test-data-and-isolation | Merge (suite-hygiene case of the existing temp-files row) |
| 5 | testing/quality/checks-that-cannot-pass | Merge (exact refinement of its pre-implementation-test edge row) |
| 6 | backend/common/reliability/timeouts-and-retries | Merge (single edge-case row; a new `client-rate-limiting` page was rejected as one-row-page fragmentation) |
| 7 | — | **Dropped from wiki**: specific to dev-loop's own orchestrate guardrail (`worktree_escape` ask-on-read behavior and escalation workflow). No wiki domain/category owns agent-orchestration coordination, and creating one for a single tool-specific page is unjustified. The right home is the orchestrate skill's own docs — schema/workflow layer, owner-approval-only per AGENTS.md — so it is surfaced here for the owner instead: *brief authors should budget escalation round-trips when briefs reference other worktrees, and state "read approved, write + /tmp forbidden" in the worker's first instruction*. Candidate retired to `.processed.jsonl` (status `dropped`). |

No new categories created; no contradictions flagged. Indexes updated: platforms (2 load-when lines + 1 new page row), testing (2 load-when lines), backend (1 load-when line). `log.md` appended.
