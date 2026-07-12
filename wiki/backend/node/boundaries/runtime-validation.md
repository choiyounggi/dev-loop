---
id: backend-node-boundaries-runtime-validation
domain: backend
category: boundaries
applies_to: [nodejs, typescript]
confidence: verified
sources:
  - https://zod.dev/basics
last_verified: 2026-07-10
related: [security-input-validation-at-trust-boundaries, backend-common-api-design-error-responses, backend-common-jobs-idempotent-handlers]
---

# Typing External Data in a TypeScript Service

## When this applies

Assigning a TypeScript type to data that enters the process from outside — HTTP
bodies, query params, env vars, third-party API responses, queue messages; an `as`
cast on external data; or a runtime shape error (`undefined is not a function`,
missing field) deep inside code that compiled cleanly.

## Do this

1. **TypeScript types are erased at compile time — they check nothing at runtime.**
   Treat every value that crosses the process boundary as `unknown` until a runtime
   check has proven its shape.
2. **Validate at the boundary with a schema library** (zod-style): `schema.parse(input)`
   returns a typed value or throws a structured error; `schema.safeParse(input)`
   returns a result object to branch on without exceptions.
3. **Derive the static type from the schema** — `type CreateOrder = z.infer<typeof CreateOrderSchema>`.
   One source of truth: the schema IS the type, so validation and typing cannot drift
   apart the way a hand-written interface asserted alongside a check does.
4. Apply per boundary:

| Boundary | Do |
|----------|-----|
| Request body / query / path params | `safeParse` in the handler or middleware; on failure respond 400 with per-field errors (error body shape: [backend-common-api-design-error-responses]); only the parsed value crosses into service code |
| Env vars / config | Validate the whole config object once at startup and crash the boot on failure — a missing/garbage env var found at boot is a deploy error; found at first use it is a 3am outage |
| Third-party API responses | `parse` the response before use — when their contract drifts, you get a typed validation error naming the field at the call site, not an `undefined` crash levels deeper |
| Queue / event messages | `parse` before handling; a message that fails validation is a poison message — route it to the DLQ path from [backend-common-jobs-idempotent-handlers], never retry-loop it |
| Internal module-to-module calls | Static types suffice — the data never left the typed world, so runtime re-validation adds cost without information |

5. Which boundaries count as trust boundaries, and validation depth (allowlists,
   canonicalization, size caps) is owned by
   [security-input-validation-at-trust-boundaries] — this page owns the TypeScript
   mechanics of making the check produce the type.

## Edge cases

| Case | Then |
|------|------|
| Fields you receive but do not use | Schema only what you consume; decide passthrough vs strip vs reject of extras explicitly (zod: `.passthrough()` / default strip / `.strict()`) so unknown fields cannot ride along unnoticed |
| Transforms during parse (string → number/Date) | Encode them in the schema (`z.coerce.*` / `.transform()`) so input and output types differ correctly (`z.input` vs `z.output`) instead of casting after |
| Response construction (data leaving the service) | Serialize from typed internal values; add a schema on egress only when the payload is assembled from untyped sources |
| Generated types from an OpenAPI/GraphQL spec | Generated types are still erased at runtime — pair them with generated validators, or parse with a schema at the boundary anyway |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `req.body as CreateOrderDto` | `CreateOrderSchema.safeParse(req.body)` and use the parsed value | A cast is a promise the compiler cannot check and the runtime will not enforce — malformed input walks in wearing a valid type |
| Read `process.env.X!` at point of use | Parse an env schema once at startup; import the typed config | `!` silences the compiler while the value stays `string \| undefined` at runtime; boot-time crash beats first-use crash |
| Hand-write `interface Foo` next to a hand-written validator | `z.infer<typeof FooSchema>` | Two artifacts drift; a derived type cannot disagree with its schema |
| Re-validate a value on every internal function it passes through | Validate once at the boundary; pass the typed value | Inside the process the type system already guarantees the shape |

## Sources

- https://zod.dev/basics — `.parse` / `.safeParse` semantics; `z.infer` deriving the static type from the schema; `z.input`/`z.output` for transforms
