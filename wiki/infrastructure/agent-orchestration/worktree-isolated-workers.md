---
id: infrastructure-agent-orchestration-worktree-isolated-workers
domain: infrastructure
category: agent-orchestration
applies_to: [git, general]
confidence: verified
sources:
  - https://git-scm.com/docs/git-worktree
last_verified: 2026-08-05
related: [infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-pane-delivery-confirmation, platforms-shells-command-text-inspected-before-execution]
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

## Edge cases

| Case | Then |
|------|------|
| A worker needs the plan another worker produced | The orchestrator copies it into the consuming worker's worktree, or the worker reads it (reads pass); do not have the producer write into the consumer's tree |
| The escalation arrives as a permission prompt in a non-interactive session | It becomes a hard denial — the worker halts with no task-level error, which is why the symptom is a stalled phase rather than a failure |
| The brief names the main checkout only as a read source | It works, and it still couples the brief to one machine's layout — pass it as a named variable so the brief stays portable |
| The guardrail is heuristic and matches on absolute paths | A relative path inside the worktree cannot trip it at all; that is the second reason to write paths relative |
| A worker writes to a path under the main root that is a *sibling* string (`<main_root>-backup/…`) | The guardrail does not fire — the match requires a path separator after the main root — but the write is still outside the worktree; keep it out of the brief |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Put the main checkout's absolute path in a worker's `<output_contract>` | Give a worktree-relative path and collect the artifact from the worktree | One absolute write path halts every worker at the same phase, and the coordinator sees only a wait-loop timeout |
| Disable the escape guardrail so the workers proceed | Rewrite the paths in the brief | The guardrail is what makes parallel workers safe to run against one repo |
| Designate a shared scratch directory inside the repo for worker output | Place it outside the repo and pass its path as one named variable | A shared in-repo directory is both a guardrail trip and a write race between workers |

## Sources

- https://git-scm.com/docs/git-worktree — linked worktrees are separate checkouts sharing one repository; each has its own working directory
- Field reproduction 2026-08-05 (groundwork guardrails 1.0.0 `hooks/bash-guard.sh`, `worktree_escape` rule, macOS): from a linked worktree, `cp ./a <main_root>/b` and `echo z > <main_root>/f` were both stopped; `cat <main_root>/f`, `ls <main_root>/.orchestration`, and `grep -n x <main_root>/f` all passed. The rule matches an absolute main-root mention together with a write verb (`rm|mv|cp|tee|mkdir|touch|install|dd`) or a redirect to an absolute path
- Field context: a parallel run stalled at the same phase for two workers whose brief's `<output_contract>` named a main-checkout absolute path; the coordinator's wait loop returned its escalation status repeatedly. Rewriting the contract to worktree-relative paths let the remaining workers record their plans locally
