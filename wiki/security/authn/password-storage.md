---
id: security-authn-password-storage
domain: security
category: authn
applies_to: [general]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
last_verified: 2026-07-10
related: [security-authn-session-vs-token, security-secrets-secrets-in-code]
---

# Storing Passwords

## When this applies

You are implementing signup/login credential storage, reviewing how an existing
system hashes passwords, or tuning login performance/DoS behavior around hashing.

## Do this

1. Hash with a **deliberately slow, memory-hard password function** — never a
   general-purpose fast hash:

| Case | Do |
|------|----|
| New system | argon2id, minimum m=19456 (19 MiB), t=2, p=1 (OWASP minimum; raise as your latency budget allows) |
| argon2 unavailable in your stack | bcrypt with work factor ≥ 10 |
| Existing system on a fast hash (SHA-256/MD5, even salted) | Migrate: wrap existing hashes (`bcrypt(sha256_hash)`) immediately so stored values are protected today, then rehash to the target algorithm on each user's next successful login |

2. Salting is built into argon2/bcrypt (unique salt per password, stored in the
   hash string) — do not design your own salting scheme around them.
3. **Store algorithm + parameters in the hash string** (the standard encoded
   formats do this) and define a current policy: on successful login, when the
   stored hash's parameters are below policy, rehash with current parameters —
   this is your only upgrade path, since you never see the password otherwise.
4. **Budget the slowness.** Target the highest cost your login endpoint tolerates
   (sub-second verification under normal load), and re-evaluate periodically as
   hardware improves.
5. A slow hash makes login an amplification target: attackers POST junk
   credentials to burn your CPU. Pair the endpoint with rate limiting per
   account/IP and a bounded concurrency for verification — the defense lives at
   the endpoint, not in a weaker hash.

## Edge cases

| Case | Then |
|------|------|
| bcrypt input limit | bcrypt truncates at 72 bytes — cap accepted password length explicitly (e.g. 64-72) or pre-hash per OWASP guidance; silent truncation means `password123...(73rd char)` variants collide |
| Very long passwords accepted (paste-a-paragraph) | Cap length (e.g. ≤ 128 chars) — memory-hard functions on unbounded input are their own DoS |
| Extra defense layer wanted | Pepper: an additional secret key (from the secret manager, not the DB — [security-secrets-secrets-in-code]) applied around the hash; plan its rotation before adopting |
| Verifying "email exists" timing | Run a dummy verification against a fixed hash when the account doesn't exist, so response time doesn't reveal account existence |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `SHA-256(salt + password)` "because it's a standard hash" | argon2id / bcrypt | Fast hashes let attackers test billions of guesses per second on GPUs; slow memory-hard functions are designed to be slow for the attacker specifically |
| Lower the cost factor because login got slow under attack | Keep the cost; rate-limit and bound concurrency at the endpoint | Lowering cost permanently weakens every stored password to fix a transient load problem |
| Store passwords encrypted (reversible) "for support" | One-way slow hash | Anything reversible is disclosable — by breach, subpoena, or insider |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html — argon2id/bcrypt parameters, fast-hash warning, peppering, migration
