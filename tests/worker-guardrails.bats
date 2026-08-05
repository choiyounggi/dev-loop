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

# The three tests below split the config into two named properties, because one
# combined assertion cannot say which one broke: COVERAGE (every rule id is still
# there) and VALIDITY (each rule's mode is still the one it shipped with), plus the
# new allowPaths declaration. Coverage asserts the rule COUNT before comparing the
# id set — a config that parsed to zero rules would otherwise satisfy any set
# comparison and pass vacuously.
@test "worktree_escape declares .orchestration as an allowed path" {
  sh "$WG" "$wt"
  cfg="$wt/.groundwork/guardrails.json"
  run jq -r '.rules.worktree_escape.allowPaths[0] // "MISSING"' "$cfg"
  [ "$output" = ".orchestration" ]
  # boundary: exactly one sanctioned path — this declares a path, it does not
  # widen the rule into an allow-everything list.
  run jq -r '.rules.worktree_escape.allowPaths | length' "$cfg"
  [ "$output" -eq 1 ]
  # the rule itself must stay `ask`: protection is declared-around, not disabled.
  run jq -r '.rules.worktree_escape.mode' "$cfg"
  [ "$output" = "ask" ]
}

@test "coverage: the emitted config still holds exactly the nine known rule ids" {
  sh "$WG" "$wt"
  cfg="$wt/.groundwork/guardrails.json"
  run jq -r '.rules | length' "$cfg"
  [ "$status" -eq 0 ]
  [ "$output" -eq 9 ]
  run jq -r '.rules | keys_unsorted | join(",")' "$cfg"
  [ "$output" = "rm_rf,git_discard,system_tmp_write,cloud_delete,sql_drop,git_force_push,secret_export,curl_pipe_shell,worktree_escape" ]
}

@test "validity: every pre-existing rule keeps its mode, and only worktree_escape gains a key" {
  sh "$WG" "$wt"
  cfg="$wt/.groundwork/guardrails.json"
  for pair in rm_rf:off git_discard:off system_tmp_write:off cloud_delete:ask \
              sql_drop:ask git_force_push:ask secret_export:ask \
              curl_pipe_shell:ask worktree_escape:ask; do
    id="${pair%%:*}"; want="${pair##*:}"
    run jq -r --arg r "$id" '.rules[$r].mode // "MISSING"' "$cfg"
    [ "$output" = "$want" ]
  done
  # no other rule was handed an allowPaths while we were in there
  run jq -r '[.rules | to_entries[] | select(.value.allowPaths) | .key] | join(",")' "$cfg"
  [ "$output" = "worktree_escape" ]
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
