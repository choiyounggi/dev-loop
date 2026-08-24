#!/usr/bin/env bats
# Tests for skills/loop-implement/scripts/gate-check.sh (gates-ledger checker).
# Covers normal (met/run), error (parse, failing CHECK), and boundary cases
# (CLAIMED evidence, ABANDON, timeout, empty ledger).

setup() {
  GC="${BATS_TEST_DIRNAME}/../skills/loop-implement/scripts/gate-check.sh"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

_write_ledger() { # <file> <content...>
  printf '%s\n' "$2" > "$1"
}

# ---------- usage / parse errors (exit 2) ----------

@test "no mode: usage error exit 2" {
  run bash "$GC"
  [ "$status" -eq 2 ]
}

@test "missing file: exit 2" {
  run bash "$GC" --status "$WORK/absent.md"
  [ "$status" -eq 2 ]
}

@test "ledger with no gates: parse error exit 2" {
  printf '# Gates: t1\n\nScope: nothing\n' > g.md
  run bash "$GC" --status g.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"no gates found"* ]]
}

@test "CHECK without EXPECT: parse error exit 2" {
  cat > g.md <<'EOF'
- [ ] G1: builds
  CHECK: true
  EVIDENCE: pending
EOF
  run bash "$GC" --status g.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"both CHECK and EXPECT"* ]]
}

@test "duplicate gate id: parse error exit 2" {
  cat > g.md <<'EOF'
- [ ] G1: a
  EVIDENCE: pending
- [ ] G1: b
  EVIDENCE: pending
EOF
  run bash "$GC" --status g.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"duplicate id G1"* ]]
}

@test "ABANDON with blank reason: parse error exit 2" {
  cat > g.md <<'EOF'
- [ ] G1: a
  EVIDENCE: pending
ABANDON: G1
EOF
  run bash "$GC" --status g.md
  [ "$status" -eq 2 ]
}

@test "ABANDON referencing unknown gate: parse error exit 2" {
  cat > g.md <<'EOF'
- [ ] G1: a
  EVIDENCE: pending
ABANDON: G9 impossible on this platform
EOF
  run bash "$GC" --status g.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown gate G9"* ]]
}

# ---------- --status states ----------

@test "unchecked gate: UNMET, exit 1" {
  cat > g.md <<'EOF'
- [ ] G1: tests pass
  CHECK: true
  EXPECT: ok
  EVIDENCE: pending
EOF
  run bash "$GC" --status g.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNMET g.md:G1"* ]]
}

@test "checked box with pending evidence: CLAIMED, exit 1" {
  cat > g.md <<'EOF'
- [x] G1: tests pass
  CHECK: true
  EXPECT: ok
  EVIDENCE: pending
EOF
  run bash "$GC" --status g.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"CLAIMED g.md:G1"* ]]
}

@test "checked with real evidence: MET, exit 0" {
  cat > g.md <<'EOF'
- [x] G1: tests pass
  CHECK: true
  EXPECT: ok
  EVIDENCE: exit=0 matched: ok
EOF
  run bash "$GC" --status g.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"MET g.md:G1"* ]]
  [[ "$output" == *"SUMMARY met=1 unmet=0 abandoned=0"* ]]
}

@test "abandoned gate is excluded from unmet: exit 0" {
  cat > g.md <<'EOF'
- [ ] G1: impossible thing
  EVIDENCE: pending
ABANDON: G1 upstream API removed the endpoint
EOF
  run bash "$GC" --status g.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"ABANDONED g.md:G1"* ]]
}

@test "--status never executes CHECK commands" {
  cat > g.md <<'EOF'
- [ ] G1: side effect probe
  CHECK: touch executed.flag
  EXPECT: nothing
  EVIDENCE: pending
EOF
  run bash "$GC" --status g.md
  [ ! -e executed.flag ]
}

# ---------- --run execution ----------

@test "--run: passing CHECK with EXPECT match ticks box and writes evidence" {
  cat > g.md <<'EOF'
- [ ] G1: echo works
  CHECK: echo ALL-PASS
  EXPECT: ALL-PASS
  EVIDENCE: pending
EOF
  run bash "$GC" --run g.md
  [ "$status" -eq 0 ]
  grep -q '^- \[x\] G1:' g.md
  grep -q 'EVIDENCE: exit=0 matched: ALL-PASS' g.md
}

@test "--run: failing CHECK stays unchecked with failure evidence, exit 1" {
  cat > g.md <<'EOF'
- [ ] G1: command fails
  CHECK: sh -c 'echo boom; exit 3'
  EXPECT: ALL-PASS
  EVIDENCE: pending
EOF
  run bash "$GC" --run g.md
  [ "$status" -eq 1 ]
  grep -q '^- \[ \] G1:' g.md
  grep -q 'EVIDENCE: exit=3' g.md
}

@test "--run: exit 0 but EXPECT missing counts unmet (no-match)" {
  cat > g.md <<'EOF'
- [ ] G1: wrong token
  CHECK: echo something-else
  EXPECT: ALL-PASS
  EVIDENCE: pending
EOF
  run bash "$GC" --run g.md
  [ "$status" -eq 1 ]
  grep -q 'EVIDENCE: no-match' g.md
}

@test "--run: re-verify demotes a previously ticked gate whose CHECK now fails" {
  cat > g.md <<'EOF'
- [x] G1: regressed
  CHECK: false
  EXPECT: ok
  EVIDENCE: exit=0 matched: ok
EOF
  run bash "$GC" --run g.md
  [ "$status" -eq 1 ]
  grep -q '^- \[ \] G1:' g.md
}

@test "--run: manual gate is never auto-run or modified" {
  cat > g.md <<'EOF'
- [ ] G1: reviewed the screenshots by eye
  EVIDENCE: pending
EOF
  run bash "$GC" --run g.md
  [ "$status" -eq 1 ]
  grep -q '^- \[ \] G1:' g.md
  grep -q 'EVIDENCE: pending' g.md
}

@test "--run: timeout is recorded as timeout evidence" {
  cat > g.md <<'EOF'
- [ ] G1: hangs
  CHECK: sleep 5
  EXPECT: never
  EVIDENCE: pending
EOF
  GATE_CHECK_TIMEOUT=1 run bash "$GC" --run g.md
  [ "$status" -eq 1 ]
  grep -q 'timeout after 1s' g.md
}

@test "--run: multiple files aggregate into one summary" {
  cat > a.md <<'EOF'
- [ ] G1: ok
  CHECK: echo PASS-A
  EXPECT: PASS-A
  EVIDENCE: pending
EOF
  cat > b.md <<'EOF'
- [ ] G1: fails
  CHECK: false
  EXPECT: PASS-B
  EVIDENCE: pending
EOF
  run bash "$GC" --run a.md b.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"MET a.md:G1"* ]]
  [[ "$output" == *"UNMET b.md:G1"* ]]
  [[ "$output" == *"SUMMARY met=1 unmet=1 abandoned=0"* ]]
}
