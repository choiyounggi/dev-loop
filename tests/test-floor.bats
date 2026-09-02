#!/usr/bin/env bats
# Tests for test-floor.sh — the mechanical pre-gate in front of the
# test-quality-auditor (issue #107). It judges only the countable half of
# test quality: tests exist, >=3 cases per NEW test file, >=1 assertion per
# case. It never executes tests and never writes files.
#
# Fixture bats files are built via a single $'...' assignment, not a heredoc:
# bats' own test-discovery preprocessor scans every source line for a leading
# `@test`, so a heredoc body containing literal `@test "..." {` lines is
# misparsed as additional top-level tests in THIS file, corrupting the
# fixture written to disk. Keeping the whole fixture on one source line (via
# ANSI-C `$'...'` escapes) means no line in test-floor.bats itself starts
# with `@test` except real test declarations.

bats_require_minimum_version 1.5.0

setup() {
  TF="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/test-floor.sh"
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email "test-floor@test.local"
  git -C "$REPO" config user.name "test-floor"
  echo "base" > "$REPO/base.txt"
  git -C "$REPO" add base.txt
  git -C "$REPO" commit -q -m base
}

commit() { # $1 = commit message; commits whatever is currently staged/dirty
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "$1"
}

@test "source-only diff, no tests -> exit 3 fail, stderr no-tests" {
  printf '#!/bin/sh\necho hi\n' > "$REPO/app.sh"
  commit "add app.sh"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 3 ]
  [ "$output" = "fail" ]
  [[ "$stderr" == *"no-tests"* ]]
}

@test "new bats file with only 2 cases -> exit 3 fail, stderr case-count:<file>:2" {
  two_bats=$'@test "case one" {\n  run echo hi\n  [ "$status" -eq 0 ]\n}\n\n@test "case two" {\n  [ 1 -eq 1 ]\n}\n'
  printf '%s' "$two_bats" > "$REPO/two.bats"
  commit "add two.bats"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 3 ]
  [ "$output" = "fail" ]
  [[ "$stderr" == *"case-count:two.bats:2"* ]]
}

@test "new bats file, 3 cases, one bodiless -> exit 3 fail, stderr no-assertion names that case" {
  three_bats=$'@test "case one" {\n  run echo hi\n  [ "$status" -eq 0 ]\n}\n\n@test "case two" {\n  [ 1 -eq 1 ]\n}\n\n@test "case three empty" {\n  true\n}\n'
  printf '%s' "$three_bats" > "$REPO/three.bats"
  commit "add three.bats"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 3 ]
  [ "$output" = "fail" ]
  [[ "$stderr" == *"no-assertion:three.bats:case three empty"* ]]
}

@test "passing diff: source change + new bats with 3 asserting cases -> exit 0 pass" {
  printf '#!/bin/sh\necho hi\n' > "$REPO/app.sh"
  app_bats=$'@test "case one" {\n  run echo hi\n  [ "$status" -eq 0 ]\n}\n\n@test "case two" {\n  [ 1 -eq 1 ]\n}\n\n@test "case three" {\n  run echo bye\n  assert_success\n}\n'
  printf '%s' "$app_bats" > "$REPO/app.bats"
  commit "add app.sh + app.bats"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 0 ]
  [ "$output" = "pass" ]
}

@test "unknown framework: source change + new tests/foo.exotic -> exit 2 unknown" {
  printf '#!/bin/sh\necho hi\n' > "$REPO/app.sh"
  mkdir -p "$REPO/tests"
  echo "not a recognized framework" > "$REPO/tests/foo.exotic"
  commit "add app.sh + tests/foo.exotic"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 2 ]
  [ "$output" = "unknown" ]
}

@test "jest: new .test.js with 3 expect() cases -> exit 0 pass" {
  cat > "$REPO/app.test.js" <<'EOF'
it('one', () => {
  expect(1).toBe(1);
});

it('two', () => {
  expect(2).toBe(2);
});

it('three', () => {
  expect(3).toBe(3);
});
EOF
  commit "add app.test.js"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 0 ]
  [ "$output" = "pass" ]
}

@test "jest: new .test.js with one bodiless case -> exit 3 fail, stderr no-assertion" {
  cat > "$REPO/app.test.js" <<'EOF'
it('one', () => {
  expect(1).toBe(1);
});

it('two', () => {
  expect(2).toBe(2);
});

it('three empty', () => {
  doSomething();
});
EOF
  commit "add app.test.js"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 3 ]
  [ "$output" = "fail" ]
  [[ "$stderr" == *"no-assertion:app.test.js:three empty"* ]]
}

@test "pytest: new test_app.py with 3 asserting cases -> exit 0 pass" {
  cat > "$REPO/test_app.py" <<'EOF'
def test_one():
    assert 1 == 1

def test_two():
    assert 2 == 2

def test_three():
    assert 3 == 3
EOF
  commit "add test_app.py"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 0 ]
  [ "$output" = "pass" ]
}

@test "pytest: new test_app.py with one bodiless case -> exit 3 fail, stderr no-assertion" {
  cat > "$REPO/test_app.py" <<'EOF'
def test_one():
    assert 1 == 1

def test_two():
    assert 2 == 2

def test_three_empty():
    pass
EOF
  commit "add test_app.py"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 3 ]
  [ "$output" = "fail" ]
  [[ "$stderr" == *"no-assertion:test_app.py:test_three_empty"* ]]
}

