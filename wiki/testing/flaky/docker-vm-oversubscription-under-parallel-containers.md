---
id: testing-flaky-docker-vm-oversubscription-under-parallel-containers
domain: testing
category: flaky
applies_to: [vitest, jest, playwright, testcontainers, docker]
confidence: field-tested
sources:
  - https://vitest.dev/config/maxworkers
  - https://jestjs.io/docs/cli#--maxworkersnumstring
  - https://playwright.dev/docs/test-cli
  - "Field reproduction 2026-10-12 (linkly-invitation, Vitest 5 + @testcontainers/postgresql on macOS Docker Desktop, docker info 8 CPUs / 4 GB): three full runs at one commit each failed only on DB-backed files, a different subset each time (2, then 1, then 4); --maxWorkers=4 passed 126/126 files"
last_verified: 2026-10-12
related: [testing-flaky-diagnosing-flaky-tests, testing-data-testcontainers-reaper-on-docker-desktop-macos, testing-data-test-data-and-isolation]
---

# Container-Backed Test Files Failing in a Different Subset Each Run

## When this applies

A suite whose test files each start their own service container (Testcontainers,
docker-compose per file) fails on a different subset of those container/DB-backed
files on every full run, with a container error (`HTTP code 409 ... is not
running`, a container start or connect timeout) instead of an assertion failure,
while each failing file passes when run alone.

## Do this

1. Treat it as a resource ceiling first, not as a test defect. The runner's
   default worker count follows the host's cores (Vitest: available
   parallelism; Jest: cores minus one; Playwright: 50% of logical cores), so a
   many-core host starts that many containers at once inside a Docker VM sized
   independently of the host.
2. Compare the Docker VM's memory (`docker info`: `Total Memory`) against
   worker count x per-container memory.
3. Lower the worker cap and re-run the whole suite until it is green on
   repeated runs:

| Runner | Cap |
|--------|-----|
| Vitest | `vitest run --maxWorkers=N` (or `maxWorkers` in config) |
| Jest | `jest --maxWorkers=N` |
| Playwright Test | `playwright test --workers=N` |

4. Pin the cap in every full-suite gate command (CI script, pre-merge gate,
   package script), so the gate runs with the same concurrency that was proven
   green. The file set and test counts stay the same; only how many containers
   run at once drops.

## Edge cases

| Case | Then |
|------|------|
| The failures stay on the same file(s) at any worker cap | It is not oversubscription — diagnose the test itself ([testing-flaky-diagnosing-flaky-tests]) |
| 0 tests run and the error is a Ryuk / Docker socket mount failure on macOS Docker Desktop | Different cause — [testing-data-testcontainers-reaper-on-docker-desktop-macos] |
| A cap low enough to be green makes the suite too slow | Raise the Docker VM's memory limit (Docker Desktop settings) and re-measure the cap, or share one container across files instead of one per file |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Retry or quarantine a DB/container test that fails on a different file each run | Cap the runner's worker count to the Docker VM's memory and re-run the whole suite | The tests are correct; the VM was oversubscribed, so a retry only reshuffles which files lose their container |

## Sources

- https://vitest.dev/config/maxworkers — `maxWorkers` caps concurrent worker processes; it accepts a number or a percentage string, and with watch mode off it defaults to the host's available parallelism (halved in watch mode)
- https://jestjs.io/docs/cli#--maxworkersnumstring — "Specifies the maximum number of workers the worker-pool will spawn for running tests. In single run mode, this defaults to the number of the cores available on your machine minus one for the main thread"
- https://playwright.dev/docs/test-cli — `--workers`: "Number of concurrent workers or percentage of logical CPU cores, use 1 to run in a single worker (default: 50%)"
- Field reproduction 2026-10-12 (linkly-invitation, Vitest 5 + `@testcontainers/postgresql` on macOS Docker Desktop, `docker info` 8 CPUs / 4 GB): three `pnpm test` runs at one commit each failed only on DB-backed files, a different subset each time (2, then 1, then 4), with `HTTP code 409 ... is not running` and a 120 s `startTestDatabase` timeout; `pnpm test --maxWorkers=4` passed 126/126 files (1077 passed, 2 skipped) and every later full-suite gate passed with the same cap. The causal link to VM memory rests on this single machine, hence `field-tested`
