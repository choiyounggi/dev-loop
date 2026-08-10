---
id: backend-java-jpa-raw-jdbc-inside-a-jpa-transaction
domain: backend
category: jpa
applies_to: [java, spring, jpa, hibernate]
confidence: verified
sources:
  - https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/orm/jpa/JpaTransactionManager.html
  - https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/jdbc/datasource/DataSourceUtils.html
  - https://github.com/spring-projects/spring-framework/blob/v6.2.0/spring-orm/src/main/java/org/springframework/orm/jpa/JpaTransactionManager.java
  - https://github.com/spring-projects/spring-framework/blob/v6.2.0/spring-jdbc/src/main/java/org/springframework/jdbc/support/SQLStateSQLExceptionTranslator.java
  - https://github.com/hibernate/hibernate-orm/blob/main/hibernate-core/src/main/java/org/hibernate/dialect/PostgreSQLDialect.java
last_verified: 2026-08-10
related:
  [
    backend-common-orm-transaction-boundaries,
    backend-common-reliability-timeouts-and-retries,
    backend-common-errors-exception-handling,
    backend-java-spring-proxy-pitfalls,
  ]
---

# A Raw JdbcTemplate Query Inside a JPA-Managed Transaction

## When this applies

A Spring service is JPA/Hibernate-backed, and one query was dropped to
`JdbcTemplate`/`NamedParameterJdbcTemplate` for performance while
`@Transactional(timeout = N)` is what is supposed to bound its runtime. Also when
one endpoint's slow queries are cancelled at N seconds through some paths and run
for minutes through others, or when the same timeout surfaces as a 4xx on one
path and a 5xx on another.

Where the transaction boundary belongs → [backend-common-orm-transaction-boundaries].
The annotation having no effect at all (self-invocation, non-public method) →
[backend-java-spring-proxy-pitfalls].

## Do this

