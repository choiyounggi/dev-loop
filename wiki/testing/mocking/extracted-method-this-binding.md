---
id: testing-mocking-extracted-method-this-binding
domain: testing
category: mocking
applies_to: [javascript, typescript, vitest, jest]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/this
  - https://vitest.dev/api/mock.html
last_verified: 2026-09-03
related: [testing-mocking-what-to-mock, testing-quality-tests-that-cannot-fail, testing-mocking-captured-call-arguments, testing-strategy-test-level-choice]
---

# A Method Extracted From Its Object and Tested Through a Mock

## When this applies

Code reads an optional method off an object into a variable and calls it later
(`const resolve = source.resolveGate; if (resolve) resolve(x)`), or passes
`obj.method` as a callback; the object is a class instance (a client, a store,
an IPC bridge) whose methods read `this`; the unit tests inject the method as
`vi.fn()`/`jest.fn()`. Also when such a feature crashes in the browser or an E2E
run while its unit tests are green.

## Do this

1. **Bind at the extraction site, in the code:**
   `const resolve = source.resolveGate?.bind(source)`. A method extracted from
   its object and called standalone runs with `this` of `undefined` (strict mode
   and modules), so its first `this.x` read throws `TypeError`; a bound
   function's `this` no longer depends on the caller. Arrow-function class
   fields and `obj.method(...)` call syntax are the other two safe shapes.

2. **Write the regression test with a `this`-dependent callable, or assert the
   recorded context.** A bare `vi.fn()` returns its canned value whatever `this`
   is, so a test that only checks it was called passes on the unbound code too:

| Test shape | Assertion |
|------------|-----------|
| Inject a real instance whose method reads `this` (the production class, or a two-line class with a counter) | The call succeeds and the instance's state changed |
| Inject `function () { return this === obj; }` | The returned value is `true` |
| Keep `vi.fn()` | `expect(fn.mock.contexts[0]).toBe(obj)` — Vitest records the `this` of every call in `mock.contexts` |

3. **Prove the test reddens on the unbound form before keeping it:** remove
   the `.bind(...)`, require red, restore ([testing-quality-tests-that-cannot-fail]).

4. **When a report reads "unit tests green, crashes in the real app" and the
   crashing call is a method used as a value, check the binding first** — the
   gap between a `this`-indifferent mock and a `this`-reading instance is the
   usual mechanism.

## Edge cases

| Case | Then |
|------|------|
| The method is optional on the type (`resolveGate?: () => …`) | `source.resolveGate?.bind(source)` is `undefined` when the method is absent; keep the existence check on the bound variable |
| The object is a plain literal with arrow-function members | No `this` dependency today; keep the `this` assertion in the test anyway so a later class-based implementation cannot regress silently |
| The callback is handed to a framework that calls it with its own `this` (event emitters, some ORMs) | Bind explicitly to the object you mean; the framework's `this` is not your instance |
| Two real implementations back the interface (a dev mock service, a production IPC bridge) | Run the test against each real one: the field crash was on both, and only a `this`-reading callable exposed it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Test the extracted-method path with `vi.fn()` and assert it was called | Inject a `this`-dependent callable, or assert `mock.contexts[0]` | The bare mock is indifferent to `this`, so it passes on code that throws in production |
| Fix the crash by wrapping the call in `try/catch` | Bind at extraction | The catch hides the lost context; the feature still does nothing |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/this — extracting a method (`const carSayHi = car.sayHi`) and calling it standalone loses `this`; "For bound methods, `this` doesn't depend on the caller"
- https://vitest.dev/api/mock.html — `mock.contexts` is "an array of `this` values used during each call to the mock function"; `vi.fn()` places no requirement on `this`
- Local reproduction 2026-09-03 (Node): `class Foo { constructor(){ this.value = 42 } method(){ return this.value } }`; `const fn = new Foo().method; fn()` → `TypeError: Cannot read properties of undefined (reading 'value')`; `obj.method.bind(obj)()` → `42`
- Field reproduction 2026-09-02 (linkly-crew approvals inbox, React/TS + Tauri): `defaultSource.resolveGate` extracted unbound crashed on click against both the dev mock service (`gateEnvCounter` on `this`) and the Tauri bridge (`this.invoke`), while three unit tests built on `vi.fn()` stayed green; `.bind` fixed both, verified in the browser
