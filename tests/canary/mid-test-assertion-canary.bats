#!/usr/bin/env bats
# Negative control: this file must FAIL.
#
# It proves the harness can still detect a mid-test `[[ ]]` assertion failure
# (issue #114) — a checker's own report is not evidence it works until it has
# been shown to fail on something (wiki/testing/quality/checks-that-cannot-pass.md).
# CI runs this file inverted (must-fail) on both matrix legs
# (wiki/testing/quality/harness-reverse-controls.md). It lives outside
# `tests/` so the default `bats tests/` run never picks it up — bats does not
# recurse without `-r`.

@test "deliberately FALSE mid-test assertion must fail the file (issue #114)" {
  [[ "a" == "b" ]]
  true
}
