---
id: backend-node-boundaries-structured-output-schema-from-zod
domain: backend
category: boundaries
applies_to: [typescript, zod, anthropic-sdk]
confidence: verified
sources:
  - https://platform.claude.com/docs/en/build-with-claude/structured-outputs
  - https://zod.dev/json-schema
last_verified: 2026-10-07
related: [backend-node-boundaries-runtime-validation]
---

# Turning a zod Schema into the JSON Schema for Claude Structured Outputs

## When this applies

TypeScript code describes the reply it wants from Claude as a zod 4 schema and sends
it as the JSON Schema of a structured-output request (`output_config.format`), or
stores, snapshots or asserts that converted schema. Also when choosing between the
SDK helper and `z.toJSONSchema`, picking the `io` mode, or when the schema uses
`.default()`, `.transform()`, `enum`/`const`, or `.min()`/`.max()` limits.

## Do this

1. **With `@anthropic-ai/sdk`, wrap the schema in `zodOutputFormat()` and call
   `client.messages.parse()`**, the TypeScript path the docs give. `parse()` validates
   the reply with the original zod schema and returns `parsed_output`; a reply that
   fails validation throws `AnthropicError` ("Failed to parse structured output").
   What the helper sends (SDK 0.131.0, read from its source and run on a sample):

| Step | `zodOutputFormat()` |
|------|---------------------|
| Convert | `z.toJSONSchema(schema, { reused: 'ref' })`: zod's default output mode |
| Objects | `additionalProperties: false` on every object; `required` kept as zod wrote it |
| Kept keywords | `type`, `anyOf` (`oneOf` is rewritten to `anyOf`), `allOf`, `$ref`/`$defs`, `description`, `title`, `properties`, `required`, `items`, `minItems` 0 or 1, string `format` from the documented list |
| Every other keyword | Appended to that field's `description` as text: `enum` becomes `"{enum: [\"rose\",\"noir\"]}"`, `default` becomes `"{default: 4}"`, the root `$schema` too |

2. **When converting by hand (another client, a stored or snapshotted schema), call
   `z.toJSONSchema(schema)` in its default output mode.** Output mode writes
   `additionalProperties: false` on every object, which Claude requires, and lists
   `.default()` keys in `required`; `io: 'input'` writes neither:

| zod 4.6.5, object with a nested object and `.default()` keys | Output mode (default) | `io: 'input'` |
|------|------|------|
| Root and nested `additionalProperties` | `false` | absent |
| Root `required` | `name, palette, size, parts` | `name, palette, parts` (`size` has a default) |
| Nested `required` | `hair, top` | `hair` (`top` has a default) |

   Output mode keeps every limit in the schema it writes: `.min()`, `.max()` and
   `.length()` become `minimum`, `maximum`, `minLength`, `maxLength`, or an array bound
   other than `minItems` 0 or 1. The docs list those as not supported ("If you use an
   unsupported feature, you'll receive a 400 error with details"), so delete them from
   the schema you send (or append them to the field's `description`, as the helper
   does) and keep them in the zod schema that validates the reply.

3. **Send a transform-free schema and apply `.transform()` after parsing.** Output mode
   throws `Transforms cannot be represented in JSON Schema`, and so does
   `zodOutputFormat()`, which converts in output mode. Keep the sent schema to the
   reply's shape and transform `parsed_output` (or parse it again with a schema that
   adds the transform).

## Edge cases

