---
id: testing-mocking-proving-a-value-never-reaches-the-console
domain: testing
category: mocking
applies_to: [javascript, nodejs, vitest]
confidence: verified
sources:
  - https://nodejs.org/api/console.html
  - https://github.com/nodejs/node/blob/main/lib/internal/util/inspect.js
  - https://nodejs.org/api/util.html
  - "Local reproduction 2026-10-11 (Node v26.7.0, Vitest 5.0.3): which console spies observe nine leak shapes, and whether a throwing Proxy trap fires under console.warn"
  - "Field case 2026-10 (linkly-invitation task t7; recorded by the originating session): six console-method mutants passed an error-only suite"
last_verified: 2026-10-11
related: [security-data-masking-verification, testing-quality-absence-assertions-over-generated-output, testing-quality-tests-that-cannot-fail, testing-mocking-what-to-mock]
---

# Proving a Value Never Reaches the Console

## When this applies

A JavaScript test (Vitest, `node:test`) must prove that a sensitive or unknown
value — an error carrying a user's name, a token, a raw payload — is never
logged, and it watches logging through `console` spies: a spy on
`console.error` alone, a `Proxy` around the value whose `get` trap throws as a
tripwire, or both.

## Do this

1. **Spy on every function-valued property of `console`, then assert that no
   spy was called.** Each method is its own property. Node documents
   `console.info` and `console.debug` as aliases for `console.log` and
   `console.warn` as an alias for `console.error`, yet replacing one property
   does not intercept a call made through another:

```ts
afterEach(() => vi.restoreAllMocks())

test('never logs the error', () => {
  const methods = Object.keys(console).filter((k) => typeof console[k] === 'function')
  const spies = methods.map((m) => vi.spyOn(console, m).mockImplementation(() => {}))
  report(new Error('FAKE-SECRET-MARKER')) // the code under test
  expect(methods.filter((m, i) => spies[i].mock.calls.length > 0)).toEqual([])
})
```

   Which spy records each leak (measured, Node 26 and Vitest 5):

| Call in the code under test | A spy on `console.error` only | A spy on every method |
|-----------------------------|-------------------------------|-----------------------|
| `console.warn(err)` | records nothing | `warn` |
| `console.log`, `info`, `debug`, `dir` or `dirxml` (`err`) | records nothing | that method |
| `console.table(err)` | records nothing | `table` |
| `console.assert(false, err)` | records nothing | `assert` |
| `console.trace(err)` | records it (Node's `trace` prints through `this.error`) | `trace` |

2. **Prove the spies can see a leak before trusting their silence.** Add one
   mutant per method to the code under test — `console.warn(err)`,
   `console.info(err)`, `console.dir(err)` — and require the test to go red for
   each ([testing-quality-tests-that-cannot-fail]).

3. **Rely on the spies, not on a throwing `Proxy`.** Node's console formats
   objects with `util.inspect`, which replaces a proxy with its target before
   formatting and never runs its handler, so `console.warn(proxy)` prints the
   target's message and throws nothing. The trap fires only when the code turns
   the value into a string itself (`` `${err}` ``, `String(err)`).

## Edge cases

| Case | Then |
|------|------|
| The code logs on purpose through one method (an `info` line on success) | Keep the spy on every method; assert zero calls on the others, and for the expected method assert that no recorded argument is the value or contains its marker text |
| The value must also stay out of `process.stdout.write`, files, HTTP responses or error-report payloads | Console spies cover the console only; sweep the other channels per [security-data-masking-verification] |
| Choosing the planted value | Use a marker no generator in the output can produce ([testing-quality-absence-assertions-over-generated-output]) |
| A spy created without `mockImplementation` | It calls the original method, which prints the planted value into the test log; pass `mockImplementation(() => {})` |
| The spies are restored in a `finally` block before the assertion | Read the calls first and restore afterwards (`afterEach(() => vi.restoreAllMocks())`): in Vitest 5.0.3 `mockRestore()` cleared the spy's recorded calls (1 → 0), so an assertion after it reads zero for leaking code too |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `vi.spyOn(console, 'error')` and assert it was not called | Spy on every function-valued `console` property and assert none was called | Measured: an error-only spy recorded 1 of 9 leak shapes (`trace`) |
| Wrap the value in a `Proxy` whose `get` trap throws and expect logging to throw | Assert on the spies | `util.inspect` bypasses the trap: `console.warn(proxy)` printed the value and threw nothing |

## Sources

- https://nodejs.org/api/console.html — "The `console.debug()` function is an alias for `console.log()`"; "The `console.info()` function is an alias for `console.log()`"; "The `console.warn()` function is an alias for `console.error()`"; `console.dirxml` "calls `console.log()` passing it the arguments received"; `console.dir` "Uses `util.inspect()` on `obj`"
- https://github.com/nodejs/node/blob/main/lib/internal/util/inspect.js — `formatValue`: "Always check for proxies to prevent side effects and to prevent triggering any proxy handlers", followed by `getProxyDetails(value, …)`, which hands back the target that is then formatted
- https://nodejs.org/api/util.html — `util.inspect` option `showProxy`, default `false`; when `true`, "`Proxy` inspection includes the `target` and `handler` objects"
- Local reproduction 2026-10-11 (Node v26.7.0): with `p = new Proxy(new Error('secret-XYZ'), { get() { throw new Error('TRAP') } })`, `console.warn(p)`, `console.warn('%o', p)` and `util.inspect(p)` threw nothing and printed `secret-XYZ`; `` `${p}` `` and `String(p)` threw from the trap. With `console.log`, `console.warn` and `console.error` replaced by recorders, calls to `info`, `debug`, `dirxml` and `dir` reached none of them, `trace` reached `error`, `table`, `group`, `count` and `timeLog` reached `log`, and `assert` reached `warn`
- Local reproduction 2026-10-11 (Vitest 5.0.3, node environment): nine leak shapes (`warn`, `log`, `info`, `debug`, `dir`, `dirxml`, `trace`, `table`, `assert(false, err)`) against a `console.error`-only spy — only `trace` reached it, and no shape threw; with all 19 function-valued `console` properties spied, each shape was recorded by its own method. A bare `vi.spyOn(console, 'warn')` called the original; with `mockImplementation(() => {})` it did not. `mockRestore()` dropped `mock.calls.length` from 1 to 0. The step-1 snippet passed for code that logs nothing and failed for `console.warn(err)` with `expected [ 'warn' ] to deeply equal []`
- Field case 2026-10 (linkly-invitation task t7; recorded by the originating session): six mutants adding `console.warn`, `log`, `info`, `debug`, `dir` or `dirxml(error)` passed a suite that spied on `console.error` only, one of them printing the planted secret to stderr; with every method spied, each went red on the named test (6/6)
