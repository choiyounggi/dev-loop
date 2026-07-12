---
id: backend-common-auth-jwt-server-side
domain: backend
category: auth
applies_to: [general]
confidence: verified
sources:
  - https://www.rfc-editor.org/rfc/rfc8725
  - https://www.rfc-editor.org/rfc/rfc7519
  - https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html
  - https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
  - https://auth0.com/docs/secure/tokens/refresh-tokens/refresh-token-rotation
last_verified: 2026-07-10
related: [databases-schema-design-requirements-to-tables, databases-indexing-index-selection, backend-common-reliability-timeouts-and-retries]
---

# JWT Issuance and Verification on the Server

## When this applies

Implementing or reviewing server-side JWT auth: choosing the signing algorithm,
verifying incoming tokens, setting lifetimes, building the refresh flow, revoking
sessions. Chosen token-based auth — the session-vs-token choice criteria live in
wiki/security/authn/ (plain text pointer; do not restate them here). Client-side
token storage is owned by wiki/frontend/ (plain text pointer).

## Do this

1. Choose the signing algorithm by who verifies:

| Case | Do |
|------|----|
| One service both issues and verifies | HS256 with a ≥256-bit random key held only by that service |
| More than one service verifies | Asymmetric algorithm — RS256, ES256, or EdDSA. Distribute only the public key to verifiers; no verifier can mint tokens |

2. Run this verification checklist in every verifier, on every request:

| Check | Rule |
|-------|------|
| Signature | Verify against a server-side allowlist of accepted algorithms; reject `alg: none` and any header `alg` outside the list — never let token input choose the algorithm (blocks alg confusion, e.g. an RS256 public key replayed as an HS256 HMAC secret) |
| `exp` / `nbf` | Enforce both, with a clock-skew leeway of 60 seconds; RFC 7519 caps sanctioned leeway at a few minutes |
| `iss` | Equals your issuer value exactly |
| `aud` | Contains your service's audience value; reject tokens without it |
| `typ` | Matches the expected token type; reject unexpected `typ` header values |

3. Access-token lifetime: 5–15 minutes. The revocation gap equals the
   access-token lifetime — after revocation, a stolen access token keeps
   working until `exp`.
4. Refresh token: an opaque random value from a CSPRNG (≥128 bits), not a JWT.
   Store it server-side **hashed like a password** in a `refresh_tokens`/
   `sessions` table holding user id, expiry, and device/session metadata —
   design the table per [databases-schema-design-requirements-to-tables]; the
   lookup by token hash needs an index per [databases-indexing-index-selection].
5. Rotate on every use: issue the new refresh token and invalidate the old one
   in the same transaction. Reuse detection: a presented token that was already
   rotated means theft — revoke the whole session family (every token descended
   from that login).
6. Revoke by event:

| Event | Do |
|-------|----|
| User logout | Delete that refresh token; the access token expires on its own within minutes |
| Password change or account compromise | Delete all the user's refresh tokens |
| Requirement: kill access tokens instantly | Check a denylist/session store on every request — this rebuilds stateful auth; weigh that trade on the choice page, wiki/security/authn/ (plain text pointer) |

7. Keep claims minimal: `sub`, a session/token id (`jti`), and roles only when
   the role set is small and non-sensitive. The payload is base64-encoded, not
   encrypted — anyone holding the token reads every claim. Keep PII and secrets
   out.

## Edge cases

| Case | Then |
|------|------|
| Building a denylist entry for a token | Key it by the `jti` + `iss` claims, not by raw token bytes or their hash — a JWT has no single canonical byte representation (OWASP) |
| A legitimate client retries a refresh call after a timeout and trips reuse detection | The family is revoked and the user re-authenticates — accept this as the safe default (theft is indistinguishable from a retry); give refresh calls a single attempt, no auto-retry → [backend-common-reliability-timeouts-and-retries] |
| One issuer serves several relying services | Every token carries `aud` and every service validates its own audience value or rejects the token (RFC 8725 §3.9) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Issue day/week-lived access tokens to cut refresh traffic | 5–15 minute access tokens + rotating refresh tokens | The revocation gap equals the access lifetime — a revoked or stolen token stays valid for days |
| Store refresh tokens in plaintext | Hash them like passwords before storing | A DB leak makes every live session hijackable |
| Make the refresh token a JWT | Opaque random value stored hashed server-side | Rotation and revocation need the server-side row anyway; a signed self-contained format adds parsing attack surface, not capability |
| Put user profile fields or PII into claims | `sub` + session id; fetch profile data from the service on demand | Claims are readable base64 for anyone who holds the token |

## Sources

- https://www.rfc-editor.org/rfc/rfc8725 — JWT Best Current Practices: algorithm allowlist, rejecting `none`, alg-confusion attack, `iss`/`aud` validation
- https://www.rfc-editor.org/rfc/rfc7519 — `exp`/`nbf` semantics; clock-skew leeway bounded at a few minutes
- https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html — denylist keyed by `jti`+`iss` (no canonical byte form), payload base64-readable, `none`-algorithm attack
- https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html — server-side invalidation on logout and on privilege change (password change)
- https://auth0.com/docs/secure/tokens/refresh-tokens/refresh-token-rotation — rotation on every exchange; reuse detection revoking the entire token family
