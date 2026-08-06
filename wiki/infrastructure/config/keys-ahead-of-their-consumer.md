---
id: infrastructure-config-keys-ahead-of-their-consumer
domain: infrastructure
category: config
applies_to: [general]
confidence: verified
sources:
  - https://pydantic.dev/docs/validation/latest/api/pydantic/config/
  - https://json-schema.org/understanding-json-schema/reference/object
  - https://serde.rs/container-attrs.html
last_verified: 2026-08-05
related: [infrastructure-config-environment-config, backend-common-integrations-externally-owned-defaults, backend-node-boundaries-runtime-validation, backend-python-boundaries-runtime-validation]
---

# Writing a Config Key Before the Consumer That Reads It Ships

## When this applies

You are adding a key to a config file that a component outside your repository
parses — a plugin, hook, agent tool, sidecar, or vendored binary — and the key
belongs to a version of that component which has not shipped yet. Also when
reviewing a change justified by "older versions just ignore unknown keys".

## Do this

1. **Open the consumer's parsing code and read how it handles a key it does not
   know**, before adding the key. The consumer's behavior is the fact; the schema
   document describes intent and is written by the same people who can tighten the
   parser in the next release.

| What the consumer uses to read config | Unknown key | Safe to pre-declare? |
|---------------------------------------|-------------|----------------------|
| A path query per known key (`jq '.rules[$r].mode'`, `cfg.get("x")`, a hand-written getter) | Never read | Yes — nothing enumerates the object |
| A permissive model binding (pydantic default `extra='ignore'`, JSON Schema without `additionalProperties`) | Dropped | Yes, while that setting holds |
| A strict model binding (`extra='forbid'`, `additionalProperties: false`, serde `deny_unknown_fields`) | Hard validation error | No — the process fails to start on the key alone |

2. **Record the evidence next to the key**, as a comment carrying the date and the
   `file:line` you read: which parser, which version, what it does with unknown
   keys. A reviewer six months later cannot re-derive why the key was considered
   safe, and the consumer will have moved.
3. **Pin what you verified against**, by naming the consumer version in the same
   comment. "Unknown keys are ignored" is a property of one release, not of the
   project.
4. **When the parser is strict, or you cannot read it, keep the key out of the
   shipped config** and stage it instead: land it behind the consumer upgrade, or
   in a separate file the current version does not load.
5. **Prefer the failure to be loud and local.** When the pre-declared key matters
   for correctness once it activates, add your own startup assertion that the
   consumer version supports it, so a silently-ignored key does not read as an
   enabled control ([infrastructure-config-environment-config] owns startup
   validation shape).

## Edge cases

| Case | Then |
|------|------|
| The consumer validates with JSON Schema composed via `allOf`/`anyOf` | Check for `unevaluatedProperties: false` as well — it "can recognize properties declared in subschemas" and rejects keys that plain `additionalProperties` would let through |
| The consumer is a shell script reading with `jq`/`grep` | Path queries never enumerate, so unknown keys are inert; confirm no branch iterates the object (`keys[]`, `to_entries`) before concluding that |
| Several consumers read the same file (a tool plus its CI validator) | The strictest parser decides — check every reader, not the one you had in mind |
| The key you want exists upstream but is unimplemented in the installed version | Verify by searching the installed tree for the key name; zero hits plus a per-key path query means inert-but-present, which is the safe case |
| The consumer is one you also own | Ship the reader first, then the key — the ordering problem disappears and no comment is needed |
| The key carries a security control (allow-list, path restriction) | Treat silent ignoring as the dangerous case, not the safe one: an ignored restriction reads as enforced. Gate on the version assertion in step 5 |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add an unreleased key because "unknown keys are ignored" | Read the consumer's parsing code and record what it actually does | Tolerance is a per-parser setting, not a convention; a strict binding turns the same key into a startup failure of every worker that loads the file |
| Cite the upstream schema document as evidence | Cite the installed parser at `file:line` with a date | The document states the intended shape; the code states what happens to your key in the version deployed now |
| Leave the key with no note once verified | Comment the parser, version, `file:line`, and date | The next reader sees a key nothing implements and cannot tell "verified inert" from "leftover typo" |
| Assume an ignored security-relevant key is harmless | Assert the supporting version at startup, or withhold the key | A dropped restriction looks identical to an enforced one from inside the config file |

## Sources

- https://pydantic.dev/docs/validation/latest/api/pydantic/config/ — `extra` takes `'ignore'`, `'forbid'`, `'allow'` with `'ignore'` as the default; with `extra='forbid'` "Providing extra data is not permitted, and a `ValidationError` will be raised if this is the case" ("Extra inputs are not permitted")
- https://json-schema.org/understanding-json-schema/reference/object — "By default any additional properties are allowed"; "Setting the `additionalProperties` schema to `false` means no additional properties will be allowed"; `unevaluatedProperties` "is similar to `additionalProperties` except that it can recognize properties declared in subschemas"
- https://serde.rs/container-attrs.html — by default "unknown fields are ignored for self-describing formats like JSON"; `#[serde(deny_unknown_fields)]` makes it "always error during deserialization when encountering unknown fields"

## Field context

Verified 2026-08-05 against an installed `guardrails` 1.0.0 plugin before
pre-declaring an `allowPaths` key: `hooks/bash-guard.sh:71` reads config with
`jq -r --arg r "$id" '.rules[$r].mode // empty'` — a per-rule path query that
never enumerates the object — and `grep -rn allowPaths` over the whole installed
tree returned zero hits. The key is therefore unimplemented but inert in that
version, which is the row-1 case above; the same key against a
`deny_unknown_fields`-style reader would have stopped every worker that loads the
file.
