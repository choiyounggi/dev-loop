---
id: backend-java-spring-jackson-3-jsonnode-coercion
domain: backend
category: spring
applies_to: [java, kotlin, spring, jackson]
confidence: verified
sources:
  - https://javadoc.io/static/tools.jackson.core/jackson-databind/3.0.0/tools.jackson.databind/tools/jackson/databind/JsonNode.html
  - https://docs.openrewrite.org/recipes/java/jackson/upgradejackson_2_3_jsonnodemethodrenames
last_verified: 2026-10-29
related: [backend-common-errors-exception-handling, backend-common-change-impact-call-site-enumeration, testing-quality-minimum-case-set]
---

# Jackson 3 `JsonNode.asString()` / `asDouble()` Throwing on Object and Array Nodes

## When this applies

You are moving JSON tree-model code from Jackson 2 (`com.fasterxml.jackson.databind`)
to Jackson 3 (`tools.jackson.databind`, the default with Spring Boot 4), and renaming
`asText()` to `asString()` or keeping `asDouble()`/`asInt()` calls as they were. This
applies to any call on a node that can hold an object or an array. In Jackson 2 those
calls returned `""` or `0`; in Jackson 3 the no-default form throws `JsonNodeException`.

## Do this

1. List every `asString()` / `asXxx()` call with no argument that reads a field
   from input you do not control: external API responses, user JSON, or
   heterogeneous arrays ([backend-common-change-impact-call-site-enumeration]).
2. Pick the call by what the node can hold:

| Node can hold | Call |
|---------------|------|
| A JSON scalar only (string, number, boolean), guaranteed by a schema you own | `asString()` / `asDouble()`; a container there is a contract break, and the exception reports it |
| Missing or JSON `null` | `asString()` returns `""` on missing/null nodes (reproduced on 3.1.7); write `asString("")` when the intent should be visible |
| An object or array is possible | `asString("")`, `asDouble(0.0)`, `asInt(0)`; the Javadoc says the default form returns the default "instead of throwing an exception for non-coercible values" |
| Absence must be told apart from the default value | `asStringOpt()` (empty `Optional` instead of an exception) |
| Anything other than a JSON string must be rejected | `stringValue()`; it throws `JsonNodeException` on a non-string by design, so catch that type at the call site |

3. Add a test case that puts an object (`{}`) and an array (`[]`) at each changed
   field and asserts the per-field result. Revert the fix once and confirm the test
   fails inside `BaseJsonNode.asString` ([testing-quality-minimum-case-set]).
4. Narrow any outer `catch (Exception e)` around the parsing code. A catch-all
   turns one field's `JsonNodeException` into "the whole response failed", so a
   single odd field drops every other field
   ([backend-common-errors-exception-handling]).

## Edge cases

| Case | Then |
|------|------|
| The rename came from the OpenRewrite Jackson 2→3 recipe | The recipe renames the method (`asText(..)` → `asString`). `asText()` with no argument becomes `asString()` with no argument and throws on containers, so review each such site with step 2 |
| The same recipe also maps `textValue()` to `asString` | `textValue()` returned `null` for a non-text node in Jackson 2. Check whether the code relied on that `null` before accepting the mapped call; `stringValue()` or `asStringOpt()` may match the old intent better |
| The value is deserialized into a POJO/record, not read from the tree | Coercion follows `DeserializationFeature` / coercion config, not these `JsonNode` accessors; this page does not cover it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rename `asText()` → `asString()` everywhere and call the migration done when it compiles | Classify each site with step 2 and add the container test | The rename compiles, but a value that used to read as `""` now throws |
| Wrap the parse in `try { … } catch (Exception e) { return error; }` to "make it safe" | Use the default-taking accessor for the field, and catch `JsonNodeException` only where rejecting is the intent | The catch-all fails the whole result because of one field |

## Sources

- https://javadoc.io/static/tools.jackson.core/jackson-databind/3.0.0/tools.jackson.databind/tools/jackson/databind/JsonNode.html — `asString(String defaultValue)`: "instead of throwing an exception for non-coercible values or coercing null (or missing value), will return the specified default value"; `stringValue()` works "if (and only if) node contains JSON String or null value: if not, a JsonNodeException will be thrown"; `asStringOpt()` returns an empty `Optional` instead of throwing (read through a search summary of the 3.0.0 and 3.2.x Javadoc pages; the page itself was not fetched in this run)
- https://docs.openrewrite.org/recipes/java/jackson/upgradejackson_2_3_jsonnodemethodrenames — the Jackson 2→3 `JsonNode` rename recipe lists `asText(..)` → `asString` and `textValue()` → `asString` (read through a search summary)
- Field reproduction 2026-10-29 (a Spring Boot 4 migration, jackson-databind 3.1.7 jar run directly): `ObjectNode.asString()` threw, `asString("")` returned `""`, `asString()` on Missing/Null nodes returned `""`, `ObjectNode.asDouble()` threw. With the fix reverted, the regression test failed at `BaseJsonNode.asString(BaseJsonNode.java:393)`
