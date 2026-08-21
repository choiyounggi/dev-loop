#!/usr/bin/env bats
# Tests for safe-cleanup.sh guards

setup() {
  SC="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/safe-cleanup.sh"
  # Per-test scratch root for the injected tmux fake. Kept INSIDE the repo
  # (.claude/ is git-ignored) rather than under $BATS_TEST_TMPDIR, because the
  # fake needs an exec bit and host EDR flags chmod +x under /tmp,$TMPDIR.
  STUB_ROOT="${BATS_TEST_DIRNAME}/../.claude/tmp/sc-$$-${BATS_TEST_NUMBER:-0}"
}

teardown() {
  [ -n "${STUB_ROOT:-}" ] && rm -rf "$STUB_ROOT"
  return 0
}

# Assertion helpers. NOTE: a bare `[[ ... ]]` mid-test-body does NOT fail a bats
# test (bash exempts the [[ keyword from the ERR trap), so substring assertions
# written that way are decorative. These are plain function calls, whose failure
# DOES abort the test — and they print what was expected vs. actual.
_has() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) printf 'expected to find [%s] in [%s]\n' "$2" "$1" >&2; return 1 ;;
  esac
}
_hasnt() {
  case "$1" in
    *"$2"*) printf 'did NOT expect [%s] in [%s]\n' "$2" "$1" >&2; return 1 ;;
    *) return 0 ;;
  esac
}

# Install a recording tmux fake on PATH for THIS test only (never globally: the
# pre-existing kill-sessions test relies on the real tmux reporting "no such
# session"). Records every kill target and the $TMUX it was invoked with.
_use_fake_tmux() {
  mkdir -p "$STUB_ROOT/bin"
  FAKE_KILL_LOG="$STUB_ROOT/kills.log"; : > "$FAKE_KILL_LOG"
  FAKE_ENV_LOG="$STUB_ROOT/env.log";   : > "$FAKE_ENV_LOG"
  export FAKE_KILL_LOG FAKE_ENV_LOG
  cat > "$STUB_ROOT/bin/tmux" <<'FAKE'
#!/bin/sh
printf 'TMUXENV=%s\n' "${TMUX:-<unset>}" >> "$FAKE_ENV_LOG"
verb="$1"; shift
case "$verb" in
  list-sessions) printf '%s' "${FAKE_ROSTER:-}" ;;
  has-session)   exit 0 ;;
  kill-session)
    while [ $# -gt 0 ]; do
      case "$1" in -t) shift; printf '%s\n' "$1" >> "$FAKE_KILL_LOG"; break ;; *) shift ;; esac
    done ;;
esac
exit 0
FAKE
  chmod +x "$STUB_ROOT/bin/tmux"
  PATH="$STUB_ROOT/bin:$PATH"; export PATH
}

# Count non-empty lines in the kill log (0 when nothing was killed).
_kill_count() { grep -c . "$FAKE_KILL_LOG" 2>/dev/null || true; }

# Minimal committed git repo; echoes its path. `sweep` prunes worktrees, so its
# <repo-root> must be a real repo even when a test only exercises the session half.
_mkroot() {
  _p="${BATS_TEST_TMPDIR}/root-${1:-0}"
  mkdir -p "$_p"
  git -C "$_p" init -q
  git -C "$_p" config user.email t@t; git -C "$_p" config user.name t
  echo x > "$_p/f"; git -C "$_p" add f; git -C "$_p" commit -qm init
  printf '%s' "$_p"
}

@test "init-check: refuse inside an existing repo (nesting)" {
  outer="${BATS_TEST_TMPDIR}/outer"; mkdir -p "$outer/sub"
  git -C "$outer" init -q
  run bash "$SC" init-check "$outer/sub"
  [ "$status" -ne 0 ]
  [[ "$output" == *"REFUSE"* ]]
}

@test "init-check: refuse when secret-like files present" {
  wd="${BATS_TEST_TMPDIR}/sec"; mkdir -p "$wd"; : > "$wd/.env"
  run bash "$SC" init-check "$wd"
  [ "$status" -ne 0 ]
  [[ "$output" == *"secret"* ]]
}

@test "init-check: ok on a clean dir" {
  wd="${BATS_TEST_TMPDIR}/fresh"; mkdir -p "$wd"
  run bash "$SC" init-check "$wd"
  [ "$status" -eq 0 ]
}

@test "merge: refuse when a worktree has uncommitted changes" {
  root="${BATS_TEST_TMPDIR}/repo"; mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" config user.email t@t; git -C "$root" config user.name t
  echo x > "$root/f"; git -C "$root" add f; git -C "$root" commit -qm init
  git -C "$root" branch feat/t1
  git -C "$root" worktree add -q "$root/.worktrees/feat-t1" feat/t1
  echo dirty > "$root/.worktrees/feat-t1/g"   # untracked → dirty
  run bash "$SC" merge "$root" main feat/t1
  [ "$status" -ne 0 ]
  [[ "$output" == *"REFUSE"* ]]
}

