---
id: testing-mocking-destructive-operations-on-shared-daemons
domain: testing
category: mocking
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/mocksArentStubs.html
  - https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap08.html
last_verified: 2026-08-05
related: [testing-mocking-what-to-mock, testing-data-test-data-and-isolation, testing-quality-tests-that-cannot-fail, platforms-environment-path-resolution]
---

# Testing Code That Bulk-Deletes Resources from a Machine-Wide Daemon

## When this applies

The code under test enumerates a shared daemon's resources by name or pattern
(tmux sessions, docker containers, systemd units, k8s namespaces, cron entries)
and deletes the matches — and that daemon is running on the machine executing the
test, holding the developer's own resources and often the test runner's session.

## Do this

1. **Never point this test at the real daemon.** The pattern-scope bug is exactly
   what the test exists to catch, and its first manifestation deletes the
   developer's live resources instead of producing a failure report. The failure
   arrives as a destroyed environment, not as a red test.

2. **Inject a recording fake ahead of the real binary on `PATH`** and run the
   script with that `PATH`. The fake answers the enumeration call with fixture
   names and appends every destructive call to a log file:

   ```sh
   # fakebin/tmux
   case "$1" in
     list-sessions) printf '%s\n' "run-1" "run-2" "mydev" ;;
     kill-session)  shift; echo "KILL $2" >> "$FAKE_LOG" ;;
   esac
   ```

3. **Keep `PATH` usable as the seam.** The script under test must resolve the tool
   at call time — a bare `tmux`, or `TOOL="$(command -v tmux)"` evaluated inside the
   function. A hardcoded absolute path removes the seam; when the path must be
   absolute, read it from one env var the test overrides
   ([platforms-environment-path-resolution]).

4. **Assert both directions.** The log contains exactly the intended targets, *and*
   contains none of the bystanders. Put a realistic bystander in the fixture list —
   a name shaped like the developer's own sessions — because the scope bug shows up
   as an extra line, not a missing one.

5. **Include a deletes-nothing case.** Run the sweep with a pattern that matches no
   fixture and assert the log is empty. Without it, a fake that silently fails to
   record makes every "no bystanders" assertion vacuous
   ([testing-quality-tests-that-cannot-fail]).

## Edge cases

| Case | Then |
|------|------|
| The script calls the daemon for setup as well as deletion | The fake implements the read subcommands as fixtures too, so one binary serves both; keep the fixture list in the test, not in the fake |
| A test genuinely needs the real daemon (integration coverage of the daemon's own behaviour) | Give its resources a dedicated prefix the sweep pattern provably cannot match, and assert that non-match in the test itself before the destructive call runs |
| CI has no daemon installed at all | The fake is the only way this code is covered there — keep the fake test at unit level so coverage does not depend on the runner's environment |
| The script builds the deletion list and the deletion in one pipeline | Split enumeration from deletion into two functions so the scope decision is testable without any deletion call at all |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run the sweep against the real daemon with "harmless" test resources | Inject a recording fake on `PATH` and assert its log | The bug under test is the pattern matching too much, so its first occurrence takes the resources you did not list — including the runner's own session |
| Assert only that the intended targets were deleted | Assert the bystanders' absence from the same log | Over-deletion is invisible to a test that only checks the targets are gone |
| Guard the real run with a dry-run flag and eyeball the output | Make the fake's log the assertion subject | A human reading output is not a gate; a diffed log is, and it runs on every commit |
| Trust an empty kill log as proof of correct scoping | Add a positive case that produces a non-empty log with the same fake | An empty log is also what a broken fake produces |

## Sources

- https://martinfowler.com/articles/mocksArentStubs.html — fakes as working implementations with a shortcut; recording interactions to verify outbound commands rather than resulting state
- https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap08.html — `PATH` is searched left to right for a command name containing no slash, which is what makes a prepended directory a substitution seam
- Field context (2026-08-05, verified by reproduction): with a fake `tmux` prepended to `PATH`, a prefix sweep over the fixture list `run-1, run-2, mydev` logged exactly `KILL run-1` / `KILL run-2`, zero bystander lines, and an empty log for a non-matching prefix — while the machine's eight real tmux sessions, three of which matched the pattern under test, were untouched