@test "go: new app_test.go with 3 asserting cases -> exit 0 pass" {
  cat > "$REPO/app_test.go" <<'EOF'
func TestOne(t *testing.T) {
	if 1 != 1 {
		t.Error("fail")
	}
}

func TestTwo(t *testing.T) {
	require.Equal(t, 1, 1)
}

func TestThree(t *testing.T) {
	assert.Equal(t, 1, 1)
}
EOF
  commit "add app_test.go"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 0 ]
  [ "$output" = "pass" ]
}

@test "go: new app_test.go with one bodiless case -> exit 3 fail, stderr no-assertion" {
  cat > "$REPO/app_test.go" <<'EOF'
func TestOne(t *testing.T) {
	if 1 != 1 {
		t.Error("fail")
	}
}

func TestTwo(t *testing.T) {
	require.Equal(t, 1, 1)
}

func TestThreeEmpty(t *testing.T) {
	doSomething()
}
EOF
  commit "add app_test.go"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 3 ]
  [ "$output" = "fail" ]
  [[ "$stderr" == *"no-assertion:app_test.go:TestThreeEmpty"* ]]
}

@test "doc-only diff -> exit 0 pass (vacuous floor)" {
  echo "# hello" > "$REPO/README.md"
  commit "add README.md"
  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 0 ]
  [ "$output" = "pass" ]
}

@test "bad range -> exit 4, empty stdout" {
  run --separate-stderr sh "$TF" "$REPO" "not-a-ref...HEAD"
  [ "$status" -eq 4 ]
  [ "$output" = "" ]
}

@test "bad repo-dir -> exit 4, empty stdout" {
  run --separate-stderr sh "$TF" "${BATS_TEST_TMPDIR}/no-such-repo" "HEAD~1..HEAD"
  [ "$status" -eq 4 ]
  [ "$output" = "" ]
}

@test "modified (not new) pre-existing test file with 1 case -> exempt, exit 0" {
  existing_v1=$'@test "already here" {\n  [ 1 -eq 1 ]\n}\n'
  printf '%s' "$existing_v1" > "$REPO/existing.bats"
  commit "add existing.bats"

  printf '#!/bin/sh\necho hi\n' > "$REPO/app.sh"
  existing_v2=$'@test "already here, tweaked" {\n  [ 1 -eq 1 ]\n}\n'
  printf '%s' "$existing_v2" > "$REPO/existing.bats"
  commit "modify app.sh + existing.bats"

  run --separate-stderr sh "$TF" "$REPO" "HEAD~1..HEAD"
  [ "$status" -eq 0 ]
  [ "$output" = "pass" ]
}

@test "committed empty range HEAD...HEAD -> exit 2 unknown, stderr empty-range:" {
  run --separate-stderr sh "$TF" "$REPO" "HEAD...HEAD"
  [ "$status" -eq 2 ]
  [ "$output" = "unknown" ]
  [[ "$stderr" == *"empty-range:HEAD...HEAD"* ]]
}

@test "working-tree mode: tracked source edit + untracked new bats with 3 asserting cases -> exit 0 pass" {
  printf '#!/bin/sh\necho hi\n' > "$REPO/app.sh"
  commit "add app.sh"
  printf '#!/bin/sh\necho bye\n' > "$REPO/app.sh"
  wt_bats=$'@test "case one" {\n  run echo hi\n  [ "$status" -eq 0 ]\n}\n\n@test "case two" {\n  [ 1 -eq 1 ]\n}\n\n@test "case three" {\n  run echo bye\n  assert_success\n}\n'
  printf '%s' "$wt_bats" > "$REPO/app.bats"
  run --separate-stderr sh "$TF" "$REPO" "HEAD"
  [ "$status" -eq 0 ]
  [ "$output" = "pass" ]
}

@test "working-tree mode: tracked source edit, no test files anywhere -> exit 3 fail, stderr no-tests" {
  printf '#!/bin/sh\necho hi\n' > "$REPO/app.sh"
  commit "add app.sh"
  printf '#!/bin/sh\necho bye\n' > "$REPO/app.sh"
  run --separate-stderr sh "$TF" "$REPO" "HEAD"
  [ "$status" -eq 3 ]
  [ "$output" = "fail" ]
  [[ "$stderr" == *"no-tests"* ]]
}

@test "working-tree mode: untracked new bats with only 2 cases -> exit 3 fail, stderr case-count:<file>:2" {
  wt_two_bats=$'@test "case one" {\n  run echo hi\n  [ "$status" -eq 0 ]\n}\n\n@test "case two" {\n  [ 1 -eq 1 ]\n}\n'
  printf '%s' "$wt_two_bats" > "$REPO/wt-two.bats"
  run --separate-stderr sh "$TF" "$REPO" "HEAD"
  [ "$status" -eq 3 ]
  [ "$output" = "fail" ]
  [[ "$stderr" == *"case-count:wt-two.bats:2"* ]]
}

@test "working-tree mode: clean worktree, single-ref HEAD -> exit 2 unknown, stderr empty-range:" {
  run --separate-stderr sh "$TF" "$REPO" "HEAD"
  [ "$status" -eq 2 ]
  [ "$output" = "unknown" ]
  [[ "$stderr" == *"empty-range:HEAD"* ]]
}

@test "wiring: SKILL.md Phase 4 invokes test-floor.sh with the single-ref working-tree form" {
  skill_md="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  run grep -n "test-floor.sh <wt> '<integ>'" "$skill_md"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
