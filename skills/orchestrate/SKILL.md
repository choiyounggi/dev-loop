---
name: orchestrate
effort: high
argument-hint: "[goal or parent issue]"
description: Orchestrate one natural-language goal into parallel tmux Claude Code sessions. It decomposes the goal (with your approval), plans each task with wiki-plan, implements and reviews, runs an integration test, and merges after your confirmation. Use to build a goal across multiple sessions. For a single task, use loop-implement instead.
---

# orchestrate — multi-session orchestrator

You are the orchestrator. **You do not implement — sessions do.** You clarify,
decompose, distribute, review, integrate, and merge. Autonomy lives inside the
implementation loop; two human gates bracket it (task-split, pre-merge).

Scripts referenced below live in `${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/`.
Communication: session→orchestrator via `.orchestration/status/<task>.json`;
orchestrator→session via `launch-session.sh` (the first prompt) then
`send-prompt.sh` (every later one), carrying templates/session-prompt.md §1–§4 on
tmux, or the Task `--spec` (same file, §O1–§O4) on Orca.

## Tool profile
Resolve the pluggable tool profile once up front:
`sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --summary`. It maps capability
roles — `intake` (issue-tracker work-list source), `knowledge` (domain/policy),
`tacit` (incidents/danger zones), `verify` (test/build/QA
command), `explore` (code search), `design` (visual/UI spec, e.g. Figma) — to
whatever tools this installation has, or to generic defaults when unset (optional,
layered per-user then per-repo; see `references/tool-profile.md`). Use
`knowledge`/`tacit` yourself during Clarify/Decompose, and write each task's
resolved roles into its `<tools_guidance>` brief so worker sessions inherit them
even if they can't re-read the config. A role is a tool injected into one step,
never a loop: do not map a role to an implement/verify-loop tool or another
orchestrator (that nests loops); there is no `implement` role.

## Preflight
Run `${CLAUDE_PLUGIN_ROOT}/hooks/preflight.sh` to resolve git/tmux/jq paths and
surface any missing CLI. **git, tmux, and jq are all required** — if any is
missing, stop and ask the user to install it (the SessionStart preflight hook is
advisory only; this skill must hard-require them). For a missing tmux: with the
user's consent, install it (macOS: `brew install tmux`; otherwise advise) before
launching sessions. Never auto-install without consent.

**Coordinator permissions (tmux substrate).** `launch-session.sh` starts each
worker as `claude --permission-mode bypassPermissions` — the exact surface an
auto-mode permission classifier hard-flags as privilege escalation. It cannot
see the context that makes this safe (each worker worktree carries a guardrails
deny-net that still blocks dangerous commands in bypass mode and escalates
`ask` rules to you), so under an auto-mode coordinator the launch may be
DENIED. Handle this at onboarding, not at the first failure:

1. **Probe once, read-only**, during Preflight:
   `sh {SKILL}/scripts/install-permission-rules.sh --check` — exit 0 rules
   present (nothing to do), **4** absent, 3 the settings file is malformed
   (surface that to the user; fix before anything else).
2. **On 4, ask the user — never install silently.** One question: "orchestrate's
   tmux workers launch with permission prompts off (guardrails-sandboxed);
   pre-approve the three worker-management scripts in ~/.claude/settings.json?"
   Show what it adds (the snippet below). A plugin that widens permissions
   without a fresh explicit yes is the supply-chain pattern guardrails exists
   to stop — and the fresh consent is also what lets the classifier pass the
   write at all.
3. **On an explicit yes**, run `sh {SKILL}/scripts/install-permission-rules.sh`
   (idempotent; backs up, refuses a malformed target, atomic write). On no —
   or if the installer itself is classifier-blocked — fall back to showing the
   snippet for the user to paste themselves, then continue; the launch will
   simply prompt (default mode) or deny (auto mode) until it lands.
4. If a launch is DENIED later anyway: do **not** work around the block — an
   agent widening its own permissions on its own initiative is itself
   classifier-blocked, by design. Re-offer step 2 and stop until the user
   decides.

What the installer adds (equivalently pasteable into
`.claude/settings.local.json` per-project, or `~/.claude/settings.json`
globally; `safe-cleanup.sh` is deliberately absent so destructive verbs keep
their normal review):

```json
{
  "permissions": { "allow": [
    "Bash(sh /Users/<you>/.claude/plugins/cache/*/dev-loop/*/skills/orchestrate/scripts/launch-session.sh *)",
    "Bash(sh /Users/<you>/.claude/plugins/cache/*/dev-loop/*/skills/orchestrate/scripts/send-prompt.sh *)",
    "Bash(sh /Users/<you>/.claude/plugins/cache/*/dev-loop/*/skills/orchestrate/scripts/watch-status.sh *)"
  ]},
  "autoMode": { "allow": [
    "$defaults",
    "Running the dev-loop orchestrate plugin's worker-management scripts (launch-session.sh, send-prompt.sh, watch-status.sh) is allowed, including launch-session.sh starting a tmux worker with `claude --permission-mode bypassPermissions`: the user sanctioned this orchestration workflow, and each worker worktree is sandboxed by groundwork guardrails, which still blocks dangerous commands in bypass mode and escalates `ask` rules to the coordinator. This does NOT extend to safe-cleanup.sh or other destructive commands, which keep their normal review."
  ]}
}
```

The path rules cover full-path invocations; the `autoMode.allow` rule teaches
the classifier the context so variable-form invocations (`sh $SKILL/scripts/…`)
pass too. The Orca substrate does not spawn through `launch-session.sh`, but
its worker terminals embed the same flag — if a classifier flags those, the
same `autoMode.allow` rule is the fix.

