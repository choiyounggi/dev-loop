---
id: infrastructure-agent-orchestration-worktree-isolated-workers
domain: infrastructure
category: agent-orchestration
applies_to: [git, general]
confidence: verified
sources:
  - https://git-scm.com/docs/git-worktree
  - https://code.claude.com/docs/en/hooks
last_verified: 2026-09-03
related: [infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-shared-run-state, platforms-shells-command-text-inspected-before-execution, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, platforms-tools-deny-rules-under-bypassed-permissions, infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge, infrastructure-agent-orchestration-verify-command-in-a-worker-brief]
---

# Writing the Brief for a Worker Confined to Its Own Worktree

## When this applies

You are authoring the brief, prompt, or output contract for parallel agent
workers that each run in their own git worktree under a guardrail that stops
writes outside it. Also when workers stall at the same step and the coordinator's
wait loop keeps escalating with no error from the task itself.

## Do this

1. **Write every path a worker produces as worktree-relative**, so the
   correctness of the brief does not depend on where the worktree lives:
   `.orchestration/plans/<task>.md`, not `/repo/.orchestration/plans/<task>.md`.
2. **Collect, don't deposit.** The orchestrator reads each worker's artifacts
   out of that worker's worktree after the phase; a worker never writes into the
   shared main checkout. This is what keeps N workers from racing on one file.
3. **Route by direction — the guardrail is asymmetric**, so state it precisely
   in the brief:

| Worker action on a main-checkout path | Guardrail outcome | Brief should say |
|----------------------------------------|-------------------|------------------|
| Write (`cp`, `mv`, `mkdir`, `touch`, `tee`, `rm`, `dd`, or a `>`/`>>` redirect to an absolute path) | fires — `ask` or `deny` | Never — emit to a worktree-relative path |
| Read (`cat`, `ls`, `grep` with no redirect) | passes | Allowed, and the right way to consume shared read-only input |

4. **When workers must share a mutable directory, put it outside both the main
   checkout and the worktrees** and pass its absolute path as one named
   variable, so the brief has exactly one absolute path and it is not a repo
   path.
5. **Fix the brief rather than relaxing the rule.** Isolation is the precondition
   for running the workers in parallel at all; turning the guardrail off trades
   a stall you can see for main-checkout corruption you cannot.
6. **Dry-run one worker's output contract before fanning out.** Run the exact
   write commands from the brief inside a worktree and require them to complete
   without an escalation — one probe costs a minute and a bad brief costs every
   worker's first phase.
