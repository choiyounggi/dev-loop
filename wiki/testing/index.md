# testing — Domain Index

Route here for: writing or structuring automated tests — choosing the test
level, selecting cases and assertions, test data and isolation, mock/fake
decisions, fixing flaky tests, verifying tests can actually fail, validating a
check before its target exists, testing
async code (promises/timers/events), and browser E2E selector/wait/setup
strategy. Release-process quality (gates, manual testing, bug triage) →
wiki/qa/.

Match your situation to a "load when" line; load only matching pages.

## strategy

| Page | Load when |
|------|-----------|
| [differential-testing](strategy/differential-testing.md) | Two code paths must satisfy one specification and you want each to act as the other's oracle — interpreter vs compiled backend, a rewrite beside the service it replaces, v1 vs v2, a fast path beside a reference path, a cache beside its source; deciding which observable classes must agree and which the contract permits to differ; needing migration evidence beyond "the new one's own tests pass" |
| [import-time-side-effects](strategy/import-time-side-effects.md) | Unit-testing a pure function whose module runs real I/O at import (`init_db()`, client connect, app object at module scope); a test errors during collection instead of skipping; a module-level `skipif`/marker fails to prevent a DB connect; choosing between `importorskip`, module-level skip, and `collect_ignore` |
| [test-level-choice](strategy/test-level-choice.md) | Deciding at which level (unit/integration/e2e) to test new or changed behavior; reviewing a test plan's level distribution; logic buried in a controller or framework wiring needs coverage; a "pure" function's module runs I/O at import so its "unit" test needs a DB (and a function-level skip can't prevent it) |
| [signal-delivery-to-a-process-under-test](strategy/signal-delivery-to-a-process-under-test.md) | Testing a program's SIGINT/Ctrl-C shutdown path; a `kill -INT` on a `&`-backgrounded PID is silently ignored and `wait` hangs to the harness timeout; the signal test passes by hand in a terminal but hangs in CI; choosing between a shell script and a subprocess driver for delivering signals |

## quality

| Page | Load when |
|------|-----------|
| [completion-predicates](quality/completion-predicates.md) | Writing the "everything is done" condition a monitor, wait loop, or polling script uses to decide background work has finished; a monitor declared completion far sooner than the work could have finished; matching a status marker that contains regex metacharacters, or passing that pattern through wrapper/ssh/send-keys quoting layers; deciding completion by counting rather than by absence |
| [differential-run-agreement](quality/differential-run-agreement.md) | Two implementations of one spec were run on the same input and the harness reported agreement (EQUIVALENT / no diff / N-of-N checks pass) and you are about to cite it; the two sides model different amounts of state (one stubs out a repository, cache, clock, or session); choosing the input that forces an asymmetric dimension to decide the outcome |
| [guard-shape-vs-consequence](quality/guard-shape-vs-consequence.md) | A repo-wide guard asserting that no shipped artifact (example, config, migration, fixture) has a structural shape has gone red on a legitimate new artifact; authoring such a scanning guard; deciding between exempting an artifact, deleting the guard, and sharpening it; an existing guard has accumulated an exemption/allow list |
| [injected-clock-duration-assertions](quality/injected-clock-duration-assertions.md) | Asserting an elapsed duration between two readings of an injected/fake float clock (rate-limit interval, backoff, debounce, TTL); choosing that fake clock's start value; a single duration test fails on correct code by a margin in the far decimal places; choosing a comparison tolerance, or deciding between float seconds and integer nanoseconds |
| [write-path-assertions](quality/write-path-assertions.md) | Writing an HTTP-level test for an endpoint that persists something (form submit, create/update, onboarding step) and choosing what to assert beyond the status code; such a test is green while the records are empty or defaulted; sending repeated form fields from a client (httpx/TestClient) and deciding the `data=` shape |
| [minimum-case-set](quality/minimum-case-set.md) | Writing tests for a function/endpoint/change and choosing which cases to cover; reviewing whether coverage suffices; picking boundary values by input type; adding a regression test for a bug fix |
| [behavior-not-implementation](quality/behavior-not-implementation.md) | Deciding what a test should assert; a behavior-preserving refactor broke tests; tempted to expose privates for testing; deciding whether a snapshot test is appropriate |
| [tests-that-cannot-fail](quality/tests-that-cannot-fail.md) | Reviewing tests that always pass; a bug shipped through an area the suite reported as covered; auditing a suspiciously green suite; judging whether an assertion, error-path test, or mock-based test can actually detect a defect |
| [checks-that-cannot-pass](quality/checks-that-cannot-pass.md) | Authoring a check whose target does not exist yet (grep/regex gate on an unwritten file or doc section, lint/scan rule, schema assertion on an unbuilt endpoint, a plan's verification command) and it has only ever been observed failing; reviewing a plan's gates before adopting them; separating "target missing" from "content missing" in a gate's exit status |
| [spec-artifact-checks](quality/spec-artifact-checks.md) | Writing or reviewing an automated check that a mapping table covers every rule/field/enum case, or that ids resolve across documents; deciding whether a green check earned "verified" or only "present"; designing one negative control per check in a multi-check harness; parsing Markdown table rows programmatically in a doc-as-spec repo |
| [schema-additions-under-a-golden-gate](quality/schema-additions-under-a-golden-gate.md) | Adding a node kind, variant, discriminator value, or field to a document format (IR, JSON Schema, spec artifact) whose only automated gate builds its negatives by mutating one committed golden example; the gate or the whole suite comes back green right after a schema change; deciding which negative each new schema keyword needs, and whether a green suite that never loads the schema is evidence at all |
| [harness-reverse-controls](quality/harness-reverse-controls.md) | You built a harness that scores how well something is verified (mutation run, doc/spec gate suite, CI check matrix) and are about to cite its score in a commit, PR, README, or report; its verdicts come out uniform (every case caught, or every case green); deciding what control run proves the harness discriminates, how to score errored/never-ran cases, and what the harness's isolated working tree must contain |

## data

| Page | Load when |
|------|-----------|
| [artifact-leakage-from-a-suite](data/artifact-leakage-from-a-suite.md) | Temp directories, build outputs, or scratch files pile up in the repo or system temp after a suite runs; a clone grows with no obvious owner; you suspect the leak comes from everywhere and need a way to locate it; deciding between per-site cleanup, the runner's owned-temp API, and a static rule that enforces the convention |
| [test-data-and-isolation](data/test-data-and-isolation.md) | Tests need fixture data and you are choosing how to create it; tests pass alone but fail together (or vice versa); DB cleanup, shared fixtures, time-dependent logic, or unique-value collisions |

## mocking

| Page | Load when |
|------|-----------|
| [destructive-operations-on-shared-daemons](mocking/destructive-operations-on-shared-daemons.md) | The code under test enumerates and deletes a machine-wide daemon's resources by name/pattern (tmux sessions, docker containers, systemd units, namespaces) and that daemon runs on the test machine; proving a sweep deletes the targets and spares bystanders; keeping a scope bug from destroying the dev environment instead of failing the test; giving a shell script a substitution seam for the tool it shells out to |
| [what-to-mock](mocking/what-to-mock.md) | Deciding whether to mock/stub/fake a dependency or use the real one; mocks breaking on refactors; testing handling of a third-party's failure modes; the same mock setup is copy-pasted across tests |

## flaky

| Page | Load when |
|------|-----------|
| [diagnosing-flaky-tests](flaky/diagnosing-flaky-tests.md) | A test fails intermittently with no code change: on retry, in CI only, or only when run with other tests; deciding policy for a newly identified flaky test (quarantine vs retry) |

## async

| Page | Load when |
|------|-----------|
| [async-testing](async/async-testing.md) | Testing async code — promises, timers, retries, debounce, event-driven flows; the runner warns about assertions after completion or un-awaited promises; an async test intermittently interferes with the next test; deciding between fake timers and condition waits |

## e2e

| Page | Load when |
|------|-----------|
| [e2e-stability](e2e/e2e-stability.md) | Writing browser E2E tests (Playwright/Cypress-style); an E2E suite is flaky or slow; choosing selectors (role/label vs test id vs CSS), wait strategy, auth/data setup layer, or what to stub at the network edge |
