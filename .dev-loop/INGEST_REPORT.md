# Knowledge flush — 9 insight(s)

Drained 9 pending candidates from 7 session files in `~/.dev-loop/queue`. Result:
**5 new pages, 2 existing pages extended, 0 dropped.** No candidate was accepted on
assertion alone — each was re-derived from primary docs, reproduced locally, or
demoted to `field-tested` with the reason stated.

## Verified best-practice

### 1. `create_all()` + hand-written ALTER — testing additive migrations
**Claim:** a test that calls `init_db()` twice does not test the migration; only a
run that starts from the *previous* schema does.
**Checked:** SQLAlchemy [metadata](https://docs.sqlalchemy.org/en/20/core/metadata.html)
— `create_all()` "will issue queries that first check for the existence of each
individual table, and if not found will issue the CREATE statements", and altering
constructs "via the ALTER statement … is outside of the scope of SQLAlchemy itself".
SQLAlchemy [defaults](https://docs.sqlalchemy.org/en/20/core/defaults.html) —
`server_default` "gets placed in the CREATE TABLE statement", and neither default
backfills existing rows. PostgreSQL [ddl-alter](https://www.postgresql.org/docs/current/ddl-alter.html)
— "the default value will be returned the next time the row is accessed".
**Correction applied:** the candidate credited the surviving-row values to the model's
`server_default`. The docs place the backfill on the `DEFAULT` clause of the `ALTER`
instead; the page now says so, and adds `ADD COLUMN` without a `DEFAULT` as the defect
the assertion catches. → **verified**

### 2. tmux pane-diff is not delivery evidence
**Claim:** a busy pane echoes typed characters, so a `capture-pane` diff reports
"delivered" for input that was never consumed.
**Reproduced (tmux 3.7b, macOS):** sent `echo SECOND_PROMPT` to a pane running
`sleep 6` — pane content changed (naive diff → delivered) while the command's own
output count stayed **0**, becoming **1** only after the sleep drained. Mechanism is
terminal `ECHO` in canonical mode
([POSIX chap11](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html)).
→ **verified**

### 3. `tmux send-keys` payloads need a `--` separator
**Reproduced:** `tmux send-keys -t S -l "-n hello"` → `command send-keys: unknown flag -n`,
exit 1; the identical call with `-- "-n hello"` → exit 0.
[POSIX Guideline 10](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap12.html)
gives the mechanism. Noted honestly in the page: [tmux.1](https://man.openbsd.org/tmux.1)
documents `-l` but does **not** document `--`; the behaviour follows getopt convention.
→ **verified**

### 4. Backticks survive double quotes and gut a CLI text payload
**Reproduced** — in zsh, with the command example backquoted inside double quotes:

```
$ echo "run: `pip install -e .[dev]` first"
zsh:1: no matches found: .[dev]
run:  first          # exit 0, message gutted
```

bash substituted the command's output instead; the single-quoted form printed the
text verbatim.
[POSIX 2.2.3](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html):
the backquote "shall retain its special meaning introducing the other form of command
substitution" inside double quotes. → **verified**

### 5. POSIX `set --` inside a helper function is discarded
**Reproduced under `/bin/sh` and `dash`:** `parse_flags "$@"` left the caller with
`argc=4` still containing `--dry-run`; the identical loop inline gave `argc=3` with the
space-bearing operand intact. `DRY=1` in **both** — the flag is detected either way, so
only the operand list is wrong and nothing errors. POSIX 2.9.5: on return "the value of
the special parameter `#` and the positional parameters shall be restored to the values
they had before the function was executed". → **verified**

### 6. A gate-blocked command is indistinguishable from a silent success
**Claim:** a `worktree_escape` guardrail blocked the orchestrator's own
`status-update.sh`; empty stdout read as success while no status file was written.
**Verified in-session:** the status directory was empty afterwards, and a Write-tool
call to the same tree succeeded — proving the block is command-text-scoped, not a
filesystem permission. Consistent with the page's already-cited
[hooks doc](https://code.claude.com/docs/en/hooks) (exit 2 blocks; the reason goes to
stderr, not stdout). → **verified**

### 7. A harness hook can replace a tool's result
**Claim:** a session-memory plugin returned only line 1 of a file plus a remediation
note that did not work.
**Checked:** the [hooks doc](https://code.claude.com/docs/en/hooks) documents
`PostToolUse` `updatedToolOutput` — it "replaces the tool's result" — and names
transformation of "inbound tool results" as an intended use. The *mechanism* is
therefore verified; the specific plugin's behaviour is dated field context in the page,
and the page's rule is "size-check with `wc` first, because interception and a
genuinely small file look identical". → **verified** (mechanism) with dated field context

### 8. PATH-injected recording fake for destructive daemon sweeps
**Reproduced:** with a fake `tmux` prepended to `PATH`, a prefix sweep over fixtures
`run-1, run-2, mydev` logged exactly `KILL run-1` / `KILL run-2`, **zero** bystander
lines, and an **empty** log for a non-matching prefix — while the machine's 8 real tmux
sessions, 3 of which matched the pattern under test, were untouched. The seam is
[POSIX chap08](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap08.html)
`PATH` search order; fake-vs-mock framing from
[Fowler](https://martinfowler.com/articles/mocksArentStubs.html). → **verified**

### 9. Auth/token requests bypass a method-level rate-limit throttle
**Claim:** a throttle on the client's public methods misses the token POST issued
inside `_headers()`, so two requests leave in the same second.
**Checked:** [Okta](https://developer.okta.com/docs/reference/rate-limits/) documents
per-endpoint rate-limit buckets covering OAuth token endpoints;
[Auth0](https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy)
publishes an `/oauth/token` limit; [GitHub](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
states OAuth-app requests "count towards" the user's limit. Together these source the
general rule (token issuance is metered) and the remedy (throttle at the lowest
HTTP-issuing layer).
**Honest limit:** the specific 2-requests/second quota and the timestamped log evidence
come from one provider's mock environment and were **not** confirmed against that
provider's published spec — no primary doc stating the number was found, and no URL was
invented for it. The page is therefore **field-tested**, not verified, with the
provider-specific numbers confined to a "Field context" note.

## Existing-layer check

Routed via `INDEX.md`, then read every domain index whose route line overlapped, then
every page whose "load when" line could collide.

**Pages read in full:** `platforms/shells/portable-shell-scripts`,
`platforms/shells/command-text-inspected-before-execution`,
`platforms/processes/non-interactive-cli-invocation`,
`platforms/processes/background-services` (its tmux mention),
`databases/schema-design/online-schema-changes`, `testing/mocking/what-to-mock`,
`backend/common/reliability/timeouts-and-retries`. Plus a repo-wide grep for
`tmux|orchestrat|rate limit|throttl|quota` to catch coverage the index lines hide.

**Merged rather than duplicated (2):**

| Candidate | Merged into | What was added |
|-----------|-------------|----------------|
| POSIX `set --` in a function; backticks in a double-quoted payload | `platforms/shells/portable-shell-scripts` | Step 5 extended with the POSIX-sh in-place `"$@"` reordering idiom + the inline-only rule; new step 6 on single- vs double-quoting a text payload; 3 edge cases, 3 Instead-of rows, 3 sources |
| Guardrail blocks a script, silent failure | `platforms/shells/command-text-inspected-before-execution` | New steps 6–7 (verify the artifact, not the silence; hand a blocked signal back as un-emitted); 2 edge cases, 2 Instead-of rows, dated field context |

Both pages' `last_verified` bumped to 2026-08-05; both stay under the 120-line cap
(92 and 107 body lines).

**Overlap examined and rejected as a merge (4):**

- `timeouts-and-retries` covers outbound-call reliability (timeouts, retry-by-failure-type,
  backoff, concurrency caps) but never client-side pacing to a provider quota — a
  repo-wide grep found no `throttl|rate limit` page outside edge/WAF contexts in
  `security/`. New page; cross-linked for the 429/`Retry-After` path.
- `what-to-mock` decides *whether* to substitute an in-process dependency at an
  interface. The daemon case has a different seam (`PATH`, not an interface) and a
  different stake (the test can destroy the developer's environment). New page,
  `related`-linked.
- `online-schema-changes` owns ALTER **lock** behaviour, not proving that a hand-rolled
  migration ran. New sibling page in the same category, cross-linked for the
  volatile-default rewrite case.
- `non-interactive-cli-invocation` owns *starting* a prompt-capable CLI; driving an
  *already-running* TUI through a pty is a distinct case. New page, `related`-linked.

**Conflicts flagged:** none. No new directive contradicts an existing one.

**Related-links added:** every new page links back into the existing graph
(`online-schema-changes`, `nullability-and-defaults`, `test-data-and-isolation`,
`tests-that-cannot-fail`, `what-to-mock`, `path-resolution`,
`command-text-inspected-before-execution`, `non-interactive-cli-invocation`,
`background-services`, `timeouts-and-retries`, `jwt-server-side`, `hypothesis-testing`).
An invariant pass confirms every `related:` id and inline `[page-id]` reference
resolves, all 7 touched pages appear in their domain index, and no page exceeds 120
body lines.

## Routing decision

| # | Insight | Target | New/merge |
|---|---------|--------|-----------|
| 1 | Testing an additive migration under `create_all()` + hand-written ALTER | `databases/schema-design/verifying-additive-migrations` | **new** |
| 2+3 | Confirming a keystroke reached a TUI in a tmux pane; `--` for `send-keys` payloads | `platforms/processes/driving-a-tui-in-a-tmux-pane` | **new** (one page — both are the same operation) |
| 7 | A harness hook substituted a tool's result | `platforms/processes/harness-tool-result-interception` | **new** |
| 8 | Sweep-tests against a live shared daemon | `testing/mocking/destructive-operations-on-shared-daemons` | **new** |
| 9 | Token requests bypassing a client throttle | `backend/common/reliability/client-side-rate-limit-pacing` | **new** |
| 4+5 | POSIX `set --` scope; backticks in a double-quoted payload | `platforms/shells/portable-shell-scripts` | merge |
| 6 | Gate-blocked command reads as a silent success | `platforms/shells/command-text-inspected-before-execution` | merge |

**No new categories were created.** Each new page landed in an existing category, and
in the two places a new category was tempting the closest fit was taken instead:

- Insight 1 could have opened `databases/migrations/`, but `schema-design/` already
  holds `online-schema-changes`, which is migration machinery. A category holding one
  page next to its sibling adds a routing hop for no discrimination.
- Insights 2, 3 and 7 are agent/orchestration concerns that could have opened
  `platforms/orchestration/`. `platforms/processes/` already covers "keeping processes
  alive as services" and "invoking prompt-capable CLIs non-interactively"; driving and
  observing another process is the same concern, so all three went there.

Root `INDEX.md` route lines were extended for all four touched domains (databases,
backend, testing, platforms); `log.md` gained one `ingest` and one `revise` entry.

**Reviewer's attention is best spent on:** the `field-tested` rating on
`client-side-rate-limit-pacing` (§9 — the provider-specific quota is unsourced by
design), and on whether insights 2, 3 and 7 belong under `platforms/processes/` or
justify an `orchestration` category once more agent-harness pages accumulate.
