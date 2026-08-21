---
id: testing-strategy-failing-test-first
domain: testing
category: strategy
applies_to: [general]
confidence: verified
sources:
  - https://newsletter.kentbeck.com/p/canon-tdd
  - https://martinfowler.com/bliki/TestDrivenDevelopment.html
  - https://github.com/obra/superpowers
last_verified: 2026-08-22
related: [testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, testing-quality-behavior-not-implementation, debugging-methodology-verify-the-fix]
---

# Writing the Failing Test Before the Code That Passes It

## When this applies

Implementing new behavior or a bug fix and deciding the order of test and
production code; production code already exists that no test ever required;
encoding a bug reproduction as the regression test that
[debugging-methodology-verify-the-fix] requires.

## Do this

1. Turn the requirement into a test list first: expected behaviors, boundary
   values, and error paths, chosen per [testing-quality-minimum-case-set] —
   before writing any test or code.
2. Write ONE failing test from the list, run it, and read the failure. The
   first run decides what you do next:

| First run shows | Read as | Do |
|-----------------|---------|-----|
| Assertion failure on the missing behavior | RED confirmed | Implement |
| Import/name/type/setup error | Test-infrastructure defect, not RED | Fix the test setup and rerun until the failure is the behavioral one |
| Immediate pass | The test pins existing behavior or asserts nothing | For new behavior, rewrite the test until it is red; for existing behavior, prove it can fail by mutation per [testing-quality-tests-that-cannot-fail] |

3. Derive expected values from the requirement, not by running the code under
   test — an expectation copied from the code's own output inherits the code's
   bugs as specification ([testing-quality-behavior-not-implementation]).
4. Write the minimum code that turns the test green; run the new test and the
   rest of the suite; require both green before the next list item.
5. Refactor only while green, in behavior-preserving steps, rerunning the suite
   after each step.
6. Production code you wrote before its test: delete it and restart from step 2
   — a test written while the implementation exists gets shaped by what the
   code does instead of what it should do (large inherited diffs: see Edge
   cases).

## Edge cases

| Case | Then |
|------|------|
| Throwaway spike answering a feasibility question | Write it without tests while it cannot ship; when the answer is "build it", delete the spike and rebuild test-first |
| The fix is config/infra with no code seam to test | Verify by toggling the config both ways against the recorded repro — the config row of [debugging-methodology-verify-the-fix] |
| A large untested implementation already exists (inherited branch, generated code) | Retrofit proof instead of deleting: write the test list, then prove each test catches a defect by mutation per [testing-quality-tests-that-cannot-fail] |
| The "new" behavior turns out to already exist (test green on first run) | Confirm by mutation that the test can fail, then drop the duplicate implementation from the plan |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Implement now and add tests after | Write the failing test first | Tests-after describe what the code does; tests-first define what it should do — after-the-fact tests adopt implementation bugs as expectations |
| Keep pre-test code around "as reference" while writing its tests | Delete it, go red, reimplement | The reference version anchors both test and reimplementation to its own behavior, bugs included |
| Paste the function's actual output into the assertion | Compute the expectation from the requirement | A mirror assertion passes for any implementation, broken ones included |

## Sources

- https://newsletter.kentbeck.com/p/canon-tdd — Kent Beck's canonical TDD loop: test list → one failing test → make it pass → refactor
- https://martinfowler.com/bliki/TestDrivenDevelopment.html — write the test first, watch it fail, write the simplest passing code
- https://github.com/obra/superpowers — test-driven-development skill: verify-RED for the expected reason, delete code written before its test, mirror-assertion ban; field-tested across agentic coding sessions