## Phase 0 — Intake + Clarify
Two ways the work-list arrives:
- **`intake` role configured** (e.g. an issue tracker) → if the user names a parent
  issue (key/URL), use the intake tool to read it and its children: the parent gives
  the overall goal/architecture, each child becomes a candidate task. Extract the
  issue key from a URL (last path segment). This is the "Jira-style" entry — only
  taken when `intake` is set *and* the user supplies an issue; otherwise:
- **`intake` unset, or a free-text goal** → the natural-language path (default):
  decompose the goal yourself in Phase 2.

**Already-done children (partial resume):** treat a child as *completed* if the user
says so (by key) or — when intake exposes status — its tracker status is Done. A
completed child is **not** decomposed into a task (no session/worktree), but it is
**not silently dropped** either: record what it produced as a **base output** — the
exact exposed signature (function/type/component/endpoint). Any task that depends on
it then still gets that contract injected (Phase 2/3). If the user names a completed
key without the signature, read it from the integration branch / its merged code
rather than re-creating it. This is how "one sub-issue already done, do the rest"
works safely.

Either way, ask the user — one question at a time — until goal / scope / constraints
/ done criteria are clear enough to decompose. Don't start until they are.

## Phase 1 — Environment branch
- **git repo present** → create a feature (integration) branch + one worktree per
  task. Determine base via `gh repo view --json defaultBranchRef` (fallback: the
  current branch) — measure, don't assume.
- **no git repo** → run `scripts/safe-cleanup.sh init-check <workdir>`. Only if it
  returns ok, `git init` (add a `.gitignore` incl. `.orchestration/` first), then
  proceed as above. If it REFUSEs (nested repo / secrets), stop and report.

## Phase 2 — Decompose
Get the task set: use the `intake` children as candidate tasks if Phase 0 read an
issue, otherwise split the goal into independent tasks yourself. **Drop the
completed children (Phase 0) from the task set** — but seed the dependency graph
with their base outputs (already-satisfied), so their dependents still resolve and
get the signature injected, while no session is spawned for them. Then, the same way
for both, for each *remaining* task extract **affected files**, **outputs** (what it newly
creates — component/schema/endpoint/type), and **consumes** (another task's output
it depends on). Build a conflict/dependency matrix from those and topologically sort
into Waves (`conflict-matrix.md`): a dependency edge `A → B` means B consumes A's
output, so A's Wave precedes B's. Detect duplicate outputs and assign a single
producer; others consume (add a dependency edge). Write BOTH artifacts: `conflict-matrix.md` for humans and
`.orchestration/graph.json` for the scheduler. A markdown table is not machine
readable.

```json
{ "tasks": [
    { "id": "t1", "deps": [],     "files": ["src/auth/**"], "outputs": ["AuthToken"] },
    { "id": "t3", "deps": ["t1"], "files": ["src/api/**"],  "consumes": ["AuthToken"] }
] }
```

Waves are **an illustration in the Gate 1 report, not an execution unit.**
Execution is decided by `ready-set.sh`: a task runs as soon as its dependencies
are `approved` and a slot is free. Still topologically sort — the result shows
the user the expected flow — but nothing waits on a Wave boundary.

**Propose the slot count.** Pick the number from the task count, their size, and
their risk, and **say what the number protects**: this cap guards **coordinator attention** and **API usage/budget**, not machine resources. Neither is
queryable, which is why it is a judgement rather than a computation. A slot is
held from dispatch until the task reaches a terminal state — `plan_ready` and
`impl_done` (review pending) count as held, because a pile of unreviewed tasks
next to a stream of new ones makes the cap meaningless. When `LO_MAX_SESSIONS`
is set it is an upper bound and overrides the proposal.

After writing it, run `scripts/ready-set.sh <graph> <status-dir> <cap>` once and
confirm it does **not** exit 4 — malformed JSON, a missing `.tasks` array, and a
dependency naming an undefined task are all caught here.

**Visual spec (`design` role).** While extracting the above, flag each task that is
UI-facing *and* whose source issue references a design (e.g. a Figma link). If the
`design` role is configured, pull that task's spec with it (don't guess from the
link) and carry it into the brief's `<design_spec>` (Phase 3 step 2). Backend-only
tasks, or any task with no design reference, skip this. With `design` unset, ignore
design links entirely — the original behavior.

## 🚦 Gate 1 — task-split approval (REQUIRED)
Report the task list, the dependency graph (showing the expected flow as Waves is
fine), the proposed **slot count with its rationale and what it protects**, and a
rough cost note. **Wait for the
user's approval** before launching anything.

**Substrate — ask here, in this same turn.** Before writing that report, run
`scripts/orca-detect.sh`. Non-zero (no Orca): tmux, silently — say nothing about
substrates. Exit 0: report that Orca was detected and put the choice in this same
report — **Orca**: native trust-screen handling, event-driven waits, native
liveness; **tmux**: mid-flight steering via `send-prompt.sh`, no extra dependency. **Wait
for the user's answer**; their answer decides, and you carry it into Phase 3. A
detected Orca always asks — there is no default, no remembered choice, no
environment override. Launch nothing until both the split and the substrate are
answered.

## Phase 3 — Launch + plan (dispatch loop)
**Phases 3–4 are one dispatch loop, not a per-Wave repeat.** Each round:

1. `scripts/ready-set.sh .orchestration/graph.json .orchestration/status <cap>`
   → **0** dispatch the printed ids, **2** nothing dispatchable but work is in
   flight (go wait for an event), **3** **DEADLOCK** — a failed dependency or a
   cycle: **do not wait**, report it and get a human decision (with no worker
   running, no event can ever arrive); after the human intervenes, return to
   step 1 to re-run the check, **4** the graph or status could not be read —
   refuse, do not guess; fix the error then re-run step 1, **5** every task is
   in a terminal state → go to Phase 5.
