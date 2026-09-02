#!/usr/bin/env bats
# Tests for hooks/loop-gate.sh (Stop hook).
# Run in CI; the same cases are verified directly via shell during development.

setup() {
  GATE="${BATS_TEST_DIRNAME}/../hooks/loop-gate.sh"
  WS="${BATS_TEST_TMPDIR}/ws"
  mkdir -p "$WS/.orchestration/status"
  FAKE_TMUX="${BATS_TEST_TMPDIR}/fake-tmux"
  cat > "$FAKE_TMUX" <<'EOF'
#!/usr/bin/env bash
# Stub: answers `display-message -p '#S'` with $FAKE_TMUX_SESSION.
if [ "$1" = "display-message" ]; then
  printf '%s\n' "${FAKE_TMUX_SESSION:-}"
  exit 0
fi
exit 1
EOF
  chmod +x "$FAKE_TMUX"
}

_run_gate() { # <cwd> <stop_hook_active>
  printf '{"cwd":"%s","stop_hook_active":%s}' "$1" "${2:-false}" | bash "$GATE"
}

@test "non-managed session: exit 0 (no .orchestration)" {
  run _run_gate "${BATS_TEST_TMPDIR}" false
  [ "$status" -eq 0 ]
}

@test "incomplete loop (phase=implementing): blocks with exit 2 + advice" {
  printf '{"worktree":"%s","phase":"implementing"}' "$WS" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
  [[ "$output" == *"incomplete"* ]]
}

