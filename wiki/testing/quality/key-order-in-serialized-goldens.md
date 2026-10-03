---
id: testing-quality-key-order-in-serialized-goldens
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://docs.python.org/3/library/stdtypes.html#mapping-types-dict
  - https://docs.python.org/3/library/json.html#json.JSONEncoder
  - https://docs.python.org/3/library/collections.html#collections.OrderedDict
  - https://www.rfc-editor.org/rfc/rfc8259#section-4
  - https://www.rfc-editor.org/rfc/rfc8259#section-9
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON/stringify
  - https://tc39.es/ecma262/ — 10.1.11.1 OrdinaryOwnPropertyKeys
last_verified: 2026-10-04
related: [testing-quality-value-preserving-refactor-assertions, qa-document-verification-generated-reference-drift-gates, testing-quality-behavior-not-implementation, testing-quality-schema-additions-under-a-golden-gate, testing-quality-stale-artifact-baselines]
---

# Key Order When Rebuilding a Map That Serializes into a Committed Golden

## When this applies

You are rewriting code that builds a dict/object which is then serialized into a
committed golden file (JSON, OpenAPI, JSON Schema, a generated reference) — for
example turning a dict literal into step-by-step assignment so one key can become
conditional — and the change is meant to leave the golden files unchanged. Also
when deciding whether to make key order irrelevant by switching to sorted keys.

## Do this

1. **Assign keys in the same order the old literal listed them.** Python dicts
   "preserve insertion order" and `json.dumps` preserves "input and output order
   by default", so the order in which each key is *first* inserted is the order
   of the bytes. JavaScript is the same for ordinary string keys: `JSON.stringify`
   visits properties with the `Object.keys()` algorithm, which the spec defines
   as array-index keys in ascending numeric order, then the other string keys in
   "ascending chronological order of property creation".
2. **Write the conditional key in its old slot, not at the end.** When the key
   that becomes optional sat between two others, open the `if` at that position
   and continue assigning the following keys after it — moving it to the end
   reorders every golden that still contains it.
