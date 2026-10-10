#!/bin/sh
# worker-guardrails.sh <worktree-path> — scope guardrails inside ONE worker
# worktree and keep the config out of commits.
# worker-guardrails.sh --path <worktree-path> — print the EXTERNAL config path
# (see below) for a worktree without writing anything.
#
# An isolated sandbox loosens harmless rules (rm_rf, git_discard, tmp writes) and
# keeps genuinely dangerous ones as `ask` — which the escalation env
# (GROUNDWORK_ESCALATION_DIR, exported by launch-session.sh / orca-worker-start.sh /
# orca-spawn.sh) turns into a coordinator escalation rather than a hard block.
# Unknown rule ids are ignored by older guardrails, so worktree_escape is
# forward-compatible.
#
# Two copies of this same config are written:
#   1. `<worktree>/.groundwork/guardrails.json` — the REPO config, read by an
#      OLDER guardrails. A newer guardrails now only lets a repo config
#      TIGHTEN rules, so this copy alone no longer loosens anything there.
#   2. `$HOME/.claude/groundwork/overrides/dev-loop-<id>.json` — the EXTERNAL,
#      trusted copy a newer guardrails actually loosens from, named by env
#      `GROUNDWORK_GUARDRAILS_CONFIG` (set by the launching process: every
#      worker launch path — launch-session.sh, orca-worker-start.sh,
#      orca-spawn.sh — exports it next to GROUNDWORK_ESCALATION_DIR /
#      GROUNDWORK_TASK_ID above). Guardrails deliberately REFUSES to trust a
#      GROUNDWORK_GUARDRAILS_CONFIG path that resolves inside any project tree
#      (the current worktree, its main worktree, or $PWD) — any command
#      running in that worktree could rewrite such a file and loosen its own
#      sandbox, so the trusted copy must live outside every repo, specifically
#      under guardrails' own allowlisted override directory
#      (`$HOME/.claude/groundwork/overrides/`) — the only location guardrails
#      trusts an override from. `<id>` is the first 16 hex chars of the
#      sha256 of the worktree's own absolute, symlink-resolved path — stable
#      across repeated calls on the same worktree (idempotent), distinct per
#      worktree. A caller that needs this path (the launch scripts) gets it
#      from `--path` instead of re-deriving the hash in three places.
#
# worktree_escape stays `ask` — `allowPaths` declares the ONE sanctioned path
# (`.orchestration`, the coordination dir a worker writes its status and plan into)
# rather than disabling the rule. Without it every such write reads as a write into
# the main worktree: measured 2026-08-05, three escalations in one run, each
# aborting the watch (exit 5) for legitimate coordination writes. Older guardrails
# read only `.rules[<id>].mode` (guardrails 1.0.0 hooks/bash-guard.sh, inspected
# 2026-08-05), so they ignore the extra key — safe to ship before the release that
# implements it. Paths are relative to the MAIN worktree root.
#
# This is the SINGLE source of the worker config. `setup-worktrees.sh` calls it
# for the tmux substrate; on the Orca substrate the worktree is created by
# `orca worktree create`, so the orchestrator calls this script directly with the
# path Orca reports — same contract, no prose to re-implement.
#
# usage: worker-guardrails.sh <worktree-path>
#        worker-guardrails.sh --path <worktree-path>
# exit: 0 written / path printed (idempotent) | 1 usage | 2 path is not a
#       directory, or the external path could not be derived (no sha256 tool)
set -eu

# --- shared: hash a worktree's absolute, symlink-resolved path to the id
#     that names its external config file. ---------------------------------
wg_hash16() { # stdin: bytes to hash -> stdout: first 16 hex chars
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -c1-16
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -c1-16
  else
    echo "worker-guardrails: neither shasum nor sha256sum found on PATH" >&2
    return 1
  fi
}

wg_external_path() { # <worktree-path> -> stdout: $HOME/.claude/groundwork/overrides/dev-loop-<id>.json
  wg_abs=$(cd "$1" 2>/dev/null && pwd -P) || return 2
  wg_id=$(printf '%s' "$wg_abs" | wg_hash16) || return 1
  printf '%s/.claude/groundwork/overrides/dev-loop-%s.json\n' "$HOME" "$wg_id"
}

if [ "${1:-}" = "--path" ]; then
  wt="${2:-}"
  [ -n "$wt" ] || { echo "usage: worker-guardrails.sh --path <worktree-path>" >&2; exit 1; }
  [ -d "$wt" ] || { echo "worker-guardrails: '$wt' is not a directory" >&2; exit 2; }
  wg_external_path "$wt"
  exit 0
fi

wt="${1:-}"
[ -n "$wt" ] || { echo "usage: worker-guardrails.sh <worktree-path>" >&2; exit 1; }
[ -d "$wt" ] || { echo "worker-guardrails: '$wt' is not a directory — create the worktree first" >&2; exit 2; }