@test "kill-sessions: skip a non-existent exact name (no prefix match)" {
  run bash "$SC" kill-sessions "lo-nonexistent-xyz-000"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip"* ]]
}

# ---------------------------------------------------------------------------
# Task 01 — --dry-run on the existing destructive verbs.
# New tests invoke the script with `sh`, never `bash`: `bash script.sh` overrides
# the #!/bin/sh shebang, so a bashism would pass here and fail under dash in
# production (wiki: platforms-shells-portable-shell-scripts).
# ---------------------------------------------------------------------------

# Build a repo with one commit, a task branch, and its worktree. Echoes the
# default branch name so tests never hard-code main-vs-master.
_mkrepo() {
  _r="$1"
  mkdir -p "$_r"
  git -C "$_r" init -q
  git -C "$_r" config user.email t@t; git -C "$_r" config user.name t
  echo x > "$_r/f"; git -C "$_r" add f; git -C "$_r" commit -qm init
  git -C "$_r" branch feat/t1
  git -C "$_r" worktree add -q "$_r/.worktrees/feat-t1" feat/t1
  git -C "$_r" rev-parse --abbrev-ref HEAD
}

@test "dry-run: remove-worktrees prints the plan and removes nothing" {
  root="${BATS_TEST_TMPDIR}/dr1"; _mkrepo "$root" >/dev/null
  run sh "$SC" remove-worktrees --dry-run "$root" feat/t1
  [ "$status" -eq 0 ]
  _has "$output" "would remove"
  _hasnt "$output" "removed:"
  # the resource must still be there — an exit-0 assertion alone cannot fail
  [ -d "$root/.worktrees/feat-t1" ]
  git -C "$root" worktree list | grep -q "feat-t1"
}

@test "dry-run: merge prints the plan and leaves the integration branch at the same SHA" {
  root="${BATS_TEST_TMPDIR}/dr2"; defbr=$(_mkrepo "$root")
  before=$(git -C "$root" rev-parse "$defbr")
  run sh "$SC" merge --dry-run "$root" "$defbr" feat/t1
  [ "$status" -eq 0 ]
  _has "$output" "would merge"
  after=$(git -C "$root" rev-parse "$defbr")
  [ "$before" = "$after" ]
}

@test "dry-run: merge still REFUSEs a dirty worktree (dry-run must not soften a refusal)" {
  root="${BATS_TEST_TMPDIR}/dr3"; defbr=$(_mkrepo "$root")
  echo dirty > "$root/.worktrees/feat-t1/g"   # untracked -> dirty
  run sh "$SC" merge --dry-run "$root" "$defbr" feat/t1
  [ "$status" -ne 0 ]
  _has "$output" "REFUSE"
}

@test "dry-run: boundary — a trailing --dry-run is parsed as a flag, not as a branch name" {
  root="${BATS_TEST_TMPDIR}/dr4"; _mkrepo "$root" >/dev/null
  run sh "$SC" remove-worktrees "$root" feat/t1 --dry-run
  [ "$status" -eq 0 ]
  _has "$output" "would remove"
  # if the flag had been consumed as an operand, DRY would be 0 and this is gone
  [ -d "$root/.worktrees/feat-t1" ]
}

@test "dry-run: kill-sessions announces the kill but issues none" {
  _use_fake_tmux
  run sh "$SC" kill-sessions --dry-run "lo-1-runA"
  [ "$status" -eq 0 ]
  _has "$output" "would kill"
  _hasnt "$output" "killed:"
  [ "$(_kill_count)" -eq 0 ]
}

@test "kill-sessions: actually kills the exact name it is given" {
  _use_fake_tmux
  run sh "$SC" kill-sessions "lo-1-runA"
  [ "$status" -eq 0 ]
  _has "$output" "killed:"
  [ "$(_kill_count)" -eq 1 ]
  _has "$(cat "$FAKE_KILL_LOG")" "lo-1-runA"
}

@test "kill-sessions: does not clobber tmux's own \$TMUX socket variable" {
  # Regression: `TMUX=\$(command -v tmux)` inherits the exported attribute when
  # the script runs INSIDE a tmux session (as every orchestrator worker does),
  # so tmux then tries to use the binary path as its server socket and every
  # has-session call fails -> teardown silently kills nothing.
  _use_fake_tmux
  export TMUX="/private/tmp/tmux-501/default,111,2"
  run sh "$SC" kill-sessions "lo-1-runA"
  [ "$status" -eq 0 ]
  _has "$(cat "$FAKE_ENV_LOG")" "TMUXENV=/private/tmp/tmux-501/default,111,2"
  _hasnt "$(cat "$FAKE_ENV_LOG")" "TMUXENV=$STUB_ROOT/bin/tmux"
}

