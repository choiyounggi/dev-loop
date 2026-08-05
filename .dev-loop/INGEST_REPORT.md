# Knowledge flush — 7 insight(s)

Drained `~/.dev-loop/queue` (7 pending rows across 5 session files). Result:
**5 new pages, 2 revised pages, 1 new category** (`infrastructure/orchestration`).

## Verified best-practice

### I1 — A plugin hook rewrites what a tool returns
**Claim:** when a tool returns content that does not match the file, test its
suggested workaround once; if it fails, switch to `grep -n` + `awk` and name that
fallback in every spawned worker's brief.
**Sources checked:** [Claude Code hooks reference](https://code.claude.com/docs/en/hooks) —
documents `PostToolUse` → `hookSpecificOutput.updatedToolOutput`, which "replaces
the tool's result", and `PreToolUse` → `updatedInput`, which "replaces a tool's
arguments before it runs"; explicitly names this the interception point "for
redaction or transformation use cases … `PostToolUse` for inbound tool results".
**Verification:** the *mechanism* is documented, which upgrades the insight from
"a plugin was weird" to a named, expected harness capability. The specific
substitution behavior is the session's own observation (4 files, retry with
`offset=151, limit=120` returned line 1 again, two worker panes independently
logged it). Also corrected the queued claim's framing: the file is intact, the
*channel* is mediated — so the page directs at channel choice, not at the file.
**Confidence: `verified`** (mechanism cited; field incident recorded separately
under "Field context").

