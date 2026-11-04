---
id: infrastructure-agent-orchestration-gate-evidence-exit-code-class
domain: infrastructure
category: agent-orchestration
applies_to: [claude-code, general]
confidence: verified
sources:
  - https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
  - https://code.claude.com/docs/en/plugins-reference
  - https://www.gnu.org/software/coreutils/manual/html_node/timeout-invocation.html
last_verified: 2026-11-04
related: [testing-quality-checks-that-cannot-pass, infrastructure-agent-orchestration-session-completion-gates, platforms-environment-path-resolution, infrastructure-config-path-valued-config, debugging-signals-reading-error-messages, testing-quality-gate-parsing-vs-command-execution, platforms-tools-plugin-mcp-server-registration, qa-process-completion-claims]
---

# A Gate-Check EVIDENCE Line Whose Exit Code Names the Checker's Failure, Not the Check's Verdict

## When this applies

A check runner that executes each gate's command through a shell and records
its exit code (a gates ledger, a CI step matrix, a pre-merge checklist
script — dev-loop's `gate-check.sh --run` is one) reports gates as failed, and
the recorded evidence reads `exit=127: ... No such file or directory` or
`exit=126: ... Permission denied` / `... not executable`, or
`exit=142`/`exit=124 timeout after <T>s`. Deciding whether to edit the checked
artifact, the gate's own invocation, or its time budget before re-running.

## Do this

1. **Read the recorded exit code before touching the checked artifact.** A
   runner that records `exit=<code>` for every non-zero result does not
   separate "the checker never ran" from "the checker ran and found a defect"
   — that classification is the reader's job.
2. **Classify by exit code before acting**:

| Exit code | Meaning | What it tells you |
|-----------|---------|--------------------|
| 127 | command not found | the shell never found/started the program the gate names — a broken invocation, not a verdict on the artifact |
| 126 | found but not executable | same class as 127 — a permission/exec-bit problem on the invoked file, not a verdict |
| 124 / 142 | timeout (`timeout(1)` returns 124; an alarm-signal wrapper returns 142 = 128 + SIGALRM(14) — dev-loop's `GATE_CHECK_TIMEOUT` is one) | the command ran but exceeded its budget — size the budget (Edge cases), do not edit the artifact |
| Any other code the checker documents (e.g. dev-loop's `plan-gate.sh`: 3 = content defect, 4 = target file/section missing) | the checker ran to completion and returned its own documented failure | this is the only class that means "edit the artifact" |

3. **When exit is 127/126, look for an unresolved variable in the gate's
   command line before opening the artifact.** A command templated as
   `${ROOT_VAR}/path/to/checker` that the runner expands via `bash -c` at
   execution time depends on the environment of whoever runs it. An unset
   `${VAR}` with no `:-`/`:=` default expands to the empty string (POSIX
   §2.6.2), so the command becomes `/path/to/checker` — a path that never
   exists. dev-loop's plan gates are this shape: `${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh`.
4. **Supply the variable the harness normally exports, then re-run the
   ledger unchanged.** A harness-injected variable exists only in the
   contexts that harness launches. Claude Code, for example, exports
   `CLAUDE_PLUGIN_ROOT` only into plugin skill/agent content, hook and
   monitor commands, and MCP/LSP server fields — so a ledger produced in one
   context and re-run by hand in a plain shell needs it exported explicitly.
5. **Only the checker's own documented failure code is evidence of a real
   content defect** — edit the artifact only then.
6. **Use a mixed result within one ledger as its own diagnostic.** A gate
   whose command needs no templated root (e.g. one that runs the project's
   own test command) passing while sibling gates in the same run fail with
   `exit=127` isolates the fault to the variable expansion, not to artifact
   content — read it as confirmation, not as partial progress.

## Edge cases

| Case | Then |
|------|------|
| Re-running with `CLAUDE_PLUGIN_ROOT` exported flips every UNMET gate to MET, with zero file edits | The gate identified an invocation bug, not a plan defect — this confirms the exit-127 reading and closes the investigation |
| Only some `exit=127` gates flip after exporting `CLAUDE_PLUGIN_ROOT` | Diff the still-UNMET gates' `CHECK:` lines for a second broken path, or a genuine content defect now visible as exit 3/4 |
| The EVIDENCE line reads `exit=124` or `exit=142` | Timeout, not command-not-found — the command ran and was killed at its budget; no artifact edit is indicated. Raise `GATE_CHECK_TIMEOUT` (next row) or investigate why the checked command is slow |
| One `CHECK:` runs the full suite N times (once per env variant, e.g. a default leg and an override leg) and reads `exit=142 timeout after <T>s` | Measure one full pass first, then set `GATE_CHECK_TIMEOUT` to that single-pass time × N plus margin before re-running — the timeout is one alarm around the whole `bash -c` command, not per pass. Re-run the ledger unchanged; a flip to MET with every pass green confirms the budget, not the code, was the cause |
| Hand-testing `plan-gate.sh` / `gate-check.sh` directly in a terminal, outside any dev-loop skill invocation | `CLAUDE_PLUGIN_ROOT` will never be auto-set there; export it yourself (pointed at the plugin's cache directory) or invoke the scripts by absolute path instead of relying on the `CHECK:` line's `${CLAUDE_PLUGIN_ROOT}` form |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Treat every UNMET gate as a defect in `analysis.md`/`design.md` and start editing | Read the EVIDENCE exit code first; edit content only on the checker's own documented failure code | `exit=127`/`126` means the shell could not even start the checker — editing content it never evaluated does nothing and hides the real (environment) cause |
| Assume a `CHECK:` line's `${CLAUDE_PLUGIN_ROOT}` resolves the same in a plain shell as inside a Claude Code session | Export `CLAUDE_PLUGIN_ROOT` to the plugin's root before running `gate-check.sh`/`plan-gate.sh` outside Claude Code | Claude Code exports `CLAUDE_PLUGIN_ROOT` only into plugin hook/skill/MCP/LSP contexts; a bare `sh`/`bash` invocation never receives it, so the variable silently expands to empty rather than erroring |

## Sources

- https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html — "If a command is not found, the child process created to execute it returns a status of 127. If a command is found but is not executable, the return status is 126."
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — POSIX Shell & Utilities §2.6.2 Parameter Expansion: `${parameter}` substitutes the value of `parameter`, if any; with no `:-`/`:=`/`:?`/`:+` modifier, an unset parameter substitutes nothing
- https://www.gnu.org/software/coreutils/manual/html_node/timeout-invocation.html — exit status "124 if command times out, and --preserve-status is not specified"
- https://code.claude.com/docs/en/plugins-reference — `${CLAUDE_PLUGIN_ROOT}` is substituted/exported inline in skill and agent content, hook and monitor commands, MCP `stdio`/`http`/`sse`/`ws` server fields, and LSP server fields; no plain-shell or interactive-session export is documented
- Local reproduction 2026-09-10, dev-loop plugin `groundwork/dev-loop` v1.21.0 (`~/.claude/plugins/cache/groundwork/dev-loop/1.21.0`): `templates/plan-gates.md` states `${CLAUDE_PLUGIN_ROOT}` is "left as a live shell variable — gate-check.sh runs CHECK via `bash -c`, which expands it at execution time"; `skills/loop-implement/scripts/gate-check.sh`'s `run_check()` executes `CHECK:` via `/bin/bash -c` and records EVIDENCE as `exit=<code>: <truncated output>` for any non-zero, non-timeout exit, with no special-casing of 126/127; `skills/wiki-plan/scripts/plan-gate.sh` documents its own exit codes (0 ok, 2 usage, 3 check failed/content defect, 4 target file/section missing) — one layer below the shell-level 126/127 a broken `${CLAUDE_PLUGIN_ROOT}` produces
- https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html — "When a command terminates on a fatal signal whose number is N, Bash uses the value 128+N as the exit status" (SIGALRM = 14 → 142)
- Local read 2026-11-04, dev-loop v1.34.5 `skills/loop-implement/scripts/gate-check.sh`: `run_check()` sets one `perl` `alarm` of `GATE_CHECK_TIMEOUT` seconds (default 120) and then `exec`s `/bin/bash -c "<CHECK>"`, so the whole CHECK — every suite pass inside it — shares one budget; exit 124 or 142 is recorded as `exit=<code> timeout after <T>s`
- Field reproduction (a dev-loop orchestrate task, 2026-11-02): a CHECK running the bats suite twice (default + override env, ~229 cases each) recorded `exit=142 timeout after 900s`; the identical CHECK re-run with `GATE_CHECK_TIMEOUT=2400` → MET, 229/229 in both passes
- Field reproduction (a dev-loop wiki-plan run, 2026-09-09): `.dev-loop/gates/plan-A-t1-normalize.md`, first `gate-check.sh --run` → `met=1 unmet=4`, all four UNMET `EVIDENCE:` lines reading `exit=127: sh: /skills/...: No such file or directory`; identical file re-run with `CLAUDE_PLUGIN_ROOT` exported to the plugin root → `met=5 unmet=0`, no file edited