# ---------------------------------------------------------------------------
# Task 02 — `sweep`: destructive, and scoped to LO_RUN_ID.
# Every one of these drives the INJECTED tmux fake, never the real server: this
# machine runs live lo-N-<runid> orchestration sessions, and a scoping bug (the
# exact defect under test) would otherwise tear down the running workers.
# ---------------------------------------------------------------------------

@test "sweep: kills exactly this run's sessions" {
  _use_fake_tmux
  export FAKE_ROSTER='lo-1-runA
lo-2-runA
lo-9-runB
lo-test
mydev'
  export LO_RUN_ID=runA
  run sh "$SC" sweep "$(_mkroot sw)"
  [ "$status" -eq 0 ]
  killed=$(cat "$FAKE_KILL_LOG")
  _has "$killed" "lo-1-runA"
  _has "$killed" "lo-2-runA"
  [ "$(_kill_count)" -eq 2 ]
}

@test "sweep: two run ids present — the foreign run is never touched" {
  _use_fake_tmux
  export FAKE_ROSTER='lo-1-runA
lo-2-runA
lo-9-runB
lo-test
mydev'
  export LO_RUN_ID=runA
  run sh "$SC" sweep "$(_mkroot sw)"
  [ "$status" -eq 0 ]
  killed=$(cat "$FAKE_KILL_LOG")
  _hasnt "$killed" "lo-9-runB"
  _hasnt "$killed" "lo-test"
  _hasnt "$killed" "mydev"
}

@test "sweep: error — REFUSEs when LO_RUN_ID is unset and kills nothing" {
  _use_fake_tmux
  export FAKE_ROSTER='lo-1-runA
lo-2-runA'
  unset LO_RUN_ID
  run sh "$SC" sweep "$(_mkroot sw)"
  [ "$status" -ne 0 ]
  _has "$output" "REFUSE"
  [ "$(_kill_count)" -eq 0 ]
}

@test "sweep: error — REFUSEs a malformed LO_RUN_ID and kills nothing" {
  _use_fake_tmux
  export FAKE_ROSTER='lo-1-runA'
  export LO_RUN_ID='a b'
  run sh "$SC" sweep "$(_mkroot sw)"
  [ "$status" -ne 0 ]
  _has "$output" "REFUSE"
  [ "$(_kill_count)" -eq 0 ]
}

@test "sweep: boundary — a run id that is a prefix of another id is not swept" {
  _use_fake_tmux
  # lo-1-runAB: runA is a prefix of runAB, must NOT match.
  # lo-1-x-runA: ends with -runA but belongs to a differently-named run.
  export FAKE_ROSTER='lo-1-runAB
lo-1-x-runA
lo-3-runA'
  export LO_RUN_ID=runA
  run sh "$SC" sweep "$(_mkroot sw)"
  [ "$status" -eq 0 ]
  killed=$(cat "$FAKE_KILL_LOG")
  _hasnt "$killed" "lo-1-runAB"
  _hasnt "$killed" "lo-1-x-runA"
  _has "$killed" "lo-3-runA"
  [ "$(_kill_count)" -eq 1 ]
}

@test "sweep: boundary — an empty session roster is a clean no-op" {
  _use_fake_tmux
  export FAKE_ROSTER=''
  export LO_RUN_ID=runA
  run sh "$SC" sweep "$(_mkroot sw)"
  [ "$status" -eq 0 ]
  _has "$output" "0 session"
  [ "$(_kill_count)" -eq 0 ]
}

@test "sweep: --dry-run announces the kills and issues none" {
  _use_fake_tmux
  export FAKE_ROSTER='lo-1-runA
lo-9-runB'
  export LO_RUN_ID=runA
  run sh "$SC" sweep --dry-run "$(_mkroot swdry)"
  [ "$status" -eq 0 ]
  _has "$output" "would kill: lo-1-runA"
  _hasnt "$output" "killed: lo-1-runA"
  [ "$(_kill_count)" -eq 0 ]
}

