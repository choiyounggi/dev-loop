---
id: backend-common-reliability-client-side-rate-limiting
domain: backend
category: reliability
applies_to: [general]
confidence: verified
sources:
  - https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy
  - https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/
last_verified: 2026-08-05
related: [backend-common-reliability-timeouts-and-retries, backend-common-auth-jwt-server-side, debugging-concurrency-intermittent-failures]
---

# Self-Throttling a Client Against a Provider's Per-Second Quota

## When this applies

You wrapped an API client in a throttle to respect a documented requests-per-second
limit, and calls still come back rate-limited — characteristically on the process's
first call, or on some days and not others. Also when writing such a throttle for a
client whose transport refreshes credentials on its own.

## Do this

1. **Count every HTTP request the client emits, not every public method call.**
   One logical operation routinely becomes several requests: token acquisition,
   redirects, discovery, a pre-flight. Auth0 states the shape plainly — "A single
   end user request (e.g., Login or Signup) typically initiates multiple requests
   to Authentication API Endpoints" — and evaluates each against both a global and
   an endpoint-specific limit.
2. **Put the throttle at the transport, below credential refresh.** A throttle
   wrapped around the public methods cannot see a token POST issued from inside
   `_headers()`, an auth interceptor, or a retry handler. When the throttle must
   stay at the wrapper layer, make the refresh path call the same throttle
   explicitly.
3. **Take the throttle's timestamp immediately before the request leaves**, and
   from the same clock for every path. A stamp taken at method entry, before an
   intervening refresh, understates the interval by exactly the refresh's duration
   — which is when the burst happens.
4. **Give the first call of the process a real interval.** Initialize the
   last-request timestamp so the first call waits its slot, or seed it to "now"
   at construction:

| Initial state | First call | Effect |
|---------------|-----------|--------|
| `last_request_at = 0` (epoch) | Interval computes as decades — no wait | Token POST and the first API call land in the same second |
| `last_request_at = now()` at construction | Waits one full slot | The process cannot exceed the limit even on its first operation |

5. **Verify with the credential cache cold.** Delete the cached token and run the
   first operation; that is the only state in which the refresh and the call
   compete. A suite run against a warm cache exercises a different request
   sequence entirely.
6. **Log every outbound request with its timestamp and purpose**, so a
   limit breach can be read as a sequence rather than reconstructed. Pair the
   throttle with the retry rules for 429 in
   [backend-common-reliability-timeouts-and-retries].

## Edge cases

| Case | Then |
|------|------|
| The provider limits per account, and several processes share it | A per-process throttle cannot hold the budget — move the limiter to a shared store, or partition the quota per process and configure each with its share |
| The limit is documented per endpoint as well as globally | Size the throttle to the tightest applicable limit; a global-only throttle passes while one endpoint's own limit is exceeded |
| The SDK you wrap already retries internally | Its retries are requests too — either disable them and own the policy, or budget the throttle for the maximum attempt count ([backend-common-reliability-timeouts-and-retries]) |
| Token refresh happens concurrently on several threads | Serialize refresh behind one lock so N threads produce one token request, then let the throttle meter the rest |
| The failure appears only on days the token expires | That is this page's signature, not a flaky provider — reproduce by clearing the cache rather than waiting for the next expiry ([debugging-concurrency-intermittent-failures]) |
| A health check or warm-up runs before the first business call | It consumes slots as well; register it with the same throttle instead of exempting it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Throttle the client's public methods | Throttle at the layer that issues HTTP, so refreshes and pre-flights are metered too | Credential refresh happens inside header construction and bypasses a wrapper-level limiter entirely |
| Initialize the throttle's last-request time to zero | Initialize it to construction time | An epoch timestamp makes the first call's computed gap effectively infinite, so the first burst is unthrottled by design |
| Stamp the throttle clock when the public method is entered | Stamp it immediately before the request is sent | Work between entry and send (a token POST) is invisible to the interval, which is exactly the work that breaks the limit |
| Call an occasional rate-limit error intermittent and add a retry | Reproduce it with the credential cache cleared | The behavior is deterministic in the cold-cache state; retrying hides a burst you can remove |

## Sources

- https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy — "As requests to your tenant are made, Auth0 evaluates requests against the global limit for the API, and then evaluates requests against the rate limit for specific API endpoints"; "A single end user request (e.g., Login or Signup) typically initiates multiple requests to Authentication API Endpoints" — token/authentication traffic is itself metered
- https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/ — every remote call is a call the caller must budget for; client-side limiting and backoff belong to the caller, not only to retries

## Field context

`stock-trader` `kis_client.py`, diagnosed 2026-08-05: `_headers()` called
`_throttle()` and then `_get_token()`, so the token POST was issued after the
throttle had already stamped its slot and was never itself counted. On the two
days the cached token had expired (07-23, 08-04) the logs show the token POST at
`…00.354`, issuance at `…00.495`, and the balance request failing at `…00.543` —
three requests inside one second against a 2-per-second limit. On days the cache
was warm the identical code ran clean, which had the failure filed as
intermittent.