7. **Name every tool-owned gate/state directory (`.dev-loop/`, `.orchestration/`)
   as worktree-relative in the brief, before the worker's first write.** A tool
   that derives its repository root from `git rev-parse --git-common-dir` (the
   main checkout's `.git`, shared by every linked worktree) instead of
   `--show-toplevel` (the current worktree's own root) computes its state path
   under the main checkout even while running inside a worktree — the relative
   rule in the brief is what stops the worker from acting on that path.

## Edge cases

| Case | Then |
|------|------|
| A worker needs the plan another worker produced | The orchestrator copies it into the consuming worker's worktree, or the worker reads it (reads pass); do not have the producer write into the consumer's tree |
| The escalation arrives as a permission prompt in a non-interactive session | It becomes a hard denial — the worker halts with no task-level error, which is why the symptom is a stalled phase rather than a failure |
| The brief names the main checkout only as a read source | It works, and it still couples the brief to one machine's layout — pass it as a named variable so the brief stays portable |
| The guardrail is heuristic and matches on absolute paths | A relative path inside the worktree cannot trip it at all; that is the second reason to write paths relative |
| A worker writes to a path under the main root that is a *sibling* string (`<main_root>-backup/…`) | The guardrail does not fire — the match requires a path separator after the main root — but the write is still outside the worktree; keep it out of the brief |
| A read-only command (`ls`, `grep`, `awk`, `git status`) naming the main checkout's or another worktree's absolute path raises an `ask` escalation anyway, halting the watch | Guardrail rules differ by version: a conservative rule treats any cross-worktree path reference in command text as a potential write, reads included. Extend the step-6 dry run with one read probe to learn which behavior you have; when reads escalate, budget the round-trip into the phase (read the escalation record → approve or deny → clear the escalation state → restart the watch) and state in the worker's first briefing which reads are pre-approved and that writes and system-temp use stay forbidden — this cuts repeat escalations for the same access |
| A worker reads another **worker's** worktree (`<main_root>/<other-worktree>/FINDINGS.md`) — a later wave consuming an earlier wave's output | The rule strips only the worker's *own* worktree path before looking for a main-root mention, so a sibling worktree's path stays in the string and the read is one write verb away from firing. Give the consumer a copy in its own worktree, or keep the cross-worktree read on a command line of its own |
| A read of a main-root path shares a command line with any write verb (`mkdir -p .claude/tmp && grep … <main_root>/x`) | It fires `ask`, even though the write targets a worktree-relative path — the two conditions are matched independently over the whole command string, not correlated with each other. Split the write and the read into separate commands |
| A read of a main-root path is redirected to an absolute path (`grep … <main_root>/x > /tmp/out`) | It fires — the redirect-to-absolute branch matches regardless of what is being read. Redirect to a worktree-relative path |
| The brief points the worker at a coordinator-state directory that is gitignored (`.orchestration/`, `.state/`) via a repo-relative path | The path resolves only in the main checkout: `git worktree add` checks out tracked files, so an ignored directory never materializes in a worktree. Substitute the absolute main-checkout path into the brief and state that the directory is gitignored and absent from the worktree — a capable worker otherwise hides the miss by searching for the file instead of failing |
| The guardrail is a Bash-command hook and the worker edits files through its native Edit/Write tool | The hook never runs — tool hooks match on the tool name, so a `Bash` matcher does not fire for Edit/Write calls, and an absolute-path edit into the main checkout lands with no block and no log. State in the brief that **all** file operations, whatever the tool, use worktree-relative paths, and `git status` the protected tree before merging any worker's branch — discovery otherwise depends on luck |
| A `worktree_escape` escalation arrives, or the main checkout's `git status --porcelain -uall` shows modifications while workers run | Read the Bash escalation as the visible part and check the main tree in the same step. When it holds files a worker's task owns, transfer them before touching either branch: in the main checkout `git diff -- <paths> > <patch>`, in that worker's worktree `git apply --check <patch>` then `git apply <patch>` (untracked files: copy them across), then in the main checkout `git checkout -- <paths>` and delete the copied untracked files, and re-run `git status` there to confirm it is clean. Stop the escaping worker before lifting the patch — a live worker keeps writing while you transfer — and when several workers are in flight, attribute the dirty files by mtime: `ls -lT` (or `stat`) against each worker's active window names the one whose own worktree is clean while its files sit dirty in main. A hook that also guards the file tools registers a PreToolUse matcher of `Bash\|Write\|Edit\|MultiEdit` |
| A test unrelated to the task just merged fails, or the integration branch checked out in main shows modifications nobody merged | Treat it as an escape that already landed: `git status --porcelain` in main and in every worktree; a worker whose worktree is clean while main is dirty wrote by absolute path. With the integration branch checked out in main those edits ride into the next merge commit as another task's work, so transfer and clean main (row above) before the next merge, then re-run the failing tests |
| A `worktree_escape` escalation arrives for a write that has **not yet executed** (`rm -rf <main_root>/.dev-loop`, `mkdir <main_root>/.dev-loop/gates`) | Deny it — nothing has landed, so there is nothing to transfer — and hand the worker the same path rewritten worktree-relative (`.dev-loop/gates`) to retry with. A write that already landed through a non-Bash tool is the recovery case above, not this one |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Put the main checkout's absolute path in a worker's `<output_contract>` | Give a worktree-relative path and collect the artifact from the worktree | One absolute write path halts every worker at the same phase, and the coordinator sees only a wait-loop timeout |
| Disable the escape guardrail so the workers proceed | Rewrite the paths in the brief | The guardrail is what makes parallel workers safe to run against one repo |
| Designate a shared scratch directory inside the repo for worker output | Place it outside the repo and pass its path as one named variable | A shared in-repo directory is both a guardrail trip and a write race between workers |
| Reuse the coordinator's repo-relative path to a gitignored state directory in a worker's prompt template | Expand it to the absolute path at substitution time and note the directory is absent from the worktree | Ignored files exist only where they were created; the relative form silently resolves to a nonexistent path in every worker, and reads of absolute main-root paths pass the guardrail |
| Trust a Bash-hook guardrail as the only isolation for workers with native file tools | Pair it with a relative-paths-only instruction in the brief and a pre-merge `git status` of the main checkout | The hook inspects only the tool its matcher names; an Edit-tool write to an absolute main-checkout path passes silently — the worker need not be routing around anything for the escape to happen |
| Answer a worktree-escape escalation and move on | Check the main checkout's `git status` in the same step and transfer any worker-owned changes by patch | The Bash hook sees one channel; file-tool edits into the main checkout raise no escalation and are found only by looking |
| Approve a pre-write `worktree_escape` for a state directory because "the tool needs it" | Deny, and reply with the worktree-relative equivalent of the same path | The tool resolved its root against the shared `.git` common dir; the same directory inside the worktree serves it, and approving lets N workers write one shared state tree in main |
| Rely on workers complying with a relative-paths-only instruction for edits made through the native Edit/Write tools, when the hook matcher cannot be widened to cover those tools | Route the worker's edits through Bash (heredoc, `sed`, worktree-relative paths) instead of the Edit/Write tools, so the existing Bash-only guard covers every write, and run `git status --porcelain` in main after each task | Edit/Write bypass the guard regardless of instruction compliance, as the field evidence below shows; moving the edit itself onto the channel the guard inspects removes the failure path instead of relying on the worker following a rule |

## Sources

- https://git-scm.com/docs/git-worktree — linked worktrees are separate checkouts sharing one repository; each has its own working directory
- https://code.claude.com/docs/en/hooks — tool-event hook matchers filter on the tool name ("`Bash` matches only the Bash tool"); a hook registered for Bash does not run on Edit/Write calls; the documented matcher form `Edit|Write` fires on both file tools
- https://git-scm.com/docs/git-apply — `--check`: "Instead of applying the patch, see if the patch is applicable to the current working tree and/or the index file and detects errors"
- https://git-scm.com/docs/git-rev-parse — `--show-toplevel` shows the top-level directory of the working tree; `--git-common-dir` shows `$GIT_COMMON_DIR` (the repository shared by all linked worktrees). Reproduction 2026-09-03 (git 2.x, macOS): from a linked worktree the first returned the worktree's own root and the second the main checkout's `.git`
- Field evidence 2026-08-24 (linkly, second orchestration run): escalations lo-19 (`rm -rf <main_root>/.dev-loop`) and lo-22 (`mkdir <main_root>/.dev-loop/gates`) arrived back to back from workers whose tool resolved its state directory against the main checkout; both were denied with the worktree-relative path in the reply and the workers proceeded without touching main
- Field reproduction 2026-08-21 (dev-loop orchestrate, task hide-color-nudge): on a `worktree_escape` escalation, the main checkout held three files belonging to worker lo-2 whose own worktree was clean; `git diff > patch` in main, `git apply --check` (rc 0) and `git apply` in lo-2's worktree, then `git checkout --` in main left the main tree clean (`MAIN_CLEAN` confirmed) with the work preserved on the worker branch
- Field evidence 2026-08-25 (linkly t112): a worker's cwd was its worktree, yet `diagnostics.py` and `lower.py` in the main checkout carried mtimes 14:23–14:27 when checked at 14:29, naming the worker active in that window; after stopping it and cleaning main by patch transfer, all 11 diagnostic test failures attributed to the just-merged task disappeared
- Field observation 2026-08-17 (linkly run, worker under a `worktree_escape` Bash-hook guard): the worker modified two `examples/*.lnpl` files in the **main checkout** via its native Edit tool with absolute paths — no block, no log; discovered only when the coordinator's `git pull` failed on local changes (contents happened to match the merged branch, so no damage). The same paths written via Bash redirection would have escalated
- Field reproduction 2026-08-05 (groundwork guardrails 1.0.0 `hooks/bash-guard.sh`, `worktree_escape` rule, macOS): from a linked worktree, `cp ./a <main_root>/b` and `echo z > <main_root>/f` were both stopped; `cat <main_root>/f`, `ls <main_root>/.orchestration`, and `grep -n x <main_root>/f` all passed. The rule matches an absolute main-root mention together with a write verb (`rm|mv|cp|tee|mkdir|touch|install|dd`) or a redirect to an absolute path
- Field evidence 2026-08-06 (dev-loop orchestrate, Wave 2 worker consuming an upstream worktree's FINDINGS file): a read-only `awk`/`grep` verification and a `git status` check each raised `worktree_escape` as `ask` and stopped the coordinator's watch with exit 5; both were confirmed read-only and approved. This rule version fired on reads, unlike the 1.0.0 reproduction above where bare `cat`/`ls`/`grep` passed — the read/write asymmetry in the Do-this table is version-dependent, so probe before fanning out
- Field evidence 2026-08-26 (linkly): task t119's read-only Bash diff tripped the guardrail as `ask`, while task t113's three native Edit-tool writes all passed silently and landed in the main checkout; adding a `git status --porcelain` post-check in main after each task caught the third write immediately
- Local reproduction 2026-08-06 (groundwork guardrails 1.2.0 `hooks/bash-guard.sh`, `worktree_escape`, macOS), run from a linked worktree against a sibling worktree's path: `grep -n foo <main_root>/<other>/FINDINGS.md`, `awk 'NR<5' <main_root>/<other>/FINDINGS.md`, `cat <main_root>/README.md` and `git -C <main_root>/<other> status --short` all passed; `mkdir -p .claude/tmp && grep -n foo <main_root>/<other>/FINDINGS.md`, `cp <main_root>/README.md ./x` and `grep -n foo <main_root>/<other>/FINDINGS.md > /tmp/out` each returned `ask`. Reading the rule confirms why: it fires when a main-root mention survives the strip **and** `(rm|mv|cp|tee|mkdir|touch|install|dd)` or a redirect to an absolute path matches anywhere in the command — the two tests are independent
- Field context: a parallel run stalled at the same phase for two workers whose brief's `<output_contract>` named a main-checkout absolute path; the coordinator's wait loop returned its escalation status repeatedly. Rewriting the contract to worktree-relative paths let the remaining workers record their plans locally
- Local reproduction 2026-08-13 (git 2.x, macOS): in a repo with `.gitignore` containing `.orchestration/` and a populated `.orchestration/status/`, `git worktree add ../wt1 -b wt1` produced a worktree where `ls ../wt1/.orchestration` → No such file or directory and `cat .orchestration/status/run.json` from the worktree cwd failed; `git ls-files .orchestration` → 0 tracked files. Field context: dev-loop's own `templates/session-prompt.md` handed workers `.orchestration/…` relative paths, and workers located the files by searching the main checkout rather than failing
