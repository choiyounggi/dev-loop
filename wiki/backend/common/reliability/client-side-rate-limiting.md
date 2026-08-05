---
id: backend-common-reliability-client-side-rate-limiting
domain: backend
category: reliability
applies_to: [general]
confidence: verified
sources:
  - https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
  - https://developer.okta.com/docs/reference/rl2-token-oauth/
  - https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy
  - https://github.com/koreainvestment/open-trading-api
  - https://datatracker.ietf.org/doc/html/rfc6749#section-4.4
last_verified: 2026-08-05
related: [backend-common-reliability-timeouts-and-retries, backend-common-auth-jwt-server-side, debugging-concurrency-intermittent-failures]
---

# A Client-Side Throttle That the Auth/Token Request Slips Past

## When this applies

You wrapped an external API client with a per-second (or per-minute) throttle to
respect the provider's published limit, and a rate-limit error still comes back —
characteristically on the *first* call after process start, or only on some days.
Also when adding a throttle to a client that refreshes its own credentials.

## Do this

1. **Place the throttle at the single lowest point every outbound request passes
   through** — the transport/session layer (`Session.send`, an httpx event hook, an
   interceptor), not the public methods. Credential refresh is issued from inside
   `_headers()`, an interceptor, or a retry path; a throttle wrapped around the
   public methods never sees it.

2. **Stamp the throttle's timestamp immediately before the request is written, and
   only there.** Stamping in the caller lets any request issued between the stamp
   and the send share one slot.

3. **Establish which bucket the token endpoint consumes, and encode the answer.**
   This is provider-specific and decides whether the token request needs a slot:

| Provider policy | Do |
|-----------------|----|
| One limit covers the API host, token endpoint included (KIS `EGW00201` 초당 거래건수) | Take a throttle slot for the token request too |
| Token endpoint has its own bucket (GitHub: 2,000 OAuth token requests/hour as a secondary limit, separate from the primary REST limit; Okta and Auth0 meter `/oauth/token` separately) | Give the token request its own limiter at that endpoint's rate, and keep it out of the API limiter |
| Policy not documented | Take a slot for it and cache the token; the cost is one slot per refresh, the alternative is a hard failure on refresh day |

4. **Cache the credential and refresh it before expiry**, so the token request is
   rare rather than per-call. Providers additionally cap issuance itself — KIS
   reissues an access token once per minute — so a client that re-issues per
   request fails on the token endpoint even when the API limiter is correct.

5. **Verify the cold-start path, not just the steady state.** With
   `_last_request_at = 0`, the first call computes a huge elapsed time and sleeps
   zero — correct for a single request, and exactly the state in which a token POST
   plus the first API GET both proceed with no gap. Assert the first *two* requests
   are spaced, not the first one.

6. **Log the wall-clock time of every outbound request with its endpoint.** The
   ordering of token POST versus API GET within one second is what identifies this
   fault; without it, the failure reads as a provider-side flake.

## Edge cases

| Case | Then |
|------|------|
| The failure reproduces only on some days | Correlate with token-cache expiry, not with load. A valid cached token removes the extra request, so the same code passes every day the cache is warm |
| Multiple processes or workers share one credential and one limit | The limit is per account/key, not per process. Move the counter to a shared store or give each process a documented fraction of the limit — an in-process throttle cannot see its siblings |
| The client retries internally on 429 | Retries are outbound requests and must take slots too, or the retry storm sustains the violation ([backend-common-reliability-timeouts-and-retries]) |
| Provider returns a rate-limit error as HTTP 200 with an error code in the body | Parse the body for the code (KIS returns `EGW00201`); a status-only check counts the response as success and the throttle is never seen to be wrong |
| Sandbox/paper credentials fail where production credentials pass | Paper accounts carry lower per-second limits than live ones; size the throttle from the environment's own documented limit, not from production's |
| A token refresh is triggered concurrently by several in-flight calls | Guard the refresh with a single-flight lock so N callers produce one token request, not N |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Wrap each public API method in the throttle | Throttle in the transport layer every request passes through | Token/refresh requests originate below the public methods and bypass a method-level throttle entirely |
| Stamp the throttle timestamp when the wrapper is entered | Stamp immediately before the request is sent | Any request issued between the stamp and the send shares that slot, so two requests land in one window |
| Call the failure intermittent and add a retry | Log request times and endpoints, then compare a token-issuing day against a cached-token day | The trigger is cache expiry, which is deterministic; a retry hides it until the limit tightens |
| Assume the token endpoint is free | Read the provider's limit for it and encode the branch in step 3 | Providers split about evenly between shared and separate buckets, and the wrong assumption fails only on refresh |

## Sources

- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api — "No more than 2,000 OAuth access token requests per hour are allowed for GitHub Apps and OAuth apps", documented as a secondary rate limit distinct from the primary REST API limit
- https://developer.okta.com/docs/reference/rl2-token-oauth/ — OAuth 2.0 token endpoint limits are metered per authorization server, separately from other API endpoints
- https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy — Auth0 meters "the number of requests made to API endpoints and, in some cases, the number of endpoint operations", with per-endpoint policies including the Authentication API
- https://github.com/koreainvestment/open-trading-api — KIS Open API: `EGW00201` 초당 거래건수 초과; "토큰 재발급 - 1분당 1회 발급됩니다"; 모의투자 계좌는 REST API 호출 제한이 낮음
- https://datatracker.ietf.org/doc/html/rfc6749#section-4.4 — the client credentials grant obtains the token by an HTTP POST to the token endpoint; it is an ordinary request subject to the server's limits

## Field context

Diagnosed 2026-08-04 in a trading client whose `_headers()` called `_throttle()`
and *then* `_get_token()`, so the token POST and the following API GET were issued
inside one throttle window against a 2-requests-per-second paper-account limit.
Logs from the two token-issuance days (07-23, 08-04) show POST at `…00.354`, token
returned at `…00.495`, balance call failing at `…00.543`; on every day the cached
token was still valid the identical code succeeded, which is why it had been
recorded as an intermittent outage.
