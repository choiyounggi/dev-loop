---
id: backend-java-jpa-not-null-check-and-lifecycle-callbacks
domain: backend
category: jpa
applies_to: [java, kotlin, jpa, hibernate, spring]
confidence: verified
sources:
  - https://github.com/hibernate/hibernate-orm/blob/5.6/hibernate-core/src/main/java/org/hibernate/engine/internal/Nullability.java
  - https://github.com/hibernate/hibernate-orm/blob/6.6/hibernate-core/src/main/java/org/hibernate/event/internal/DefaultFlushEntityEventListener.java
  - https://github.com/hibernate/hibernate-orm/blob/6.6/hibernate-core/src/main/java/org/hibernate/action/internal/AbstractEntityInsertAction.java
  - https://github.com/hibernate/hibernate-orm/blob/6.6/hibernate-core/src/main/java/org/hibernate/boot/beanvalidation/TypeSafeActivator.java
  - https://docs.hibernate.org/orm/6.6/javadocs/org/hibernate/cfg/ValidationSettings.html
  - https://docs.hibernate.org/orm/6.6/javadocs/org/hibernate/boot/spi/SessionFactoryOptions.html
  - https://thorben-janssen.com/hibernate-tips-whats-the-difference-between-column-nullable-false-and-notnull/
  - https://www.baeldung.com/hibernate-not-null-error
last_verified: 2026-08-13
related: [backend-java-jpa-persistence-context, backend-java-kotlin-frameworks-and-jpa, databases-schema-design-nullability-and-defaults, databases-data-survey-audit-columns-as-update-evidence]
---

# Attributing Hibernate's Not-Null Check Exception, and Knowing Whether It Runs

## When this applies

A write fails with `PropertyValueException: not-null property references a null or
transient value : <path>` and you must decide which attribute and which code path
produced it; you are about to fix it inside a `@PreUpdate` listener; or you are asking
why an entity's `nullable = false` was never enforced before (or stopped being).

Column-side nullability design → [databases-schema-design-nullability-and-defaults].
Reading the failed rows' audit columns → [databases-data-survey-audit-columns-as-update-evidence].

## Do this

1. Identify the attribute from the **path shape**, not from the words "or transient".
   `Nullability` throws this message from two sites that share one hardcoded literal —
   it is the only production occurrence of that string in hibernate-orm — so the
   wording says nothing about which site fired:

| Path in the message | Means | Inspect |
|---------------------|-------|---------|
| No dot (`title`) | A top-level attribute of the entity held `null` when the check ran | That attribute's column mapping, and every path that assembles the entity |
| Contains a dot (`address.city`) | A sub-attribute of a composite value (`@Embeddable`) held `null`; only `checkSubElementsNullability` → `buildPropertyPath` produces dots, and it recurses into `CompositeType` | The embeddable's own `nullable = false` attributes — the owning entity attribute (`address`) was non-null |
| Contains a dot and the parent attribute is a collection | The same, reached through a collection whose **element type** is composite (`@ElementCollection` of `@Embeddable`); the first loaded non-null element decides | The element class's not-null attributes |

2. On the UPDATE path, drop `@PreUpdate`/`@PostUpdate` from both the suspect list and
   the fix. `DefaultFlushEntityEventListener.scheduleUpdate` runs
   `new Nullability( session ).checkNullability( values, persister, … )` and only then
   adds `EntityUpdateAction` to the action queue; the callbacks fire inside that
   action's `execute()`. The order is the same in 5.6, 6.6 and 7.0. So when this
   exception is thrown, no `@PreUpdate` listener has run on that entity: a listener
   cannot have nulled the value, and a listener cannot supply it.
3. Fix the value where the entity state is assembled — the service, mapper, or
   deserializer that produced the instance — or change the declared nullability if
   "absent" is a real state of the domain.
4. Before ruling an attribute out, check whether the loop even examined it.
   `Nullability` skips an attribute when it is not insertable (INSERT) or not
   updatable (UPDATE), when its value is `UNFETCHED_PROPERTY` (lazy, not loaded), and
   when Hibernate generates the value in memory (`GenerationTiming != NEVER` — e.g.
   `@CreationTimestamp`, `@UpdateTimestamp`).
5. Measure whether the check is active instead of inferring it from the mapping.
   `hibernate.check_nullability` "Defaults to disabled if Bean Validation is present in
   the classpath and annotations are used, or enabled otherwise":
   `TypeSafeActivator.applyCallbackListeners` calls `setCheckNullability( false )`
   whenever the validation mode is `CALLBACK`/`AUTO` **and** the setting has no value.
   Adding or removing a dependency such as `spring-boot-starter-validation` therefore
   flips it. Read it, or assert it:

| To establish | Do |
|--------------|----|
| The effective setting at startup | `emf.unwrap( SessionFactoryImplementor.class ).getSessionFactoryOptions().isCheckNullability()` |
| That the behaviour holds for this build | A test that flushes an entity whose `nullable = false` attribute is null and expects `PropertyValueException` |

