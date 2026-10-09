---
id: mobile-navigation-test-files-in-expo-router-app-directory
domain: mobile
category: navigation
applies_to: [expo-router, react-native, jest]
confidence: verified
sources:
  - https://docs.expo.dev/router/reference/testing/
  - https://docs.expo.dev/develop/unit-testing/
  - https://github.com/expo/expo/blob/main/packages/expo-router/_ctx-shared.js
last_verified: 2026-10-01
related: [mobile-navigation-deep-links-and-entry-points, testing-strategy-test-level-choice, testing-async-async-testing, testing-quality-checks-that-cannot-pass]
---

# Test File Placement in an Expo Router Project

## When this applies

An app uses Expo Router's file-based routing and you are deciding where a
route's or layout's Jest test lives, configuring `testMatch`, or reviewing a
diff that adds `app/__tests__/…` or `app/**/foo.test.tsx`. Also when a
production bundle contains `@testing-library/*` or `jest.mock` strings, or an
unexpected route such as `/__tests__/index.test` appears in the route list.

## Do this

1. **Keep every test file outside `app/`.** Expo Router turns each `.ts`/`.tsx`/
   `.js`/`.jsx` file under `app/` into a route or layout; its context pattern
   excludes only `+api`, `+html`, and `+native-intent` files and has no
   test-file exclusion. A test placed there becomes a route and its imports are
   bundled into the app.

2. **Mirror the route tree under a top-level `__tests__/`** so the pairing stays
   obvious: `app/(tabs)/index.tsx` ↔ `__tests__/app/(tabs)/index.test.tsx`.

3. **Point Jest at those locations** with `testMatch` (for example
   `["<rootDir>/__tests__/**/*.test.[jt]s?(x)", "<rootDir>/src/**/*.test.[jt]s?(x)"]`)
   so a test dropped into `app/` is not collected and its absence from the run
   is noticed.

4. **Gate the placement mechanically.** In CI or a pre-commit step run
   `find app \( -iname '*.test.*' -o -iname '*.spec.*' -o -name '__tests__' \)`
   and fail on any output. Confirm the gate both ways: it prints nothing on the
   clean tree and prints the path after you add a probe file
   ([testing-quality-checks-that-cannot-pass]).

5. **Verify the bundle once after moving tests**: run `npx expo export` into a
   scratch directory and search the output for `testing-library` and
   `jest.mock`; require zero matches, and confirm the search works by grepping
   the same output for a string you know is present (a screen title).

## Edge cases

| Case | Then |
|------|------|
| The test needs the real route tree | Use `renderRouter` from `expo-router/testing-library` with a fixture path or `{ appDir, overrides }`; the test file itself still lives outside `app/` |
| Non-route helpers (components, hooks, constants) sit inside `app/` | Move them out as well (`src/`, `components/`) — every file there is treated as a route, test or not |
| The project sets a custom root (`src/app/`) | The same rule applies to that directory; point the `find` gate at it |
| A colocated `*.test.tsx` beside a component outside `app/` | Fine — the restriction is the router directory, not colocation in general |
| A future Expo Router release adds a test-file exclusion | Re-read `_ctx-shared.js` at the installed version before relaxing the gate; the docs' placement rule is the contract, the pattern is its current mechanism |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Create `app/__tests__/login.test.tsx` next to the screen | `__tests__/app/login.test.tsx` plus a matching `testMatch` | Under `app/` the file is a route; its test imports ship in the bundle |
| Conclude "no tests in app/" from a green Jest run | Run the `find` gate | Jest passing says the tests ran, not where they live |
| Trust an empty bundle grep without a positive control | Grep the same export for a known-present string first | An export that failed or wrote elsewhere also yields zero matches |

## Sources

- https://docs.expo.dev/router/reference/testing/ — "When using Expo Router, do not put your test files inside the **app** directory. All files inside your **app** directory must be either routes or layout files. Instead, use the **\_\_tests\_\_** directory or a separate directory"; `renderRouter` forms (inline mock, fixture path, `appDir` + `overrides`)
- https://docs.expo.dev/develop/unit-testing/ — "Structure your tests" section the routing docs point to for test placement
- https://github.com/expo/expo/blob/main/packages/expo-router/_ctx-shared.js — `EXPO_ROUTER_CTX_IGNORE`, commented "Ignore root `./+html.js` and API route files `./generate+api.tsx`": the pattern's negative lookahead names only `+api` and `+html`/`+native-intent` files; no `test`/`spec` alternative (fetched 2026-10-01)
- Field evidence 2026-09-29 (an Expo SDK 57 app, expo-router 57.0.23): with route tests moved to `__tests__/app/…` and `testMatch` restricted to them, a scratch `expo export` bundle contained 0 matches for `testing-library` and `jest.mock`