3. **Regenerate every golden the generator owns and byte-compare each one with
   the committed file** (`git diff --exit-code -- <golden dir>` plus an empty
   `git status --porcelain -- <golden dir>`, which also catches a new untracked
   golden; or the generator's `--check` mode), not only the files a test pins. A golden test that pins a
   subset of the outputs passes while the rest change.
4. **Read a byte diff with no semantic change as a key-order or formatting
   regression in your rewrite** — `diff` the two files to see which — and fix
   the assignment order or the dump arguments rather than re-committing the goldens.
   Re-committing turns a no-op refactor into a churn diff across every file.

| Byte comparison after regenerating | Then |
|---|---|
| Every golden identical | The rewrite is byte-preserving; commit code only |
| A golden differs, and parsing both sides gives equal objects | Key order or formatting (`indent`, `separators`, `ensure_ascii`, trailing newline) moved — `diff` to tell which, then restore the old assignment order or dump arguments |
| A golden differs, and the parsed objects differ | A real output change — decide whether it is intended before touching any golden |

## Edge cases

| Case | Then |
|------|------|
| The generator serializes with `sort_keys=True` (or a canonicalizing stringify) | Assignment order cannot change the bytes; byte-compare all goldens anyway for the semantic changes |
| You want key order to stop mattering for good | Switch the generator to sorted keys in its own commit that regenerates every golden once and changes nothing else — Python's docs name `sort_keys` as "useful for regression tests" |
| Array-index keys in a JavaScript object (canonical integers `"0"`…`"4294967294"`) | They serialize first, in ascending numeric order, ahead of all other string keys regardless of insertion; `"01"`, `"-1"`, `"1.5"`, `"4294967295"` are ordinary string keys and keep insertion order — `JSON.stringify({"01":1,b:1,"1":1,"4294967295":1,"4294967294":1})` → `{"1":1,"4294967294":1,"01":1,"b":1,"4294967295":1}` |
| Python dict: a key is assigned twice, or the dict is built by `{**a, **b}` / `update` / `setdefault` | The key stays where it was first inserted — "updating a key does not affect the order"; `{**{"a":1,"b":2}, **{"b":3,"a":4}}` keeps `a, b`. Place the key in the first assignment or first merged dict at the position the golden needs; deleting then re-adding moves it to the end |
| The dict comes from `dataclasses.asdict` or a model's dump method | Field declaration order sets the bytes; reorder the field declarations, not the call site (reproduced: fields `b, a` → `asdict` keys `b, a`) |
| Both sides are `OrderedDict` | `==` already checks order — "Equality tests between OrderedDict objects are order-sensitive" — but still byte-compare the serialized output for formatting changes |
| The generator writes YAML, TOML, or another format | Read that writer's key-order behaviour in its docs (some sort by default, some group nested tables after scalars), then byte-compare after regenerating to see the order it actually wrote |
| The golden is consumed by a tool that ignores member order | Bytes still matter: the committed file is the review surface and the gate's diff, and RFC 8259 notes parsers differ on whether they expose member order |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust a green `assert old == new` dict comparison as proof the golden is unchanged | Serialize both and compare the bytes, or regenerate and `git diff --exit-code` | Plain dicts "compare equal if and only if they have the same (key, value) pairs (regardless of ordering)", so equality hides a reordering the serializer writes out |
| Run only the golden test that pins some outputs | Regenerate and byte-compare every output the generator produces | Unpinned goldens drift with no red test |
| Append the newly conditional key after all the others | Assign it at its old position inside the `if` | Appending reorders the key in every golden that still contains it |
| Re-commit the goldens to make a key-order diff go away | Restore the assignment order | The refactor was meant to change no output; a re-commit hides that it did |

## Sources

- https://docs.python.org/3/library/stdtypes.html#mapping-types-dict — "Dictionaries compare equal if and only if they have the same (key, value) pairs (regardless of ordering)"; "Dictionaries preserve insertion order. Note that updating a key does not affect the order. Keys added after deletion are inserted at the end."; "Changed in version 3.7: Dictionary order is guaranteed to be insertion order"
- https://docs.python.org/3/library/json.html#json.JSONEncoder — module intro: "This module's encoders and decoders preserve input and output order by default. Order is only lost if the underlying containers are unordered."; `JSONEncoder`: "If sort_keys is true (default: False), then the output of dictionaries will be sorted by key; this is useful for regression tests to ensure that JSON serializations can be compared on a day-to-day basis."
- https://docs.python.org/3/library/collections.html#collections.OrderedDict — "Equality tests between OrderedDict objects are order-sensitive"
- https://www.rfc-editor.org/rfc/rfc8259#section-4 — "An object is an unordered collection of zero or more name/value pairs"
- https://www.rfc-editor.org/rfc/rfc8259#section-9 — "JSON parsing libraries have been observed to differ as to whether or not they make the ordering of object members visible to calling software"
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON/stringify — "Properties are visited using the same algorithm as Object.keys(), which has a well-defined order and is stable across implementations"
- https://tc39.es/ecma262/ (10.1.11.1 OrdinaryOwnPropertyKeys) — array-index keys "in ascending numeric index order", then String keys that are not array indices "in ascending chronological order of property creation"; an array index is an integer index in "the inclusive interval from +0 to 2^32 - 2"
- Reproduction 2026-10-04 (Python 3, Node): `{"type":…,"properties":…,"required":[…],"additionalProperties":False}` vs the same keys assigned with `additionalProperties` before `required` → `old == new` True, `json.dumps` bytes equal False, bytes equal with `sort_keys=True` True; the Node equivalent gives `JSON.stringify` bytes equal false
- Field observation 2026-10-03 (an OpenAPI generator's response-schema builder rewritten so `required` could be omitted): the step-by-step version first assigned `required` after `additionalProperties`; caught before running, the order was restored, and all six committed example `*.openapi.json` goldens regenerated byte-identical while the golden test pinned only a subset of them
