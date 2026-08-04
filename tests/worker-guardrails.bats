#!/usr/bin/env bats
# Tests for worker-guardrails.sh — the single source of the worker-scoped
# guardrails config. The tmux substrate reaches it via setup-worktrees.sh; the
# Orca substrate calls it directly on an orca-created worktree, so it must work
# standalone, be idempotent, and fail loudly on a path that does not exist
# (silently writing "nowhere" would leave the worker unsandboxed).

setup() {
  WG="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/worker-guardrails.sh"
  wt="${BATS_TEST_TMPDIR}/wt"; mkdir -p "$wt"
  git -C "$wt" init -q -b main
  git -C "$wt" config user.email t@t; git -C "$wt" config user.name t
}

@test "writes the worker-scoped guardrails config" {
  run sh "$WG" "$wt"
  [ "$status" -eq 0 ]
  cfg="$wt/.groundwork/guardrails.json"
  [ -f "$cfg" ]
  run jq -r '.rules.rm_rf.mode' "$cfg"
  [ "$output" = "off" ]
  run jq -r '.rules.curl_pipe_shell.mode' "$cfg"
  [ "$output" = "ask" ]
  run jq -r '.rules.worktree_escape.mode' "$cfg"
  [ "$output" = "ask" ]
}

@test "the config is git-excluded, so a worker cannot commit its sandbox" {
  sh "$WG" "$wt"
  run git -C "$wt" status --porcelain
  [ "$status" -eq 0 ]
  [[ "$output" != *".groundwork"* ]]
  # `status` staying quiet is only circumstantial — prove git itself considers
  # the path ignored, and that an explicit `add -A` still refuses to stage it.
  run git -C "$wt" check-ignore -q .groundwork/guardrails.json
  [ "$status" -eq 0 ]
  git -C "$wt" add -A
  run git -C "$wt" diff --cached --name-only
  [[ "$output" != *".groundwork"* ]]
}

@test "idempotent: a second run rewrites the config without duplicating the exclude" {
  sh "$WG" "$wt"
  run sh "$WG" "$wt"
  [ "$status" -eq 0 ]
  excl=$(git -C "$wt" rev-parse --git-path info/exclude)
  case "$excl" in /*) : ;; *) excl="$wt/$excl" ;; esac
  run grep -cxF '.groundwork/' "$excl"
  [ "$output" -eq 1 ]
}

@test "errors on a missing argument (usage)" {
  run sh "$WG"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "errors instead of silently writing when the worktree does not exist" {
  run sh "$WG" "${BATS_TEST_TMPDIR}/nope"
  [ "$status" -eq 2 ]
  [ ! -e "${BATS_TEST_TMPDIR}/nope" ]
}

@test "boundary: a non-git directory still gets the config (exclude simply skipped)" {
  plain="${BATS_TEST_TMPDIR}/plain"; mkdir -p "$plain"
  run sh "$WG" "$plain"
  [ "$status" -eq 0 ]
  [ -f "$plain/.groundwork/guardrails.json" ]
}

# The real orchestrator shape. Note (measured): for a LINKED worktree git resolves
# `--git-path info/exclude` to an ABSOLUTE path inside the MAIN repo, so the
# exclusion is shared across worktrees rather than per-worktree — which is why the
# absolute/relative normalization in the script must leave absolute paths alone.
@test "a linked worktree is excluded too (via the main repo's shared exclude)" {
  echo x > "$wt/f"; git -C "$wt" add f; git -C "$wt" commit -qm init
  linked="${BATS_TEST_TMPDIR}/linked"
  git -C "$wt" worktree add -q -b task "$linked"
  run sh "$WG" "$linked"
  [ "$status" -eq 0 ]
  [ -f "$linked/.groundwork/guardrails.json" ]
  run git -C "$linked" check-ignore -q .groundwork/guardrails.json
  [ "$status" -eq 0 ]
  run git -C "$linked" status --porcelain
  [[ "$output" != *".groundwork"* ]]
}
