---
id: backend-common-api-design-error-responses
domain: backend
category: api-design
applies_to: [general]
confidence: verified
sources:
  - https://www.rfc-editor.org/rfc/rfc9457
  - https://www.rfc-editor.org/rfc/rfc9110
  - https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status
last_verified: 2026-07-10
related: [backend-common-errors-exception-handling]
---

# Choosing Status Codes and an Error Body Shape for an API

## When this applies

Designing or reviewing how an API reports failures: which HTTP status code to
return and what the error response body contains. Also when clients report that
errors are unparseable or inconsistent across endpoints.

## Do this

1. Define **one machine-readable error shape** and return it from every endpoint.
   Use RFC 9457 problem details (`Content-Type: application/problem+json`) —
   fields `type`, `title`, `status`, `detail`, `instance` — extended with:
   - a stable, documented error `code` string that clients branch on (clients
     never branch on the human-readable message),
   - an `errors[]` array for field-level validation failures, one
     `{field, code, message}` entry per failing field, all failures in one response.
2. Pick the status code by failure class:

| Failure | Status |
|---------|--------|
| Request unparseable, or a field fails syntactic validation (missing, wrong type, bad format) | 400 |
| No credentials, or credentials invalid/expired | 401 |
| Identity known, but this action is not permitted | 403 |
| Resource does not exist | 404 |
| Resource exists but the caller must not learn that it exists | 404 with the identical body as the absent case, so existence does not leak |
| Request conflicts with current state (duplicate create, stale version/ETag) | 409 |
| Request parseable and well-typed, but violates a semantic/business rule | 422 |
| Unexpected server fault (bug, dependency crash) | 500 |

3. If your API does not distinguish 400 from 422, use 400 for **all**
   request-validation failures API-wide and distinguish cases by error `code`.
   Mixing conventions per endpoint breaks client error handling.
4. For 500: the body carries only a generic message plus a **correlation id**;
   log the stack trace, exception class, and internals server-side under that id.
   The response body never contains stack traces, SQL, class names, file paths,
   or dependency hostnames.
5. Treat error `code` values as API contract: keep them stable across releases;
   changing or removing one is a breaking change and goes through the same
   review as removing a field.

## Edge cases

| Case | Then |
|------|------|
| Undecided between 401 and 403 | Missing/invalid *identity* → 401; valid identity lacking *permission* → 403 |
| Client used an unsupported HTTP method on the path | 405 with an `Allow` header listing supported methods (RFC 9110) |
| The fault is a downstream dependency timing out or unavailable | 503 or 504, not 500 — lets clients and monitoring separate retryable infrastructure faults from application bugs |
| Multiple fields fail validation in one request | Return all failures in `errors[]` in a single 400 — one-error-at-a-time forces clients into fix-resubmit loops |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Return 200 with `{"success": false}` | Return the real status code with a problem+json body | Caches, retry logic, load balancers, and monitoring all key off the status code and will treat the failure as success |
| Put `exception.getMessage()` in the response body | Return a stable `code` + generic message; log the exception server-side under the returned correlation id | Leaks internals; exception messages are not a stable client contract |
| Invent a new error JSON shape for this endpoint | Reuse the single API-wide shape | Clients write exactly one error parser |

## Sources

- https://www.rfc-editor.org/rfc/rfc9457 — problem+json format (type/title/status/detail/instance, extension members)
- https://www.rfc-editor.org/rfc/rfc9110 — status code semantics, 405 + Allow
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status — 400/401/403/404/409/422/429/500 definitions
