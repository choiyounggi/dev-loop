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
last_verified: 2026-09-10
related: [testing-quality-checks-that-cannot-pass, infrastructure-agent-orchestration-session-completion-gates, platforms-environment-path-resolution, infrastructure-config-path-valued-config, debugging-signals-reading-error-messages]
---

# A Gate-Check EVIDENCE Line Whose Exit Code Names the Checker's Failure, Not the Check's Verdict

## When this applies

A dev-loop gates-ledger run (`gate-check.sh --run`, or a `CHECK:` line that
itself invokes `plan-gate.sh check ...`) reports one or more gates UNMET, and
the recorded `EVIDENCE:` line reads `exit=127: ... No such file or
directory` or `exit=126: ... Permission denied` / `... not executable`.
Deciding whether to edit the checked plan/artifact (`analysis.md`,
`design.md`) or the gate's own invocation before re-running.

## Do this

1. **Read the EVIDENCE exit code before touching the plan.** `gate-check.sh`
   records `exit=<code>: <truncated output>` for any non-zero, non-timeout
   result; it does not itself separate "the checker never ran" from "the
   checker ran and found a defect" — that classification is the reader's job.
2. **Classify by exit code before acting**:

| Exit code | Meaning | What it tells you |
|-----------|---------|--------------------|
| 127 | command not found | the shell never found/started the program named in `CHECK:` — a broken invocation, not a verdict on the plan |
| 126 | found but not executable | same class as 127 — a permission/exec-bit problem on the invoked file, not a verdict |
| 124 / 142 | timeout (`GATE_CHECK_TIMEOUT`, default 120s, via `gate-check.sh`'s own perl-alarm wrapper) | the command ran but exceeded its budget — not this page's case |
| Any other code the checked script defines (e.g. dev-loop's `plan-gate.sh`: 3 = content defect, 4 = target file/section missing) | the checker ran to completion and returned its own documented failure | this is the only class that means "edit the plan" |

3. **When exit is 127/126, look for an unresolved variable in the `CHECK:`
   line itself before opening the artifact.** dev-loop's
   `templates/plan-gates.md` leaves `${CLAUDE_PLUGIN_ROOT}` as a live shell
   variable that `gate-check.sh` expands via `bash -c` at execution time. In
   a plain, non-Claude-Code shell it is unset, and an unset `${VAR}` with no
   `:-`/`:=` default expands to the empty string (POSIX §2.6.2), so
   `${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh` becomes
   `/skills/wiki-plan/scripts/plan-gate.sh` — a path that never exists.
4. **Export `CLAUDE_PLUGIN_ROOT` to the plugin's installed root before
   re-running outside a Claude Code session**, then re-run
   `gate-check.sh --run` unchanged. `CLAUDE_PLUGIN_ROOT` is exported by
   Claude Code only into plugin skill/agent content, hook and monitor
   commands, and MCP/LSP server fields — not into an arbitrary shell, so a
   ledger produced for one context and re-run by hand in another needs the
   variable supplied explicitly.
5. **Only exit 1/3 (or whatever the checker's own documented failure code
   is) is evidence of a real content defect** — edit the plan/artifact only
   then.
6. **Use a mixed result within one ledger as its own diagnostic.** A gate
   whose `CHECK:` needs no plugin-rooted script (e.g. dev-loop's
   `baseline-tests-ran`, whose command is the plan's own recorded Baseline
   command) passing while sibling gates in the same run fail with
   `exit=127` isolates the fault to the plugin-path expansion, not to plan
   content — read it as confirmation, not as partial progress.

## Edge cases

| Case | Then |
|------|------|
| Re-running with `CLAUDE_PLUGIN_ROOT` exported flips every UNMET gate to MET, with zero file edits | The gate identified an invocation bug, not a plan defect — this confirms the exit-127 reading and closes the investigation |
| Only some `exit=127` gates flip after exporting `CLAUDE_PLUGIN_ROOT` | Diff the still-UNMET gates' `CHECK:` lines for a second broken path, or a genuine content defect now visible as exit 3/4 |
| The EVIDENCE line reads `exit=124` or `exit=142` | Timeout, not command-not-found — raise `GATE_CHECK_TIMEOUT` or investigate why the checked command is slow; this page does not cover that case |
| Hand-testing `plan-gate.sh` / `gate-check.sh` directly in a terminal, outside any dev-loop skill invocation | `CLAUDE_PLUGIN_ROOT` will never be auto-set there; export it yourself (pointed at the plugin's cache directory) or invoke the scripts by absolute path instead of relying on the `CHECK:` line's `${CLAUDE_PLUGIN_ROOT}` form |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Treat every UNMET gate as a defect in `analysis.md`/`design.md` and start editing | Read the EVIDENCE exit code first; edit content only on the checker's own documented failure code | `exit=127`/`126` means the shell could not even start the checker — editing content it never evaluated does nothing and hides the real (environment) cause |
| Assume a `CHECK:` line's `${CLAUDE_PLUGIN_ROOT}` resolves the same in a plain shell as inside a Claude Code session | Export `CLAUDE_PLUGIN_ROOT` to the plugin's root before running `gate-check.sh`/`plan-gate.sh` outside Claude Code | Claude Code exports `CLAUDE_PLUGIN_ROOT` only into plugin hook/skill/MCP/LSP contexts; a bare `sh`/`bash` invocation never receives it, so the variable silently expands to empty rather than erroring |

## Sources

- https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html — "If a command is not found, the child process created to execute it returns a status of 127. If a command is found but is not executable, the return status is 126."
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — POSIX Shell & Utilities §2.6.2 Parameter Expansion: `${parameter}` substitutes the value of `parameter`, if any; with no `:-`/`:=`/`:?`/`:+` modifier, an unset parameter substitutes nothing
- https://code.claude.com/docs/en/plugins-reference — `${CLAUDE_PLUGIN_ROOT}` is substituted/exported inline in skill and agent content, hook and monitor commands, MCP `stdio`/`http`/`sse`/`ws` server fields, and LSP server fields; no plain-shell or interactive-session export is documented
- Local reproduction 2026-09-10, dev-loop plugin `groundwork/dev-loop` v1.21.0 (`~/.claude/plugins/cache/groundwork/dev-loop/1.21.0`): `templates/plan-gates.md` states `${CLAUDE_PLUGIN_ROOT}` is "left as a live shell variable — gate-check.sh runs CHECK via `bash -c`, which expands it at execution time"; `skills/loop-implement/scripts/gate-check.sh`'s `run_check()` executes `CHECK:` via `/bin/bash -c` and records EVIDENCE as `exit=<code>: <truncated output>` for any non-zero, non-timeout exit, with no special-casing of 126/127; `skills/wiki-plan/scripts/plan-gate.sh` documents its own exit codes (0 ok, 2 usage, 3 check failed/content defect, 4 target file/section missing) — one layer below the shell-level 126/127 a broken `${CLAUDE_PLUGIN_ROOT}` produces
- Field reproduction (a dev-loop wiki-plan run, 2026-09-09): `.dev-loop/gates/plan-A-t1-normalize.md`, first `gate-check.sh --run` → `met=1 unmet=4`, all four UNMET `EVIDENCE:` lines reading `exit=127: sh: /skills/...: No such file or directory`; identical file re-run with `CLAUDE_PLUGIN_ROOT` exported to the plugin root → `met=5 unmet=0`, no file edited
