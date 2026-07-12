---
id: security-authn-session-vs-token
domain: security
category: authn
applies_to: [general]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
  - https://www.rfc-editor.org/rfc/rfc8725
last_verified: 2026-07-10
related: [security-authz-resource-level-checks]
---

# Choosing How Users Stay Authenticated: Server Session vs Token

## When this applies

Choosing the authentication mechanism for a new app or API — server-side session
cookie vs JWT/stateless tokens — or reviewing an existing auth design. This page
owns the choice; implementation lives in wiki/backend/common/auth/ (server side) and
wiki/frontend/auth/ (client side).

## Do this

Pick by topology, not by fashion:

| Case | Do |
|------|----|
| Same-site browser app, single backend | Server-side session; session id in an `httpOnly` `Secure` `SameSite` cookie. Simplest revocation (delete the session) and no client-side token-storage problem |
| Multiple services/APIs must verify identity without a shared session store, or third parties call your API | Short-lived JWT access token + refresh token. Server-side issuance/verification → wiki/backend/common/auth/; client-side acquisition/storage/refresh → wiki/frontend/auth/ |
| Mobile native app | Token-based, tokens in secure OS storage (Keychain/Keystore) → wiki/mobile/ |

Accept the cost of what you picked — each choice carries one:

| Choice | You accept |
|--------|-----------|
| Server-side sessions | A session-store lookup on every request; multi-instance deployments need a shared store (or sticky routing) |
| JWT | A token cannot be revoked before expiry without a server-side check on each request. Your revocation requirement bounds the access-token lifetime: max lifetime = the longest a logged-out/disabled user may retain access (minutes, not days). Refresh-token rotation, storage, and reuse detection become your code |

Set the JWT access-token lifetime **from** the revocation requirement first, then
design refresh around it — not the other way around.

## Edge cases

| Case | Then |
|------|------|
| "JWT for everything because stateless", and you find yourself checking a DB denylist per request | You rebuilt sessions with extra steps — the per-request lookup you were avoiding is back. Use server-side sessions |
| Instant revocation required (account ban, password change, admin kill switch) under JWT | Check revocation at token refresh and keep the access token within the tolerated exposure window; when the business tolerates zero window, use sessions |
| Browser app that also fans out to several internal services | Hybrid: session cookie at the edge (BFF pattern); the backend mints short-lived tokens for downstream service calls |
| Verifying JWTs you did not issue | Pin accepted algorithms and issuer/audience per RFC 8725 — details in wiki/backend/common/auth/ |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Default to JWT because it is "modern/stateless" | Walk the topology table; a single-backend browser app gets a session cookie | JWT buys distributed verification at the price of revocation — a price with no benefit when one backend serves one app |
| Issue long-lived access tokens (days+) to avoid refresh complexity | Short-lived access token + refresh token | A stolen long-lived token is valid for its whole life with no way to kill it |
| Store the choice's implementation details in this decision | Point to wiki/backend/common/auth/ and wiki/frontend/auth/ | Choice criteria and implementation drift independently |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html — server-side session properties, cookie attributes, revocation
- https://www.rfc-editor.org/rfc/rfc8725 — JWT Best Current Practices: short lifetimes, algorithm/issuer pinning
