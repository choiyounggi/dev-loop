---
id: backend-node-convex-ascii-keys-in-returned-objects
domain: backend
category: convex
applies_to: [convex, convex-test]
confidence: verified
sources:
  - https://docs.convex.dev/database/types
  - https://docs.convex.dev/production/state/limits
  - convex 1.46.0 and 1.47.0 npm packages, dist/esm/values/value.js, validateObjectField
last_verified: 2026-11-04
related: [backend-node-boundaries-runtime-validation, backend-node-convex-parallel-children-writing-one-parent-document]
---

# Object Keys Built From Labels in a Convex Return Value

## When this applies

A Convex query, mutation or action returns or stores an object whose keys come
from data or display labels: an age bucket such as `16–30` with an en dash, an
accented word, an emoji. Also when the code typechecks, its helper tests pass,
and the real app logs `Field name ... has invalid character`.

## Do this

1. Build every object key from an ASCII id (`16-30`, `preco`, `bucket_1`), at
   every nesting level.
2. Keep the human label in a value, or map id to label on the client.

| Data shape | Do |
|------------|----|
| Keys are a small fixed set | ASCII ids as keys, labels in a client-side map |
| Keys come from user data | Return an array of `{ label, value }`, so the label stays a value |

3. Prove the shape by calling the registered function, through `t.query` or
   `t.mutation` in `convex-test` or on a real deployment. Both serialize the
   return value and throw for a non-ASCII key.

## Edge cases

| Case | Then |
|------|------|
| The docs state the ASCII rule only for `Record` keys, and the limits page gives no character rule for nested keys | Follow the code: the check runs on every object field, nested ones included. `convexToJson({ "16–30": 1 })` throws while `convexToJson({ "16-30": 1 })` passes |
| A test covers the helper that builds the object and passes | The helper returns a plain JavaScript object, so nothing validates it; add one test that calls the registered function, or pass the object through `convexToJson` from `convex/values` |
| The key starts with `$` | Rename it: the same validation rejects it as reserved |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust TypeScript and a test of the building helper for a label-keyed object | Call the registered function in `convex-test`, or run the object through `convexToJson` | The rule is a runtime check on the key's characters; `Record<string, number>` accepts any string, and the check runs only where the value is serialized |

## Sources

- https://docs.convex.dev/database/types — the values table; states the ASCII rule for `Record` keys and the `$`/`_` rule for object fields
- https://docs.convex.dev/production/state/limits — value limits apply to documents, arguments and return values; nested keys up to 1024 characters, with no character rule stated
- convex 1.46.0 and 1.47.0, dist/esm/values/value.js, `validateObjectField` — rejects char codes below 32 or from 127 up: `Field names can only contain non-control ASCII characters`
- Local reproduction 2026-11-04: `convexToJson` threw for `16–30`, `preço` and an emoji, and passed `16-30`. Through `convexTest` (convex 1.46.0 with convex-test 0.0.60, and 1.47.0 with 0.0.62), `t.query` and `t.mutation` threw the same error for a top-level `16–30` key and a nested `preço` key, and passed `16-30`
- Field report: a production-style app logged `Field name 16–30 has invalid character '–'` from a query; renaming the keys to `16-30` fixed it. The report said `convex-test` passed; the reproduction above shows that holds only for tests that do not call the registered function
