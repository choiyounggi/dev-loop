---
id: debugging-methodology-probe-path-vs-operation-path
domain: debugging
category: methodology
applies_to: [general, headless-browser, cookie-auth]
confidence: verified
sources:
  - https://github.com/velopert/velog-server/blob/master/src/lib/token.ts
last_verified: 2026-08-14
related: [debugging-methodology-hypothesis-testing, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, debugging-methodology-silent-registration-failure-in-a-finder-launched-app]
---

# A Passing Precondition Probe for a Failing Operation

## When this applies

An automation's precondition check (login status, health, connectivity) reports
success, yet the operation it gates fails immediately after with an
auth/permission error — e.g. a headless-browser "logged in" check passes while
the API call made with the same stored cookies returns "Not logged in". Also
applies when deciding what a preflight probe for a direct API operation must
exercise.

## Do this

1. **Treat a probe's success as evidence about the probe's path only.** Before
   trusting it, state what the probe actually exercised and diff that against
   the failing operation: same credential material, same endpoint/host, same
   client. A green probe over a different path does not contradict the failure
   — it locates it.
2. **Probe the operation's own path with the operation's exact inputs.** For a
   cookie/token-authenticated API, call the API's identity endpoint (GraphQL
   `currentUser`, REST `/me`) with the same cookie jar and client the operation
   will use, and require a non-null identity before proceeding.
3. **Under refresh-token cookie auth, expect page-load probes and replayed
   cookie jars to diverge.** The server keeps a short-lived access token beside
   a long-lived refresh token and rotates both via `Set-Cookie` when a request
   arrives with an expired access token. A browser context persists that
   rotation, so a page-load login check passes for as long as the refresh token
   lives; a script replaying a stored cookie jar keeps sending the stale access
   token it saved.
4. **On an API-probe failure, refresh the stored credentials, persist them, and
   re-probe** — re-run the login flow (or the refresh endpoint), write the
   rotated cookies back to the store the operation reads, then repeat step 2
   before the operation.

## Edge cases

| Case | Then |
|------|------|
| Probe page and operation API live on different hosts (`velog.io` page vs `v3.velog.io/graphql`) | Cookie domain scoping can differ per host — verify the jar's cookies actually attach to the API request (dump request headers), not just that they exist in the store |
| The API layer itself refreshes when handed a valid refresh token (velog's `consumeUser` middleware) | Rotation is returned via `Set-Cookie`; a client that discards response cookies works once and fails on a later run — persist rotated cookies after every authenticated call |
| Probe passes, operation starts, then fails auth mid-run | The access token expired during the operation; capture the operation's own error and re-authenticate there — tightening the preflight cannot cover a token that outlives it |
| Both probe and operation fail after refresh | The refresh token itself is expired or revoked — re-run the interactive login flow, not the refresh path |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Gate a direct API operation on a browser page-load login check | Gate on the API's identity query with the operation's own client and cookie jar | Page navigation triggers server-side token refresh that the browser persists; the check validates the refresh token while the operation depends on the stored access token |
| Retry the operation because the probe "proves" auth is fine | Diff the probe's path against the operation's path first | The contradiction is the diagnosis: two paths, one credential expired on exactly one of them |
| Fix the failure by loosening or removing the probe | Move the probe onto the operation's path | The probe was not wrong, it was answering a different question |

## Sources

- https://github.com/velopert/velog-server/blob/master/src/lib/token.ts — `setTokenCookie` sets `access_token` with `maxAge` 1 hour beside `refresh_token` with 30 days; `consumeUser` middleware refreshes on an expired/near-expiry access token and returns new cookies via `Set-Cookie`, so only clients that persist response cookies stay authenticated
- Field reproduction 2026-08-14 (auto-velog pipeline, headless Chromium + stored cookie jar): page-load check returned `STATUS:LOGGED_IN`, the immediately following publish mutation failed with "Not logged in", and a direct `v3.velog.io/graphql` `currentUser` query with the same stored cookies returned null; re-running the login flow (rewriting the cookie store) made the same publish succeed