### I2+I3 — A control signal is not evidence
**Claim:** confirm a status file or watcher verdict against the primary artifact
(git log, substrate liveness) before restarting, discarding, or merging; report
an orchestrator-assigned task id rather than a discovered session name; `stat`
the status file after writing it.
**Sources checked + reproduced:**
- [tmux manual](https://man.openbsd.org/tmux) — "if a session is omitted, the
  current session is used if available; if no current session is available, the
  most recently used is chosen."
- **Reproduced locally 2026-08-05:** `env -u TMUX tmux display-message -p '#S'`
  printed `lo-test` — an unrelated session — with **exit 0**. This is the exact
  false-positive mechanism the queued insight described (`lo-14/15/16-npmcli`):
  a worker outside tmux does not get an error, it gets someone else's session name.
- **Verified against this machine's own guardrail source:**
  `plugins/guardrails/hooks/bash-guard.sh:217-245` — `worktree_escape` fires when a
  linked worktree's command *text* names the main root together with a write verb
  (`rm|mv|cp|tee|mkdir|touch|install|dd` or a `>`/`>>` redirect), independent of
  the command's purpose; `plans/worker-safety-v0.1/design.md:82` states the rule
  "only sees the literal command text", which is why the Write tool succeeded on
  the same path. Default mode `ask` → `deny` under `GROUNDWORK_NONINTERACTIVE=1`.
- [Claude Code hooks](https://code.claude.com/docs/en/hooks) — `PreToolUse` runs
  "Before a tool call executes. Can block it", so a blocked call leaves no side effect.
**Confidence: `verified`.**

### I4 — Shared orchestration state across concurrent runs
**Claim:** namespace the state directory per run id; survey it for foreign task
ids before writing; confirm a foreign run from `git worktree list` / branches /
default-branch HEAD rather than from the status files.
**Sources checked:** [git-worktree](https://git-scm.com/docs/git-worktree) —
`git worktree list` enumerates every linked worktree of the repository including
another process's, `git worktree prune` clears administrative files for removed
ones (this is what makes the repo, not the status dir, the reliable witness).
**Verification:** the *incident* is field evidence only (two dev-loop runs sharing
`.orchestration/status`; run B merged four of run A's branches to the default
branch `373d9fa`→`24ea9e8` without A's gate). The remedy is standard shared-mutable-
state hygiene, but no external source prescribes this specific layout.
**Confidence: `field-tested`** — deliberately not upgraded to verified.

### I5 — A throttle the token request slips past
**Claim:** throttle at the transport layer every request passes through, stamp the
timestamp immediately before the send, and decide whether the token endpoint takes
a slot from the provider's documented bucket policy.
**Sources checked — and this materially corrected the queued directive:**
- [GitHub REST rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) —
  "No more than 2,000 OAuth access token requests per hour", a **secondary** limit
  distinct from the primary REST limit.
- [Okta OAuth token endpoint limits](https://developer.okta.com/docs/reference/rl2-token-oauth/) —
  metered per authorization server, separately from other API endpoints.
- [Auth0 rate limit policy](https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy) —
  per-endpoint policies, Authentication API metered separately.
- [KIS open-trading-api](https://github.com/koreainvestment/open-trading-api) —
  `EGW00201` 초당 거래건수 초과; "토큰 재발급 - 1분당 1회 발급됩니다"; 모의투자 계좌는
  REST API 호출 제한이 낮음 (corroborates the reported 2/sec paper-account limit).
- [RFC 6749 §4.4](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4) — the
  token is obtained by an ordinary HTTP POST, subject to the server's limits.
**Correction made:** the queued directive said flatly "include token requests in
the throttle counter". That is **not universally right** — GitHub, Okta and Auth0
meter the token endpoint in its own bucket, where charging it to the API limiter
would under-use the quota. The page therefore ships a three-row decision table
(shared bucket / separate bucket / undocumented) instead of the flat rule, and
keeps the genuinely universal part: the throttle must sit below the auth layer,
because that is what the bug actually was.
**Confidence: `verified`.**

### I6 — Enumerating call sites for a signature migration
**Claim:** search by callee symbol, not parameter name; audit test helper
definitions that reproduce the old shape.
**Sources checked:**
- [Python tutorial — keyword arguments](https://docs.python.org/3/tutorial/controlflow.html#keyword-arguments) —
  the same parameter may be passed positionally or by keyword, so the parameter
  name is simply absent from a positional call's text. This is the mechanism.
- [rope ChangeSignature](https://deepwiki.com/python-rope/rope/4.6-change-signature-and-other-refactorings) —
  resolves call sites through the callee **symbol** and normalizes positional↔keyword.
- [ReSharper Change Signature](https://www.jetbrains.com/help/resharper/Refactorings__Change_Signature.html) —
  "finds and updates all usages, base symbols, implementations, and overrides".
**Verification:** every serious refactoring tool is symbol-driven, not
parameter-name-driven — that is the industry answer to this exact problem, and it
also supplied a directive the queued insight lacked (prefer the symbol-aware
rename; use grep to *verify* it, not to plan it).
**Confidence: `verified`.** Session measurement retained as field context
(`Ran 472 tests / FAILED (failures=11)`).

### I7 — `${VAR:-default}` swallows a deliberate empty value
**Claim:** `:-` substitutes for unset **and** null; `-` only for unset. So passing
`VAR=` to disable a feature is silently ignored.
**Sources checked:** [POSIX Shell Command Language §2.6.2](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html) —
"use of the &lt;colon&gt; in the format shall result in a test for a parameter that
is unset or null; omission of the &lt;colon&gt; shall result in a test for a
parameter that is only unset."
**Reproduced locally 2026-08-05** with `VAR=` under **sh, bash, zsh and dash**:
`${VAR:-d}` → `d`, `${VAR-d}` → empty, in all four.
**Confidence: `verified`** (strongest of the batch — spec text + 4-shell repro).

## Existing-layer check

**Pages read before writing:** `INDEX.md`, `AGENTS.md`, `templates/page.md`, and
the full domain indexes for `platforms`, `infrastructure`, `testing`, `backend`,
`debugging`. Full bodies read where "load when" overlapped:
`platforms/shells/portable-shell-scripts`,
`platforms/shells/command-text-inspected-before-execution`,
`backend/common/reliability/timeouts-and-retries`.

| Insight | Overlap found | Resolution |
|---------|---------------|------------|
| I7 | `portable-shell-scripts` already had an edge case pointing `set -u` users at `"${OPT:-}"` — same expansion family, opposite direction (there `:-` is the fix; here it is the trap) | **Merged, not created.** Added directive 6 (two-row form-choice table), one edge case, one Instead-of row, and the §2.6.2 quote + 4-shell repro to the existing source line. `last_verified` 2026-07-10 → 2026-08-05 |
| I2 (guardrail half) | `command-text-inspected-before-execution` already owns "a gate blocked a correct command"; its existing edge case covers exit-2-to-stderr | **Merged 3 edge cases**, none duplicating: blocked command emits *no side effect* so a poller waits forever; a path-scoped rule matches text not purpose (so the harness's own script is refused); Write succeeding where Bash was refused is gate *scope*. Cross-linked to the new orchestration page. `last_verified` 2026-07-30 → 2026-08-05 |
| I5 | `timeouts-and-retries` covers outbound calls, 429 + `Retry-After`, and concurrency caps — but not *client-side rate limiting to stay under a published quota*, and says nothing about auth-layer requests | **New page**, `related:` both ways. Its 429 row is referenced from the new page's retry edge case rather than restated |
| I6 | `testing/quality` holds `tests-that-cannot-fail`, `checks-that-cannot-pass`, `harness-reverse-controls` — all "your verification evidence is weaker than you claim" | **New page** in that category (same shape: *your grep evidence is weaker than you claim*). `related:` both ways with `tests-that-cannot-fail`, which its "suite is green" edge case defers to |
| I1 | `command-text-inspected-before-execution` (harness *gates* a command) and `non-interactive-cli-invocation` (harness *runs* a CLI) are adjacent but neither covers a harness *rewriting a result* | **New page**, cross-linked to both |
| I3 | Nothing in the wiki covers worker liveness/completion verdicts | **New page** (merged with I2's orchestration half — one case: a control signal is a hint, the primary artifact is the evidence) |
| I4 | `backend/common/concurrency/distributed-locks` and `jobs/scheduled-job-overlap` cover mutual exclusion between *processes of one service*, not *two orchestration runs over one repo* | **New page**, `related:`-linked to both rather than duplicating their lock guidance |

**Conflicts flagged:** none. No new directive contradicts an existing page. The
one tension — I5's queued wording vs. the providers' actual bucket policies — was
a defect in the *candidate*, resolved by branching the directive (see I5 above),
not by overwriting anything.

**Merge decision on I2+I3:** the queue carried these as two rows from two sessions,
but they are one case (a control signal is not evidence) with two failure
instances (a false "dead" verdict; a never-emitted status write). Per
`wiki-ingest` step 4 they went into one page rather than two near-duplicates.

**Back-links added both ways:** `timeouts-and-retries` → `client-side-rate-limiting`;
`tests-that-cannot-fail` → `migration-call-site-survey`;
`command-text-inspected-before-execution` → both new orchestration and harness pages.

## Routing decision

| # | Insight | Target | New category? |
|---|---------|--------|---------------|
| I1 | Hook rewrites a tool's result | `platforms/tools/harness-mediated-tool-results` | No — closest fit |
| I2+I3 | Status/liveness verdict vs. primary artifact | `infrastructure/orchestration/control-signals-vs-primary-artifacts` | **Yes** |
| I4 | Shared orchestration state directory | `infrastructure/orchestration/shared-run-state` | **Yes** (same) |
| I5 | Throttle bypassed by the token request | `backend/common/reliability/client-side-rate-limiting` | No |
| I6 | Call-site survey for a signature migration | `testing/quality/migration-call-site-survey` | No |
| I7 | `${VAR:-}` vs `${VAR-}` | merged → `platforms/shells/portable-shell-scripts` | No |

**New category `infrastructure/orchestration` — why the existing six don't fit.**
`ci-cd` is pipeline structure and build secrets; `deploy` is how a service reaches
production; `observability` is instrumenting a running service; `config` is
per-environment settings; `containers` and `data` are plainly unrelated. None
covers *several agent/worker sessions coordinating over one repository* — the
subject of three of the seven candidates, which is what justifies a category
rather than a lone page. `INDEX.md` and the domain index route line were both
updated so the category is reachable.

**Routing note on I6.** The queue's `domain` hint said `testing`, and it landed in
`testing/quality` — but on the category's actual theme (*is your evidence as strong
as your claim?*) rather than on "it broke some tests". Its "load when" leads with
the signature-migration trigger so a migration task routes in without a test failure
having happened yet.

**Routing note on I1.** `platforms` is nominally OS-level, but it already absorbs
agent-harness concerns (`command-text-inspected-before-execution`,
`non-interactive-cli-invocation`), so `tools` was taken as the closest fit rather
than opening a second new category. The domain's route line now names it.

## Lint

Run against the `AGENTS.md` maintenance invariants across all 7 touched pages:

- Body lines: 73 / 88 / 82 / 83 / 85 / 80 / 85 — all ≤ 120 ✅
- Banned vague qualifiers (`usually`, `consider`, `generally`, `typically`, …): **0** ✅
- `id:` matches file path on every page ✅
- Every `related:` id resolves — re-checked **repo-wide**, not just on new pages ✅
- Every inline `[page-id]` reference resolves ✅
- All 5 new pages listed in their domain `index.md` with a "load when" line ✅
- New category reachable from `INDEX.md` ✅
- `log.md`: 1 `ingest` + 2 `revise` entries appended ✅
- Prohibitions appear only in `Instead of` rows, each paired with a replacement ✅

## Queue

The 7 flushed rows are appended to `~/.dev-loop/queue/.processed.jsonl` and removed
from their 5 session files, so the next flush does not re-ingest them.
