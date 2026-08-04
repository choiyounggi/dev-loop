---
id: backend-common-reliability-client-side-rate-limiting
domain: backend
category: reliability
applies_to: [general]
confidence: field-tested
sources:
  - https://www.rfc-editor.org/rfc/rfc6749.html
  - https://www.rfc-editor.org/rfc/rfc6585.html
last_verified: 2026-08-04
related: [backend-common-reliability-timeouts-and-retries, backend-common-auth-jwt-server-side, debugging-concurrency-intermittent-failures]
---

# Staying Under a Provider's Requests-per-Second Quota from a Client Wrapper

## When this applies

You wrapped an external API client in a throttle (sleep-until, token bucket,
semaphore) to stay under a published requests-per-second quota, and the provider
still returns a rate-limit error. Also when that error appears on the process's
first call, or only on some days with no code change.

## Do this

1. **Count every HTTP request the process sends to that host against the quota,
   including the token/authentication request.** An OAuth-style credential
   exchange is itself a request to the provider ("The client makes a request to
   the token endpoint"), issued over the same connection budget as the data
   calls. A throttle wrapped around "the API call" and an auth refresh performed
   inside the header builder or an interceptor sit on opposite sides of the
   counter.
2. **Place the throttle at the lowest layer every outbound request passes
   through** — the transport/send function — so no code path can reach the network
   without decrementing the counter. When the auth refresh must live in a header
   builder, have that builder issue its request through the same throttled sender.
3. **Stamp the throttle's timestamp immediately before the request is sent, and
   record it for the request that was actually sent.** A timestamp taken at the
   start of a wrapper that then performs a token exchange records the wrong
   instant, and the following call computes its wait from it.
4. **Give the first call of a process a real wait.** Initialize the last-request
   timestamp so that the first call observes the full interval, or seed the bucket
   with the same capacity a steady-state client would hold:

| Initial state | First-call behavior | Do |
|---------------|---------------------|-----|
| `last_request_at = 0` | Elapsed time is decades, so the wait is skipped and the first N calls burst | Initialize to the process start time, or make the first acquisition pay the interval |
| Bucket pre-filled to capacity | A burst of `capacity` requests leaves immediately | Size capacity to the provider's stated burst allowance, not to the per-second rate |
| Counter shared per client instance | Two instances double the rate | Scope the counter to the process (or to a shared store when multiple processes call one quota) |

5. **Make the throttle's unit match the provider's stated unit.** When the quota
   is per second, a fixed sleep between calls only holds if the sleep is at least
   `1 / rate`; when the quota is a sliding window, track request timestamps within
   that window rather than the gap since the last one.
6. **Log the throttle's decision with each request** (wait applied, requests in
   the current window, endpoint). An intermittent quota error is unresolvable from
   provider-side error text alone, and the log is what turns the next occurrence
   into a one-run diagnosis.
7. **Keep the reactive path too.** Honor `Retry-After` on 429 and back off with
   jitter ([backend-common-reliability-timeouts-and-retries]); a proactive
   throttle handles your own traffic, and the reactive path handles the provider's
   accounting differing from yours.

## Edge cases

| Case | Then |
|------|------|
| The failure reproduces only on some days | Correlate with the credential cache's expiry: on days the cached token is still valid there is no token request, so the same code sends one fewer request per burst and stays under ([debugging-concurrency-intermittent-failures]) |
| The provider limits token issuance on its own separate schedule | Cache the token to disk or a shared store with its expiry, refresh ahead of expiry, and count the refresh against the request quota as well |
| Several processes share one API key | Move the counter to a shared store; per-process throttles each stay under the limit while their sum exceeds it |
| The client library retries internally | Count library retries against the quota — configure the library's retry policy explicitly rather than layering your own on top of an unknown one |
| A batch job and an interactive path share the client | Give the batch path a lower rate than the quota so the interactive path keeps headroom |
| The provider publishes remaining-quota headers | Read them and reconcile against your counter; a persistent gap identifies a request path bypassing the throttle |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Wrap only the public `get`/`post` methods of the client in the throttle | Throttle the single transport function all requests funnel through | Token refresh commonly happens inside the header builder or an interceptor and never reaches the wrapper |
| Read a first-call rate-limit error as a provider-side glitch | Check whether the initial timestamp is a zero value that makes the first wait evaluate to zero | A zero-initialized "last request" makes the elapsed time effectively infinite, disabling the throttle exactly when the token request is also being sent |
| Treat a rate-limit failure that "does not reproduce" as flaky | Reproduce it with a cleared credential cache | The extra token request exists only on refresh runs, so a warm cache hides a deterministic over-quota burst |
| Time the throttle from the start of the wrapper method | Stamp immediately before the send, per request sent | Work performed between the stamp and the send (auth exchange, serialization) is credited as elapsed time that never happened |

## Sources

- https://www.rfc-editor.org/rfc/rfc6749.html — the token endpoint is reached by an ordinary HTTP request from the client ("The client makes a request to the token endpoint by adding the following parameters..."), so credential acquisition consumes the same request budget as data calls
- https://www.rfc-editor.org/rfc/rfc6585.html — 429 Too Many Requests: "The 429 status code indicates that the user has sent too many requests in a given amount of time ('rate limiting')", and the response "can include a Retry-After header indicating how long to wait before making a new request"
- Field incident 2026-08-04 (`stock-trader`, KIS REST client): `_headers()` called `_throttle()` and then `_get_token()`, so the token POST and the following data GET landed in the same second and exceeded the per-second allowance. Request log on a token-issuing day: POST at `:00.354` → token returned `:00.495` → balance call rejected at `:00.543`. The same code ran clean on days the cached token was still valid, which is why the failure had been filed as intermittent. Reproduced on two separate token-issuance days (07-23, 08-04)
