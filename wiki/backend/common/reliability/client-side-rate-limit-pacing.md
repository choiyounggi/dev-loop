---
id: backend-common-reliability-client-side-rate-limit-pacing
domain: backend
category: reliability
applies_to: [general]
confidence: field-tested
sources:
  - https://developer.okta.com/docs/reference/rate-limits/
  - https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy
  - https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
last_verified: 2026-08-05
related: [backend-common-reliability-timeouts-and-retries, backend-common-auth-jwt-server-side, debugging-methodology-hypothesis-testing]
---

# Pacing Your Own Calls Under a Provider's Per-Second Quota

## When this applies

You wrapped an external API client with a throttle (minimum interval, token
bucket) to stay under a documented per-second quota, and rate-limit errors still
appear — characteristically on the first call after process start, or on some
days and not others.

## Do this

1. **Count every HTTP request the client issues, including the ones it makes to
   get credentials.** Token issuance and refresh normally happen inside
   header-building or a request interceptor — below the layer the throttle
   decorates — so a token POST and the API GET it enables leave in the same second
   and deterministically exceed a small quota. Providers rate-limit their token
   endpoints as their own buckets (Okta publishes per-endpoint buckets for
   `/oauth2/v1/token`; Auth0 publishes a `/oauth/token` limit), and OAuth-app
   traffic counts against the caller's quota (GitHub). Route the credential request
   through the same throttle as everything else.

2. **Place the throttle at the lowest layer that issues HTTP** — the send/execute
   method, not the public wrapper methods. That is the only position auth refresh
   cannot bypass.

3. **Stamp the throttle clock immediately before the request goes out**, not on
   entry to the wrapper. Anything between the stamp and the send — token refresh,
   payload serialization, signing — shortens the real gap below the interval you
   think you are enforcing.

4. **Check what the first call of a process does.** A "last request at" state
   initialized to zero correctly exempts the first call from waiting; the defect is
   that an unthrottled token request then fires inside it, making two requests
   where the throttle counted one. Assert the first call's request count, not just
   its spacing.

5. **Reproduce with a cold credential cache.** Clear the cached token, then run.
   A live token removes the extra request, which is why the failure looks
   intermittent and gets filed as a flaky provider.

## Edge cases

| Case | Then |
|------|------|
| Several processes or workers share one API key | An in-process throttle cannot see the others — move pacing to a shared store (Redis token bucket) or divide the quota explicitly per worker; the per-process interval is not the quota |
| The token is cached on disk and shared between runs | Only the first process after expiry pays the extra request — schedule a warm-up call at startup so the cost lands outside a user-facing request |
| The provider's limiter is a sliding window | Pace below the nominal limit rather than exactly at it; requests bunched at a window boundary breach a limit that per-second averaging satisfies |
| The provider publishes a separate quota for token issuance | Confirm it in their docs before exempting it from the shared throttle; when the limits are unpublished, count it |
| A 429 still arrives despite correct pacing | Honour `Retry-After` and back off — pacing prevents self-inflicted breaches, it does not cover provider-side or cross-tenant limits ([backend-common-reliability-timeouts-and-retries]) |
| Mock/sandbox credentials have a lower quota than production | Pace to the environment's own limit, read at startup from config — a throttle tuned to production silently breaches in sandbox |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Decorate the public API methods with the throttle | Put it at the lowest HTTP-issuing layer | Requests issued from header-building or an interceptor never pass through a method-level decorator |
| Record the throttle timestamp when the wrapper method is entered | Record it immediately before the send | Token refresh between the two makes the enforced interval shorter than the configured one |
| File a first-call rate-limit error as an intermittent provider fault | Re-run with the credential cache cleared and count the outbound requests | The bug reproduces only on token-issuance runs, so most runs are green and hide it |
| Raise the throttle interval until the errors stop | Count the requests per second the client actually emits | Padding the interval hides an uncounted request instead of counting it, and it returns under any change in timing |

## Sources

- https://developer.okta.com/docs/reference/rate-limits/ — rate-limit buckets are per-endpoint collections sharing a quota; OAuth endpoints (`/oauth2/v1/authorize`, token) carry their own buckets, with nested per-client quotas
- https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy — the `/oauth/token` endpoint has a published production rate limit, i.e. token issuance is metered like any other call
- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api — requests made by an OAuth/GitHub App on a user's behalf "count towards" that user's rate limit
- Field context: a trading-API client throttled its public methods, while `_headers()` called `_throttle()` and then `_get_token()`. On the two days the cached token had expired, the logs show token POST at `…:00.354`, issuance at `…:00.495`, and the following balance call rejected at `…:00.543` — two requests inside one second against a 2/second quota. On days with a valid cached token the identical code passed