@test "complete loop (phase=done): allows stop (exit 0)" {
  printf '{"worktree":"%s","phase":"done"}' "$WS" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "stop_hook_active=true: never loops even if incomplete (exit 0)" {
  printf '{"worktree":"%s","phase":"implementing"}' "$WS" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" true
  [ "$status" -eq 0 ]
}

@test "phase incomplete but worktree mismatch: not this session, exit 0" {
  printf '{"worktree":"%s","phase":"implementing"}' "/some/other/wt" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

# --- Terminal wait-phase allowlist (#127) ---

@test "phase=plan_ready, worker identity match: allows stop (exit 0)" {
  printf '{"worktree":"%s","phase":"plan_ready","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  export TMUX=/tmp/fake-socket LOOP_GATE_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="work-t1"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "phase=impl_done, worker identity match: allows stop (exit 0)" {
  printf '{"worktree":"%s","phase":"impl_done","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  export TMUX=/tmp/fake-socket LOOP_GATE_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="work-t1"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

# --- Session identity check: block only the managed tmux worker ---

@test "worker identity match + phase=implementing: blocks (exit 2)" {
  printf '{"worktree":"%s","phase":"implementing","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  export TMUX=/tmp/fake-socket LOOP_GATE_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="work-t1"
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
  [[ "$output" == *"incomplete"* ]]
}

@test "cwd matches but tmux session differs from record .session: not blocked (exit 0)" {
  printf '{"worktree":"%s","phase":"implementing","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  export TMUX=/tmp/fake-socket LOOP_GATE_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="some-other-session"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "cwd matches, not in tmux, .session set: not blocked (exit 0)" {
  printf '{"worktree":"%s","phase":"implementing","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  unset TMUX
  export LOOP_GATE_TMUX="$FAKE_TMUX"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

# fallback (no .session field) + phase=implementing is already covered by
# "incomplete loop (phase=implementing)" above — same code path, exit 2.

# --- Boundary + error cases ---

@test "empty status dir: allows stop (exit 0)" {
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "unknown phase value: allows stop (exit 0)" {
  printf '{"worktree":"%s","phase":"some_bogus_phase"}' "$WS" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "malformed status JSON: allows stop (exit 0), no crash" {
  printf 'not valid json {{{' > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

# --- Gate 2: gates ledger (.dev-loop/gates/*.md) ---

_write_unmet_ledger() { # <dir>
  mkdir -p "$1"
  cat > "$1/t1.md" <<'EOF'
- [ ] G1: tests pass
  CHECK: true
  EXPECT: ok
  EVIDENCE: pending
EOF
}

_write_met_ledger() { # <dir>
  mkdir -p "$1"
  cat > "$1/t1.md" <<'EOF'
- [x] G1: tests pass
  CHECK: true
  EXPECT: ok
  EVIDENCE: exit=0 matched: ok
EOF
}

@test "gates: unmet gate blocks with exit 2 and names it" {
  _write_unmet_ledger "$WS/.dev-loop/gates"
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
  [[ "$output" == *"UNMET"* ]]
  [[ "$output" == *"G1"* ]]
}

@test "gates: all met allows stop and clears counter state" {
  _write_met_ledger "$WS/.dev-loop/gates"
  printf '{"sessions":{"1":{"hash":"x","blocks":3}}}' > "$WS/.dev-loop/gate-hook-state.json"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
  [ ! -f "$WS/.dev-loop/gate-hook-state.json" ]
}

@test "gates: checked box with pending evidence (CLAIMED) blocks" {
  mkdir -p "$WS/.dev-loop/gates"
  cat > "$WS/.dev-loop/gates/t1.md" <<'EOF'
- [x] G1: claimed done
  CHECK: true
  EXPECT: ok
  EVIDENCE: pending
EOF
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
  [[ "$output" == *"CLAIMED"* ]]
}

@test "gates: malformed ledger blocks (an error is not completion)" {
  mkdir -p "$WS/.dev-loop/gates"
  printf '# just a title, no gates\n' > "$WS/.dev-loop/gates/t1.md"
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
}

@test "gates: abandoned-only ledger allows stop" {
  mkdir -p "$WS/.dev-loop/gates"
  cat > "$WS/.dev-loop/gates/t1.md" <<'EOF'
- [ ] G1: impossible
  EVIDENCE: pending
ABANDON: G1 upstream removed the API
EOF
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "gates: enforced even when stop_hook_active=true" {
  _write_unmet_ledger "$WS/.dev-loop/gates"
  run _run_gate "$WS" true
  [ "$status" -eq 2 ]
}

@test "gates: releases after 6 blocks without ledger progress" {
  _write_unmet_ledger "$WS/.dev-loop/gates"
  for i in 1 2 3 4 5 6; do
    run _run_gate "$WS" false
    [ "$status" -eq 2 ]
  done
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
  [[ "$output" == *"releasing"* ]]
}

@test "gates: ledger progress resets the no-progress counter" {
  _write_unmet_ledger "$WS/.dev-loop/gates"
  for i in 1 2 3; do run _run_gate "$WS" false; done
  # progress: the ledger content changes (a second gate appears)
  cat >> "$WS/.dev-loop/gates/t1.md" <<'EOF'
- [ ] G2: another outcome
  CHECK: true
  EXPECT: ok
  EVIDENCE: pending
EOF
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
  blocks=$(jq -r '.sessions | to_entries[0].value.blocks' "$WS/.dev-loop/gate-hook-state.json")
  [ "$blocks" -eq 1 ]
}

@test "gates: no gates dir keeps legacy behavior (exit 0, unmanaged)" {
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "gates: phase gate fires before ledger gate in a managed worktree" {
  printf '{"worktree":"%s","phase":"implementing"}' "$WS" > "$WS/.orchestration/status/t1.json"
  _write_unmet_ledger "$WS/.dev-loop/gates"
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
  [[ "$output" == *"phase=implementing"* ]]
}

# --- plan-gate ledgers (plan-A-*.md / plan-B-*.md, t1-plan-gate) ---
# gate-check.sh's --status/--run glob every *.md under .dev-loop/gates with
# no filename-prefix special-casing (verified by reading gate-check.sh and
# hooks/loop-gate.sh directly), so a plan-A-<feature>.md ledger produced by
# `plan-gate.sh emit` is expected to block/allow a Stop exactly like any
# existing task ledger — these two cases prove that unmodified behavior.

_write_unmet_plan_ledger() { # <dir>
  mkdir -p "$1"
  cat > "$1/plan-A-x.md" <<'EOF'
- [ ] baseline-tests-ran: tests pass
  CHECK: false
  EXPECT: ok
  EVIDENCE: pending
EOF
}

_write_met_plan_ledger() { # <dir>
  mkdir -p "$1"
  cat > "$1/plan-A-x.md" <<'EOF'
- [x] baseline-tests-ran: tests pass
  CHECK: true
  EXPECT: ok
  EVIDENCE: exit=0 matched: ok
EOF
}

@test "plan-gate ledger: UNMET plan-A-x.md blocks stop like any other ledger" {
  _write_unmet_plan_ledger "$WS/.dev-loop/gates"
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
  [[ "$output" == *"UNMET"* ]]
  [[ "$output" == *"plan-A-x.md:baseline-tests-ran"* ]]
}

@test "plan-gate ledger: all-MET plan-A-x.md allows stop like any other ledger" {
  _write_met_plan_ledger "$WS/.dev-loop/gates"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}
