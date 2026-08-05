# Knowledge flush — 9 insight(s)

Drained `~/.dev-loop/queue/` (5 session files, 9 pending rows) on 2026-08-05.
Result: **9 new pages**, 1 new category (`infrastructure/agent-orchestration`),
7 existing pages updated with reciprocal links, 1 candidate claim **refuted by
measurement** and corrected before ingest.

## Verified best-practice

Every claim was re-tested rather than taken from the session that emitted it.
Six were reproduced locally on this machine; three rest on cited primary sources
plus a field incident.

### 1. A wrapped tool reports warnings on stderr and exits 0 → `verified`
**Claim:** a gate keyed on exit status misses warnings; capture stderr with
`OUT=$(tool "$f" 2>&1 >/dev/null)` and branch on emptiness — redirection order
decides which stream you get.
**Checked:** POSIX XCU 2.7 ("If more than one redirection operator is specified
with a command, the order of evaluation is from beginning to end");
[GCC warning options](https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html);
[Claude Code hooks](https://code.claude.com/docs/en/hooks) — `PostToolUse` exit
code 2 "Shows stderr to Claude; the tool already ran".
**Reproduced 2026-08-05** (Apple clang, macOS): unused-variable source → exit 0
with `warning:` on stderr; clean source → exit 0, empty stderr; undeclared
identifier → exit 1. Same run: `2>&1 >/dev/null` captured `STDERR-DIAG`,
`2>/dev/null >&1` captured `STDOUT-PAYLOAD` — the reversed form feeds the build
artifact back as if it were a diagnostic.

### 2. A `capture-pane` diff is not delivery evidence → `verified`
**Claim:** check the target TUI's busy/queued indicator first; the pane changes
for a queued keystroke because the tty echoes it.
**Checked:** [termios(3)](https://man7.org/linux/man-pages/man3/termios.3.html)
`ECHO` — "Echo input characters", independent of when the program calls
`read()`; [tmux(1)](https://man7.org/linux/man-pages/man1/tmux.1.html).
**Reproduced 2026-08-05** (tmux 3.7b, macOS): sent `echo SECOND_PROMPT_MARKER`
to a pane running `sleep 6`. Pane diff = **YES**, marker present once as echoed
text, command's own output line count = **0**. After the sleep drained, the
command ran and the output line appeared. A pane-diff test placed first reports
"delivered" for exactly the queued case it was written to detect.

### 3. `--` before an interpolated operand → `verified`
**Checked:** POSIX XBD 12.2 Guideline 10 — "The first `--` argument that is not
an option-argument should be accepted as a delimiter indicating the end of
options. Any following arguments should be treated as operands, even if they
begin with the '-' character."
**Reproduced 2026-08-05** (tmux 3.7b): `tmux send-keys -t S -l "-n hello"` →
`command send-keys: unknown flag -n`, exit 1; with `-- "-n hello"` → exit 0.
Generalized past tmux: this is option parsing in the callee, not shell quoting.

### 4. A Stop-gate's terminal set must include instructed pauses → `verified`
**Checked:** [Claude Code hooks](https://code.claude.com/docs/en/hooks) —
`stop_hook_active` is a documented Stop-hook input; hooks exit early when it is
true, and Claude Code overrides a Stop hook after eight consecutive blocks
(`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`).
**Reproduced in-repo at `95cf947`:** `hooks/loop-gate.sh:55` lists
`done|approved|merged|failed|""` as terminal, while
`skills/orchestrate/templates/session-prompt.md:20` instructs a plan-phase
worker to record `plan_ready` and "wait for an approval message. Do NOT write
implementation code yet." `scripts/status-update.sh:6` confirms `plan_ready` is
a first-class phase. The gate therefore fires on a worker that obeyed its own
prompt; `loop-gate.sh:30`'s `stop_hook_active` return is what bounds it.

### 5. Worktree-isolated worker briefs → `verified`, **with the candidate's stated mechanism refuted**
**Candidate claimed:** the `worktree_escape` guardrail blocks *reads* (`ls`,
`cat`) of the main checkout as well as writes.
**Measured 2026-08-05** against groundwork guardrails 1.0.0
`hooks/bash-guard.sh` (built a real repo + linked worktree and ran the hook):

| Command from a linked worktree | Decision |
|--------------------------------|----------|
| `cat <main_root>/f` | allow |
| `ls <main_root>/.orchestration` | allow |
| `grep -n x <main_root>/f` | allow |
| `cp ./a <main_root>/b` | **fires** |
| `echo z > <main_root>/f` | **fires** |

The rule (`bash-guard.sh:217-250`) matches an absolute main-root mention
together with a write verb (`rm|mv|cp|tee|mkdir|touch|install|dd`) or a redirect
to an absolute path. Reads pass. **The directive survives** (worktree-relative
output paths; orchestrator collects) — the reason given for it did not, so the
page documents the verified write-only asymmetry and adds reads as the
*sanctioned* way to consume shared input. Logged as `contradiction` in `log.md`.

### 6. httpx repeated form fields → `verified` (source-level)
**Checked:** [`httpx/_content.py`](https://github.com/encode/httpx/blob/master/httpx/_content.py).
`encode_request`: `if data is not None and not isinstance(data, Mapping):
warnings.warn("Use 'content=<...>' to upload raw bytes/text content.",
DeprecationWarning); return encode_content(data)` — a list of tuples is sent as
**raw body**, with no `application/x-www-form-urlencoded` header, so the server
parses an empty form and still returns its success status.
`encode_urlencoded_data` expands a `list`/`tuple` **value** into repeated
`(key, item)` pairs — confirming `data={"k": ["a","b"]}` is the correct form.
Also [httpx quickstart](https://www.python-httpx.org/quickstart/). httpx is not
installed on this machine, so this one is source-verified rather than re-run.

### 7. Client-side throttle bypassed by auth refresh → `field-tested`
**Checked:** the candidate asserted flatly that "token requests count toward the
rate limit". That is **provider-specific** —
[Okta](https://developer.okta.com/docs/reference/rl2-token-oauth/) and
[GitHub](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
document separate budgets for token/OAuth endpoints. The directive was therefore
narrowed: put the throttle where every outbound request passes, and read the
provider's docs for which bucket the token endpoint is in (with a documented
default when it is unstated). An Auth0 citation was dropped after fetching the
page and finding it does not support the claim.
**Field evidence:** `auto-trading-bot` commit `82a077e`
(`src/broker/kis_client.py`) — `_headers()` ran `_throttle()` then called
`_get_token()`, so on newly-issued-token days the token POST and the API GET
landed in the same second and the provider rejected the call; logs show
`POST …:00.354` → issued `…:00.495` → rejected `…:00.543`, and cached-token days
passed on identical code. Confidence held at `field-tested` — the mechanism is
production-observed, not doc-derived.

### 8. Enumerate call sites by callee, not by parameter name → `field-tested`
**Checked:** [Python tutorial 4.9.2](https://docs.python.org/3/tutorial/controlflow.html)
— a function may be called positionally or with `kwarg=value`, which is exactly
why a keyword-name grep cannot see positional callers;
[Fowler, test impact analysis](https://martinfowler.com/articles/rise-test-impact-analysis.html)
for deriving reach from the change. `refactoring.com`'s Change Function
Declaration entry was fetched but returned no body text, so it is **not** cited.
**Field evidence:** a migration scoped by `grep -rn "repo_rows"` returned 13
hits, all keyword-style, and was reported "7 of 13"; the full suite then gave
`Ran 472 tests / FAILED (failures=11)`, all in one file passing the value as the
callee's 4th positional argument, plus a `rows_for()` helper still supplying the
removed shape to 5 more call sites.

### 9. `${VAR:-default}` swallows an empty value → `verified`
**Checked:** POSIX XCU 2.6.2 — "use of the <colon> in the format shall result in
a test for a parameter that is unset or null; omission of the <colon> shall
result in a test for a parameter that is only unset."
**Reproduced 2026-08-05:** with `V=""`, `${V:-def}` → `def`, `${V-def}` → empty;
with `V` unset, both → `def`. Origin case (`WATCH_TMUX=` failing to disable a
liveness check reading `${WATCH_TMUX:-tmux}`, and `WATCH_TMUX=/nonexistent…`
working) is consistent with the spec.

## Existing-layer check

**Pages read in full before writing anything:** `INDEX.md`, `AGENTS.md`,
`templates/page.md`, the domain indexes for infrastructure / testing / platforms
/ backend / debugging / qa, and — as the overlap candidates —
`platforms/shells/portable-shell-scripts`,
`platforms/processes/non-interactive-cli-invocation`,
`testing/quality/tests-that-cannot-fail`, `testing/quality/checks-that-cannot-pass`,
`backend/common/reliability/timeouts-and-retries`,
`infrastructure/config/environment-config`, `qa/process/regression-scope`,
`backend/python/index.md`.

**Merge-vs-create outcomes:**

| Candidate | Nearest existing page | Decision |
|-----------|----------------------|----------|
| stderr/exit-0 gate | `testing/quality/checks-that-cannot-pass` | **Create.** That page's trigger is a check whose *target does not exist yet*; this is a check whose *tool succeeded*. Cross-linked both ways; the new page defers to it for the known-good-input discipline |
| `--` separator | `platforms/shells/portable-shell-scripts` §5 "build argument lists safely" | **Create.** That page's "When this applies" is cross-machine/cross-shell portability; this failure happens on one machine in one shell. Its §5 is about shell word-splitting, this is callee option parsing — the new page says so explicitly |
| `${VAR:-}` vs `${VAR-}` | `portable-shell-scripts` (edge case `"${OPT:-}"`), `infrastructure/config/environment-config` §5 | **Create.** Same reason — different trigger. `environment-config` owns service config schemas and required-keys-get-no-default; this owns a caller trying to switch a script off. Linked both ways |
| httpx repeated form fields | `testing/quality/tests-that-cannot-fail` | **Create + merge.** Trigger matches ("a bug shipped through an area the suite reported as covered"), but the encoding mechanics do not belong in a general page. Added **one new never-fails row** to `tests-that-cannot-fail` — "HTTP test of a write endpoint asserting only the response status" — pointing at the new page |
| throttle/token | `backend/common/reliability/timeouts-and-retries` | **Create.** That page owns timeouts, retry-by-failure-type and 429 *reaction*; this owns *proactive* client-side pacing and where the throttle must sit. Linked both ways |
| call-site enumeration | `qa/process/regression-scope` | **Create.** `regression-scope` already has the adjacent edge case "code with no test coverage and unclear callers → trace callers before scoping"; the new page is the how. Linked both ways |
| 3 agent-orchestration pages | none | **Create.** No page in any domain covers driving/gating/isolating agent worker sessions. `platforms/processes/non-interactive-cli-invocation` is the nearest neighbour (invoking a prompt-capable CLI unattended) and is now linked from the pane page |

**Conflicts flagged:** one — the `worktree_escape` reads-vs-writes claim (§5
above), logged in `log.md` as a `contradiction` entry rather than silently
written as fact.

**Reciprocal links added:** `portable-shell-scripts` → all three new shells
pages; `checks-that-cannot-pass` → `exit-status-vs-diagnostics`;
`tests-that-cannot-fail` → `write-path-assertions`; `regression-scope` →
`call-site-enumeration`; `timeouts-and-retries` → `client-side-rate-limiting`;
`environment-config` → `env-var-off-switches`;
`non-interactive-cli-invocation` → `pane-delivery-confirmation`.

## Routing decision

| # | Insight | Target |
|---|---------|--------|
| 1 | Warnings on stderr with exit 0 | `platforms/shells/exit-status-vs-diagnostics.md` |
| 2 | Pane diff ≠ delivery | `infrastructure/agent-orchestration/pane-delivery-confirmation.md` |
| 3 | `--` before interpolated operands | `platforms/shells/option-like-argument-values.md` |
| 4 | Stop-gate terminal set | `infrastructure/agent-orchestration/session-completion-gates.md` |
| 5 | Worktree-relative worker briefs | `infrastructure/agent-orchestration/worktree-isolated-workers.md` |
| 6 | Write-path assertions / httpx form encoding | `testing/quality/write-path-assertions.md` |
| 7 | Throttle vs auth refresh | `backend/common/reliability/client-side-rate-limiting.md` |
| 8 | Enumerating call sites | `qa/process/call-site-enumeration.md` |
| 9 | Env-var off switches | `platforms/shells/env-var-off-switches.md` |

**New category — `infrastructure/agent-orchestration` (3 pages).** Justified
because no existing category covers it: `ci-cd` is pipeline structure,
`config`/`deploy`/`observability` are service lifecycle, `containers` is images
and limits, and `platforms/processes` owns *invoking* a CLI unattended, not
*coordinating a fleet of worker sessions*. All three insights hinted
`infrastructure`, and the domain's route line + `INDEX.md` were updated so the
category is reachable rather than orphaned. Three pages seed it at once, so it
does not land as a one-page category.

**Routing calls worth a reviewer's attention:**

- **#8 → `qa`, not `testing` or `backend`.** The queue hinted `testing`, but the
  trigger is a signature migration, not writing tests. `qa` owns regression
  scoping and the Integration ring ("the contract changed — then test **every**
  consumer of that contract, not a sample"); a function signature is a contract
  and its call sites are the consumers. `backend/common` was rejected because
  its categories are all runtime concerns and the lesson is language-agnostic
  code-change methodology. Alternative home if you disagree: a new
  `testing/quality` page — say so and it moves.
- **#6 → `testing/quality`, not `backend/python`.** The artifact is test code;
  `backend/python` is server-side application code. The httpx mechanics ride
  along as the concrete cause.
- **#1 and #3 → `platforms/shells` rather than the new orchestration category.**
  Both mechanisms (redirection order, POSIX option parsing) are reusable well
  beyond agent harnesses, and both were reproduced with non-agent tools.
- **Three new pages in one category (`platforms/shells`).** Each has a distinct
  trigger per the one-case-per-page rule; none is a variant of another.

## Verification of the wiki's own invariants

Ran a mechanical check over all 148 pages after the edits: every `related:` id
and inline `[page-id]` reference resolves, no page exceeds 120 body lines, all
nine new pages appear in their domain index with a "load when" line, all carry
`When this applies` / `Do this` / `Sources`, and the banned vague qualifiers are
absent (three initial hits were rewritten). `log.md` has `ingest`, `revise`, and
`contradiction` entries for this flush.