@test "sweep: error — a missing repo-root argument is a usage error" {
  _use_fake_tmux
  export LO_RUN_ID=runA
  run sh "$SC" sweep
  [ "$status" -ne 0 ]
  [ "$(_kill_count)" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Task 03 — `git worktree prune` where it belongs.
# A worktree whose DIRECTORY is gone leaves git admin files behind forever;
# that is the orphan sweep removes. Live/registered worktrees are never touched
# by sweep — removing those stays an explicit `remove-worktrees <branch>`.
# ---------------------------------------------------------------------------

# Repo with a worktree whose directory has been deleted, leaving a stale
# .git/worktrees/<name> admin entry.
_mkstale() {
  _r="$1"
  mkdir -p "$_r"
  git -C "$_r" init -q
  git -C "$_r" config user.email t@t; git -C "$_r" config user.name t
  echo x > "$_r/f"; git -C "$_r" add f; git -C "$_r" commit -qm init
  git -C "$_r" branch feat/a
  git -C "$_r" worktree add -q "$_r/.worktrees/feat-a" feat/a
  rm -rf "$_r/.worktrees/feat-a"      # the orphan: dir gone, admin entry stays
}

@test "prune: remove-worktrees clears the admin entry of a vanished worktree" {
  root="${BATS_TEST_TMPDIR}/pr1"; _mkstale "$root"
  [ -e "$root/.git/worktrees/feat-a" ]        # the orphan exists before
  run sh "$SC" remove-worktrees "$root" feat/a
  [ "$status" -eq 0 ]
  [ ! -e "$root/.git/worktrees/feat-a" ]      # ...and is gone after
}

@test "prune: --dry-run reports the prune and leaves the admin entry in place" {
  root="${BATS_TEST_TMPDIR}/pr2"; _mkstale "$root"
  run sh "$SC" remove-worktrees --dry-run "$root" feat/a
  [ "$status" -eq 0 ]
  _has "$output" "prune:"
  [ -e "$root/.git/worktrees/feat-a" ]        # unchanged — this is the whole point
}

@test "prune: sweep prunes this run's stale worktree admin entries" {
  _use_fake_tmux
  export FAKE_ROSTER=''
  export LO_RUN_ID=runA
  root="${BATS_TEST_TMPDIR}/pr3"; _mkstale "$root"
  run sh "$SC" sweep "$root"
  [ "$status" -eq 0 ]
  [ ! -e "$root/.git/worktrees/feat-a" ]
}

@test "prune: error — sweep on a non-git root fails instead of reporting success" {
  _use_fake_tmux
  export FAKE_ROSTER=''
  export LO_RUN_ID=runA
  root="${BATS_TEST_TMPDIR}/pr4"; mkdir -p "$root"
  run sh "$SC" sweep "$root"
  [ "$status" -ne 0 ]
}

@test "prune: boundary — a repo with no worktrees prunes nothing and stays quiet" {
  root="${BATS_TEST_TMPDIR}/pr5"; mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" config user.email t@t; git -C "$root" config user.name t
  echo x > "$root/f"; git -C "$root" add f; git -C "$root" commit -qm init
  git -C "$root" branch feat/t1
  run sh "$SC" remove-worktrees "$root" feat/t1
  [ "$status" -eq 0 ]
  _hasnt "$output" "prune:"
}

@test "prune: boundary — an unregistered .worktrees dir is reported, never deleted" {
  _use_fake_tmux
  export FAKE_ROSTER=''
  export LO_RUN_ID=runA
  root="${BATS_TEST_TMPDIR}/pr6"; mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" config user.email t@t; git -C "$root" config user.name t
  echo x > "$root/f"; git -C "$root" add f; git -C "$root" commit -qm init
  mkdir -p "$root/.worktrees/leftover"; echo work > "$root/.worktrees/leftover/uncommitted.txt"
  run sh "$SC" sweep "$root"
  [ "$status" -eq 0 ]
  _has "$output" "unregistered worktree dir"
  # it may hold work, so reporting is the whole contract — deletion would be a bug
  [ -d "$root/.worktrees/leftover" ]
  [ -f "$root/.worktrees/leftover/uncommitted.txt" ]
}

# ---------------------------------------------------------------------------
# Task 04 — `list-orphans`: read-only, and deliberately NOT scoped to a run.
# Enumeration is unscoped so a crashed run's leaks stay discoverable (its id is
# gone from the environment); removal stays scoped to LO_RUN_ID via `sweep`.
# For these tests FAKE_ROSTER carries "<name> <epoch>" pairs, matching the
# -F format list-orphans requests.
# ---------------------------------------------------------------------------

@test "list-orphans: annotates each session with its run id, without LO_RUN_ID set" {
  _use_fake_tmux
  export FAKE_ROSTER='lo-1-runA 1700000001
lo-9-runB 1700000002
lo-test 1700000003'
  unset LO_RUN_ID
  run sh "$SC" list-orphans "$(_mkroot lo1)"
  [ "$status" -eq 0 ]
  _has "$output" "lo-1-runA"
  _has "$output" "run=runA"
  _has "$output" "lo-9-runB"
  _has "$output" "run=runB"
  # a session with no run-id suffix must be reported, not silently dropped
  _has "$output" "lo-test"
  _has "$output" "run=none"
  _has "$output" "created=1700000001"
}

@test "list-orphans: reports a worktree whose directory has vanished" {
  _use_fake_tmux
  export FAKE_ROSTER=''
  root="${BATS_TEST_TMPDIR}/lo2"; _mkstale "$root"
  run sh "$SC" list-orphans "$root"
  [ "$status" -eq 0 ]
  _has "$output" "worktree-stale"
  _has "$output" "feat-a"
}

@test "list-orphans: error — a missing repo-root argument is a usage error" {
  _use_fake_tmux
  export FAKE_ROSTER=''
  run sh "$SC" list-orphans
  [ "$status" -ne 0 ]
}

@test "list-orphans: boundary — nothing to report is a silent, successful run" {
  _use_fake_tmux
  export FAKE_ROSTER=''
  run sh "$SC" list-orphans "$(_mkroot lo4)"
  [ "$status" -eq 0 ]
  _hasnt "$output" "session	"
  _hasnt "$output" "worktree-stale"
  _hasnt "$output" "worktree-unregistered"
}

@test "list-orphans: is provably read-only — kills nothing, deletes nothing" {
  _use_fake_tmux
  export FAKE_ROSTER='lo-1-runA 1700000001
lo-2-runA 1700000002'
  export LO_RUN_ID=runA          # even with a scope set, it must not act
  root="${BATS_TEST_TMPDIR}/lo5"; _mkstale "$root"
  mkdir -p "$root/.worktrees/leftover"
  run sh "$SC" list-orphans "$root"
  [ "$status" -eq 0 ]
  [ "$(_kill_count)" -eq 0 ]                    # no session killed
  [ -e "$root/.git/worktrees/feat-a" ]          # stale admin entry NOT pruned
  [ -d "$root/.worktrees/leftover" ]            # unregistered dir NOT deleted
}

# ---------------------------------------------------------------------------
# Task 05 — `teardown`: atomic, idempotent, run-scoped end-of-run cleanup.
# derive (this run's own status/*.json) -> remove_worktrees -> sweep ->
# archive. Every fabricated run below carries a FOREIGN worktree/session too,
# so a scoping bug (deriving from a bare .worktrees/* glob, or sweeping past
# this run's sessions) shows up as an extra removal/kill, not a missing one.
# ---------------------------------------------------------------------------

# Repo with an own branch+worktree (status record under $1, default runA) and
# a foreign branch+worktree (status record under a different run), plus one
# plan file directly under .orchestration/ to exercise the archive step.
# Echoes the repo root.
_mkteardownrun() {
  _r="${BATS_TEST_TMPDIR}/${1:-td}"; _rid="${2:-runA}"; _frid="${3:-runB}"
  mkdir -p "$_r"
  git -C "$_r" init -q
  git -C "$_r" config user.email t@t; git -C "$_r" config user.name t
  echo x > "$_r/f"; git -C "$_r" add f; git -C "$_r" commit -qm init
  git -C "$_r" branch feat/own
  git -C "$_r" worktree add -q "$_r/.worktrees/feat-own" feat/own
  git -C "$_r" branch feat/foreign
  git -C "$_r" worktree add -q "$_r/.worktrees/feat-foreign" feat/foreign
  mkdir -p "$_r/.orchestration/status"
  printf '{"task":"own","phase":"done","session":"lo-1-%s","worktree":"%s"}' \
    "$_rid" "$_r/.worktrees/feat-own" > "$_r/.orchestration/status/own.json"
  printf '{"task":"foreign","phase":"done","session":"lo-1-%s","worktree":"%s"}' \
    "$_frid" "$_r/.worktrees/feat-foreign" > "$_r/.orchestration/status/foreign.json"
  echo "plan doc" > "$_r/.orchestration/plan-own.md"
  printf '%s' "$_r"
}

# Rebuild $PATH with EVERY jq visible on it made unresolvable, while every
# other tool alongside each jq stays available: for each PATH entry that
# contains an executable jq, mirror that directory's contents minus jq into
# its own stub under STUB_ROOT and swap it in at that entry's own position.
# review r2/F1: a helper that only handles the FIRST jq hit is a no-op on any
# PATH carrying more than one (CI images ship a preinstalled jq AND the
# workflow's own install) — it must walk the whole PATH, not just resolve
# `command -v jq` once.
_path_without_jq() {
  newpath=""
  idx=0
  oldifs=$IFS; IFS=':'
  for d in $PATH; do
    if [ -x "$d/jq" ]; then
      idx=$((idx + 1))
      stub="$STUB_ROOT/nojq-$idx"; mkdir -p "$stub"
      for f in "$d"/*; do
        b=$(basename "$f")
        [ "$b" = "jq" ] && continue
        ln -sf "$f" "$stub/$b"
      done
      newpath="${newpath:+$newpath:}$stub"
    else
      newpath="${newpath:+$newpath:}$d"
    fi
  done
  IFS=$oldifs
  printf '%s' "$newpath"
}

# review r2/F1: a guard so the simulation can never silently regress into a
# no-op again — fails the test loudly (not just the downstream jq-dependent
# assertions, which could pass or fail for unrelated reasons) if the rebuilt
# PATH still resolves a jq. Called as its own top-level statement (never
# embedded in a `VAR=$(...) other_cmd` prefix): the shell does not propagate
# a command substitution's own exit status into that other command's status,
# so a failure there would be silently swallowed instead of failing the test.
_assert_no_jq() {
  if PATH="$1" command -v jq >/dev/null 2>&1; then
    printf 'expected PATH [%s] to have no resolvable jq, but found: %s\n' \
      "$1" "$(PATH="$1" command -v jq)" >&2
    return 1
  fi
  return 0
}

@test "teardown: error — REFUSEs when LO_RUN_ID is unset and touches nothing" {
  _use_fake_tmux
  root="$(_mkteardownrun td1)"
  unset LO_RUN_ID
  run sh "$SC" teardown "$root"
  [ "$status" -ne 0 ]
  _has "$output" "REFUSE"
  _has "$output" "teardown"
  [ -d "$root/.worktrees/feat-own" ]
  [ -d "$root/.worktrees/feat-foreign" ]
  [ "$(_kill_count)" -eq 0 ]
}

@test "teardown: error — missing jq exits 127 and touches nothing" {
  _use_fake_tmux
  root="$(_mkteardownrun td2)"
  export FAKE_ROSTER='lo-1-runA'
  export LO_RUN_ID=runA
  nojq_path="$(_path_without_jq)"
  _assert_no_jq "$nojq_path"
  PATH="$nojq_path" run sh "$SC" teardown "$root"
  [ "$status" -eq 127 ]
  _has "$output" "jq not found"
  [ -d "$root/.worktrees/feat-own" ]
  [ "$(_kill_count)" -eq 0 ]
}

@test "teardown: dry-run announces would-remove/would-kill/would-archive and touches nothing" {
  _use_fake_tmux
  root="$(_mkteardownrun td3)"
  export FAKE_ROSTER='lo-1-runA
lo-1-runB'
  export LO_RUN_ID=runA
  run sh "$SC" teardown --dry-run "$root"
  [ "$status" -eq 0 ]
  _has "$output" "would remove"
  _has "$output" "would kill: lo-1-runA"
  _has "$output" "would archive"
  _hasnt "$output" "removed:"
  _hasnt "$output" "killed:"
  _hasnt "$output" "archived:"
  _hasnt "$output" "lo-1-runB"
  [ -d "$root/.worktrees/feat-own" ]
  [ -d "$root/.worktrees/feat-foreign" ]
  [ "$(_kill_count)" -eq 0 ]
  [ -d "$root/.orchestration/status" ]
  [ -f "$root/.orchestration/plan-own.md" ]
}

@test "teardown: removes this run's worktree, kills its session, archives .orchestration — the foreign run is never touched" {
  _use_fake_tmux
  root="$(_mkteardownrun td4)"
  export FAKE_ROSTER='lo-1-runA
lo-1-runB'
  export LO_RUN_ID=runA
  run sh "$SC" teardown "$root"
  [ "$status" -eq 0 ]
  [ ! -d "$root/.worktrees/feat-own" ]
  [ -d "$root/.worktrees/feat-foreign" ]           # foreign worktree untouched
  killed=$(cat "$FAKE_KILL_LOG")
  _has "$killed" "lo-1-runA"
  _hasnt "$killed" "lo-1-runB"                     # foreign session untouched
  archived="$root/.orchestration/archive-$(date +%Y%m%d)-runA"
  [ -f "$archived/status/foreign.json" ]           # foreign's status record is archived, not deleted
  [ -f "$archived/plan-own.md" ]
}

@test "teardown: boundary — re-run after teardown is an idempotent no-op that archives nothing" {
  _use_fake_tmux
  root="$(_mkteardownrun td5)"
  export FAKE_ROSTER='lo-1-runA'
  export LO_RUN_ID=runA
  run sh "$SC" teardown "$root"
  [ "$status" -eq 0 ]
  run sh "$SC" teardown "$root"
  [ "$status" -eq 0 ]
  _has "$output" "nothing to archive"
}

@test "teardown: boundary — no status records at all is a silent no-op for the derive step" {
  _use_fake_tmux
  root="${BATS_TEST_TMPDIR}/td6"; mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" config user.email t@t; git -C "$root" config user.name t
  echo x > "$root/f"; git -C "$root" add f; git -C "$root" commit -qm init
  export FAKE_ROSTER=''
  export LO_RUN_ID=runA
  run sh "$SC" teardown "$root"
  [ "$status" -eq 0 ]
  [ "$(_kill_count)" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Task t3 — #129: teardown archives untracked worker scratch (including
# excluded .claude/) before removal; tracked modifications still SKIP.
# ---------------------------------------------------------------------------

@test "teardown: untracked-only worker scratch (.claude/) is archived then the worktree is removed" {
  _use_fake_tmux
  root="$(_mkteardownrun td7)"
  mkdir -p "$root/.worktrees/feat-own/.claude/tmp"
  echo "notes" > "$root/.worktrees/feat-own/.claude/tmp/note.md"
  export FAKE_ROSTER='lo-1-runA'
  export LO_RUN_ID=runA
  run sh "$SC" teardown "$root"
  [ "$status" -eq 0 ]
  [ ! -d "$root/.worktrees/feat-own" ]
  archived="$root/.orchestration/archive-$(date +%Y%m%d)-runA/worker-scratch/feat-own"
  [ -f "$archived/.claude/tmp/note.md" ]
  run cat "$archived/.claude/tmp/note.md"
  [ "$output" = "notes" ]
}

@test "teardown: a tracked modification still SKIPs the worktree, labeled dirt=modified" {
  _use_fake_tmux
  root="$(_mkteardownrun td8)"
  echo "changed" > "$root/.worktrees/feat-own/f"   # f is tracked, committed before the worktree was branched
  export FAKE_ROSTER='lo-1-runA'
  export LO_RUN_ID=runA
  run sh "$SC" teardown "$root"
  [ "$status" -eq 0 ]
  _has "$output" "dirt=modified"
  [ -d "$root/.worktrees/feat-own" ]
}

@test "remove-worktrees: untracked-only scratch SKIPs the worktree, labeled untracked-only" {
  root="${BATS_TEST_TMPDIR}/rw1"; _mkrepo "$root" >/dev/null
  mkdir -p "$root/.worktrees/feat-t1/.claude"
  echo "scratch" > "$root/.worktrees/feat-t1/.claude/note.md"
  run sh "$SC" remove-worktrees "$root" feat/t1
  [ "$status" -eq 0 ]
  _has "$output" "untracked-only"
  # the standalone verb never archives or deletes un-archived scratch
  [ -d "$root/.worktrees/feat-t1" ]
  [ -f "$root/.worktrees/feat-t1/.claude/note.md" ]
}

@test "teardown: dry-run announces would-archive for worker scratch and touches nothing" {
  _use_fake_tmux
  root="$(_mkteardownrun td9)"
  mkdir -p "$root/.worktrees/feat-own/.claude/tmp"
  echo "notes" > "$root/.worktrees/feat-own/.claude/tmp/note.md"
  export FAKE_ROSTER='lo-1-runA'
  export LO_RUN_ID=runA
  run sh "$SC" teardown --dry-run "$root"
  [ "$status" -eq 0 ]
  _has "$output" "would archive: $root/.worktrees/feat-own/.claude/tmp/note.md"
  [ -f "$root/.worktrees/feat-own/.claude/tmp/note.md" ]
  [ -d "$root/.worktrees/feat-own" ]
  [ ! -d "$root/.orchestration/archive-$(date +%Y%m%d)-runA" ]
}

@test "teardown: boundary — a clean worktree (no scratch) is removed with nothing scratch-specific archived" {
  _use_fake_tmux
  root="$(_mkteardownrun td10)"
  export FAKE_ROSTER='lo-1-runA'
  export LO_RUN_ID=runA
  run sh "$SC" teardown "$root"
  [ "$status" -eq 0 ]
  [ ! -d "$root/.worktrees/feat-own" ]
  [ ! -d "$root/.orchestration/archive-$(date +%Y%m%d)-runA/worker-scratch/feat-own" ]
}

# review r1/F1: a directory that exists at remove_worktrees' CONVENTIONAL path
# (tr '/' '-' on the branch name) but is not the worktree the status record
# actually points to, and carries a stale/broken gitdir link — `git status`
# on it fails (nonzero exit). Under `set -eu`, a bare `status_out=$(...)`
# assignment would abort the WHOLE script right there; the fix degrades that
# to "treat as clean, let `worktree remove` report FAILED and move on" so
# sweep and archive still run.
@test "teardown: a broken (stale-gitdir) directory at the conventional worktree path does not abort sweep+archive" {
  _use_fake_tmux
  root="${BATS_TEST_TMPDIR}/td11"
  mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" config user.email t@t; git -C "$root" config user.name t
  echo x > "$root/f"; git -C "$root" add f; git -C "$root" commit -qm init
  git -C "$root" branch feat/own
  # the REAL worktree the status record points to lives elsewhere...
  git -C "$root" worktree add -q "$root/.worktrees/feat-own-real" feat/own
  # ...while a stray directory with a broken gitdir link squats at the
  # conventional path remove_worktrees always recomputes independently.
  mkdir -p "$root/.worktrees/feat-own"
  echo "gitdir: $root/.git/worktrees/does-not-exist" > "$root/.worktrees/feat-own/.git"
  mkdir -p "$root/.orchestration/status"
  printf '{"task":"own","phase":"done","session":"lo-1-runA","worktree":"%s"}' \
    "$root/.worktrees/feat-own-real" > "$root/.orchestration/status/own.json"
  export FAKE_ROSTER='lo-1-runA'
  export LO_RUN_ID=runA
  run sh "$SC" teardown "$root"
  [ "$status" -eq 0 ]
  # teardown did NOT abort: the session was still swept...
  killed=$(cat "$FAKE_KILL_LOG")
  _has "$killed" "lo-1-runA"
  # ...and .orchestration was still archived past the broken directory.
  archived="$root/.orchestration/archive-$(date +%Y%m%d)-runA"
  [ -f "$archived/status/own.json" ]
  # the broken dir itself is reported/skipped, never force-removed
  [ -d "$root/.worktrees/feat-own" ]
}

# ---------------------------------------------------------------------------
# Task 06 — `list-orphans --stale`: read-only staleness annotation.
# yes = every status record matching the session's run id is done|failed;
# no = at least one is not; unknown = no matching record (archived, foreign
# repo's run, or a hand-made session with no run-id suffix at all).
# ---------------------------------------------------------------------------

@test "list-orphans --stale: every matching record terminal -> stale=yes" {
  _use_fake_tmux
  root="$(_mkroot lo6)"
  mkdir -p "$root/.orchestration/status"
  printf '{"task":"a","phase":"done","session":"lo-1-runA"}' > "$root/.orchestration/status/a.json"
  printf '{"task":"b","phase":"failed","session":"lo-2-runA"}' > "$root/.orchestration/status/b.json"
  export FAKE_ROSTER='lo-1-runA 1700000001'
  unset LO_RUN_ID
  run sh "$SC" list-orphans --stale "$root"
  [ "$status" -eq 0 ]
  _has "$output" "stale=yes"
  _hasnt "$output" "stale=no"
  _hasnt "$output" "stale=unknown"
}

@test "list-orphans --stale: one matching record non-terminal -> stale=no" {
  _use_fake_tmux
  root="$(_mkroot lo7)"
  mkdir -p "$root/.orchestration/status"
  printf '{"task":"a","phase":"done","session":"lo-1-runA"}' > "$root/.orchestration/status/a.json"
  printf '{"task":"b","phase":"implementing","session":"lo-2-runA"}' > "$root/.orchestration/status/b.json"
  export FAKE_ROSTER='lo-1-runA 1700000001'
  unset LO_RUN_ID
  run sh "$SC" list-orphans --stale "$root"
  [ "$status" -eq 0 ]
  _has "$output" "stale=no"
}

@test "list-orphans --stale: boundary — no matching status records -> stale=unknown" {
  _use_fake_tmux
  root="$(_mkroot lo8)"
  export FAKE_ROSTER='lo-1-runZ 1700000001'
  unset LO_RUN_ID
  run sh "$SC" list-orphans --stale "$root"
  [ "$status" -eq 0 ]
  _has "$output" "stale=unknown"
}

@test "list-orphans --stale: a session with no run-id suffix is stale=unknown" {
  _use_fake_tmux
  root="$(_mkroot lo9)"
  export FAKE_ROSTER='lo-test 1700000001'
  unset LO_RUN_ID
  run sh "$SC" list-orphans --stale "$root"
  [ "$status" -eq 0 ]
  _has "$output" "run=none"
  _has "$output" "stale=unknown"
}

@test "list-orphans: boundary — without --stale, no stale field is emitted" {
  _use_fake_tmux
  root="$(_mkroot lo10)"
  mkdir -p "$root/.orchestration/status"
  printf '{"task":"a","phase":"done","session":"lo-1-runA"}' > "$root/.orchestration/status/a.json"
  export FAKE_ROSTER='lo-1-runA 1700000001'
  unset LO_RUN_ID
  run sh "$SC" list-orphans "$root"
  [ "$status" -eq 0 ]
  _hasnt "$output" "stale="
}

@test "list-orphans --stale: boundary — the flag works in trailing position too" {
  _use_fake_tmux
  root="$(_mkroot lo11)"
  mkdir -p "$root/.orchestration/status"
  printf '{"task":"a","phase":"done","session":"lo-1-runA"}' > "$root/.orchestration/status/a.json"
  export FAKE_ROSTER='lo-1-runA 1700000001'
  unset LO_RUN_ID
  run sh "$SC" list-orphans "$root" --stale
  [ "$status" -eq 0 ]
  _has "$output" "stale=yes"
}

@test "list-orphans --stale: error — missing jq warns on stderr and reports unknown for all" {
  _use_fake_tmux
  root="$(_mkroot lo12)"
  mkdir -p "$root/.orchestration/status"
  printf '{"task":"a","phase":"done","session":"lo-1-runA"}' > "$root/.orchestration/status/a.json"
  export FAKE_ROSTER='lo-1-runA 1700000001'
  unset LO_RUN_ID
  nojq_path="$(_path_without_jq)"
  _assert_no_jq "$nojq_path"
  PATH="$nojq_path" run sh "$SC" list-orphans --stale "$root"
  [ "$status" -eq 0 ]
  _has "$output" "jq not found"
  _has "$output" "stale=unknown"
}
