# testing — Domain Index

Route here for: writing or structuring automated tests — choosing the test
level, selecting cases and assertions, test data and isolation, mock/fake
decisions, fixing flaky tests, verifying tests can actually fail, validating a
check before its target exists, judging an agreement verdict from a differential
run, proving a completion predicate can report not-done, testing
async code (promises/timers/events), and browser E2E selector/wait/setup
strategy. Release-process quality (gates, manual testing, bug triage) →
wiki/qa/.

Match your situation to a "load when" line; load only matching pages.

## strategy

| Page | Load when |
|------|-----------|
| [test-level-choice](strategy/test-level-choice.md) | Deciding at which level (unit/integration/e2e) to test new or changed behavior; reviewing a test plan's level distribution; logic buried in a controller or framework wiring needs coverage |

## quality

| Page | Load when |
|------|-----------|
| [minimum-case-set](quality/minimum-case-set.md) | Writing tests for a function/endpoint/change and choosing which cases to cover; reviewing whether coverage suffices; picking boundary values by input type; adding a regression test for a bug fix |
| [behavior-not-implementation](quality/behavior-not-implementation.md) | Deciding what a test should assert; a behavior-preserving refactor broke tests; tempted to expose privates for testing; deciding whether a snapshot test is appropriate |
| [tests-that-cannot-fail](quality/tests-that-cannot-fail.md) | Reviewing tests that always pass; a bug shipped through an area the suite reported as covered; auditing a suspiciously green suite; judging whether an assertion, error-path test, or mock-based test can actually detect a defect |
| [checks-that-cannot-pass](quality/checks-that-cannot-pass.md) | Authoring a check whose target does not exist yet (grep/regex gate on an unwritten file or doc section, lint/scan rule, schema assertion on an unbuilt endpoint, a plan's verification command) and it has only ever been observed failing; reviewing a plan's gates before adopting them; separating "target missing" from "content missing" in a gate's exit status |
| [spec-artifact-checks](quality/spec-artifact-checks.md) | Writing or reviewing an automated check that a mapping table covers every rule/field/enum case, or that ids resolve across documents; deciding whether a green check earned "verified" or only "present"; designing one negative control per check in a multi-check harness; parsing Markdown table rows programmatically in a doc-as-spec repo |
| [harness-reverse-controls](quality/harness-reverse-controls.md) | You built a harness that scores how well something is verified (mutation run, doc/spec gate suite, CI check matrix) and are about to cite its score in a commit, PR, README, or report; its verdicts come out uniform (every case caught, or every case green); deciding what control run proves the harness discriminates, how to score errored/never-ran cases, what the harness's isolated working tree must contain, and which seam a monkeypatched deliberate-fault control must target so it is actually reached |
| [differential-run-agreement](quality/differential-run-agreement.md) | Two implementations of one spec were run on the same input and the harness reported agreement (EQUIVALENT / no diff / N-of-N checks pass) and you are about to cite it; the two sides model different amounts of state (one stubs out a repository, cache, clock, or session); choosing the input that forces an asymmetric dimension to decide the outcome, and how to report the two verdicts |
| [completion-predicates](quality/completion-predicates.md) | Writing the "everything is done" condition a monitor, wait loop, or polling script uses to decide background work has finished; a monitor declared completion far sooner than the work could have finished; matching a status marker that contains regex metacharacters, or passing that pattern through wrapper/ssh/send-keys quoting layers; deciding completion by counting rather than by absence |

## data

| Page | Load when |
|------|-----------|
| [test-data-and-isolation](data/test-data-and-isolation.md) | Tests need fixture data and you are choosing how to create it; tests pass alone but fail together (or vice versa); DB cleanup, shared fixtures, time-dependent logic, or unique-value collisions; a fixture file must carry the executable bit, or must live somewhere endpoint security and `git status` both tolerate |

## mocking

| Page | Load when |
|------|-----------|
| [what-to-mock](mocking/what-to-mock.md) | Deciding whether to mock/stub/fake a dependency or use the real one; mocks breaking on refactors; testing handling of a third-party's failure modes; the same mock setup is copy-pasted across tests |

## flaky

| Page | Load when |
|------|-----------|
| [diagnosing-flaky-tests](flaky/diagnosing-flaky-tests.md) | A test fails intermittently with no code change: on retry, in CI only, or only when run with other tests; deciding policy for a newly identified flaky test (quarantine vs retry) |

## async

| Page | Load when |
|------|-----------|
| [async-testing](async/async-testing.md) | Testing async code — promises, timers, retries, debounce, event-driven flows; the runner warns about assertions after completion or un-awaited promises; an async test intermittently interferes with the next test; deciding between fake timers and condition waits; driving a stream-consuming reader (readline prompts, a line-delimited protocol) from an in-memory test double, and a stream-fed test that hangs after the first record |

## e2e

| Page | Load when |
|------|-----------|
| [e2e-stability](e2e/e2e-stability.md) | Writing browser E2E tests (Playwright/Cypress-style); an E2E suite is flaky or slow; choosing selectors (role/label vs test id vs CSS), wait strategy, auth/data setup layer, or what to stub at the network edge |
