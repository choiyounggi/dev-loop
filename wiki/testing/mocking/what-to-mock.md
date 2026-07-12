---
id: testing-mocking-what-to-mock
domain: testing
category: mocking
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/mocksArentStubs.html
  - https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html
  - https://abseil.io/resources/swe-book/html/ch12.html
last_verified: 2026-07-10
related: [testing-strategy-test-level-choice, testing-quality-behavior-not-implementation]
---

# Deciding Whether to Mock, Fake, or Use the Real Dependency

## When this applies

A test's subject has a dependency and you are deciding whether to replace it
with a mock/stub/fake or use the real thing; or you are reviewing a test suite
where mocks are breaking on refactors.

## Do this

1. Replace only what you cannot control or afford in the test; keep everything
   else real:

| Case | Do |
|------|----|
| Pure in-process collaborators you own (domain objects, helpers, services without I/O) | Use the real objects — replacing them tests your guess of your own code |
| External I/O you don't control: third-party HTTP APIs, payment providers, email/SMS gateways | Stub/mock at the boundary **you own** — your client wrapper interface — with canned responses per case (success, error, timeout) |
| Nondeterminism sources: clock, randomness, UUID generation | Inject them and substitute a fixed clock / seeded generator in tests |
| Your own DB, when the test's subject is query behavior (SQL shape, mapping, constraints) | Real test database — a mocked DB asserts your assumption of the contract, not the contract ([testing-strategy-test-level-choice]) |
| A dependency that is real-capable but too slow/stateful for every unit test (your DB behind a repository, a queue) | An in-memory **fake** implementing the same interface, kept honest by running the contract's own integration tests against the real one |
| Command sent to an external boundary is itself the behavior (charge card, publish event) | Mock the owned boundary interface and assert the **outbound contract**: which command, with what arguments — not internal call sequences leading up to it |

2. Stub **queries**, assert **commands**: for data the dependency returns, a
   stub with canned answers is enough — assert the subject's resulting
   output/state. Reserve call-verification for outbound commands whose emission
   is the guarantee under test.
3. When many tests need the same replaced dependency, promote per-test mock
   setups into one shared fake: a single in-memory implementation is written
   once, behaves consistently, and survives interface refactors that break
   scattered stubbing.

## Edge cases

| Case | Then |
|------|------|
| The third-party client SDK is complex and you mocked it directly in many tests | Wrap it in a thin interface you own; mock the wrapper, and cover the wrapper itself with one integration test against the sandbox/recorded responses |
| You need to test your code's handling of a provider's failure modes (500, timeout, malformed body) | Stub those responses at your wrapper boundary per case — this is the main payoff of mocking unowned I/O |
| The mock setup has grown to mirror the collaborator's logic (conditional returns, sequencing) | Replace it with a fake or the real object — a mock that reimplements the dependency is a second implementation that can drift |
| The fake and the real implementation can diverge | Run one shared contract test suite against both; the fake stays trustworthy only while it passes the real thing's tests |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Mock every dependency "for unit purity/speed" | Mock only unowned I/O and nondeterminism; keep owned in-process collaborators real | All-mock tests verify wiring you wrote against guesses you wrote; real bugs pass |
| Assert the full internal call sequence on your own collaborators | Assert the subject's output/resulting state; verify only outbound boundary commands | Call-sequence assertions couple tests to implementation and break every refactor |
| Test repository/query code with a mocked DB driver | Use a real test database | The SQL contract is exactly what the mock cannot verify |
| Copy-paste the same multi-line mock setup across many tests | Build one shared fake implementing the interface | One honest implementation beats N drifting stubs |

## Sources

- https://martinfowler.com/articles/mocksArentStubs.html — stub/fake/mock distinctions; state vs behavior verification
- https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html — prefer real objects, fakes, or local test databases over mocks
- https://abseil.io/resources/swe-book/html/ch12.html — prefer state testing; interaction testing only where the interaction is the contract
