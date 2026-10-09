---
id: backend-node-boundaries-zod-4-checks-continue-after-a-failure
domain: backend
category: boundaries
applies_to: [nodejs, typescript, zod]
confidence: verified
sources:
  - https://zod.dev/api
  - "Local reproduction 2026-10-08 (Node v26.7.0, zod 4.6.5)"
last_verified: 2026-10-08
related: [backend-node-boundaries-runtime-validation, security-input-validation-at-trust-boundaries]
---

# zod 4 Runs Later Checks After a Failed Check

## When this applies

A zod 4 schema chains a check (`.regex()`, `.min()`, `.max()`, `.length()`,
`.email()`) and then a `.refine()` / `.superRefine()` / `.check()` whose
function throws, or gives a wrong answer, on input the earlier check should
have excluded — `BigInt(c)`, `new URL(s)`, `JSON.parse(s)`, an index lookup.

## Do this

1. **Pick one of three shapes, so the refine never sees input it cannot handle:**

| Shape | Write it as | Issue returned for a bad input |
|-------|-------------|--------------------------------|
| One refine does both tests | `z.string().refine(c => RE.test(c) && BigInt(c) <= MAX)` | One `custom` issue |
| Stop after the format check | `z.string().regex(RE, { abort: true }).refine(c => BigInt(c) <= MAX)` | `invalid_format`; the refine is skipped |
| Make the refine total | Wrap the risky call: `try { return BigInt(c) <= MAX } catch { return false }` | Both issues |

2. **Add a test with an input that fails the earlier check (`'abc'`) and assert
   `safeParse` returns `success: false`.** Without it the throw only appears in
   production.

## Edge cases

| Case | Then |
|------|------|
| The earlier failure is a type mismatch (`z.string()` given a number) | Not continuable: the refine does not run (measured: 0 calls) |
| The earlier failure is a format or size check (`.regex`, `.min`) | Continuable: the refine runs on the bad value (measured: 1 call each) |
| The refine throws | zod does not turn the exception into an issue: it propagates out of `safeParse`, so a handler that expects a result object gets an uncaught error (a 500 instead of a 400) |
| You need the refine to run even after a non-continuable issue | Use the `when` parameter; by default "refinements don't run if any non-continuable issues have already been encountered" |
| The refine needs the parsed number | Convert once in `.transform()` after an aborting check, then refine the converted value: `.regex(RE, { abort: true }).transform(c => BigInt(c)).refine(n => n <= MAX)` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Chain `.regex(RE).refine(fnThatThrowsOnNonMatch)` | Pass `{ abort: true }` to the check, or fold the regex into the refine | zod 4 "will execute all checks in sequence, even if one of them causes a validation error" |
| Test the schema only with values that pass the regex | Add one value that fails it | That is the only input that reaches the refine with a value it cannot handle |

## Sources

- https://zod.dev/api — Refinements: "Zod will execute all checks in sequence, even if one of them causes a validation error"; `abort`: "To mark a particular refinement as non-continuable, use the abort parameter. Validation will terminate if the check fails."; `when`: "By default, refinements don't run if any non-continuable issues have already been encountered."
- Local reproduction 2026-10-08 (Node v26.7.0, zod 4.6.5): `z.string().regex(/^[1-9][0-9]{0,18}$/).refine(c => BigInt(c) <= MAX).safeParse('abc')` threw `SyntaxError: Cannot convert abc to a BigInt`; the `{ abort: true }` form returned `success: false` with `invalid_format`; the single-refine form returned `success: false` with `custom`. A counting refine ran once after a failed `.regex` and once after a failed `.min`, and 0 times after `z.number()` received a string. The try/catch refine returned both `invalid_format` and `custom`; the abort + `.transform(BigInt)` + refine form returned `success: false` for `'abc'` and `12n` for `'12'`
