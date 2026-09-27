---
id: backend-java-kotlin-implicit-receiver-shadowing-in-scope-functions
domain: backend
category: kotlin
applies_to: [kotlin, general]
confidence: verified
sources:
  - https://kotlinlang.org/spec/overload-resolution.html
  - https://kotlinlang.org/docs/scope-functions.html
last_verified: 2026-09-28
related: [testing-data-test-data-and-isolation, testing-mocking-what-to-mock, backend-java-kotlin-null-safety-interop]
---

# A Top-Level Helper Shadowed by a Receiver Member Inside `apply {}`

## When this applies

Kotlin code calls an unqualified function inside a lambda with receiver
(`apply`, `run`, `with`, an extension lambda) and a member of that receiver has
the same name — typically a test that defines a top-level fixture helper
(`fun trip(id: String) = Trip(...)`) and then writes
`FakeApi().apply { map["k"] = trip("t1") }` where the fake declares
`suspend fun trip(id: String)`. Also when a test fails inside such a block with
the fake's own exception on a line that "calls the helper".

## Do this

1. **Name fixture helpers so they cannot collide with any member of the fakes
   or receivers they are used against** — `tripFixture(...)`, `aTrip(...)`,
   `newTrip(...)` — and keep that convention for every helper in the test
   source set.
2. **Where a scope lambda needs a same-named top-level function, use a lambda
   without an implicit receiver** (`also { it.map["k"] = trip("t1") }`,
   `let`) — the spec searches implicit receivers before top-level functions
   only when a receiver is in scope.
3. **When a test throws the fake's own error from a helper call, suspect
   resolution before data:** hover or `Ctrl+B` on the call to see which
   declaration it resolves to; the code compiles because the member call is
   well-formed.

| Scope function | Implicit receiver in the lambda | An unqualified `trip()` resolves to |
|----------------|--------------------------------|-------------------------------------|
| `apply`, `run`, `with`, `T.() -> R` lambdas | `this` | The receiver's member `trip` when one exists, else the top-level function |
| `also`, `let` | none (`it`) | The top-level function |

## Edge cases

| Case | Then |
|------|------|
| The receiver member is `suspend` and the caller is not in a coroutine | The compiler reports the suspend-call error, which is the first visible symptom — read it as shadowing, not as a missing `runBlocking` |
| Nested receivers (`a.apply { b.apply { trip() } }`) | The innermost receiver wins, then outer receivers, then top-level — the spec orders implicit receivers by priority before top-level callables |
| An extension function shares a member's name | The member wins on an explicit receiver too; rename the extension |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Call a top-level `trip("t1")` inside `FakeApi().apply { }` | Rename the helper or switch to `also { }` | The fake's member `trip` is found first and compiles cleanly |
| Fix the runtime error by seeding the fake with the id the helper asked for | Check which `trip` the call resolves to | The fake was never meant to be called; the data fix hides the wrong wiring |

## Sources

- https://kotlinlang.org/spec/overload-resolution.html — "Call without an explicit receiver": for an identifier `f` the sets are analyzed in order: local callables, then "the overload candidate sets for each pair of implicit receivers … in order of the receiver priority", then "top-level non-extension functions named `f`"; the first non-empty set wins
- https://kotlinlang.org/docs/scope-functions.html — `apply`/`run`/`with` expose the context object as `this`; `also`/`let` expose it as `it`
- Field evidence 2026-09-27 (linkly-calendar Android, `TripViewModelTest`): three cases failed with the fake's `NoSuchElementException("no trip t1")` thrown from inside `apply {}`; the top-level `trip(id)` fixture had been shadowed by `FakeTripApi.trip(id)`. Renaming the helper to `tripFixture` made all 13 pass
