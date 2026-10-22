---
id: testing-flaky-e2e-failures-moving-under-host-cpu-contention
domain: testing
category: flaky
applies_to: [playwright, general]
confidence: field-tested
sources:
  - https://playwright.dev/docs/test-cli
  - https://playwright.dev/docs/ci
  - "Field observation 2026-10-18 (36-test Playwright e2e suite, macOS, shared agent host): load average 19 with another session's chrome-headless-shell at 110% CPU gave 1 failed at one spec, then 1 failed at a different spec; after 60 s with no other headless browser the same tree gave 36 passed"
last_verified: 2026-10-22
related: [testing-flaky-diagnosing-flaky-tests, testing-flaky-docker-vm-oversubscription-under-parallel-containers, testing-e2e-e2e-stability, debugging-concurrency-intermittent-failures]
---

# Browser E2E Failures That Move to a Different Test Each Run on a Busy Host

## When this applies

A parallel browser e2e suite fails one timing-dependent test per run — a
locator wait, or a screen the app shows for a fixed number of seconds — and a
different test fails on each re-run of the same tree, on a machine where other
sessions (other agents, another suite, another headless browser) run at the
same time.

## Do this

1. Measure the host before reading the failure as an app bug: `uptime` (load
   average against the core count from `sysctl -n hw.ncpu` or `nproc`) and
   the process list for headless browsers your run did not start
   (`pgrep -fl 'chrome-headless-shell|chromium|firefox|webkit'`).
2. Branch on what you measured:

| Case | Do |
|------|----|
| Load average above the core count, or a foreign headless browser using CPU | Wait until no foreign headless browser has run for 60 s, then re-run the same tree once |
| Host quiet and the failure still moves between tests | It is a test-level flake — [testing-flaky-diagnosing-flaky-tests] |
| The same test fails on every run | It is not contention — diagnose that test |

3. Report every run's runner summary line in order (`1 failed`, then
   `36 passed (50.9s)`), each with the load reading taken before it — not
   only the green run.
4. When other sessions share the host as a matter of course (an agent
   machine), lower the suite's own concurrency for gate runs
   (`playwright test --workers=N`) and pin that value in the gate command, so
   a gate is not decided by whatever else happens to be running.

## Edge cases

| Case | Then |
|------|------|
| The foreign headless browser is an orphan from your own earlier run | Stop it only after its parent process or working directory shows it is yours; when ownership is unclear, wait it out as in step 2 |
| The moving failure appears on a dedicated CI runner with no other sessions | The contention is inside the suite — lower `--workers`; Playwright's CI guide recommends 1 worker in CI for stability and reproducibility |
| The quiet re-run is red again on a different test | Contention is ruled out for that run — go to [testing-flaky-diagnosing-flaky-tests] with all run lines |
| Container-backed files fail with `409 ... is not running` or a start timeout | Memory ceiling, not CPU — [testing-flaky-docker-vm-oversubscription-under-parallel-containers] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Fix app code at whichever test failed this run | Measure host load and re-run once in a quiet window | The failing test changes with CPU scheduling, not with the code |
| Report only the green re-run | Report every run's runner line with its load reading | The red runs are evidence; hiding them makes a real flake look fixed |
| Raise every timeout in the spec | Remove the contention, or lower the suite's workers | Longer windows slow every run and still expire under heavier load |

## Sources

- https://playwright.dev/docs/test-cli — `--workers`: "Number of concurrent workers or percentage of logical CPU cores, use 1 to run in a single worker (default: 50%)" — the default sizes itself to the host's cores, not to what is free on them
- https://playwright.dev/docs/ci — recommends `workers: 1` in CI to prioritize stability and reproducibility, since tests run one at a time then get the full system resources (confirmed via web search of the official page on 2026-10-22; the page itself was not fetched in this run)
- Field observation 2026-10-18 (36-test Playwright e2e suite, macOS, shared agent host): load average 19 with another session's `chrome-headless-shell` at 110% CPU gave "1 failed" at `leave.spec.ts:37`, then "1 failed" at `game-bell.spec.ts:33` (a 5 s results-screen window and a 10 s locator wait); after 60 s with no other headless browser, the same tree gave "36 passed (50.9s)". One host, one suite — hence `field-tested`
