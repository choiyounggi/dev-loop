#!/bin/sh
# orca-worker-start.sh — bind a supervised Orca Dispatch to a worker terminal.
#
# Two modes:
#
#   WORKER MODE (--worktree <existing selector> --agent claude)
#     `orchestration worker-start --agent` launches Orca's own configured agent
#     command, which cannot carry environment variables — so it CANNOT deliver
#     the guardrails escalation contract (GROUNDWORK_ESCALATION_DIR /
#     GROUNDWORK_TASK_ID) or `--permission-mode`. A dev-loop worker needs both,
#     so this mode creates the terminal itself with `terminal create --command`
#     (same command shape as orca-spawn.sh), waits for `tui-idle`, and only then
#     binds the Dispatch with `worker-start --terminal`.
#
#     On re-entry this mode is idempotent, automatically — no flag to pass.
#     Before creating anything it asks Orca whether this task's Dispatch already
#     names a terminal that is still live on the worktree (`orchestration
#     dispatch-show` joined against `terminal list --worktree`):
#       live      -> binds THAT terminal and creates nothing, saying so on
#                    stderr. --perm / --name are inert on this path: the agent
#                    is already running with the mode it was created with.
#       not live  -> unchanged: terminal create + tui-idle wait + bind.
#       no record -> unchanged (this is the task's first start).
#       can't tell-> exit 6, creates nothing, not retried automatically.
#     To force a fresh agent, stop the old one first (`orca orchestration
#     worker-stop`) and re-run. This is a check-then-create, so it protects a
#     sequential re-entry — not two coordinators racing on one worktree.
#
#   REUSE MODE (--terminal <handle>)
#     Bind this task's next phase (implement / rework) to the agent that already
#     holds the task's context. No new terminal, no env to re-inject.
#
# When GROUNDWORK_ESCALATION_DIR is NOT set, worker mode falls back to Orca's
# composed agent-first `worker-start --agent`, which also accepts new-child /
# new-top-level and adds no fallback shell.
#
# usage:
#   orca-worker-start.sh --task <task_id> --worktree <selector> --agent <agent>
#                        [--name <name>] [--perm <permission-mode>]
#   orca-worker-start.sh --task <task_id> --terminal <handle>
#
# env (also test hooks):
#   GROUNDWORK_ESCALATION_DIR  exported into the worker so a guardrails `ask`
#                              escalates instead of blocking (activates worker mode)
#   GROUNDWORK_TASK_ID         worker task label
#   LO_READY_TIMEOUT           seconds to wait for TUI readiness (default 60)
#   ORCA_BIN                   orca executable (default: orca)
#   ORCA_WORKER_START_DRYRUN   print the orca commands instead of running them
#   ORCA_WORKER_START_JSON     canned `worker-start --json` receipt (tests)
#   ORCA_WORKER_START_CREATE_JSON  canned `terminal create --json` receipt (tests)
#   ORCA_WORKER_START_DISPATCH_JSON  canned `orchestration dispatch-show --json` (tests)
#   ORCA_WORKER_START_TERMLIST_JSON  canned `terminal list --json` (tests)
#
# On success prints: dispatch=<id>, handle=<agent-terminal-handle>, state=, setup=
# Exit: 0 ok | 1 usage | 2 unsupported agent/placement for the escalation contract
#       | 3 receipt without a dispatch | 4 start failed (inspect stage/effects/
#       residualResources; do NOT auto-retry) | 5 could not create the terminal
#       | 6 could not determine whether a live agent terminal already exists —
#       refused to create a second one (verify, then re-run or use --terminal)
set -u

ORCA="${ORCA_BIN:-orca}"
JQ=$(command -v jq) || { echo "orca-worker-start: jq not found" >&2; exit 127; }

usage() {
  echo "usage: orca-worker-start.sh --task <task_id> (--worktree <selector> --agent <agent> [--name <name>] [--perm <mode>] | --terminal <handle>)" >&2
  exit 1
}