GRJSON_BODY='{"rules":{"rm_rf":{"mode":"off"},"git_discard":{"mode":"off"},"system_tmp_write":{"mode":"off"},"cloud_delete":{"mode":"ask"},"sql_drop":{"mode":"ask"},"git_force_push":{"mode":"ask"},"secret_export":{"mode":"ask"},"curl_pipe_shell":{"mode":"ask"},"worktree_escape":{"mode":"ask","allowPaths":[".orchestration"]}}}'

mkdir -p "$wt/.groundwork"
printf '%s\n' "$GRJSON_BODY" > "$wt/.groundwork/guardrails.json"

# Mirror the same config to the EXTERNAL, outside-every-repo path a newer
# guardrails actually trusts as a loosening source (see header). Best-effort:
# a failure here must not abort the caller (set -e is in effect) — the
# in-worktree file above still sandboxes the worker under an OLDER
# guardrails; warn rather than silently leaving a newer one unloosened.
if ext_path=$(wg_external_path "$wt" 2>/dev/null); then
  ext_dir=$(dirname "$ext_path")
  if mkdir -p "$ext_dir" 2>/dev/null && chmod 700 "$ext_dir" 2>/dev/null; then
    if printf '%s\n' "$GRJSON_BODY" > "$ext_path" 2>/dev/null; then
      chmod 600 "$ext_path" 2>/dev/null \
        || echo "worker-guardrails: warn — could not chmod 600 $ext_path" >&2
    else
      echo "worker-guardrails: warn — could not write external guardrails config at $ext_path" >&2
    fi
  else
    echo "worker-guardrails: warn — could not create $ext_dir (mode 700)" >&2
  fi
else
  echo "worker-guardrails: warn — could not derive the external guardrails config path for '$wt' (no shasum/sha256sum on PATH?) — GROUNDWORK_GUARDRAILS_CONFIG will point nowhere" >&2
fi

# Deny `git stash` (any subcommand) in the worker's own Claude settings —
# refs/stash is repository-global, so a stash by one worktree worker can
# silently swap another worker's uncommitted work (issue #166). Deny rules
# block in EVERY permission mode, including bypassPermissions, and `:*`
# covers the bare command plus every subcommand (code.claude.com/docs/en/
# permissions.md, /permission-modes.md, verified 2026-09-02). Create the file
# if absent; merge (dedup) into an existing valid one; never touch a
# malformed one — warn instead of destroying a user file.
settings="$wt/.claude/settings.local.json"
mkdir -p "$wt/.claude"
if [ ! -f "$settings" ]; then
  printf '%s\n' '{"permissions":{"deny":["Bash(git stash:*)"]}}' > "$settings"
elif jq empty "$settings" >/dev/null 2>&1; then
  stmp="$settings.tmp.$$"
  if jq '.permissions.deny = ((.permissions.deny // []) + ["Bash(git stash:*)"] | unique)' "$settings" > "$stmp"; then
    mv "$stmp" "$settings"
  else
    rm -f "$stmp"
    echo "worker-guardrails: warn — failed to merge git-stash deny rule into $settings" >&2
  fi
else
  echo "worker-guardrails: warn — $settings is malformed JSON; left untouched, git-stash deny rule NOT added" >&2
fi

# Keep the sandbox config out of commits (worktree-local git exclude). Create the
# exclude file if it does not exist, and never let an append failure abort the
# caller (set -e) — warn instead. A non-git path is fine: the config still applies.
GIT=$(command -v git 2>/dev/null || true)
[ -n "$GIT" ] || { echo "worker-guardrails: warn — git not found, .groundwork/ not excluded in $wt" >&2; exit 0; }

excl=$("$GIT" -C "$wt" rev-parse --git-path info/exclude 2>/dev/null || echo "")
[ -n "$excl" ] || exit 0
case "$excl" in /*) : ;; *) excl="$wt/$excl" ;; esac   # rev-parse may return a relative path
mkdir -p "$(dirname "$excl")" 2>/dev/null || true
if ! grep -qxF '.groundwork/' "$excl" 2>/dev/null; then
  printf '.groundwork/\n' >> "$excl" 2>/dev/null \
    || echo "worker-guardrails: warn — could not exclude .groundwork/ in $wt" >&2
fi

# Claude worker sessions predictably create untracked .claude/ scratch in
# their cwd; exclude it the same way as .groundwork/ above so it never
# dirties the worker worktree's status (issue #129 proposal 1).
if ! grep -qxF '.claude/' "$excl" 2>/dev/null; then
  printf '.claude/\n' >> "$excl" 2>/dev/null \
    || echo "worker-guardrails: warn — could not exclude .claude/ in $wt" >&2
fi
exit 0