2. For each dispatched task (`<N>` = the number of tasks in this round):
   - tmux: **0** (Preceding-interface injection) + steps **1–3** below (setup,
     brief, launch, watch plan_ready). Orca: **O1–O5**.
   - **1** `scripts/setup-worktrees.sh <integ> <root> <base> <branch>...` then
     verify with `git worktree list`.
   - **2** Per task: write `briefs/<task>.md` (templates/brief.md) — fill
     `<tools_guidance>` and `<design_spec>` — then launch session and watch
     until `plan_ready` (step 3 below). **Write the brief at dispatch time.**
     It only needs the signatures this task consumes, and by then those are
     `approved`, so they're settled.
   - **3** Collect `plans/<task>.md` when each session reaches `plan_ready`.
3. For each planned task, deliver §2 (implement) with `scripts/send-prompt.sh
   send lo-<n> "<prompt>"` (tmux, see Phase 4 for exit-code branch logic), or
   `orca orchestration task-create` the implement Task then
   `scripts/orca-worker-start --task <impl_task> --terminal <handle>` (Orca).
   On delivery failure, re-run step 3 after fixing the error.
4. Wait for event. tmux: `scripts/watch-status.sh --tasks <running ids>
   <status-dir> impl_done <N>` — without `--tasks` the tasks approved in
   earlier rounds satisfy `expected=<N>` immediately and the wait spins. Orca:
   `scripts/orca-wait.sh` with the implement Task ids, already event-driven.
