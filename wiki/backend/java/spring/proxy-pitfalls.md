---
id: backend-java-spring-proxy-pitfalls
domain: backend
category: spring
applies_to: [java, kotlin, spring]
confidence: verified
sources:
  - https://docs.spring.io/spring-framework/reference/core/aop/proxying.html
  - https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html
  - https://docs.spring.io/spring-framework/reference/integration/scheduling.html
last_verified: 2026-07-10
related: [backend-common-orm-transaction-boundaries, backend-common-errors-async-failure-handling]
---

# Spring Proxy-Based Annotations Silently Not Applying

## When this applies

A Spring behavior annotation — `@Transactional`, `@Async`, `@Cacheable`,
`@Retryable` — has no effect at runtime (no transaction, same thread, no cache hits,
no retries) with no error; or reviewing where such annotations are placed.

## Do this

1. Apply the mental model: these annotations work by wrapping the bean in a proxy.
   The behavior runs only when the call enters through the proxy from outside the
   bean. Any call path that skips the proxy skips the annotation — silently.
2. Check the call path against the failure table; apply the fix in the row:

| Call path | What happens | Fix |
|-----------|--------------|-----|
| Self-invocation: `this.annotatedMethod()` from the same bean | Bypasses the proxy; annotation ignored, no error | Move the annotated method to another bean and inject it (preferred). When restructuring is not viable, inject the bean's own proxy (`ObjectProvider<Self>` / self-`@Autowired`) and call through it |
| Annotated method is not `public` | Interface (JDK) proxies advise `public` only; Spring 6+ class (CGLIB) proxies also advise `protected`/package-visible | Make annotated entry methods `public`; confirm your proxy type before relying on non-public advice |
| `final` class or `final` method with CGLIB proxying | CGLIB cannot override it — the method runs unadvised, silently | Remove `final` from the class/method (Kotlin: `open` or the `kotlin-spring` compiler plugin), or proxy an interface |
| Call made from a constructor or `@PostConstruct` | The proxy is not assembled yet; the raw bean runs | Move the call to `ApplicationReadyEvent` / `SmartInitializingSingleton`, after context refresh |
| Call through a stored raw reference (`this` leaked to a field/callback) instead of the injected bean | The raw target runs unadvised | Pass and call the injected (proxied) bean reference |

3. Verify the effect, not the annotation: write an integration test that asserts the
   observable behavior — a throw inside `@Transactional` leaves no row committed;
   an `@Async` method reports a different thread name; a second `@Cacheable` call
   skips the repository (verify with a mock/counter). An annotation that compiles
   proves nothing about interception.
4. Place the annotation on the bean's entry method — the method other beans call.
   Where the transaction boundary belongs and how nested/propagation behaves is
   owned by [backend-common-orm-transaction-boundaries]; where async failures must
   be routed is owned by [backend-common-errors-async-failure-handling]. Load those
   for the principle; this page owns only the JVM/Spring interception mechanics.

## Edge cases

| Case | Then |
|------|------|
| `@Async` method returns `void` and its exception vanishes | `void` async exceptions never reach the caller — register an `AsyncUncaughtExceptionHandler`, or return a `Future`/`CompletableFuture` that a caller consumes → [backend-common-errors-async-failure-handling] |
| Annotation must apply to internal calls too (self-invocation is required by design) | Switch that aspect to AspectJ weaving (`mode = AdviceMode.ASPECTJ`) — proxy mode cannot intercept internal calls |
| Two proxied annotations on one method (`@Transactional` + `@Async`) | Behavior depends on advice order — assert the combined effect in an integration test rather than reasoning from annotation order |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `@Transactional` to a private helper called via `this` | Move the boundary to the public entry method, or extract the helper to its own bean | The proxy never sees the call; the annotation is dead code |
| Fix self-invocation by grabbing `AopContext.currentProxy()` inline | Extract the method to another bean; self-inject only when extraction is not viable | `currentProxy()` couples business code to AOP internals and requires `exposeProxy=true` globally |
| Trust that the annotation works because the app starts | Integration-test the effect (rollback happened, thread differs, cache hit counted) | Every failure in the table above is silent at startup and at call time |

## Sources

- https://docs.spring.io/spring-framework/reference/core/aop/proxying.html — JDK vs CGLIB proxies; final methods/classes cannot be advised; self-invocation not intercepted and its remedies
- https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html — method visibility rules (Spring 6 class proxies advise protected/package-visible), self-invocation produces no transaction at runtime, AspectJ mode alternative
- https://docs.spring.io/spring-framework/reference/integration/scheduling.html — `@Async` proxy advice mode, local calls not intercepted, `AsyncUncaughtExceptionHandler` for void returns
