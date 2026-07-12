# security — Domain Index

Route here for: trust-boundary decisions — input validation, authn approach
choice, per-resource authorization, secrets hygiene, dependency trust, PII
handling. Mechanics owned elsewhere are linked: XSS rendering → frontend,
CI secrets → infrastructure, JWT implementation → backend/frontend auth.

Match your situation to a "load when" line; load only matching pages.

## input

| Page | Load when |
|------|-----------|
| [validation-at-trust-boundaries](input/validation-at-trust-boundaries.md) | Data crosses a trust boundary into your system — HTTP bodies/params/headers/cookies, file uploads, webhook payloads, inter-service messages; choosing injection defense per output sink (SQL, shell, HTML, filesystem path); deciding validate-reject vs sanitize |

## api-exposure

| Page | Load when |
|------|-----------|
| [exposing-an-origin-http-api](api-exposure/exposing-an-origin-http-api.md) | Putting an internal/origin HTTP API behind a public reverse proxy, CDN, or tunnel (Cloudflare Tunnel); deciding which security controls are code vs edge (TLS/HSTS, rate limiting, WAF); adding security response headers and making them apply to 5xx too; disabling docs/OpenAPI schema at the origin; sanitizing error responses; a dev-mode flag that can disable auth in production |

## authn

| Page | Load when |
|------|-----------|
| [session-vs-token](authn/session-vs-token.md) | Choosing how users stay authenticated (server session cookie vs JWT/stateless tokens) for a new app or API; reviewing an auth design; setting access-token lifetime against a revocation requirement (implementation → wiki/backend/common/auth/, wiki/frontend/auth/) |
| [password-storage](authn/password-storage.md) | Implementing or reviewing password hashing (argon2id/bcrypt parameters, migrating off SHA-256/MD5); tuning hash cost vs login latency; login endpoint as a hashing-DoS target; bcrypt length limits |

## authz

| Page | Load when |
|------|-----------|
| [resource-level-checks](authz/resource-level-checks.md) | An endpoint reads/writes a resource identified by a request-supplied id (IDOR risk); designing permission checks — role vs ownership/tenancy; choosing the 404-vs-403 policy; bulk endpoints acting on lists of ids |

## secrets

| Page | Load when |
|------|-----------|
| [secrets-in-code](secrets/secrets-in-code.md) | Code needs an API key/password/private key; a secret was just committed/pasted/logged (leak response, rotation); setting up repo secret hygiene (scanners, env files); deciding whether a value may ship in client code (CI/build secrets → infrastructure/ci-cd/secrets-handling) |

## dependencies

| Page | Load when |
|------|-----------|
| [supply-chain](dependencies/supply-chain.md) | Adding a dependency (add-vs-write decision, name verification, install scripts); updating dependencies (auto-update PRs, major versions, transitive CVE overrides); hardening against malicious/compromised packages (lockfiles, reproducible installs) |

## data

| Page | Load when |
|------|-----------|
| [pii-handling](data/pii-handling.md) | A feature stores/processes personal data (emails, names, phones, addresses, government ids); reviewing a log/analytics/export/URL path that can carry PII; designing retention/erasure or handling an erasure request; choosing staging/test data for tables holding PII |