6. When the app-level check must hold regardless of which dependencies are on the
   classpath, set `hibernate.check_nullability=true` explicitly. `@Column(nullable =
   false)` alone does not give you a Bean Validation constraint — it "adds a not null
   constraint to the database column, if Hibernate creates the database table
   definition" — so with the core check off, the enforcement left is the DB constraint.
   Add `@NotNull` (Kotlin: `@field:NotNull` →
   [backend-java-kotlin-frameworks-and-jpa]) when you want the validator to reject it.

## Edge cases

| Case | Then |
|------|------|
| The same message on `persist()`/INSERT | The check runs in `AbstractEntityInsertAction.nullifyTransientReferencesIfNotAlready()`, immediately after `nullifyTransientReferences( getState() )` — a to-one attribute holding an unsaved instance is nulled first, then reported as null. That is where "or transient" comes from; the reported path is still the plain attribute name |
| The path names an attribute whose DB column is nullable | The entity declares not-null while the column allows NULL; existing rows can already violate it, and they surface only once this check is on (directive 5) |
| No exception at all despite a null on a `nullable = false` attribute | The check is off — the statement reaches the database, where a real NOT NULL constraint raises a `ConstraintViolationException` and a nullable column accepts the row silently |
| The failing attribute is `@UpdateTimestamp`/`@CreationTimestamp` | It is skipped by the check (directive 4); the reported path belongs to another attribute |
| The write path is a bulk JPQL/HQL `update` or native SQL | No entity flush happens, so this check never runs — the database constraint is the only gate → [databases-data-survey-audit-columns-as-update-evidence] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add a `@PreUpdate` listener that fills the missing value | Set it where the entity state is assembled (directive 3) | The check runs before `EntityUpdateAction` exists, so no `@PreUpdate` has run — the listener is never reached on the failing flush |
| Read "or transient" as evidence that an unsaved association caused it | Read the path shape (directive 1); on INSERT, treat a nulled transient reference as one of the causes | One literal is shared by both throw sites; the distinct unsaved-instance error carries its own message, "object references an unsaved transient instance" |
| Conclude the check is on because the mapping says `nullable = false` | Read `isCheckNullability()` or assert the exception in a test (directive 5) | Bean Validation on the classpath disables the core check unless the setting is explicit |
| Set `hibernate.check_nullability=false` to get past the exception | Supply the value, or relax the declared nullability | Disabling moves the failure to the DB constraint, or writes the incomplete row when the column is nullable |

## Sources

- https://github.com/hibernate/hibernate-orm/blob/5.6/hibernate-core/src/main/java/org/hibernate/engine/internal/Nullability.java — two throw sites share the literal `"not-null property references a null or transient value"`; the dotted path comes only from `buildPropertyPath(...)` via `checkSubElementsNullability`, which recurses into `CompositeType` and into collections whose element type is composite; the loop skips non-checkable, `UNFETCHED_PROPERTY`, and `GenerationTiming != NEVER` attributes; comment: "Typically when Bean Validation is on, we don't want to validate null values at the Hibernate Core level. Hence the checkNullability setting."
- https://github.com/hibernate/hibernate-orm/blob/6.6/hibernate-core/src/main/java/org/hibernate/event/internal/DefaultFlushEntityEventListener.java — `scheduleUpdate`: "check nullability but do not doAfterTransactionCompletion command execute" → `new Nullability( session ).checkNullability(...)` precedes `new EntityUpdateAction(...)` (same order on 5.6 and 7.0)
- https://github.com/hibernate/hibernate-orm/blob/6.6/hibernate-core/src/main/java/org/hibernate/action/internal/AbstractEntityInsertAction.java — `nullifyTransientReferencesIfNotAlready()` nullifies transient references and then runs the CREATE-type nullability check
- https://github.com/hibernate/hibernate-orm/blob/6.6/hibernate-core/src/main/java/org/hibernate/boot/beanvalidation/TypeSafeActivator.java — "de-activate not-null tracking at the core level when Bean Validation is present unless the user explicitly asks for it": guarded by validation mode `CALLBACK`/`AUTO`, then `if ( cfgService.getSettings().get( CHECK_NULLABILITY ) == null ) … setCheckNullability( false )`
- https://docs.hibernate.org/orm/6.6/javadocs/org/hibernate/cfg/ValidationSettings.html — `CHECK_NULLABILITY`: "Enable nullability checking, raises an exception if an attribute marked as not null is null at runtime"; "Defaults to disabled if Bean Validation is present in the classpath and annotations are used, or enabled otherwise"
- https://docs.hibernate.org/orm/6.6/javadocs/org/hibernate/boot/spi/SessionFactoryOptions.html — `boolean isCheckNullability()` exposes the effective setting
- https://thorben-janssen.com/hibernate-tips-whats-the-difference-between-column-nullable-false-and-notnull/ — `@Column(nullable = false)` "adds a not null constraint to the database column, if Hibernate creates the database table definition" and otherwise leaves validation to the database; `@NotNull` is what Bean Validation checks on pre-persist/pre-update
- https://www.baeldung.com/hibernate-not-null-error — the widely repeated two-cause framing this page corrects: the same message attributed to "a null value for a column marked with nullable = false" and to "an association referencing an unsaved instance", with no mention of the path shape
