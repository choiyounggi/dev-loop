---
id: backend-common-reliability-client-side-rate-limiting
domain: backend
category: reliability
applies_to: [general]
confidence: field-tested
sources:
  - https://developer.okta.com/docs/reference/rl2-token-oauth/
  - https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
last_verified: 2026-08-05
related: [backend-common-reliability-timeouts-and-retries, backend-common-auth-jwt-server-side, debugging-concurrency-intermittent-failures]
---

# A Client-Side Throttle That the Auth Refresh Slips Past

## When this applies

Your API client wrapper enforces a provider's requests-per-second cap itself
(a minimum interval or token bucket around each call), and a rate-limit error
still comes back — characteristically on the **first** call of a process, or on
some days and not others.

## Do this

1. **Put the throttle where every outbound request passes, including the ones
   the client issues on its own behalf.** Token/credential refresh is issued from
   inside a header builder or an interceptor *below* the wrapper method, so a
   throttle applied per public method never sees it. Either wrap the transport
   (session/adapter/middleware) or call the throttle explicitly from the refresh
   path as well.
2. **Stamp the throttle's timestamp immediately before the request goes out**,
   inside the same function that issues it. A timestamp written by the caller
   before an inner request happens leaves that inner request unaccounted for and
   lets the next one land in the same second.
3. **Make the refresh and the call it enables two separate slots.** After a
   refresh has consumed a slot, the request that needed the token waits its own
   interval:

   ```python
   def _headers(self, tr_id):
       token = self._get_token()   # throttles internally when it must refresh
       self._throttle()            # separates this call from that refresh
       return {...}
   ```

4. **Read the provider's docs for which bucket the token endpoint is in** — this
   differs by provider and decides step 1's shape:

| Provider's rule | Client design |
|-----------------|---------------|
| Token endpoint shares the general request budget | One throttle covering every request, refresh included |
| Token endpoint has its own separate budget | Two counters; the refresh must not consume the API budget's slot, and must still respect its own |
| Undocumented | Route the refresh through the shared throttle — one extra interval per refresh costs a fraction of a second and a shared bucket costs a failed call |

5. **Check the process's initial state.** A last-request timestamp initialized to
   zero must produce "no wait" against a monotonic clock and "no wait" only for
   the genuinely first request — assert it in a test that issues two calls back
   to back from a fresh client and requires the measured gap.
6. **Keep the server's own 429 handling as well** — the client throttle prevents
   the common case, the retry path ([backend-common-reliability-timeouts-and-retries])
   handles the rest.

## Edge cases

| Case | Then |
|------|------|
| The failure reproduces only on days the cached token expired | That is the signature of this bug, not intermittency — compare a failing day's log timestamps against a day the cache was warm |
| Several client instances run in one process | The throttle state must be shared across them (class/module-level or an injected limiter); per-instance state multiplies the effective rate by the instance count |
| Several processes or hosts call the same account | Per-process throttling cannot hold an account-wide cap — move the limiter to a shared store ([backend-common-concurrency-distributed-locks] for the coordination primitive) or divide the budget explicitly per process |
| The refresh is triggered lazily by a 401 retry rather than by expiry | The retry path issues a token request too — route it through the same throttle, or the retry storms the limit it was recovering from |
| The provider counts by endpoint class, not per account | Model the buckets the provider documents; one global interval under-uses the fast bucket and still overruns the slow one |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Apply the throttle in each public wrapper method | Apply it at the transport, or call it from the refresh path too | Auth refresh is issued from below the wrapper and is invisible to a per-method throttle |
| Raise the minimum interval until the errors stop | Find which request was unaccounted for and route it through the throttle | A larger interval slows every call to hide one uncounted request, and still fails when two uncounted ones coincide |
| File the first-call failure as intermittent and add a retry | Compare a fresh-token run against a cached-token run | The trigger is the token cache state, which is deterministic — a retry hides a reproducible ordering bug |

## Sources

- https://developer.okta.com/docs/reference/rl2-token-oauth/ — OAuth token endpoints carry their own documented rate limits, separate from general API limits; which bucket applies is provider-specific
- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api — access-token requests are budgeted separately from REST API requests
- Field reproduction, `auto-trading-bot` commit `82a077e` (`src/broker/kis_client.py`): the wrapper's `_throttle()` ran in `_headers()`, which then called `_get_token()`; on days the token was newly issued the token POST and the following API GET landed in the same second and the provider rejected the call for exceeding its per-second cap. Logs from two such days show `POST …:00.354` → token issued `…:00.495` → balance call rejected `…:00.543`; on cached-token days the same code succeeded. The fix throttles inside `_get_token()` and throttles again after it in `_headers()`
