---
id: frontend-auth-token-handling-client-side
domain: frontend
category: auth
applies_to: [general]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html
  - https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
  - https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html
  - https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html
  - https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies
  - https://datatracker.ietf.org/doc/html/rfc9700
last_verified: 2026-07-10
related: [frontend-security-xss-safe-rendering]
---

# Storing and Sending Auth Tokens in the Browser

## When this applies

A browser app must store or send auth credentials — JWT access/refresh tokens
or session ids; you are reviewing where tokens live client-side, or
implementing silent refresh or logout. The choice of auth approach itself
(sessions vs JWTs, provider) is owned by the security domain's authn pages
(text pointer, no page link); this page starts after that decision.

## Do this

1. Pick storage by what the token grants and by XSS blast radius — take the
   first row that fits, top row is the default:

| Case | Do |
|------|----|
| Server can set cookies for the app's site (same-site API — the default) | Keep the token out of JavaScript entirely: server sets it as an `HttpOnly; Secure; SameSite=Lax` (or `Strict`) cookie. Applies to session ids and JWTs equally — JS cannot read it, so an injected script cannot exfiltrate it |
| Cross-origin API, or a cookie cannot be set for your origin | Hold the access token in memory only (module-scope variable or closure — not `window`, not Web Storage); obtain and renew it via a refresh endpoint backed by an httpOnly cookie or rotation flow |
| Low-privilege token (narrow scope, short life) AND XSS defenses are in place per [frontend-security-xss-safe-rendering] AND the team explicitly accepts XSS-readable storage | localStorage/sessionStorage allowed — record the accepted trade in the PR: any injected script can read these stores, so XSS defense is the prerequisite, not an afterthought |

2. Silent refresh — single-flight. On a 401 (or ahead of a known `exp`), issue
   ONE refresh call; queue every request that also hit a 401 behind that same
   in-flight promise; on success retry the queued requests with the new token;
   on failure hard-logout. Parallel refreshes rotate the token more than once,
   and under rotation with reuse detection (RFC 9700) presenting an
   already-rotated refresh token revokes the whole session.
3. Logout: clear the in-memory token and cached user data, then call the
   server endpoint that revokes the refresh token/session. Issuance, rotation,
   and revocation logic are server-side — see wiki/backend/common/auth/ (text pointer).
4. CSRF defense follows from the transport:

| Auth transport | CSRF defense |
|----------------|--------------|
| Cookie (browser attaches it automatically) | Required: `SameSite=Lax` as the baseline, plus a CSRF token on state-changing endpoints reachable cross-site |
| `Authorization` header set from a memory token | Not required for those endpoints — the browser never attaches the header on its own |

5. Decode JWT claims client-side for UX only — display name, timing the
   refresh before `exp`. Authorization comes from the server's response on
   every request; a client-side role check hides UI, it secures nothing.

## Edge cases

| Case | Then |
|------|------|
| Page reload with a memory-only token | On boot, call the refresh endpoint once (the httpOnly cookie authenticates it) before issuing API calls; render a loading state, not a logged-out state |
| Refresh call itself fails (401 / invalid grant) | Hard logout: clear token and user caches, navigate to login — retrying an already-rejected refresh trips reuse detection |
| Several tabs each hold a memory token | Coordinate the refresh across tabs (Web Locks or BroadcastChannel: one tab refreshes and broadcasts the new token) — independent tab refreshes present the same rotated refresh token twice |
| Cookie must flow cross-site (embedded widget, third-party context) | `SameSite=None; Secure` — the SameSite baseline is gone, so the CSRF token becomes mandatory on every state-changing endpoint |
| Clock skew makes `exp`-scheduled refresh fire late | Keep the 401-triggered refresh path even when refresh is scheduled ahead of `exp` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Store a JWT in localStorage "so it survives reload" | httpOnly cookie; or memory token + one refresh call on boot | Any injected script reads Web Storage — one XSS exfiltrates the token |
| Fire one refresh per 401 when parallel requests expire together | Single-flight: one in-flight refresh promise; queue and retry the rest | Multiple rotations; under reuse detection the session is revoked |
| Pass a token in a URL (query/fragment, links, redirects) | Send it in the `Authorization` header or a cookie | URLs persist in history, server logs, and the Referer header |
| Gate a route or button on a decoded JWT role as the security check | Treat client checks as UX; the server authorizes every request | Client code and client storage are attacker-controlled |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html — no session identifiers/sensitive data in Web Storage; readable by any JS, stolen via one XSS
- https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html — HttpOnly + Secure + SameSite for session cookies; ids in URLs leak via logs/history/Referer
- https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html — token sidejacking; hardened-cookie storage; closure/sessionStorage trade-offs
- https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html — SameSite as defense-in-depth; CSRF tokens on state-changing requests
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies — HttpOnly/Secure/SameSite attribute semantics
- https://datatracker.ietf.org/doc/html/rfc9700 — refresh token rotation; revocation on replay of rotated tokens
