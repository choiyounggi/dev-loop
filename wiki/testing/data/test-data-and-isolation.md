---
id: testing-data-test-data-and-isolation
domain: testing
category: data
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/nonDeterminism.html
  - https://abseil.io/resources/swe-book/html/ch12.html
  - https://testing.googleblog.com/2017/01/testing-on-toilet-keep-cause-and-effect.html
  - https://nodejs.org/api/fs.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/env.html
last_verified: 2026-08-14
related: [testing-flaky-diagnosing-flaky-tests, testing-strategy-test-level-choice, testing-strategy-import-time-side-effects, testing-data-artifact-leakage-from-a-suite, testing-quality-behavior-not-implementation, platforms-filesystems-permissions-and-exec-bits, backend-common-change-impact-call-site-enumeration, infrastructure-agent-orchestration-shared-run-state]
---

# Owning Test Data and Isolating Test State

## When this applies

Tests need fixture data and you are deciding how to create it; or tests pass
alone but fail when run together (or pass together but fail alone) — a
state-leak symptom.

## Do this

1. **Each test creates the data it needs and owns it.** Build fixtures through
   factory functions/builders that fill defaults, and pass explicitly only the
   fields the test's behavior depends on — a reader must be able to tell why
   the test passes from the values visible in the test body.
2. **No test depends on execution order or leftover state.** Every test must
   pass when run alone, in any order, and in parallel with the rest of its
   suite. When one test's setup relies on another test having run, merge them
   or give each its own setup.
3. Isolate by resource type:

| Case | Do |
|------|----|
| DB-backed tests | Wrap each test in a transaction rolled back at the end, or truncate the touched tables between tests — pick one mechanism per suite and apply it uniformly |
| Rollback impossible (code under test commits, or asserts across connections) | Truncate/reset between tests, or give each test uniquely-keyed rows it queries back by its own keys |
| Shared mutable fixture object (module-level constant a test mutates) | Give each test its own copy from the factory; reserve shared fixtures for immutable data |
| The fixture's shape depends on a value the test also passes to the code under test (a key, a tenant id, a payload, a timestamp) | Put that value in the factory's signature so every call site names it — a factory that defaults it to a module-level constant lets fixture and run diverge silently |
| Time-dependent logic (expiry, scheduling, "created today") | Inject a clock/time source and freeze it in the test; assert against the frozen instant |
| Unique-constrained values (emails, usernames, external ids) | Generate per test (counter, UUID suffix) inside the factory — hardcoded constants collide across tests and across parallel runs |
| Filesystem / temp files | Create a fresh per-test temp directory and remove it in teardown; when directories are already accumulating, attribute them to their creators first ([testing-data-artifact-leakage-from-a-suite]) |
| Global config / environment variables / singletons mutated by a test | Set in setup, restore in teardown that runs on failure too (`finally`/fixture teardown) |
| Code under test derives a write path from the environment (`~/...`, `$HOME`, `$XDG_CONFIG_HOME`, `%APPDATA%`) and would touch the real machine | Point that environment variable at a per-test scratch directory in setup and restore it in `finally`; the production path expression then resolves inside the scratch tree with no signature change. Assert afterwards that the real location gained no files |
| A case whose behavior depends on a variable being **absent** (`run env VAR=x cmd`, `subprocess(env={...})`) | `unset` it in setup — `env` merges into the inherited environment unless given `-i`, so running the suite from a session that exports it silently flips that case to the opposite branch; CI's clean environment stays green and hides it |
| A fixture file must carry the executable bit (permission checks, PATH/binary-resolution code) | Create it with the mode set at creation time (`writeFileSync(p, body, { mode: 0o755 })`, `open` with a mode) inside a per-test directory under an already-gitignored build-output path of the repo, and remove it in teardown |
| The suite runs inside a session that a harness/orchestrator injected coordination variables into (run id, status-directory path, task id), and the code under test reads them | `unset` every injected variable in setup and pass state paths to the code under test explicitly as per-test tempdir arguments — the inherited values both flip env-dependent branches against the unset-env baseline and point the tests' writes at the live run's shared state |

4. Keep fixture data **minimal**: create only the entities the behavior under
   test reads. Every extra row is a value a reader must rule out and a
   dependency that breaks when the schema changes.

## Edge cases