task=""; wt=""; agent=""; name=""; term=""; perm="bypassPermissions"
while [ $# -gt 0 ]; do
  case "$1" in
    --task)     task="${2:-}";  shift 2 || usage ;;
    --worktree) wt="${2:-}";    shift 2 || usage ;;
    --agent)    agent="${2:-}"; shift 2 || usage ;;
    --name)     name="${2:-}";  shift 2 || usage ;;
    --terminal) term="${2:-}";  shift 2 || usage ;;
    --perm)     perm="${2:-}";  shift 2 || usage ;;
    *) echo "orca-worker-start: unknown argument '$1'" >&2; usage ;;
  esac
done

[ -n "$task" ] || usage

# Placement is exactly one of: launch an agent, or bind a live terminal. Both at
# once is ambiguous — Orca would pick one silently. `--worktree` is allowed with
# either: worker-start resolves a bare `--terminal` against the CALLER's current
# worktree and rejects the pair with `terminal_worktree_mismatch` (verified live),
# so a terminal outside the coordinator's checkout must name its worktree.
{ [ -n "$term" ] && [ -n "$agent" ]; } && usage
{ [ -z "$term" ] && [ -z "$agent" ]; } && usage
if [ -z "$term" ]; then [ -n "$wt" ] || usage; fi

# Both values are interpolated into a command line; whitelist them.
if [ -n "$agent" ]; then
  case "$agent" in
    claude|codex|opencode|gemini|droid|grok|cursor|omp|pi) : ;;
    *) echo "orca-worker-start: unsupported agent '$agent'" >&2; exit 2 ;;
  esac
fi
case "$perm" in
  bypassPermissions|acceptEdits|plan|default) : ;;
  *) echo "orca-worker-start: invalid permission mode '$perm'" >&2; exit 2 ;;
esac

esc_dir="${GROUNDWORK_ESCALATION_DIR:-}"
worker_mode=0
if [ -z "$term" ] && [ -n "$esc_dir" ]; then worker_mode=1; fi

if [ "$worker_mode" = 1 ]; then
  # The escalation contract is only expressible through a custom terminal
  # command, which needs a worktree that already exists and a CLI whose
  # permission flag we know. Refuse rather than silently dropping the contract.
  case "$wt" in
    new-child|new-top-level)
      echo "orca-worker-start: '$wt' cannot carry GROUNDWORK_ESCALATION_DIR — create the worktree first, then pass its exact selector" >&2
      exit 2 ;;
  esac
  [ "$agent" = "claude" ] || {
    echo "orca-worker-start: the guardrails escalation contract is only wired for --agent claude (got '$agent')" >&2
    exit 2; }
else
  case "$wt" in
    new-child|new-top-level)
      [ -n "$name" ] || { echo "orca-worker-start: --name is required for '$wt'" >&2; exit 1; } ;;
  esac
  # Fail closed instead of degrading silently: a worktree that already carries a
  # worker-scoped guardrails config (written by setup-worktrees.sh) is a
  # dev-loop worker checkout, and launching an agent into it WITHOUT the
  # escalation env would leave every `ask` unroutable. Losing the variable
  # between coordinator invocations must be an error, not a quiet downgrade.
  if [ -z "$term" ]; then
    wt_path=""
    case "$wt" in
      path:*) wt_path="${wt#path:}" ;;
      *::*)   wt_path="${wt##*::}" ;;
    esac
    if [ -n "$wt_path" ] && [ -f "$wt_path/.groundwork/guardrails.json" ]; then
      echo "orca-worker-start: '$wt_path' is a guardrails worker worktree but GROUNDWORK_ESCALATION_DIR is unset — export it (and GROUNDWORK_TASK_ID) so an \`ask\` escalates instead of blocking" >&2
      exit 2
    fi
  fi
fi

print_cmd() { printf 'orca'; for a in "$@"; do printf ' [%s]' "$a"; done; printf '\n'; }
dry="${ORCA_WORKER_START_DRYRUN:-}"

rt="${LO_READY_TIMEOUT:-60}"; [ "$rt" -ge 1 ] 2>/dev/null || rt=60

reused=""

