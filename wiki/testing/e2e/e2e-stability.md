---
id: testing-e2e-e2e-stability
domain: testing
category: e2e
applies_to: [general]
confidence: verified
sources:
  - https://playwright.dev/docs/best-practices
  - https://playwright.dev/docs/locators
  - https://playwright.dev/docs/actionability
  - https://playwright.dev/docs/auth
  - https://testing-library.com/docs/queries/about/
last_verified: 2026-07-10
related: [testing-flaky-diagnosing-flaky-tests, testing-data-test-data-and-isolation, testing-quality-minimum-case-set, testing-mocking-what-to-mock]
---

# Keeping Browser E2E Tests Stable and Fast

## When this applies

You are writing browser E2E tests (Playwright/Cypress-style), an E2E suite is
flaky or slow, or you are choosing selectors and setup strategy for one.

## Do this

1. Select elements in this stability order — take the first row that applies:

| Selector | Use when |
|----------|----------|
| User-visible role/label (`getByRole` with accessible name, `getByLabel`; text for non-interactive elements) | First choice for every element a user perceives — it tests what users experience and survives markup/style refactors |
| Dedicated test id (`data-testid`) | The element has no accessible identity and giving it one (edge case below) is not warranted |
| CSS classes / DOM structure / `nth-child` | Last resort, only when neither row above can address the element — structure-bound selectors break on style refactors; styling classes are not contracts |

2. **Wait on conditions, never durations.** Rely on the framework's
   auto-waiting and web-first assertions (`expect(locator).toHaveText(...)`
   retries until timeout); when an explicit wait is needed, target the
   condition — element visible, request settled — with a bounded timeout.
   Hard sleeps are the #1 E2E flake source ([testing-flaky-diagnosing-flaky-tests]).
3. **Set up state through the fastest layer.** Reach the state under test via
   API calls, seeded data, or saved storage state — log in once per worker via
   API and reuse the auth state. Drive the UI only for the flow the test
   verifies; UI-path setup in every test multiplies flake surface and runtime.
4. **Each test owns independent data** ([testing-data-test-data-and-isolation]).
   E2E against a shared mutable environment inherits every collision; give
   parallel workers their own accounts and rows.
5. **Scope E2E to the few user-critical flows.** Case-level coverage
   (boundaries, error contracts) is unit/integration's job
   ([testing-quality-minimum-case-set]); level choice → level pyramid in
   wiki/testing/strategy/.
6. **Stub only third-party/external calls at the network edge** (payment,
   analytics, external APIs) and keep your own stack real — exercising your
   real stack is what E2E verifies ([testing-mocking-what-to-mock]).
7. When an E2E test is identified as flaky, apply the same quarantine policy
   as unit tests: out of the blocking path, ticketed, fixed, proven by a clean
   streak ([testing-flaky-diagnosing-flaky-tests]).

## Edge cases

| Case | Then |
|------|------|
| Interactive element has no accessible name (icon-only button) | Add an `aria-label` — this fixes the product's accessibility and gives the test a stable role locator; fall back to a test id for purely decorative targets |
| Tests mutate shared server-side state (settings, org-wide data) | Authenticate each parallel worker with its own account so workers cannot collide |
| Entry animation makes clicks land on a moving element | Auto-waiting's stability check waits for the bounding box to settle; disable or shorten animations in the test environment to cut wait time and misclicks |
| Saved auth/storage state expires during long runs | Regenerate it in the setup project once per run — never per test, and never by committing credentials or state files to the repo |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `sleep(3000)` after a click | Web-first assertion on the expected outcome (`toHaveText`/`toBeVisible`-style, auto-retrying) | The sleep is too long on every green run and too short under load; the assertion proceeds the moment the outcome holds |
| Select with `nth-child`/CSS-class chains | Role/label locator, or a dedicated test id | Structure and styling change without behavior changing; user-visible identity survives refactors |
| Log in through the UI in every test | API login once per worker; reuse saved storage state | Repeated UI login multiplies runtime and flake surface without verifying anything new |
| Stub your own backend to make a flaky E2E pass | Stub only third-party edges; fix the instability in your stack or the test's waits/data | Your own stack's behavior is the thing E2E exists to verify; stubbing it leaves the flow unproven |

## Sources

- https://playwright.dev/docs/best-practices — user-facing locators over CSS/XPath; web-first assertions; test isolation; stub only what you don't control
- https://playwright.dev/docs/locators — role/label/text locators first; test ids when semantics are insufficient; structure-bound CSS/XPath not recommended
- https://playwright.dev/docs/actionability — auto-waiting: visible/stable/enabled checks retried before each action
- https://playwright.dev/docs/auth — authenticate once in a setup project, reuse storage state; per-worker accounts for mutating tests
- https://testing-library.com/docs/queries/about/ — query priority: role with accessible name first, test id last resort
