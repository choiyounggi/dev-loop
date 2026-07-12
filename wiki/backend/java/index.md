# backend/java — Stack Subtree Index

Route here for: JVM (Java/Kotlin, Spring, JPA/Hibernate) stack-specific backend
concerns, including Kotlin-only cases — null-safety at Java boundaries, coroutines,
Kotlin class shape for Spring/JPA (the `kotlin` category; shared JVM/Spring/JPA
mechanics stay in the jpa/spring/runtime pages). Language-agnostic principles →
wiki/backend/common/ (backend domain index routes both).

Match your situation to a "load when" line; load only matching pages. When a common
page owns the principle (transaction boundaries, async failure routing, pool sizing),
load it alongside the stack page here — these pages link the exact ids.

## jpa

| Page | Load when |
|------|-----------|
| [entity-mapping](jpa/entity-mapping.md) | Writing or reviewing JPA entity classes/associations — fetch types (to-one EAGER default), bidirectional sync helpers, entity equals/hashCode; debugging `LazyInitializationException`, `MultipleBagFetchException`, entities vanishing from Sets, or unexpected joins/queries traced to mappings; deciding DTO projection vs entity for read-only endpoints; evaluating Open Session in View |
| [persistence-context](jpa/persistence-context.md) | Debugging changes saved without calling save (dirty checking), stale reads within one transaction (first-level cache), flush timing surprises around queries, detached-entity errors (merge vs persist, lost updates after merge); designing or fixing slow/memory-hungry JPA batch inserts; choosing IDENTITY vs SEQUENCE id generation for batch-heavy tables |

## spring

| Page | Load when |
|------|-----------|
| [proxy-pitfalls](spring/proxy-pitfalls.md) | A Spring annotation (`@Transactional`/`@Async`/`@Cacheable`/`@Retryable`) silently has no effect at runtime; reviewing where such annotations are placed — self-invocation, non-public methods, final classes/methods (Kotlin), calls from constructors/`@PostConstruct`; writing tests that assert the annotation's effect |

## runtime

| Page | Load when |
|------|-----------|
| [threads-and-memory](runtime/threads-and-memory.md) | Choosing platform vs virtual threads for blocking-I/O JVM services; thread-pool exhaustion under blocking I/O; virtual-thread pinning (`synchronized`, pre-Java-24); diagnosing rising heap/old-gen (heap dumps, dominator tree), container OOMKilled without Java `OutOfMemoryError` (heap vs cgroup limit, `-Xmx` sizing), or RSS growth with stable heap (native/direct memory) |

## kotlin

Kotlin-only cases. JVM/Spring/JPA mechanics shared with Java live in the categories
above — these pages link them by id rather than restating them.

| Page | Load when |
|------|-----------|
| [null-safety-interop](kotlin/null-safety-interop.md) | `NullPointerException` in Kotlin code whose types say the value cannot be null; calling Java APIs (libraries, frameworks, owned Java code) from Kotlin; reviewing uses of `!!`, `lateinit`, or platform types (`String!` in errors/tooltips) |
| [coroutines-structured-concurrency](kotlin/coroutines-structured-concurrency.md) | Launching coroutines in a backend service (fire-and-forget work, parallel calls); coroutines leaking or surviving past the request/component that started them; exceptions from `launch {}` vanishing or cancelling unrelated work; choosing coroutineScope vs supervisorScope vs a component scope; cancellation not taking effect or being swallowed |
| [coroutines-dispatchers-and-blocking](kotlin/coroutines-dispatchers-and-blocking.md) | Choosing a dispatcher for coroutine work; calling blocking libraries (JDBC, sync HTTP clients, file I/O) from coroutines; `runBlocking` appearing in server code; all coroutines stalling together under load; timing out blocking calls from coroutines |
| [frameworks-and-jpa](kotlin/frameworks-and-jpa.md) | Setting up or reviewing a Kotlin + Spring/JPA project — entities written as data classes, "No default constructor for entity" errors, proxies failing on final Kotlin classes (kotlin-spring/kotlin-jpa plugins), Bean Validation annotations not firing (`@field:` targets), entity property nullability vs column nullability, repositories or `@Transactional` called from coroutines |