# --- re-entry idempotency: never put a SECOND agent on one checkout -----------
# SKILL.md's re-entry path restarts a worker the coordinator believes is dead by
# calling this script again with --worktree/--agent. If that liveness read was
# wrong, an unconditional `terminal create` lands a second agent on the same
# working tree, with the Dispatch bound to only one of them. So ask Orca first:
# does this task's Dispatch already name a terminal that is still live on this
# worktree? A probe that cannot answer is UNKNOWN, never "no agent" — creating
# the second agent is the damaging direction, so we refuse (exit 6).
# Both calls take `</dev/null`: orca can prompt, and a headless coordinator must
# not be able to block on a read.
if [ "$worker_mode" = 1 ]; then
  probe=1
  # A dry run makes no orca calls, so there is nothing to probe unless a test
  # supplies a canned payload.
  if [ -n "$dry" ] && [ -z "${ORCA_WORKER_START_DISPATCH_JSON:-}" ]; then probe=0; fi

  if [ "$probe" = 1 ]; then
    if [ -n "${ORCA_WORKER_START_DISPATCH_JSON:-}" ]; then
      dsp="$ORCA_WORKER_START_DISPATCH_JSON"
    else
      dsp=$("$ORCA" orchestration dispatch-show --task "$task" --json </dev/null 2>/dev/null) || dsp=""
    fi
    # ok:true with dispatch:null is a definite "no worker yet" (verified live);
    # anything else means we could not read it — that is unknown, not none.
    dsp_ok=$(printf '%s' "$dsp" | "$JQ" -r '.ok // false' 2>/dev/null || echo false)
    if [ "$dsp_ok" != "true" ]; then
      echo "orca-worker-start: cannot read the dispatch for '$task' — refusing to create a second agent on '$wt'; verify with \`orca orchestration dispatch-show --task $task\`, then re-run or bind the live terminal with --terminal" >&2
      exit 6
    fi
    prev=$(printf '%s' "$dsp" | "$JQ" -r '.result.dispatch.assignee_handle // empty' 2>/dev/null)

    if [ -n "$prev" ]; then
      # A recorded assignee is only a reuse target while it is STILL LIVE on the
      # worktree we were asked to start on.
      if [ -n "${ORCA_WORKER_START_TERMLIST_JSON:-}" ]; then
        tl="$ORCA_WORKER_START_TERMLIST_JSON"
      else
        tl=$("$ORCA" terminal list --worktree "$wt" --json </dev/null 2>/dev/null) || tl=""
      fi
      tl_ok=$(printf '%s' "$tl" | "$JQ" -r '.ok // false' 2>/dev/null || echo false)
      if [ "$tl_ok" != "true" ]; then
        echo "orca-worker-start: cannot list terminals for '$wt' — refusing to create a second agent while '$prev' may still be live; verify with \`orca terminal list --worktree $wt\`" >&2
        exit 6
      fi
      live=$(printf '%s' "$tl" | "$JQ" -r --arg h "$prev" \
        '[.result.terminals[]? | select(.handle==$h and .orphaned!=true and .connected==true)] | length' 2>/dev/null)
      case "$live" in ''|*[!0-9]*) live=0 ;; esac
      if [ "$live" -ge 1 ]; then
        echo "orca-worker-start: worktree '$wt' already has a live agent terminal $prev — reusing it instead of creating a second agent (stop it first with \`orca orchestration worker-stop\` if you want a fresh one)" >&2
        term="$prev"
        reused=1
      fi
    fi
  fi
fi

