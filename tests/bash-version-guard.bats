#!/usr/bin/env bats
# Guard: refuse to run silently under bash < 4.
#
# macOS ships bash 3.2, which does not honor `set -e` (or an assertion's exit
# status) inside a mid-test `[[ ]]` — only the test function's LAST command
# decides the verdict, so an earlier failed `[[ ]]` is silently swallowed
# (issue #114). Rather than rewrite every existing mid-test assertion (the
# mechanical sweep, out of scope here), this guard makes the suite fail loudly
# with a clear name when it is ever run under bash 3.2 again, instead of
# quietly passing. This @test's ONLY command is its final command, so the
# guard itself is honest even on bash 3.2 (wiki/testing/quality/tests-that-cannot-fail.md).

@test "bats runs under bash >= 4 (bash 3.2 masks mid-test assertion failures — issue #114)" {
  [ "${BASH_VERSINFO[0]}" -ge 4 ]
}
