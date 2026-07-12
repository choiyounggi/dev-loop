---
id: backend-common-errors-exception-handling
domain: backend
category: errors
applies_to: [general]
confidence: field-tested
sources:
  - https://learn.microsoft.com/en-us/dotnet/standard/exceptions/best-practices-for-exceptions
last_verified: 2026-07-10
related: [backend-common-api-design-error-responses]
---

# Placing Catch Blocks: Where Errors Are Handled, Logged, and Translated

## When this applies

Writing a catch/except/rescue block, or deciding which layer of a service
handles, logs, and reports a failure. Also when one fault produces N duplicate
log entries or alerts.

## Do this

1. Catch an exception only at a layer that can **act** on it. Three legitimate
   catch sites:

| Catch site | Action |
|------------|--------|
| Recovery point — a concrete strategy exists | Retry with policy, fallback value, alternate path. The strategy is explicit in the code, not "log and hope" |
| Enrichment point — context exists that the raw exception lacks | Wrap with context (entity ids, operation name) and rethrow, **preserving the cause chain** (inner exception / `raise ... from` / `%w`). No log here |
| Boundary — HTTP handler, job runner, message consumer, main loop | Translate to your API error shape → [backend-common-api-design-error-responses]; log **once** with correlation id, operation, and inputs sans secrets; return the correlation id to the client |

2. Log an error **exactly once**, at the site that handles it. Catch-log-rethrow
   at every layer turns one fault into N alerts, buries the true error rate,
   and makes on-call chase duplicates.
3. Expected domain outcomes — validation failure, not-found, insufficient
   balance — are **return values / typed results** the caller checks, not
   exceptions. Reserve exceptions for faults the local code cannot anticipate
   (Microsoft: handle common conditions without exceptions).
4. When you catch and cannot handle: do not catch — remove the block and let
   the exception rise to the boundary. An empty catch, or catch-log-continue on
   an unexpected exception, leaves the process running in unknown state.
5. When wrapping, always attach the original exception as the cause. A broken
   chain deletes the stack trace that locates the fault (the debugging domain
   covers reading stack traces and cause chains — plain-text pointer, no page
   link).

## Edge cases

| Case | Then |
|------|------|
| You only need cleanup on failure | `finally` / `using` / `defer`, not a catch block — cleanup is not handling |
| Rethrowing in a language where `throw e` resets the stack (C#) | Use the bare rethrow form (`throw;`) so the original stack survives (Microsoft CA2200) |
| Cancellation/timeout exceptions during shutdown or deadline expiry | Let them propagate to the framework; translating them to 500 or retrying works against the cancellation → the caller already gave up |
| Third-party library throws untyped/string errors | Wrap into your typed error at the adapter that calls the library — one translation site, cause attached, callers see only your types |
| One batch item fails inside a loop over many items | Catch at the per-item level, record the failure against that item, continue the batch; rethrowing aborts the remaining items for one bad row |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add log-and-rethrow "for visibility" in a mid layer | Rethrow with added context, log only at the handling site | One fault → N duplicate alerts; signal drowns |
| `catch (Exception) { return null; }` | Catch only the specific expected types; let unknown ones rise to the boundary | The null converts a fault into a later null-pointer crash far from the cause |
| Throw an exception for a validation failure | Return a typed result/error value the caller must check | Control-flow exceptions hide real faults and skip normal data paths |
| `throw new X(message)` dropping the original exception | `throw new X(message, cause)` — include the causing exception | A lost chain removes the root-cause stack debugging depends on |

## Sources

- https://learn.microsoft.com/en-us/dotnet/standard/exceptions/best-practices-for-exceptions — catch only what you can recover from, handle common conditions without exceptions, preserve inner exception and stack on rethrow (CA2200). Log-once-at-handling-site is field practice, not from this source.