| Case | Then |
|------|------|
| A field relies on `enum`/`const` to restrict its values | The docs list both as supported, but the SDK 0.131.0 helper sends the field as a plain `string` with the values in `description`, so the request carries no enum constraint; `parse()` still rejects an out-of-list value with `AnthropicError`, so handle that error (retry or fail the call). `jsonSchemaOutputFormat(schema, { transform: false })` sends a hand-converted schema unchanged (`src/helpers/json-schema.ts`); its `parse()` runs only `JSON.parse`, so validate the result with your zod schema. This page did not send such a schema to the API |
| A key has `.optional()` | Allowed, up to 24 optional parameters (keys outside `required`) summed over every strict tool schema and JSON output schema in the request (docs: schema complexity limits); Claude's reply lists required properties first, then optional ones; the key stays out of `required` in both modes. Above 24, move keys into `required` |
| A key has `.default()` | Output mode puts it in `required`, so a conforming reply always carries it and the zod default never fills it; to let Claude omit the key, mark it `.optional()` and apply the fallback after parsing (it then counts toward the 24) |
| `.min()`, `.max()`, `.length()` limits on a string or number | The docs list numeric and string length constraints as not supported; the helper moves them into `description` and `parse()` enforces them on the reply, which surfaces a violation as `AnthropicError` |
| Bounds on an array | The helper keeps `.min(0)` and `.min(1)` as `minItems`; every other array bound moves into `description` the same way |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Convert with `{ io: 'input' }` because the reply is what `parse()` receives (zod's input type) | Use the default output mode with the unsupported limit keywords removed, or `zodOutputFormat()` | Input mode writes no `additionalProperties: false`, which Claude requires on every object, and drops `.default()` keys from `required` |
| Pass the helper's format to `client.messages.create()` and read the text yourself | Call `client.messages.parse()` and read `parsed_output` | Only `parse()` runs the zod validation; the helper's own doc comment says that through `.create()` it "will not result in any automatic parsing" |
| Count on a zod `enum` to constrain generation through the SDK helper | Handle the `AnthropicError` that `parse()` raises for an out-of-list value | SDK 0.131.0 moves `enum` into `description`, so the request does not constrain that field |

## Sources

- https://platform.claude.com/docs/en/build-with-claude/structured-outputs (https://docs.claude.com/en/docs/build-with-claude/structured-outputs redirects here) — supported: "enum (strings, numbers, bools, or nulls only - no complex types)", "const", "default property for all supported types", "required and additionalProperties (must be set to false for objects)"; not supported: "Numerical constraints (such as minimum, maximum, multipleOf)", "String constraints (minLength, maxLength)"; "required properties appear first, followed by optional properties"; "Wrap a Zod schema in zodOutputFormat() and pass it to client.messages.parse() as output_config.format"; "How SDK transformation works": remove unsupported constraints, add them to descriptions, add `additionalProperties: false`, filter string formats, validate responses; "If you use an unsupported feature, you'll receive a 400 error with details."; schema complexity limits: "Optional parameters", 24, "Total optional parameters across all strict tool schemas and JSON output schemas. Each parameter not listed in required counts toward this limit."
- https://zod.dev/json-schema — "By default, the result of z.toJSONSchema represents the output type; use "io": "input" to extract the input type instead."; "By default, z.object() schemas contain additionalProperties: "false""; "When converting to JSON Schema in "input" mode, additionalProperties is not set."
- `@anthropic-ai/sdk` 0.131.0 (npm), read from the installed package: `src/helpers/zod.ts` (`transformJSONSchema(z.toJSONSchema(zodObject, { reused: 'ref' }))`; `parse` runs `zodObject.safeParse`; doc comment on `.create()`), `src/lib/transform-json-schema.ts` (the kept-keyword list; every leftover key appended to `description`), `src/helpers/json-schema.ts` (`transform` option, default `true`)
- Local reproduction 2026-10-07 (zod 4.6.5, @anthropic-ai/sdk 0.131.0, Node 26.7.0, no API calls): both tables above; `z.object({ a: z.string().transform((s) => s.length) })` threw "Transforms cannot be represented in JSON Schema" in output mode and converted without error in input mode
- Origin: a wiki-plan `[no-wiki]` decision gap — a plan converting a zod schema for a later Claude call recorded `io: 'input'` as rejected because it drops `additionalProperties: false`; the same note's claim that Claude also requires every key in `required` is wrong (optional keys are allowed, up to 24 per request)
