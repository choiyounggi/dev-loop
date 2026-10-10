---
id: backend-node-boundaries-structured-output-schema-from-zod
domain: backend
category: boundaries
applies_to: [typescript, zod, anthropic-sdk, claude-code]
confidence: verified
sources:
  - https://platform.claude.com/docs/en/build-with-claude/structured-outputs
  - https://zod.dev/json-schema
  - https://code.claude.com/docs/en/agent-sdk/structured-outputs
  - https://code.claude.com/docs/en/cli-reference
  - https://ajv.js.org/json-schema.html
  - https://github.com/anthropics/claude-code/issues/80402
  - "Local reproduction 2026-10-11 (Claude Code 2.1.296, zod 4.6.5, ajv 8.20.0)"
last_verified: 2026-10-11
related: [backend-node-boundaries-runtime-validation]
---

# Turning a zod Schema into the JSON Schema for Claude Structured Outputs

## When this applies

TypeScript code describes the reply it wants from Claude as a zod 4 schema and sends
it as the JSON Schema of a structured-output request (`output_config.format`), or
stores, snapshots or asserts that converted schema. Also when choosing between the
SDK helper and `z.toJSONSchema`, picking the `io` mode, or when the schema uses
`.default()`, `.transform()`, `enum`/`const`, or `.min()`/`.max()` limits. Also when
the converted schema goes to the Claude Code CLI's `--json-schema` flag (`claude -p`).

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

4. **For the Claude Code CLI, pass `z.toJSONSchema(schema, { target: 'draft-7' })` to
   `--json-schema`.** The CLI validates the schema against JSON Schema draft-07 before
   any API call, and draft-7 is the target the Agent SDK docs give for zod. Measured on
   Claude Code 2.1.296 with zod 4.6.5:

| Schema passed to `claude -p --json-schema` | Result |
|------|------|
| `z.toJSONSchema(schema)` (default target, `$schema` draft 2020-12) | Exit 1 before any API call, empty stdout; stderr `Error: --json-schema is not a valid JSON Schema: no schema with key or ref "https://json-schema.org/draft/2020-12/schema"` |
| The same output with the `$schema` key deleted, plain object fields | Accepted |
| The same output with the `$schema` key deleted, schema contains a `z.tuple()` | Exit 1: `strict mode: unknown keyword: "prefixItems"` |
| `{ target: 'draft-7' }` (tuple written as `items: [...]` + `additionalItems: false`, recursion as `definitions` + `$ref`) | Accepted; a real run returned the tuple and the recursive tree in `structured_output` |
| `{ target: 'draft-4' }` | Exit 1: `no schema with key or ref "http://json-schema.org/draft-04/schema#"` |

   On every failing row stdout is empty, so check the exit code and stderr before
   parsing the CLI's output.

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
| Delete `$schema` from zod's default output so `--json-schema` accepts it | Convert with `{ target: 'draft-7' }` | The CLI's validator rejects 2020-12 keywords as unknown (strict mode), so a tuple's `prefixItems` still fails once the key is gone |

## Sources

- https://platform.claude.com/docs/en/build-with-claude/structured-outputs (https://docs.claude.com/en/docs/build-with-claude/structured-outputs redirects here) — supported: "enum (strings, numbers, bools, or nulls only - no complex types)", "const", "default property for all supported types", "required and additionalProperties (must be set to false for objects)"; not supported: "Numerical constraints (such as minimum, maximum, multipleOf)", "String constraints (minLength, maxLength)"; "required properties appear first, followed by optional properties"; "Wrap a Zod schema in zodOutputFormat() and pass it to client.messages.parse() as output_config.format"; "How SDK transformation works": remove unsupported constraints, add them to descriptions, add `additionalProperties: false`, filter string formats, validate responses; "If you use an unsupported feature, you'll receive a 400 error with details."; schema complexity limits: "Optional parameters", 24, "Total optional parameters across all strict tool schemas and JSON output schemas. Each parameter not listed in required counts toward this limit."
- https://zod.dev/json-schema — "By default, the result of z.toJSONSchema represents the output type; use "io": "input" to extract the input type instead."; "By default, z.object() schemas contain additionalProperties: "false""; "When converting to JSON Schema in "input" mode, additionalProperties is not set."; `target`: "The JSON Schema version to target." — `"draft-2020-12"` "Default. JSON Schema Draft 2020-12", `"draft-07"` "JSON Schema Draft 7"
- https://code.claude.com/docs/en/agent-sdk/structured-outputs — "The SDK validates schemas with JSON Schema draft-07, so schemas that declare a newer version are rejected. Zod targets draft 2020-12 by default, so pass `target: "draft-7"` when converting your schema."
- https://code.claude.com/docs/en/cli-reference — `--json-schema`: "Get validated JSON output matching a JSON Schema after the agent completes its workflow (print mode only)"; "Claude Code exits with an error on an invalid schema"
- https://ajv.js.org/json-schema.html — draft-07 is the default: "This version is provided as default export"; draft-2020-12 has "prefixItems that replaced array form of items keyword", and "To use draft-2020-12 schemas you need to import a different Ajv class"
- https://github.com/anthropics/claude-code/issues/80402 — open (checked 2026-10-11): "--json-schema rejects schemas declaring the draft 2020-12 meta-schema (since 2.1.214)"; its workarounds are a draft-07 schema or deleting the top-level `$schema`, and the tuple row of directive 4 is where the second one stops working
- `@anthropic-ai/sdk` 0.131.0 (npm), read from the installed package: `src/helpers/zod.ts` (`transformJSONSchema(z.toJSONSchema(zodObject, { reused: 'ref' }))`; `parse` runs `zodObject.safeParse`; doc comment on `.create()`), `src/lib/transform-json-schema.ts` (the kept-keyword list; every leftover key appended to `description`), `src/helpers/json-schema.ts` (`transform` option, default `true`)
- Local reproduction 2026-10-07 (zod 4.6.5, @anthropic-ai/sdk 0.131.0, Node 26.7.0, no API calls): both tables above; `z.object({ a: z.string().transform((s) => s.length) })` threw "Transforms cannot be represented in JSON Schema" in output mode and converted without error in input mode
- Origin: a wiki-plan `[no-wiki]` decision gap — a plan converting a zod schema for a later Claude call recorded `io: 'input'` as rejected because it drops `additionalProperties: false`; the same note's claim that Claude also requires every key in `required` is wrong (optional keys are allowed, up to 24 per request)
- Local reproduction 2026-10-11 (Claude Code 2.1.296, zod 4.6.5, Node 26.7.0): every row of the directive-4 table came from `claude --bare -p "…" --json-schema "<schema>" --output-format json` with a fake `ANTHROPIC_API_KEY`, so an accepted schema stopped at `"result":"Invalid API key · Fix external API key"` and a rejected one exited 1 with the quoted stderr and 0 bytes of stdout; one real `claude --safe-mode -p --model haiku` run with the draft-7 tuple-and-recursion schema exited 0 with `structured_output` `{"pair":["a",1],"tree":{"label":"root","children":[{"label":"leaf","children":[]}]}}`. The installed `claude.exe` contains the strings `no schema with key or ref` and `strict mode: ${…}`; Ajv 8.20.0's default `Ajv` class reproduces both messages on the same schemas and compiles the draft-07 one, while `Ajv2020` compiles the 2020-12 tuple
- Origin of directive 4: a session in another repository hit the 2020-12 error and fixed it by deleting the `$schema` key, which holds only for schemas without 2020-12 keywords (the tuple row)
