---
id: infrastructure-config-config-values-emitted-as-source-text
domain: infrastructure
category: config
applies_to: [general, android]
confidence: verified
sources:
  - https://developer.android.com/reference/tools/gradle-api/8.7/com/android/build/api/dsl/VariantDimension
  - https://developer.android.com/build/gradle-tips
last_verified: 2026-09-28
related: [infrastructure-config-environment-config, platforms-shells-option-like-argument-values]
---

# A Build Step That Writes a Config Value Into Generated Source

## When this applies

A build tool takes a configuration value from user or environment input (a
Gradle `-P` property, an env var, a CI secret) and writes it into generated
source code that a compiler then parses — Android Gradle Plugin
`buildConfigField(type, name, value)` into `BuildConfig.java`, a resource or
constants file emitted by a codegen step — and the design says "validation
happens at runtime".

## Do this

1. **Treat the value as a literal in the target language, not as data.** AGP
   documents `buildConfigField` as generating `<type> <name> = <value>;` where
   each part "must have valid Java content" and a `String` value "should include
   quotes". Escape `\` first and then `"` inside the input, wrap the result in
   quotes, and reject or encode newlines.
2. **Put the escaping in one helper** used by every emitted field, so a new
   field cannot bypass it.
3. **Add a build-time probe to the verification step:** run the build
   (`assembleDebug`, or the codegen plus its compiler) once with an input that
   contains `"` and `\`. The failure this guards against is a compile error
   (`unclosed string literal`), which happens before any runtime check runs.
4. **Keep the runtime validation** (URL parse, allow-list) — it covers values
   that compile but are wrong — and state in the design that it only runs on a
   build that compiled.

| Field type | Emit |
|------------|------|
| `String` | `"\"" + escaped(value) + "\""` — quotes included in the value argument |
| `boolean` / `int` / `long` | The parsed and re-serialized value (`true`, `42`), not the raw input text |
| Empty or unset input | An explicit literal (`""`, a documented default) — a missing value produces `= ;`, another compile error |

## Edge cases

| Case | Then |
|------|------|
| The value is a URL with a query string | `"` and `\` are still the only characters that break the literal; `?`, `&`, `=` need no escaping |
| Kotlin DSL `"\"$value\""` | Same rule: the string template concatenates the raw value into Java source |
| The input is a secret injected by CI | Escaping is still required, and the probe runs with a synthetic value containing the hostile characters, never the real secret |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `buildConfigField("String", "X", "\"$value\"")` with the raw input | Route the value through the escaping helper | A `"` in the input closes the Java literal early |
| Defer all validation to app start-up | Add a compile probe with hostile characters to the verification step | javac fails first, so the runtime check never sees the bad value |

## Sources

- https://developer.android.com/reference/tools/gradle-api/8.7/com/android/build/api/dsl/VariantDimension — `buildConfigField`: "The field is generated as: `<type> <name> = <value>;` This means each of these must have valid Java content. If the type is a String, then the value should include quotes."
- https://developer.android.com/build/gradle-tips — official example `buildConfigField("String", "BUILD_TIME", "\"${minutesSinceEpoch}\"")`, the value argument carrying its own quotes
- Field evidence 2026-09-27 (linkly-calendar Android, t2-dev-env design review): the generated line `public static final String LINKLY_API_BASE_URL = "http://a"b";` compiled with javac 17 exited 1 with `unclosed string literal`; the same line with the quote escaped exited 0. The plan's "validate at runtime" step could not run on the failing build