| Case | Then |
|------|------|
| A seeded reference dataset is genuinely shared (country codes, static enums) | Load it once per suite and treat it as immutable; tests still create their own mutable rows |
| Suite is too slow because every test builds a deep object graph | Move the invariant graph into a per-suite setup that tests never mutate; keep mutated entities per-test |
| Failure appears only in the full suite, never alone | Run the suite in random order to expose the order dependency, then bisect to the polluting test; fix the polluter's ownership, not the victim ([testing-flaky-diagnosing-flaky-tests]) |
| Test needs "now"-relative data but the code reads the system clock directly | Refactor the code to accept an injected clock; that seam is the fix — assertions with tolerance windows around real time stay flaky |
| A group of tests fails as a lookup miss, an empty result, or a "not found" far from any fixture code | Compare each factory's defaulted values against the input the test actually runs before migrating fixture shape; when the two disagree, the fixture was built for a different input and only the signature change fixes the group |
| The executable fixture is rewritten between tests | Delete and recreate it: a write to an existing path keeps the original mode, so a second write with a different mode leaves the first one in place (measured on Node v25.8.1) |
| The machine runs endpoint security (EDR) that flags an executable created under the system temp directory | Keep the fixture inside the repo's gitignored build-output tree and set the bit at creation; that path is what a "+x file dropped in a temp dir" heuristic looks for, and the fixture only needs the bit, not the location ([platforms-filesystems-permissions-and-exec-bits]) |
| Leftover test artifacts (temp dirs/files) accumulate in the repo and the producers look diffuse | Count leftovers by name prefix (`ls \| sed 's/-[a-z0-9]*$//' \| sort \| uniq -c`) and match the distribution against the sites that create such files — a match closes the attribution; fix those sites, then enforce the cleanup convention with a static check proven red against the unfixed code first |
| The code under test is the harness that spawned the session now running its suite (an orchestration worker runs the orchestrator's own tests in its worktree) | Treat the leak as two failures: reproduce the test failures with `env VAR=… bats <file>` on a clean checkout to confirm the mechanism, then check the live run's state files for writes stamped with test-fixture values — a leaked state path corrupts the running orchestration ([infrastructure-agent-orchestration-shared-run-state]), which surfaces later as a watcher monitoring the wrong session |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on rows created by an earlier test in the file | Create the rows in this test (or shared immutable setup) | Order dependence breaks under parallelism, filtering, and random order |
| Hardcode `test@example.com` / `user1` in many tests | Generate unique values in the factory per test | Unique-constraint collisions fail tests that are individually correct |
| `sleep()` until background work lands the data | Wait explicitly on the condition/event with a timeout | Sleeps are both too slow and too short; the race remains |
| Copy a full production-like JSON blob as fixture for one field's behavior | Build the minimal object via a factory, explicit only in that field | Giant fixtures hide the relevant value and break on unrelated schema changes |
| Let a factory seed itself from a module-level constant while the test passes a different value to the code under test | Take that value as a factory parameter and name it at every call site | The fixture is then built for the input the test actually runs; a defaulted constant makes the two drift apart with nothing in the test body showing it |
| Add a directory parameter to a production function so a test can redirect its writes | Redirect the environment variable that function already reads, restoring it in `finally` | A test-only parameter widens a public signature the callers are pinned to and lets a caller inject a wrong directory; the env var is a seam the production code already has |
| Add cleanup at every temp-file call site a grep finds | Attribute first by prefix counts, fix the dominant producers, then add a static check for the convention the compliant files already follow | Leak volume concentrates in a few sites; matching counts to call sites confirms the cause, and the static check stops the recurrence an instance-only fix invites |

## Sources

- https://martinfowler.com/articles/nonDeterminism.html — isolation between tests, wrapping the system clock, callbacks/polling over bare sleeps
- https://abseil.io/resources/swe-book/html/ch12.html — a test is complete when "its body contains all of the information a reader needs in order to understand how it arrives at its result"; prefer DAMP over DRY, and where a helper is used, give it "descriptive parameters that make dependencies explicit" rather than reusing shared constants
- https://testing.googleblog.com/2017/01/testing-on-toilet-keep-cause-and-effect.html — keep the inputs a test's result depends on visible in the test method instead of in shared setup, so the cause-and-effect relationship is readable without jumping elsewhere
- Field incident 2026-08-04 (`linkly-t1-repo-policy`, Python): `rows_for(doc)` seeded its rows from the module constant `PAYLOAD` while its tests ran payload `{}`; a shape-only migration of the helper fixed 1 of 11 failures, and moving the payload into the helper's signature fixed 11 of 11
- Field incident 2026-08-14 (dev-loop issue #100): `launch-session.sh` exports `LO_RUN_ID`/`LO_STATUS_DIR`/`LO_TASK_ID` into every worker session; a worker running `bats tests/launch-session.bats` inherited them — 6 deterministic failures absent on a clean shell, reproduced with `env LO_RUN_ID=… bats`, and the live run's `t90.json` status file was found rewritten with bats tempdir paths and a foreign session name