5. On wake, handle that task: review each worktree diff (`git -C <wt> diff
   <integ>...HEAD`). If tests weak, audit with `test-quality-auditor`. **On
   approval, merge before you loop (issue #90):** fast-forward first —
   `git fetch . <branch>:<integ>` (no checkout needed, works while the main
   worktree sits on another branch) — and only fall back to
   `scripts/safe-cleanup.sh merge <root> <integ> <branch>` when that is not
   fast-forwardable (that verb DOES check out `<integ>` in the main worktree).
   Either way, verify the merge landed with `git merge-base --is-ancestor
   <branch> <integ>` before dispatching any dependent — that exit code is the
   evidence, not the merge command's own chatter. Then return to step 1:
   whatever dependency it released shows up in the next `ready-set.sh` round
   already merged, and the freed slot refills immediately. On rework needed, run
   the Phase 4 rework sequence — `status-update.sh <task> rework`, read the
   new `.attempt`, write `reviews/<task>-rN.md`, re-deliver with
   `send-prompt.sh send` (or a new Orca Task on the same terminal). The
   rework budget is `ready-set.sh`'s job (`LO_MAX_REWORK`); exhaustion
   surfaces as exit-3 DEADLOCK, handled at step 1.
   When `ready-set.sh` returns **5**, go to Phase 5.

**Session knobs (tmux substrate, set once per run):** `export LO_RUN_ID=<short-run-id>`
so every `launch-session.sh` gets a collision-proof name `lo-<n>-<run-id>` (reuse that
exact name for later `send-prompt.sh`); the script also exports the guardrails
escalation env into each worker. Trust-screen wording drifts between CLI releases —
if a launch hangs, set `LO_READY_EXTRA` / `LO_TRUST_EXTRA` (substrings) or
`LO_READY_TIMEOUT`. `status-update.sh` resolves the status file's `session` field
from `tmux display-message -p '#S'` only when the caller is itself inside tmux
(`$TMUX` set) — a coordinator-side call (this shell, not a worker's tmux pane)
must pass `STATUS_SESSION=<lo-n-runid>` explicitly, or the record's `session`
field is left absent rather than guessed from whatever tmux session happens to
be active.
`watch-status.sh` now exits **5** on a pending guardrails escalation (approve/deny,
clear `.orchestration/escalations/`, then DELIVER the outcome to the now-idle
worker with `scripts/send-prompt.sh send lo-<n> "approved — re-run: <cmd>, then
continue"` or `"denied — <alternative>"` — the guardrails deny message told the
worker the orchestrator would re-run it, so a cleared escalation without a
delivered answer leaves it waiting forever — then relaunch) and **3** on a failed
OR a *dead* worker (a non-terminal task whose tmux session vanished — recorded via
the status file's `session` field) — both abort fast instead of waiting the
timeout. It also exits **6** on a pending worker question and **7** on a live
worker whose pane is stalled — playbooks in Phase 3 step 3. Give each
phase its own deadline with one exported
`LO_PHASE_TIMEOUTS="plan_ready=900,impl_done=3600,done=1800"`, keyed on the TARGET
phase of each wait: precedence is an explicit `[timeout-sec]` argument, then the
matching entry, then the 3600s default. A malformed entry (no `=`, non-numeric,
`<= 0`, or an unknown phase name) is refused with **exit 4**, never silently
defaulted; the effective budget and its source are printed before the wait.
`LO_MAX_REWORK` (default 3) is the rework budget `ready-set.sh` enforces —
same validation as `LO_MAX_SESSIONS` (empty/non-numeric/`<= 0` refused with
**exit 4**).

**Substrate (the user decided at Gate 1 — do not re-decide here):** the answer was
Orca or tmux. **Orca** → spawn **and supervise** workers through it, not raw tmux:
it resolves the trust/TUI screen, gives native liveness, and pushes worker events to
you instead of making you poll. Replace steps 1–3 below with O1–O5:

- **O1 — bind the Run once per orchestration run.**
  `orca orchestration run-create --objective "<goal>" --json` → keep `run_id` for the
  whole run (on re-entry, `orca orchestration run-use --id <run_id> --json` instead).
- **O2 — one Task per task-*phase*.**
  `orca orchestration task-create --spec "<the prompt>" --task-title "<short>" --json`
  → `task_id`. Use `templates/session-prompt.md` §O1–§O4 as the `--spec` body; the
  tmux §1–§4 one-liners are for `send-keys` and say "wait", which is wrong here.
  A `worker_done` settles a Task exactly once, so plan / implement / rework are
  separate Tasks. **You sequence them yourself** — dispatch phase N+1 only after
  phase N reads `completed`. Do *not* chain with `--deps`: it takes a JSON array
  (`--deps '["task_x"]'`; a bare id errors), and even then a task created that way
  came back `task_not_startable` with its dependency already `completed`
  (isolated: an identical task with no deps started fine on the same terminal).
- **O3 — start the worker.** First make sure the integration branch exists in the
  main repo (`git branch <integ> <base>` if it does not) — the tmux path gets this
  from `setup-worktrees.sh` step 1, this path does not. Then create the Orca
  worktree **from that branch**: `orca worktree create --repo id:<repoId>
  --name <task> --base-branch <integ> --no-parent --setup run --json` → copy the
  whole `worktree.id`. `--base-branch` is **not optional here**: omit it and Orca
  branches from the repo default (its documented fallback), so a Wave-2 task would
  not build on Wave 1's merged output and Phase 6's merge would drag in unrelated
  default-branch drift. Then scope guardrails inside it — **required, not a
  nicety** — with `scripts/worker-guardrails.sh <worktree-path>`, the same
  single-source script `setup-worktrees.sh` calls on the tmux path. Skip it and
  the worker inherits the *repo/global* rules instead of the sandbox ones, so
  routine in-worktree work (`rm -rf ./build`, `git checkout .`) turns into a
  `deny` + escalation and the worker stalls on the coordinator for every one of
  them. Then, with the escalation env exported:
  `GROUNDWORK_ESCALATION_DIR=<abs> GROUNDWORK_TASK_ID=<task>
  scripts/orca-worker-start.sh --task <task_id> --worktree id:<repoId>::<path>
  --agent claude` → prints `dispatch=<id>` and `handle=<agent-handle>`. For this
  task's **next** phase pass `--terminal <handle>` instead, so the session keeps its
  context. `worker-start --agent` alone cannot carry environment variables, so with
  the escalation env set the script creates the agent terminal itself
  (`terminal create --command`, the escalation contract + `--permission-mode`) and
  binds the Dispatch to it; that is why the worktree must exist first and why
  `new-child` / `new-top-level` are refused in this mode.
  Bare `worktree create` leaves one unused fallback shell beside the agent
  (measured: 3 workers → 4 terminals). After the worker is up, confirm with
  `orca terminal list --worktree id:<...> --json` that the extra handle is an idle
  shell — not a configured default tab — and close just that one with
  `orca terminal close --terminal <handle> --json`.
  A `worker-start` that fails **spends the Task**: it goes to `status=failed` and
  every later attempt on it returns `task_not_startable`. Do not retry the same
  Task — create a fresh one with the same spec. (Seen with `runtime_unavailable`,
  which is what you get when that terminal is still busy with another Dispatch.)
- **O4 — wait on pushed mail, not on a timer.**
  `GROUNDWORK_ESCALATION_DIR=<abs> scripts/orca-wait.sh [--until-all] <timeout-ms>
  [<task_id,task_id,...>]` → **0** completions arrived (acked — process them),
  **2** window elapsed *or* the ack did not land (checkpoint, just re-run), **3** a
  worker reported failure, **4** the runtime itself did not answer (`ok:false`, a
  nonzero status, or a connection lost mid-wait) — an **outage, not a checkpoint**:
  run `orca status --json` before waiting again, and restart nothing on this code
  alone, because a dead runtime does not stop a worker session (measured: workers
  kept committing and pushing while the runtime was down), **5** escalation
  pending (approve/deny, **clear
  `.orchestration/escalations/`**, then re-run — like watch-status, code 5 recurs
  while a record is still on disk, by design), **6** question pending
  (`orca orchestration reply --id <msg_id> --body "<answer>" --json`, re-run).
  **Always pass this Wave's task ids — that is correctness, not a progress
  nicety.** Heartbeats reach this mailbox despite `--types`, and so do completions
  from an earlier Wave or an unrelated Task; without the ids none of that can be
  told apart from your own work. With them, exit 0 means a *successful
  `worker_done` for one of your ids* and the `completed=<c>/<n>` line is scoped to
  this Wave. Add `--until-all` to keep consuming batches until every listed id is
  completed, so one Wave costs one coordinator turn instead of one per batch; it
  still returns immediately on 3/4/5/6. Codes 3/5/6 leave the batch unread on
  purpose, so an unhandled event is never silently dropped — which also means
  delivery is **at-least-once**: a replayed batch must be processed idempotently
  (key off `taskId`, never off a local counter). `ORCA_WAIT_RECHECK_MS` (default
  15000) slices the wait so a guardrails record written *while* you are blocked
  surfaces within one interval instead of one full `<timeout-ms>`.
- **O5 — liveness, in two questions.** `scripts/orca-worktree-alive.sh <wt>`
  (0 alive / 1 dead / 2 unknown — treat unknown as *not* dead) replaces watch's
  tmux check. It only asks whether a terminal is attached, which a wedged worker
  passes: measured, three workers sat on an interactive CLI prompt for 75 minutes,
  ALIVE the whole time, Tasks still `dispatched`, no escalation, diffs unchanged.
  So also run `scripts/orca-worker-stalled.sh <wt>` (0 progressing / 1 stalled /
  2 unknown — treat unknown as *not* stalled; `ORCA_STALL_MS`, default 600000).
  A stall is not a failure to act on blindly: read the worker's screen
  (`orca orchestration worker-read --dispatch <id> --limit 40 --json`) before you
  decide, because "wedged on a prompt" and "finished but never reported" look the
  same from the outside and need opposite responses.

**You cannot steer a running worker.** `orchestration send --to dispatch:<id>`
lands in the worker's mailbox, which a Claude worker never polls, and a new
Dispatch cannot be delivered while the current one runs (that is O2's
`runtime_unavailable`). So a mid-flight correction does not arrive: the supported
path is the Phase-4 review/rework round. (If you do send one, omit `--type` —
`note`/`guidance`/`message`/`info` are all rejected as `invalid_argument`.)

**Worker protocol on this substrate — put this in every `--spec` you dispatch.**
The worker still calls `status-update.sh` at each phase (the status files remain the
durable re-entry state); on top of that it must:
1. report the phase exactly once — `orca orchestration send --type worker_done
   --subject "<status>" --body "<what changed, what remains>" --task-id <task_id>
   --dispatch-id <dispatch_id> --outcome succeeded|failed --files-modified "a,b" --json`
   (a failure is `--outcome failed`, never failure encoded only in prose);
2. forward a guardrails escalation instead of stalling on it — when a command is
   denied with an escalation notice, `orca orchestration send --type escalation
   --subject "guardrails <rule>" --body "<command + why>" --task-id <task_id>
   --dispatch-id <dispatch_id> --json`;
3. use `orca orchestration ask --question "<q>" --timeout-ms <n> --json` for a
   blocking question, and then end its turn — and if that window expires, resume the
   same question with `ask --resume <message_id>` rather than deciding it or asking
   it again. A timeout leaves the question pending; it is not an answer. Measured on
   a 3-worker run: at 600s and 900s both workers instead "proceeded on a conservative
   assumption" and reported the guess after the fact.

Step 2 is the *fast* path for a guardrails block — it arrives with the worker's own
context. It is not the only one: `orca-wait.sh` pre-checks
`GROUNDWORK_ESCALATION_DIR` before it blocks, so a guardrails record still surfaces
when the worker never sends the message (it died, or it is not a Claude session).
Export that dir for both scripts and the file stays the safety net the tmux path
already relied on.

If the user chose tmux at Gate 1 (or `orca-detect.sh` was non-zero), use the tmux
`launch-session.sh` + `watch-status.sh` path below, unchanged. Always verify each
Orca `--json` result before relying on its fields (`worker-start` returns
`.result.dispatchId`, and the agent handle as the `role:"agent"` entry in
`.result.effects[]`). `orca-spawn.sh`
remains only for a worker needing custom agent argv (e.g. codex `--model` /
reasoning-effort flags) that `worker-start` cannot express.

0. **Preceding-interface injection (Wave 2+, and completed base outputs):** before
   launching this Wave, fill each task's brief `<dependencies>` with the **exact
   signatures** of (a) the approved preceding Wave and (b) any completed (partial-
   resume) child it depends on — the real signature, not a paraphrase. This is the
   contract the downstream session plans against; loose text invites drift. Wave 1
   with no completed dependencies skips this.

   **What a `deps` edge delivers, and what it does not (issue #90).**
   `graph.json` `deps` gate DISPATCH on the dependency's approval, and this step
   injects its SIGNATURE — never its merged CODE. Merged code reaches a task's
   worktree only through the merge-on-approval rule (step 5 below): a new
   worktree branches from the integration branch's tip at the moment
   `setup-worktrees.sh` runs (step 1), so it contains a dependency's code only
   if that dependency was already approved and merged by then. A task that must
   read merged results directly — realigning docs against another task's actual
   diff, asserting an invariant that spans two tasks' code — cannot rely on the
   signature alone: give it `deps` on every producer it reads, so it is not
   dispatched until each producer is approved and merged.
1. `scripts/setup-worktrees.sh <integ> <root> <base> <branch>...` — each worktree
   is created AT DISPATCH TIME, branched from the integration branch's CURRENT
   tip; never pre-create a worktree for a future wave, or it misses whatever
   merges land between now and that wave's dispatch. Then verify with `git
   worktree list` — the script's own `base=<hash>` line on each new worktree
   names what it actually branched from.
2. Per task: write `briefs/<task>.md` (templates/brief.md) — fill `<tools_guidance>`
   from the resolved tool profile so the session uses the right knowledge/tacit
   tools (the plan step is fixed to `wiki-plan`, not a configurable role), and for
   a UI-facing task fill `<design_spec>` with the `design` role's pulled spec
   (Phase 2) — then

   The brief and plan are what the worker reads, not what it writes, so every
   reference to them inside a composed prompt uses the `{ORCH_DIR}` token
   (absolute path to this run's `.orchestration` dir, substituted like
   `{STATUS_DIR}`) — the worker's cwd is its own worktree, which does not
   contain `.orchestration/`. Repo files (source, tests, tracked docs) stay
   relative to that cwd instead: an absolute repo path would make the worker
   edit the main worktree rather than its own. This coordinator's own
   `briefs/<task>.md` / `plans/<task>.md` references above stay relative — the
   coordinator's cwd is the main repo root.

   **2a. Plan it yourself, here, before launching.** Invoke the bundled `wiki-plan`
   skill for this task and write the result to `plans/<task>.md`. Planning runs in
   THIS coordinator session on purpose: a worker can be pinned to a cheaper tier
   (`DEV_LOOP_WORKER_MODEL`), and a plan is where an unmade decision becomes the
   implementer's guess — so the plan must come from the strongest model in the run,
   not from whatever tier is executing. Every design decision must be made and
   grounded in a `wiki/` page (record the decision->page map); leave nothing "as
   appropriate". The worker then ADOPTS this plan (session-prompt §1 / O1) instead
   of authoring one, and still signals `plan_ready` — so the phase sequence, the
   `plan_ready` watch, and the ready-set scheduler are all unchanged.

   Because planning happens here, **the planning model is whatever model this
   coordinator session is running**. There is no separate setting to turn: to plan
   on a stronger tier than you implement on, start the coordinator on that tier
   (`claude --model <planning model>`) and leave `DEV_LOOP_WORKER_MODEL` pointed at
   the cheaper implementer tier.

   A worker that reports the plan is contradictory or under-decided is telling you
   the planning pass was wrong: fix `plans/<task>.md` here and re-send §1. Do not
   let the worker re-plan — that silently moves planning back onto the worker tier,
   which is the thing this step exists to prevent. Then
   `LO_STATUS_DIR=<abs status dir> LO_TASK_ID=<task> scripts/launch-session.sh
   lo-<n> <worktree> bypassPermissions "<plan prompt>"`
   (plan prompt = templates/session-prompt.md §1 — the tmux set — with the
   subagent + tmux worker protocol blocks). With BOTH vars set, a successful
   launch (the confirmed-submission path AND the session-reuse path) pre-seeds
   `<LO_STATUS_DIR>/<LO_TASK_ID>.json` phase=pending with the resolved session
   name via the sibling status-update.sh, so dead/stalled-worker detection covers
   the pre-plan_ready window; a seeding failure warns on stderr only and never
   changes the exit code; either var unset = the previous behavior exactly.
   Exit **0** = launched *and* the prompt confirmed
   submitted; **4** = the REPL never became ready (relaunch); **5** = the prompt was
   sent but submission could NOT be confirmed — the session is alive and may be
   holding an unsubmitted prompt, so read it with `scripts/send-prompt.sh state
   lo-<n>` and re-send, never launch a second session on top of it.
3. `scripts/watch-status.sh <status-dir> plan_ready <N>` in the background; when it
   exits, collect `plans/<task>.md`. *(Orca substrate: `scripts/orca-wait.sh
   <timeout-ms> <this Wave's task ids>` per O4 instead — same exit-code contract,
   event-driven.)*
   *(Plans proceed autonomously per the user's choice — no per-plan gate.)*
   `watch-status.sh` only answers "does the session still exist"; a worker can hold a
   live session and produce nothing for hours. So on a long wait also run
   `scripts/tmux-worker-stalled.sh lo-<n>` (**0** progressing / **1** stalled /
   **2** cannot tell — treat unknown as *not* stalled; silence threshold
   `LO_STALL_SEC`, default 600s), the tmux mirror of O5. Read the pane before acting
   on a stall: "wedged on a prompt" and "finished but never reported" look identical
   from outside and need opposite responses.

**Watch exit playbooks (tmux).** Mechanical responses for the non-terminal watch
exits — handle, then relaunch watch with the same target:
- **6 — question pending** (prints `[watch] question pending — <task>: <question>`;
  recurs while `questions/<task>.json` exists, like exit 5; exit 5 wins when both
  are pending): read the record (`{ts, taskId, question, options, worktree}`),
  answer with `scripts/send-prompt.sh send lo-<n> "<answer>"`, delete the record
  file. If the task's status was recorded `phase=failed` when it asked the
  question, reset it to the phase you actually observe (read the worker pane
  first) BEFORE relaunching watch — the reset IS a normal status write, not a
  new phase word: `STATUS_DIR=<dir> STATUS_SESSION=<lo-n-runid> sh
  scripts/status-update.sh <task> <observed-phase> note="reset after exit-6
  answer"` — otherwise `watch-status.sh` counts the stale `failed` phase and
  aborts with exit 3 again on the very next poll. Then relaunch watch.
- **7 — stalled live worker** (prints `[watch] worker stalled — <task>:<session>`;
  the weakest signal — failed(3) and all-reached(0) win over it; driven by
  `tmux-worker-stalled.sh`, silence threshold `LO_STALL_SEC` default 600s; a
  missing script or tmux disables the check): read the pane FIRST
  (`tmux capture-pane -t "=<session>:" -p | tail`) and classify before acting —
  interactive chooser → answer with `scripts/send-prompt.sh keys <session>
  <key>...` (allowlist exactly `Up Down Left Right Enter Escape Tab Space 0-9 y n`;
  ALL keys validated before ANY is sent; **0** sent / **2** invalid session or
  key, nothing sent / **3** gone / **6** send failed on a live session);
  usage-limit stop ("You've hit your session limit · resets HH:MM") → wait for
  the reset time, then re-send a resume prompt that orders a state re-check
  (git status / tests) before continuing; finished-but-silent (forgot
  status-update) → send a prompt to emit the missing signal; auth/trust screen →
  keys per the screen. Then relaunch watch.
- **2 — timeout** (prints `[watch] TIMEOUT (<budget>s, source=<source>)`): a
  checkpoint, not a verdict — re-check each session with
  `scripts/tmux-worker-stalled.sh lo-<n>` and `scripts/send-prompt.sh state
  lo-<n>`, read panes, then relaunch watch with the same target.

## Phase 4 — Implement + review (max 3 rework)
Deliver §2 (implement) to each session with `scripts/send-prompt.sh send lo-<n>
"<prompt>"` — **0** delivered, **4** queued behind a busy turn, **7** unconfirmed,
**3** the session is gone, **2** the session name or prompt was rejected. Branch on
the exit code; stdout is exactly one token and stderr is advisory context that must
never be parsed. On **4**, `scripts/send-prompt.sh wait lo-<n> [timeout]` blocks
until the worker picks it up (**0** picked-up, **5** deadline expired). Then
`watch-status ... impl_done <N>`. *(Orca
substrate: `task-create` the implement Task, then `scripts/orca-worker-start.sh
--task <impl_task> --terminal <handle>` to reuse that task's existing session, and
wait with `scripts/orca-wait.sh`. Rework rounds are further Tasks on the same
`--terminal`.)*

Before the four-lens pass, run the floor: `scripts/test-floor.sh <wt>
'<integ>...HEAD'`. **Exit 3** — skip the four-lens pass and the auditor
entirely; the itemized stderr reasons (`no-tests` / `case-count:<file>:<n>` /
`no-assertion:<file>:<case>`) become the findings of `reviews/<task>-rN.md` —
this consumes a rework round exactly like any other finding (run the rework
sequence below). **Exit 0 or 2** — continue to the four-lens pass unchanged,
and when the auditor is invoked, pass `floor=pass` or `floor=unknown`
alongside it.

Run the fixed four-lens pass on each worktree diff (`git -C <wt> diff
<integ>...HEAD`) — write the result to `reviews/<task>-rN.md` from
`templates/review-report.md`:

1. **Plan conformance** — diff vs. the plan's decision→page map and the
   brief's `<scope_boundaries>` / `<out_of_scope>`; a decision silently made
   differently at implement time is a defect even when the code works.
2. **Wiki re-route from the diff** — run AGENTS.md routing protocol step 7 on
   the diff itself; report any page reached that the plan never named.
3. **Execution-environment reality** — any new flag/subcommand/API/dependency:
   confirm it exists in the version present where the code actually runs
   (`wiki/platforms/toolchains/flag-availability-at-the-execution-site.md`).
4. **Multi-object write ordering** — 2+ files/objects/rows written without a
   transaction; any ordering a concurrent reader could observe mid-flight
   (`wiki/backend/common/storage/multi-object-write-ordering.md`). You are the
   only reviewer who sees every worktree at once, so cross-task ordering
   hazards are your job alone.

Alongside the pass, if a session's tests look weak, **cross-call
`test-quality-auditor` yourself** (self-call + orchestrator cross-call).
On shortfall, decide rework: `STATUS_DIR=.orchestration/status
scripts/status-update.sh <task> rework` atomically increments `.attempt`;
read the NEW value N from `status/<task>.json`, write `reviews/<task>-rN.md`
(N is that counter value, so the filename and the counter can never
disagree), inject §3 (rework), repeat. The rework budget is
**`ready-set.sh`'s job**, not tracked here: `LO_MAX_REWORK` (default 3) fails
a non-terminal task for scheduling once its `.attempt` reaches it, and with
nothing else in flight that surfaces as **exit 3 DEADLOCK** naming the
exhausted task — Phase 3 step 1 already routes that to a human decision.
When a task is approved, merge it into the integration
branch first (Phase 3 step 5's merge-on-approval rule) before you
return to step 1 of the dispatch loop — whatever dependency it released shows up in the next
`ready-set.sh` round already merged, and the freed slot is refilled immediately.
When `ready-set.sh` returns **5**, go to Phase 5.

**Insight emission.** After a rework round's fix is confirmed by re-review,
emit one ★ Insight candidate per finding that was fixed and confirmed —
**only** for findings that sat in `## Findings` (they carried a failure
scenario: a real defect). `## Non-blocking` items never emit — they lack a
failure scenario, so they are style/preference, not the near-miss lesson this
rule captures. Both conditions must hold: the finding was a `## Findings`
item AND the following re-review round confirmed the fix — a finding that is
caught but not yet fixed is not a near-miss lesson yet. Use the frozen block
format from `hooks/insight-instruction.sh` verbatim (`trigger`/`directive`
required, `why`/`evidence` expected); the 0–3-per-session cap still applies,
so if a round confirms more fixes than the remaining budget, prioritize the
highest-signal finding. Map the fields like this:

```
★ Insight ─────────────────────────────────────
trigger: <diff signal in lens vocabulary — e.g. "new CLI flag, no version check">
directive: <reviewer's action on that signal — e.g. "confirm the flag exists in the deployed toolchain version">
why: <why the miss happened — e.g. "lens 3 exists for exactly this, the first pass skipped it">
evidence: reviews/<task>-rN.md + the fixing commit
─────────────────────────────────────────────
```

## Splitting a task mid-run

A worker may report that its task is much larger than the brief assumed. It
proposes; **you decide**, and you reply either way — a rejection that is never
sent is indistinguishable from silence, and a worker that hears nothing decides
for itself.

The proposal must carry, per piece, the `files` it would touch and the `outputs`
it would newly produce. Without them there is nothing to judge; ask for them
rather than guessing, and say the worker should hold.

**The decision is one overlap test.** Compare the proposed pieces' `files`
against every task that is currently dispatched and every task still pending in
`graph.json`:

- **No overlap** — add it as an independent node. `scripts/graph-add.sh
  .orchestration/graph.json '<node-json>'` with `split_of` naming the parent and
  `deps` carrying whatever the piece genuinely consumes. It enters the ready set
  and the next free slot picks it up, so the split buys real parallelism.
- **Overlap** — add it with `deps: ["<parent>"]` and give it to the **same worker**
  in the **same worktree** when the parent settles (Orca:
  `worker-start --task <new> --terminal <handle>`; tmux: `send-prompt.sh send
  lo-<n>`). Do **not** create a second worktree: the parent's code is not on the
  integration branch until Phase 6, so a second checkout would be editing files
  it cannot see. This split buys a smaller review and rework unit, not
  parallelism — say so when you report it.

`graph-add.sh` returns **0** added, **3** REJECTED with the reason and the file
untouched, **4** the graph or the node could not be read. On **3**, reply to the
worker with the reason; do not retry the same node. A rejection for `depth 1`
means the proposal came from a piece that was itself a split — that is a signal
Phase 2's decomposition was wrong, so bring it to the user rather than working
around it.

On **4**, the graph file is unreadable (I/O error or corruption) — a failure
class different from validation. This blocks all dispatch. Reply to the worker:
"Split on hold — orchestrator cannot read its graph state. Escalating to user
immediately." Do not add the node. Report immediately to the user: "Graph I/O
error at `.orchestration/graph.json` — resolve and resubmit the proposal. Run is
blocked until `.orchestration/graph.json` is accessible."

You decide this without a user gate, but **report it immediately** — the task
list the user approved at Gate 1 just grew, and they need the overlap verdict
and the schedule change to intervene if they disagree.

## Phase 5 — Integration test loop (max 3)
Merge-preview onto the integration branch and run the integration tests (use the
`verify` role's command if configured). On failure, route back to the responsible
session as rework. Repeat until green.

## 🚦 Gate 2 — pre-merge review (REQUIRED)
Show the full integration diff (`git diff`). **Wait for the user's confirmation.**

## Phase 6 — Cleanup + merge (only after Gate 2)
1. `scripts/safe-cleanup.sh merge <root> <integ> <branch>...` — refuses dirty
   worktrees, merges sequentially, stops + reports on conflict (no --force). A
   branch already merged on approval (Phase 3 step 5, issue #90) re-merges here
   as a no-op — git reports "Already up to date" — so this sweep stays correct
   whether or not every branch was merged early.
2. `scripts/safe-cleanup.sh remove-worktrees <root> <branch>...` (after merge
   verified; skips any dirty worktree).
3. `scripts/safe-cleanup.sh kill-sessions lo-<n>...` (exact names only), or — instead
   of remembering every name — `scripts/safe-cleanup.sh sweep <root>`, the teardown
   for ONE run: kill every tmux session named `lo-<n>-$LO_RUN_ID`, `git worktree
   prune`, then report (never delete) any `.worktrees/` directory git does not know.
   `sweep` REFUSES with exit 1, touching nothing, when `LO_RUN_ID` is unset or is not
   `[A-Za-z0-9_-]+` — with no scope it would match every concurrent run's sessions.
4. `scripts/safe-cleanup.sh list-orphans <root>` is read-only (kills, deletes and
   prunes nothing; needs no `LO_RUN_ID`) — the census across ALL run ids, and the way
   to read a dead run's id before sweeping it deliberately.
`--dry-run` may appear in any argument position on any destructive verb: it prints
exactly what the real run would touch and changes nothing, while refusals (dirty
worktree) still fire — a dry run never looks safer than the real one.
**Local merge into the feature branch only.** Remote push / PR is the user's job.

## Re-entry (resume)
On re-invocation with no context, measure real state first: `git worktree list`,
each `.orchestration/status/*.json` phase, and which `briefs/plans/reviews/`
artifacts exist. Resume from the earliest incomplete step (idempotently skip done
steps). There is no intermediate state such as a Wave index to restore. Reading
`.orchestration/graph.json` plus `status/*.json` and running `ready-set.sh` IS
the restored state — the same inputs always yield the same answer. The
rework round number is read from `status/<task>.json`'s `.attempt` field —
never reconstructed by globbing `reviews/<task>-r*.md`. Check `tmux ls`, and run `scripts/tmux-worker-stalled.sh <session>` on each
live one — a session that exists is not a worker that moves. Relaunch dead sessions and
re-deliver the right prompt with `scripts/send-prompt.sh send`. For leftovers of a
run that already died, `scripts/safe-cleanup.sh list-orphans <root>` enumerates them
read-only, including each session's run id.
On the Orca substrate, rebind the Run first (`orca orchestration run-use --id
<run_id> --json`), then measure with `orca orchestration task-list --json` +
`scripts/orca-worktree-alive.sh <wt>` **and** `scripts/orca-worker-stalled.sh <wt>`
— a Task reading `dispatched` proves only that it was handed out, never that the
worker is moving. Restart a proven-dead worker with a NEW Task (the old one is
spent, see O2) via `scripts/orca-worker-start.sh --task <new_task_id> --worktree
id:<...> --agent claude`; that call now probes first and rebinds to a live agent
terminal on that worktree instead of creating a second one, so re-running it is
safe (it exits 6 rather than guess when it cannot tell).
`setup-worktrees.sh` is idempotent (existing branches/worktrees are detected and
kept), so re-running it is safe. Note the difference from **partial resume** (Phase
0): that handles work done *outside* this orchestration — children with no
`.orchestration` record — whereas re-entry resumes this orchestration's own state.

## Guardrails
- You never implement — sessions do; you analyze, plan, review, manage.
- Gate 1 (task-split) and Gate 2 (pre-merge) are mandatory; everything else autonomous.
- No remote push, no PR, no force-push. Destructive cleanup only after Gate 2, via
  safe-cleanup (never --force).
- Sessions must not weaken tests (loop-implement guard); the auditor enforces it.
- Always verify real state after worktree/session ops (`git worktree list`, `tmux ls`,
  status files) — never trust echo logs (set -e is fail-open in eval subshells).
- Bundled agent only: `test-quality-auditor`. Don't depend on built-in agent names
  (general-purpose/Explore/Plan are version-dependent).
- A completed/excluded issue (partial resume) is injected as a **base output**, never
  silently dropped — otherwise its dependents lose their premise and re-create it.