1. **Measure the raw path's actual cancellation point before trusting the
   declared timeout.** Run a query you know exceeds N through that exact method
   and record the elapsed time (a JDBC-level logger such as p6spy, or the
   database's own cancellation message). The declared timeout and the applied
   timeout are separate facts, and nothing logs the gap between them.

2. **Trace the deadline's path.** `JdbcTemplate` ends every statement setup with
   `DataSourceUtils.applyTimeout(stmt, getDataSource(), getQueryTimeout())`, which
   applies "the current transaction timeout, **if any**". It looks the deadline up
   as a `ConnectionHolder` bound to *its own* `DataSource` instance; with no
   holder it falls back to the template's own `queryTimeout`, which defaults to
   `-1` and so sets nothing. Check each link:

| Link | Check | If it fails |
|------|-------|-------------|
| The transaction manager knows the DataSource | `JpaTransactionManager` binds a `ConnectionHolder` only inside `if (getDataSource() != null)`; it "will autodetect the DataSource used as the connection factory of the EntityManagerFactory" | Set it explicitly (`setDataSource`), matching the EntityManagerFactory's DataSource |
| The JpaDialect can expose the JDBC connection | The bind is skipped when `getJpaDialect().getJdbcConnection(...)` returns `null` — `DefaultJpaDialect`'s implementation returns `null`; enable debug logging on the manager and look for "Not exposing JPA transaction … because JpaDialect … does not support JDBC Connection retrieval" | Configure the vendor dialect (`HibernateJpaDialect`), which the docs state "requires a vendor-specific `JpaDialect` to be configured" |
| The template uses the same DataSource instance | The lookup key is the `DataSource` object the template holds; a second `DataSource` bean, or one wrapped after the manager captured it, is a different key | Build the template from the same bean, or from a `TransactionAwareDataSourceProxy` |
| The timeout is declared where the proxy sees it | `timeout` on the annotation only reaches `doBegin` when that call is proxied | → [backend-java-spring-proxy-pitfalls] |

3. **Give the raw path a deadline that does not depend on that chain.** Set
   `setQueryTimeout(N)` on the template, or set the database's own statement
   timeout for the connection, so the bound is present whether or not the holder
   is. `applyTimeout` prefers the transaction's remaining time when a holder
   exists, so an explicit value is a floor, not a conflict.

4. **Handle both timeout exception types before shipping the fix.** Cancellation
   raises different Spring exceptions per path, so a handler branch written for
   the JPA path does not cover the raw one:

| Path | Chain | Spring exception |
|------|-------|------------------|
| Hibernate/JPA query | PostgreSQL SQLState `57014` → `org.hibernate.QueryTimeoutException` → `HibernateJpaDialect` | `org.springframework.dao.QueryTimeoutException` |
| Raw JdbcTemplate, Spring Framework ≤ 6.2.x | `PSQLException` (a plain `SQLException`, so the JDBC-4 `SQLTimeoutException` branch does not match) → SQLState class `57` | `DataAccessResourceFailureException` |
| Raw JdbcTemplate, Spring Framework ≥ 7.0.0 | Same chain, plus a `"57014".equals(sqlState)` check ahead of the class-57 mapping | `org.springframework.dao.QueryTimeoutException` |

5. **Keep the timeout's response status the same on both paths, and fix the
   missing bound as its own change.** A path that now runs for minutes and a path
   cancelled at N seconds are one defect wearing two status codes; the status
   difference is the symptom that leads to it.

## Edge cases

| Case | Then |
|------|------|
| A server-side `statement_timeout` is also set | It bounds every path independently of Spring, which makes it the cheapest guard to add; keep the application timeout below it so the application's own error is what surfaces |
| The method is `@Transactional(readOnly = true)` | The timeout is unaffected by `readOnly` — both are set on the same transaction object — so a read-only annotation is not evidence the deadline applies |
| The raw query runs outside any transaction (no annotation on the path) | There is no holder to carry a deadline at all, so the explicit `setQueryTimeout` from step 3 is the only bound |
| The team's first fix is to map the new exception to a 4xx so the alerts stop | Map it after the bound exists — otherwise minute-long queries leave the 5xx alerting entirely and the remaining defect has no signal |
| The database is MySQL rather than PostgreSQL | The class-57 mapping is PostgreSQL's SQLState; Spring's fallback translator also returns `QueryTimeoutException` when the driver's exception class name contains "Timeout", which is the MySQL path — confirm which branch your driver takes before writing the handler |
| A `sql-error-codes.xml` file sits at the classpath root | The template then uses `SQLErrorCodeSQLExceptionTranslator` instead of the subclass/state chain above, so re-derive the exception type for your file's mappings |
| The same value is also enforced by an HTTP or gateway timeout | The client-visible failure comes from whichever fires first; order them so the database cancellation happens first, or the query keeps running after the response is gone ([backend-common-reliability-timeouts-and-retries]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read `@Transactional(timeout = 10)` on the class as evidence every query inside is bounded at 10s | Measure one deliberately-slow query per access path | Measured on one endpoint: the Hibernate path cancelled at 10,012 ms while raw-JdbcTemplate calls on the same annotated path ran 151,558 ms and 163,489 ms |
| Treat the new `DataAccessResourceFailureException` as a newly-broken dependency | Read it as the same timeout arriving through the other translator branch | SQLState class `57` is in Spring's `DATA_ACCESS_RESOURCE_FAILURE_CODES` through 6.2.x; the message still carries the cancellation text |
| Add the raw path's exception to the 4xx branch and close the incident | Add the missing query timeout, then align the status | The status mapping removes the alert; the unbounded query is what the alert was pointing at |
| Wrap the raw call in an application-level watchdog (a future with a timeout) | Set the statement timeout so the database cancels the work | A cancelled wrapper returns control while the query keeps running and holds its connection |
| Assume the DataSource is wired because Spring Boot auto-configured the manager | Verify the holder exists — check the manager's debug log line, or assert that a `@Transactional(timeout = 1)` method's raw query fails | Autodetection covers the DataSource, and the bind still fails silently when the dialect cannot expose the connection |
| Rely on the Spring 7 mapping and write one handler branch for `QueryTimeoutException` | Pin the framework version the branch assumes, and keep the `DataAccessResourceFailureException` branch while any service is on 6.2.x or earlier | The `"57014"` check exists in 7.0.0 and is absent in 6.2.8 and every earlier tag checked |

## Sources

- https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/orm/jpa/JpaTransactionManager.html — "This transaction manager also supports direct DataSource access within a transaction (i.e. plain JDBC code working with the same DataSource)"; "To be able to register a DataSource's Connection for plain JDBC code, this instance needs to be aware of the DataSource (`setDataSource(DataSource)`)"; "This transaction manager will autodetect the DataSource used as the connection factory of the EntityManagerFactory, so you usually don't need to explicitly specify the 'dataSource' property"; and "Note that this requires a vendor-specific `JpaDialect` to be configured"
- https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/jdbc/datasource/DataSourceUtils.html — `applyTimeout` "Apply the specified timeout - overridden by the current transaction timeout, if any - to the given JDBC Statement object"; `applyTransactionTimeout` "Apply the current transaction timeout, **if any**, to the given JDBC Statement object" — the "if any" is the silent branch
- https://github.com/spring-projects/spring-framework/blob/v6.2.0/spring-orm/src/main/java/org/springframework/orm/jpa/JpaTransactionManager.java — `doBegin` sets `conHolder.setTimeoutInSeconds(timeoutToUse)` only inside `if (getDataSource() != null)` and only when `getJpaDialect().getJdbcConnection(em, …)` returned non-null, otherwise logging "Not exposing JPA transaction … because JpaDialect … does not support JDBC Connection retrieval". `DefaultJpaDialect.getJdbcConnection` returns `null`. Read at tag v6.2.0
- https://github.com/spring-projects/spring-framework/blob/v6.2.0/spring-jdbc/src/main/java/org/springframework/jdbc/support/SQLStateSQLExceptionTranslator.java — `DATA_ACCESS_RESOURCE_FAILURE_CODES` is `Set.of("08", "53", "54", "57", "58")` and class `57` returns `new DataAccessResourceFailureException(...)` with no timeout special-case; the only `QueryTimeoutException` route is `ex.getClass().getName().contains("Timeout")` (commented "For MySQL"). Verified 2026-08-10 across tags: `"57014".equals(sqlState)` is absent in v5.3.31, v6.0.0, v6.2.0, v6.2.1, v6.2.3, v6.2.5 and v6.2.8, and present in v7.0.0 and `main` (as `indicatesQueryTimeout`, documented "with SQL state 57014 as a specific indication")
- `SQLExceptionSubclassTranslator` (same tag) maps `ex instanceof SQLTimeoutException` to `QueryTimeoutException` and constructs `setFallbackTranslator(new SQLStateSQLExceptionTranslator())`; `JdbcAccessor` documents it as the default "as of 6.0" unless a user-provided `sql-error-codes.xml` is on the classpath. PgJDBC's `PSQLException extends SQLException` and its `PSQLState.QUERY_CANCELED` is `"57014"`, so the subclass branch does not match and the state fallback decides — read from https://github.com/pgjdbc/pgjdbc/blob/master/pgjdbc/src/main/java/org/postgresql/util/PSQLException.java and `PSQLState.java`
- https://github.com/hibernate/hibernate-orm/blob/main/hibernate-core/src/main/java/org/hibernate/dialect/PostgreSQLDialect.java — SQLState `"57014"` maps to `org.hibernate.QueryTimeoutException`, which `HibernateJpaDialect` converts to `org.springframework.dao.QueryTimeoutException` (https://github.com/spring-projects/spring-framework/blob/v6.2.0/spring-orm/src/main/java/org/springframework/orm/jpa/vendor/HibernateJpaDialect.java) — the JPA half of the split in step 4
- Field measurement 2026-08-10 (production endpoint, p6spy JDBC timing, `@Transactional(readOnly = true, timeout = 10)` declared, no server-side `statement_timeout`): the Hibernate path was cancelled at 10,012 ms and surfaced as HTTP 400; two raw `JdbcTemplate` calls on the same endpoint ran 151,558 ms and 163,489 ms and surfaced as HTTP 500. Over 30 days, 11 recorded errors matched the per-path status split with no exceptions
