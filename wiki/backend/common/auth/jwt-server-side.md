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
  - https://www.rfc-editor.org/rfc/rfc7518#section-3.2
  - https://raw.githubusercontent.com/jwtk/jjwt/0.11.5/README.md
  - https://javadoc.io/static/io.jsonwebtoken/jjwt-api/0.11.5/io/jsonwebtoken/JwtBuilder.html
last_verified: 2026-10-24
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
| An HMAC key arrives as a literal (plan, ticket, config sample) with its size stated in prose ("base64 of a 72-byte secret") | Decode it and count the bytes before wiring it in; the key must be at least the hash size — 32 bytes for HS256, 48 for HS384, 64 for HS512 (RFC 7518 §3.2). Pin the floor in a test (`decode(KEY).size >= 64` for HS512). Name the algorithm when signing: jjwt `signWith(key)` picks "the most secure algorithm allowed" for the key's length (a 62-byte key signs HS384) and reports nothing, while `signWith(key, HS512)` throws `WeakKeyException` — and when that throw sits in a shared test base-class constructor, every subclass fails at once with no pointer to the constant |
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
- https://www.rfc-editor.org/rfc/rfc7518#section-3.2 — "A key of the same size as the hash output (for instance, 256 bits for "HS256") or larger MUST be used with this algorithm"
- https://raw.githubusercontent.com/jwtk/jjwt/0.11.5/README.md — HS256/HS384/HS512 require keys of at least 32/48/64 bytes; `signWith(key)` will "determine the most secure algorithm allowed for the specified key" (a 32-byte key "is not strong enough for `HS384` or `HS512`, so JJWT will automatically sign the JWT using `HS256`"); `Keys.hmacShaKeyFor(Decoders.BASE64.decode(secretString))`
- https://javadoc.io/static/io.jsonwebtoken/jjwt-api/0.11.5/io/jsonwebtoken/JwtBuilder.html — `signWith(Key, SignatureAlgorithm)` throws `InvalidKeyException` "if the Key is insufficient … for the specified algorithm"; `WeakKeyException` extends `InvalidKeyException` (jjwt-api 0.11.5 `security/WeakKeyException`)
- Field reproduction (jjwt 0.11.5): a planned base64 key described as 72 bytes decoded to 62 bytes; `signWith(key, HS512)` threw `WeakKeyException` in a test base-class constructor and 4/4 regression tests failed; a 70-byte key turned them green
