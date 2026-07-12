---
id: backend-java-kotlin-frameworks-and-jpa
domain: backend
category: kotlin
applies_to: [kotlin, spring, jpa, hibernate]
confidence: verified
sources:
  - https://kotlinlang.org/docs/all-open-plugin.html
  - https://kotlinlang.org/docs/no-arg-plugin.html
  - https://blog.jetbrains.com/idea/2026/01/how-to-avoid-common-pitfalls-with-jpa-and-kotlin/
  - https://kotlinlang.org/docs/annotations.html
  - https://docs.spring.io/spring-framework/reference/languages/kotlin/coroutines.html
last_verified: 2026-07-10
related: [backend-java-spring-proxy-pitfalls, backend-java-jpa-entity-mapping, backend-java-kotlin-coroutines-dispatchers-and-blocking, backend-common-orm-transaction-boundaries, databases-schema-design-nullability-and-defaults]
---

# Kotlin Class Shape for Spring and JPA

## When this applies

Setting up or reviewing a Kotlin + Spring/JPA project: entities written as data
classes, "No default constructor for entity" errors, proxies failing on final
classes, Bean Validation annotations not firing, repositories called from coroutines.

## Do this

1. Kotlin classes are **final by default**, and Spring proxies (`@Transactional`,
   `@Async`, `@Cacheable`) plus Hibernate lazy proxies need open classes with no-arg
   constructors. Configure this in the build file with compiler plugins — manual
   `open` on every class rots as classes are added:

| Plugin | What it does |
|--------|-------------|
| `kotlin-spring` (all-open wrapper) | Opens classes annotated or meta-annotated with `@Component`, `@Transactional`, `@Async`, `@Cacheable`, `@Configuration`/`@Service`/`@Controller`... so CGLIB can subclass them |
| `kotlin-jpa` (no-arg wrapper) | Generates synthetic no-arg constructors for `@Entity`, `@Embeddable`, `@MappedSuperclass` classes |

   Diagnosing an annotation that silently does nothing (the symptom table) →
   [backend-java-spring-proxy-pitfalls].
2. Shape each class by its role:

| Class | Shape |
|-------|-------|
| `@Entity` | Regular class, NOT a data class — data-class `equals`/`hashCode` covers every property, which breaks with lazy proxies and changes as state mutates (entity identity rules → [backend-java-jpa-entity-mapping]); `copy()` duplicates the id and detaches identity |
| Entity id / association properties | `var` (or `lateinit var` for to-one associations assigned after construction) as the mapping requires; expose intent through behavior methods, not by making every property publicly settable |
| DTOs, value objects, projections | Data classes — exactly what they are for (value equality, `copy`, destructuring) |

3. Align property nullability with column nullability: a Kotlin non-null property
   mapped to a nullable column materializes null at runtime and throws far from the
   query that loaded it. Generated ids are null before persist — declare them
   nullable (`var id: Long? = null`). Column-side rules →
   [databases-schema-design-nullability-and-defaults].
4. Property default values do not translate to DDL — they apply only when Kotlin
   code constructs the object. Declare the column default in the schema when the
   database must enforce it.
5. Put Bean Validation annotations on the field with an explicit use-site target:
   `@field:NotNull`, `@field:Size(...)`. On Kotlin ≤ 2.1 a bare annotation on a
   primary-constructor property lands on the constructor **parameter**, where the
   validator never looks; Kotlin 2.2+ also annotates the field, and the explicit
   target is correct on every version.
6. Coroutines + JPA: JDBC/JPA is blocking — run repository calls in
   `withContext(Dispatchers.IO)` → [backend-java-kotlin-coroutines-dispatchers-and-blocking].
   Spring's coroutine transaction support exists only for the reactive stack
   (`TransactionalOperator.executeAndAwait`); JPA's transaction is bound to the
   thread and does not follow a coroutine across suspension points. Keep each JPA
   transaction inside one blocking, non-suspending block — `@Transactional` on a
   blocking service method called from `withContext(Dispatchers.IO)`. Boundary
   placement rules → [backend-common-orm-transaction-boundaries].

## Edge cases

| Case | Then |
|------|------|
| `InstantiationException` / "No default constructor for entity" at load time | The `kotlin-jpa` plugin is missing or the class lacks its annotation (`@Entity`/`@Embeddable`/`@MappedSuperclass`) — fix the build, not the constructor |
| `@Transactional` bean works, but a newly added collaborator class is not proxied | Its annotation is not in the `kotlin-spring` open list — annotate with a covered stereotype or add the annotation to the all-open configuration |
| Entity property is `val` and JPA appears to work | Reflection writes through `val`, silently voiding Kotlin's immutability guarantee — declare mapped mutable state as `var` so the code tells the truth |
| Validation fires in tests but not on request DTOs (or vice versa) | Check the use-site target (rule 5) and whether that path validates fields or constructor parameters — the explicit `@field:` target removes the divergence |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Declare an `@Entity` as a `data class` | Regular class; identity-based `equals`/`hashCode` per [backend-java-jpa-entity-mapping] | All-property equality breaks with lazy proxies and mutation; `copy()` clones the id |
| Hand-write `open` on every bean and entity | `kotlin-spring` + `kotlin-jpa` plugins in the build file | Build-level opening cannot be forgotten on the next class; manual `open` rots |
| Mark a `suspend` function `@Transactional` over JPA | Blocking `@Transactional` method, called via `withContext(Dispatchers.IO)` | The JPA transaction is thread-bound; a suspension point can resume on another thread, outside the transaction |
| Rely on Kotlin default values as column defaults | Declare the default in the schema (DDL) | Construction-time defaults never reach rows written by SQL, migrations, or other services |

## Sources

- https://kotlinlang.org/docs/all-open-plugin.html — classes final by default; `kotlin-spring` opens `@Component`/`@Async`/`@Transactional`/`@Cacheable`/`@SpringBootTest` and meta-annotated stereotypes
- https://kotlinlang.org/docs/no-arg-plugin.html — `kotlin-jpa` generates synthetic no-arg constructors for `@Entity`/`@Embeddable`/`@MappedSuperclass`
- https://blog.jetbrains.com/idea/2026/01/how-to-avoid-common-pitfalls-with-jpa-and-kotlin/ — data classes a bad fit for entities; regular open classes; nullable generated ids; reflection writes through `val`
- https://kotlinlang.org/docs/annotations.html — use-site targets; bare primary-constructor annotation targeting (param on ≤2.1, param+field on 2.2+); `@field:` syntax
- https://docs.spring.io/spring-framework/reference/languages/kotlin/coroutines.html — coroutine transactions supported via the programmatic reactive variant only
