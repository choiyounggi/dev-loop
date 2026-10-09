---
id: backend-java-kotlin-coerced-enum-defaults-in-kotlinx-serialization
domain: backend
category: kotlin
applies_to: [kotlin, android, general]
confidence: verified
sources:
  - https://github.com/Kotlin/kotlinx.serialization/blob/master/docs/json.md
last_verified: 2026-09-28
related: [backend-java-kotlin-null-safety-interop, backend-java-kotlin-frameworks-and-jpa, testing-quality-schema-additions-under-a-golden-gate]
---

# Enum Defaults Under `coerceInputValues` in kotlinx.serialization

## When this applies

A `@Serializable` model is decoded with a shared `Json { coerceInputValues =
true }` (common in Android and Ktor clients so third-party payloads do not
crash on `null`), the model has enum-typed properties, and the contract says an
unknown enum value is an error. Also when reviewing a diff that adds `= Enum.X`
as a default to such a property.

## Do this

1. **Declare an enum property that must reject unknown values as required:
   non-nullable and without a default.** Coercion "treats a limited subset of
   invalid input values as if the corresponding property was missing" — `null`
   for non-nullable types and unknown enum values — and a missing value "is
   replaced either with a default property value if it exists, or with a `null`
   if `explicitNulls` is `false` and the property is nullable". With neither, the
   property is missing and decoding throws.
2. **Pin it with a decode test** that feeds an unknown enum string and expects
   `SerializationException`. The test is what turns a later "harmless" default
   into a red build instead of wrong data.
3. **When forward compatibility is wanted, make it explicit:** add an `UNKNOWN`
   member, default to it, and test that an unknown input maps to `UNKNOWN` — the
   coercion is then a documented behaviour with a visible sentinel.
4. **Treat any new default on a `@Serializable` enum property as a contract
   change** in review: it changes what unknown input decodes to.

| Property shape (with `coerceInputValues = true`) | Unknown enum value in the input decodes to |
|-----------------------------------------------|---------------------------------------------|
| Non-nullable, no default | Throws — the property counts as missing |
| Has a default | The default, silently |
| Nullable, no default, `explicitNulls = false` | `null` |

## Edge cases

| Case | Then |
|------|------|
| The shared `Json` is used for both strict and lenient models | Keep one `Json`; encode strictness in the property shape (row 1) rather than a second config that call sites can pick wrongly |
| `null` arrives for a non-nullable enum | Same rule: with a default it becomes the default, without one decoding throws |
| The enum gains a member on the server before the client ships | Row 1 makes old clients fail loudly on the new value; choose row 3 deliberately if old clients must keep working |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `= Category.ETC` to a required enum field "to be safe" | Keep it required and rely on the decode test | Under coercion the default turns a contract violation into wrong data |
| Turn off `coerceInputValues` for one model | Shape the property (required vs `UNKNOWN` default) | The config is shared; the property shape is local and testable |

## Sources

- https://github.com/Kotlin/kotlinx.serialization/blob/master/docs/json.md — "Coercing input values": the supported invalid values are "`null` inputs for non-nullable types" and "unknown values for enums"; "If value is missing, it is replaced either with a default property value if it exists, or with a `null` if explicitNulls flag is set to `false` and a property is nullable (for enums)"; the `Brush(foreground: Color = Color.BLACK, background: Color?)` example decodes unknown `"pink"`/`"purple"` to `BLACK` and `null`
- Field evidence 2026-09-27 (linkly-calendar Android, `TripPlace.category`): adding `= TripPlaceCategory.ETC` to the required enum property made `tripPlace_unknownCategory_throws` fail (9 tests, 1 failed); removing the default restored green