# --- worker mode: create the env-carrying agent terminal ourselves ------------
# (skipped when the probe above rebound us to the agent that is already there —
# the tui-idle wait below exists to pass a NEW CLI's trust screen, and a mid-task
# agent may never report idle)
if [ "$worker_mode" = 1 ] && [ -z "$reused" ]; then
  # Single-quote the values with embedded quotes escaped (`'\''`) so a path with
  # any metacharacter — including a quote — cannot break out of the command.
  esc_sq() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }
  worker_cmd="export GROUNDWORK_ESCALATION_DIR='$(esc_sq "$esc_dir")' && export GROUNDWORK_TASK_ID='$(esc_sq "${GROUNDWORK_TASK_ID:-}")' && claude --permission-mode ${perm}"

  set -- terminal create --worktree "$wt" --command "$worker_cmd" --json
  [ -n "$name" ] && set -- "$@" --title "$name"
  [ -n "$dry" ] && print_cmd "$@"
  if [ -n "${ORCA_WORKER_START_CREATE_JSON:-}" ]; then
    create_out="$ORCA_WORKER_START_CREATE_JSON"
  elif [ -n "$dry" ]; then
    create_out=""
  else
    create_out=$("$ORCA" "$@" 2>/dev/null)
  fi

  if [ -n "$create_out" ]; then
    term=$(printf '%s' "$create_out" | "$JQ" -r \
      '.result.terminal.handle // .result.startupTerminal.handle // .result.handle // empty' 2>/dev/null)
    [ -n "$term" ] || { echo "orca-worker-start: terminal create returned no handle" >&2; exit 5; }
  else
    [ -n "$dry" ] || { echo "orca-worker-start: terminal create failed" >&2; exit 5; }
    term="term_DRYRUN"
  fi

  # Readiness replaces the tmux trust-screen pattern match. A timeout here is a
  # warning, not fatal — the terminal exists and the dispatch still delivers.
  set -- terminal wait --terminal "$term" --for tui-idle --timeout-ms "$(( rt * 1000 ))" --json
  if [ -n "$dry" ]; then print_cmd "$@"; else
    "$ORCA" "$@" >/dev/null 2>&1 || echo "orca-worker-start: warning: tui-idle wait failed (continuing)" >&2
  fi
fi

# --- bind the Dispatch --------------------------------------------------------
# `--setup run` is added ONLY for a new worktree: Orca must not rerun a repo
# setup hook for current/existing worktrees (it rejects the flag there).
set -- orchestration worker-start --task "$task"
if [ -n "$term" ]; then
  # name the worktree whenever we know it, or Orca resolves the handle against
  # the coordinator's own checkout and fails with terminal_worktree_mismatch
  [ -n "$wt" ] && set -- "$@" --worktree "$wt"
  set -- "$@" --terminal "$term"
else
  set -- "$@" --worktree "$wt" --agent "$agent"
  [ -n "$name" ] && set -- "$@" --name "$name"
  case "$wt" in new-child|new-top-level) set -- "$@" --setup run ;; esac
fi
set -- "$@" --json

if [ -n "$dry" ]; then
  print_cmd "$@"
  out="${ORCA_WORKER_START_JSON:-}"
  [ -n "$out" ] || exit 0          # argv-only dry run: nothing to parse
else
  out="${ORCA_WORKER_START_JSON:-$("$ORCA" "$@" 2>/dev/null)}"
fi

# A failed or unknown start must not be retried automatically — surface the
# stage and any residual resources so the coordinator decides (Orca guide).
ok=$(printf '%s' "$out" | "$JQ" -r '.ok // false' 2>/dev/null || echo false)
if [ "$ok" != "true" ]; then
  stage=$(printf '%s' "$out" | "$JQ" -r '.result.stage // .error.code // "unknown"' 2>/dev/null || echo unknown)
  state=$(printf '%s' "$out" | "$JQ" -r '.result.state // "unknown"' 2>/dev/null || echo unknown)
  residual=$(printf '%s' "$out" | "$JQ" -c '.result.residualResources // []' 2>/dev/null || echo '[]')
  echo "orca-worker-start: start failed — state=$state stage=$stage residual=$residual" >&2
  exit 4
fi

dispatch=$(printf '%s' "$out" | "$JQ" -r '.result.dispatchId // empty' 2>/dev/null)
[ -n "$dispatch" ] || { echo "orca-worker-start: receipt carries no dispatchId" >&2; exit 3; }

# The agent handle is the terminal effect with role=agent (created or reused);
# fall back to the receipt's terminal object, then to the handle we bound.
handle=$(printf '%s' "$out" | "$JQ" -r \
  '([.result.effects[]? | select(.kind=="terminal" and .role=="agent") | .id][0])
   // .result.terminal.handle // empty' 2>/dev/null)
[ -n "$handle" ] && [ "$handle" != "null" ] || handle="$term"

state=$(printf '%s' "$out" | "$JQ" -r '.result.state // "-"' 2>/dev/null || echo -)
setup=$(printf '%s' "$out" | "$JQ" -r '.result.setup.state // "-"' 2>/dev/null || echo -)

echo "dispatch=$dispatch"
echo "handle=$handle"
echo "state=$state stage=$(printf '%s' "$out" | "$JQ" -r '.result.stage // "-"' 2>/dev/null) setup=$setup"
