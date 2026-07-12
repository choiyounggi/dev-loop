---
id: backend-java-kotlin-null-safety-interop
domain: backend
category: kotlin
applies_to: [kotlin, java, jvm]
confidence: verified
sources:
  - https://kotlinlang.org/docs/java-interop.html
  - https://kotlinlang.org/docs/null-safety.html
  - https://kotlinlang.org/docs/properties.html
  - https://docs.spring.io/spring-framework/reference/languages/kotlin/null-safety.html
last_verified: 2026-07-10
related: [backend-java-kotlin-frameworks-and-jpa]
---

# Kotlin Null Handling at Java and Framework Boundaries

## When this applies

A `NullPointerException` in Kotlin code whose types say the value cannot be null;
calling Java APIs (libraries, frameworks, owned Java code) from Kotlin; reviewing
uses of `!!`, `lateinit`, or platform types (`String!` in an error/IDE tooltip).

## Do this

1. Apply the mental model: a value from un-annotated Java has a **platform type**
   (`String!`) — the compiler relaxes null checks on it, so a Java-returned null
   throws where Kotlin **first uses** the value, which can be far from the Java call
   that produced it. The fix is always at the boundary, not at the crash site.
2. At every Java/framework boundary, declare the Kotlin type explicitly and handle
   the value by the row that matches:

| Case | Do |
|------|----|
| Java side has no nullability annotations | Declare the receiving type as nullable (`val name: String? = javaCall()`) — never leave the platform type inferred when the value crosses function boundaries |
| Java side is `@Nullable`/`@NotNull`-annotated (JetBrains, JSpecify, ...) | Use it as the real Kotlin type the compiler maps it to; annotate Java code you own so its consumers get checked types |
| Value can legitimately be absent | Nullable type + `?.` / `?:` with a decided default or an early return — the null branch is a designed outcome, not an error |
| Value must exist by construction | `checkNotNull(value) { "message naming what was expected" }` (or `require`) at the boundary — fail loud at entry, not deep inside |
| Framework-injected / late-bound property | `lateinit var`; access before init throws `UninitializedPropertyAccessException`, so guard teardown/optional paths with `::prop.isInitialized`. When the framework supports constructor injection, inject through the constructor and drop `lateinit` |
| Collection/generic from Java (`List<String!>!`) travels beyond the boundary function | Copy into a Kotlin-typed collection at the boundary (`javaList.map { requireNotNull(it) }` or `.filterNotNull()` when absence is legitimate) — element types stay unchecked otherwise |

3. Treat every `!!` as a claim with no evidence. On review, each one becomes either
   a boundary assertion with a message (`checkNotNull`/`require` — same crash point,
   named cause) or a nullable-flow redesign (`?.`/`?:`/early return). After the pass,
   remaining `!!` count is zero.

## Edge cases

| Case | Then |
|------|------|
| NPE stack trace points at a Kotlin line containing no obvious dereference | The compiler emits intrinsic null assertions where platform values enter Kotlin declarations — the null came from the Java call feeding that line; fix that boundary's type |
| Calling Spring Framework APIs | Spring's API is null-annotated with JSpecify and Kotlin 2.1+ enforces it strictly — treat Spring signatures as real Kotlin types, no defensive nullable wrapping |
| `lateinit` property read in `@PreDestroy`/shutdown while init never ran | Guard with `::prop.isInitialized` before touching it — teardown runs even when startup failed early |
| Java code can mutate a shared collection after Kotlin typed it non-null | Copy at the boundary (rule 2, last row); a live view keeps the unchecked aliasing |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Sprinkle `!!` to silence the compiler | One `checkNotNull(x) { "..." }` at the boundary where the value enters | `!!` crashes with a bare NPE at the deepest use; the boundary check crashes at entry with a named cause |
| Catch `NullPointerException` around a Java call | Declare the result nullable and branch on it | The NPE is a type declaration error, not an exceptional condition; catching it hides which value was null |
| Leave `val x = javaCall()` inferred as a platform type | Write the explicit type annotation (`val x: Foo?` or `Foo`) | Explicit annotation restores compiler null checks; inferred platform types propagate uncheckedness |
| Use `lateinit` for a dependency the framework can constructor-inject | Constructor injection | The compiler proves initialization; `lateinit` defers the proof to runtime |

## Sources

- https://kotlinlang.org/docs/java-interop.html — platform type notation (`T!`, `(Mutable)Collection<T>!`), relaxed null checks on Java values, nullability-annotation mapping to real Kotlin types, "add an explicit type annotation to restore null-safety checks"
- https://kotlinlang.org/docs/null-safety.html — `?.`, `?:`, `!!` throwing NPE, platform types and Java-interop generics listed as the NPE causes
- https://kotlinlang.org/docs/properties.html — `lateinit var`, `UninitializedPropertyAccessException`, `::prop.isInitialized`
- https://docs.spring.io/spring-framework/reference/languages/kotlin/null-safety.html — Spring API null-annotated via JSpecify; Kotlin 2.1 strict enforcement
