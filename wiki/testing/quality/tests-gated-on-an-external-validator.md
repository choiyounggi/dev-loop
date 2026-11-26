---
id: testing-quality-tests-gated-on-an-external-validator
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://github.com/pytest-dev/pytest/issues/1364
  - https://docs.python.org/3/library/unittest.html#skipping-tests-and-expected-failures
  - https://github.com/yannh/kubeconform
last_verified: 2026-11-26
related: [testing-quality-tests-that-cannot-fail, debugging-methodology-hiding-a-tool-to-reproduce-its-absent-branch, testing-quality-history-dependent-checks-on-shallow-clones, qa-process-release-gates]
---

# Tests Gated on an External Validator (Docker, CLI) That May Be Absent

## When this applies

A unit test hands generated output (Kubernetes manifests, JSON/OpenAPI documents,
config files) to an external validator that only some machines have — a pinned
Docker image (`kubeconform`), a CLI on `PATH` — and the test must skip where the
tool is missing without becoming a skip, or an always-"valid" result, on every
machine including CI.

## Do this

1. **Guard on the whole dependency chain, with a timeout.** Check the binary
   (`shutil.which("docker")`) AND that the daemon answers (`docker info` with a
   subprocess timeout, non-zero exit or timeout → unavailable). A Docker CLI with
   a stopped daemon passes the first check alone.
2. **Skip with a reason that names what is missing and the pinned tool** —
   `self.skipTest("docker unavailable; needs ghcr.io/yannh/kubeconform:v0.6.7")` —
   so a skip line in the log says what was not checked.
3. **Add an opt-in strict switch that turns the skip into a failure.** One env
   var (`<PROJECT>_REQUIRE_<TOOL>=1`): when set, call `self.fail(...)` /
   `pytest.fail(...)` with the same message instead of skipping. Set it in the CI
   job that is supposed to run the validator; leave it unset for local runs.
4. **Pair the "valid" case with a known-bad document** asserted to be rejected:
   exit code 1 and the validator's own rejection count (`Invalid: 1` in
   kubeconform's `-summary` line), plus the field it names (e.g. a missing
   required property). This proves the validator really runs and can say no.
5. **Prove the absent branch before merging.** Run once with the tool hidden
   (`PATH=/usr/bin:/bin`, see the related page on hiding a tool) and require the
   runner to report the skips (`OK (skipped=N)`); run again with the strict
   variable set and require those same tests to FAIL.

| Run | Required result |
|-----|-----------------|
| Tool present | Valid stream passes; known-bad document rejected (rc 1, `Invalid: 1`) |
| Tool hidden, strict var unset | Tests reported as skipped, with the reason |
| Tool hidden, strict var set | Same tests reported as failures |

## Edge cases

| Case | Then |
|------|------|
| The daemon is reachable but slow or wedged | The `docker info` timeout returns "unavailable" instead of hanging the suite; with the strict var set it fails fast |
| The validator treats unknown kinds as skipped (`-ignore-missing-schemas`) | Assert the summary's `Skipped:` count as well; a stream where every resource was skipped exits 0 with nothing validated |
| `docker info` fails because the user cannot open the socket (permission denied) | Same as absent — the test cannot run the image; the skip reason should quote the stderr line so the cause is visible |
| A CI runner has no Docker on purpose | Exclude that test file from that job explicitly instead of leaving the strict var unset there; then a missing Docker on the job that should have it stays red |
| pytest instead of unittest | Same shape: a marker or `conftest.py` fixture that calls `pytest.fail` when the strict var is set and `pytest.skip` otherwise (pytest maintainer suggestion in issue #1364) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read a green run as "manifests are valid" | Check the run's skip count and the known-bad case's result | A skipped test and a passed test both leave the suite green |
| Assert only that valid input passes | Also feed a known-bad document and require rejection | A validator that is not invoked, or that accepts everything, passes every valid-input test |
| Guard with `shutil.which("docker")` alone | Also run `docker info` with a timeout | The CLI can be installed while the daemon is stopped |
| Make the test always fail when the tool is missing | Skip by default and fail under the strict env var | Contributors without Docker can still run the suite; CI still cannot go green without the validator |

## Sources

- https://github.com/pytest-dev/pytest/issues/1364 — pytest maintainer (nicoddemus): "If you want the test to fail if a dependency is not installed then you shouldn't be using skip"; suggests "an explicit mark … handle that in a `conftest.py` file … Such mark would skip the test locally, but fail when running in the CI"
- https://docs.python.org/3/library/unittest.html#skipping-tests-and-expected-failures — `skipTest(reason)` skips the current test and records the reason; `fail(msg)` "Signals a test failure unconditionally"; skipped tests appear as `OK (skipped=N)` in the summary
- https://github.com/yannh/kubeconform — `-summary` prints `Summary: … - Valid: N, Invalid: N, Errors: N Skipped: N`; README examples show exit status 1 for an invalid file and 0 for a valid one; images published at `ghcr.io/yannh/kubeconform`
- Field evidence 2026-10-29 (a Python service repo validating rendered Kubernetes manifests with pinned kubeconform v0.6.7 via Docker): valid stream `Valid: 19, Invalid: 0`; a known-bad HPA gave rc 1 with `missing properties: 'maxReplicas'`; with `PATH=/usr/bin:/bin` the suite reported `OK (skipped=2)`; with the strict env var set the same two tests FAILED
