---
id: security-input-validation-at-trust-boundaries
domain: security
category: input
applies_to: [general]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html
  - https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html
  - https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html
  - https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html
  - https://cmu-sei.github.io/secure-coding-standards/sei-cert-oracle-coding-standard-for-java/rules/input-output-fio/fio16-j/
  - https://zod.dev/api
last_verified: 2026-09-03
related: [security-authz-resource-level-checks, frontend-security-xss-safe-rendering, security-agent-exposure-in-session-tool-exposure]
---

# Validating Data at a Trust Boundary

## When this applies

Data crosses a trust boundary into your system: HTTP request bodies, query/path
parameters, headers, cookies, file uploads, webhook payloads, or messages arriving
from other services/queues.

## Do this

1. **Validate at the boundary, once, against a positive schema (allowlist)**:
   declare type, length, range, and format for every field; reject any request
   that does not match. Inner layers then trust the validated shape — validation
   lives at the entry point, not scattered per-use through the call stack.
2. **Validation does not make data safe for a sink.** Injection defense is
   context-specific encoding or parameterization applied at the **output sink**,
   on every sink, even for validated data:

| Output sink | Do |
|-------------|----|
| SQL | Bound parameters for every user-influenced value; build the statement text only from constants (string-concatenated SQL is the injection) |
| Shell command | Skip the shell: exec with an argv array (`execFile`/`subprocess.run([...])`); when a tool only exposes a shell string, restrict the input to a strict allowlist (e.g. `^[a-zA-Z0-9_-]+$`) before interpolating |
| HTML page | Encode per render context — [frontend-security-xss-safe-rendering] |
| Filesystem path built from user input | Canonicalize (resolve `..`, symlinks) to an absolute path, then verify the resolved path starts with the intended base-directory prefix; reject on mismatch |

3. **File uploads**: determine type by content sniffing (magic bytes), not by
   filename extension or client `Content-Type`; enforce a size cap before
   buffering; store outside the webroot under a server-generated name and keep
   the original filename as display metadata only.
4. **Webhooks**: verify the provider signature (HMAC over the **raw** request
   bytes) before parsing the body; reject on mismatch.

## Edge cases

| Case | Then |
|------|------|
| Free-text field (names, comments) where an allowlist is too restrictive | Validate length and encoding (valid UTF-8, no control characters); safety comes from sink-side encoding, not from restricting content |
| Feature must accept and preserve rich-text HTML | The one sanitize case: run an allowlist-based maintained sanitizer, per [frontend-security-xss-safe-rendering] |
| Message from your own internal service ("we trust our services") | Validate the shape at the consumer boundary anyway — the sender can be buggy or compromised; a trust boundary is wherever data enters code that acts on it |
| Header value used in logic (`X-Forwarded-For`, `Host`) | Client-settable: validate format and accept forwarding headers only from your configured trusted proxy before using them |
| A persisted numeric value positions or sizes an entity in a shared space (placement coordinates, scale, canvas/map position in a game or collaborative board) | The valid range is a domain rule (playfield rectangle, min/max scale), not a type limit — OWASP's semantic validation. Clamp to those bounds on the server at the write, or reject with the bound in the error; a shape-only schema (`z.number()`) accepts `x=-9999` and `scale=0.01`, which place the entity off-screen or invisible and break the rules the space enforces |
| Webhook provider offers no signature | Require a shared-secret token in the URL/header, and act on provider state re-fetched from the provider's API rather than on payload fields |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Sanitize/mutate input (strip quotes, escape "dangerous" characters) to make it storable-safe | Validate-reject at the boundary + encode/parameterize at each output sink | No single stored form is safe for every sink; mutation corrupts data and gives false safety |
| Re-validate the same fields deep in the service layer, per use | One schema validation at the entry point; inner code trusts the type | Scattered checks drift apart and get skipped on new call paths |
| Treat a passing zod/JSON-schema shape check as sufficient for a persisted spatial value | Derive the range from the domain (playfield, scale limits) and clamp or reject at the server write; test the boundary and an abuse value | Syntactic validation proves the field is a number; semantic validation proves it is a legal position — zod's `.min()`/`.max()` reject only when the schema carries the real bounds, and a bare `z.number()` carries none |
| Blocklist known-bad patterns (`<script>`, `' OR 1=1`) | Allowlist known-good type/length/range/format | Attackers iterate past any blocklist; allowlists fail closed |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html — allowlist validation at the boundary; validation is not injection defense
- https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html — bound parameters as the primary defense
- https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html — avoid shell; argv-form execution
- https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html — content-based type checks, storage outside webroot, generated names
- https://cmu-sei.github.io/secure-coding-standards/sei-cert-oracle-coding-standard-for-java/rules/input-output-fio/fio16-j/ — FIO16-J: canonicalize path names before validating, then confirm the canonical path is within the secure/base directory
- https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html — "Syntactic validation should enforce correct syntax of structured fields"; "Semantic validation should enforce correctness of their values in the specific business context"; "Minimum and maximum value range check for numerical parameters"
- https://zod.dev/api — `z.number().min(n)` / `.max(n)` (aliases of `.gte()`/`.lte()`) reject out-of-range numbers at parse time; there is no built-in clamp
- Field evidence 2026-08-18 (mechameleon-web, review server-core-r1 F1): the server stored schema-valid placement values unclamped; `x=-9999` and `scale=0.01` put a player's figure off-screen or invisible, so a hidden player won by default. Fixed with a server-side `clampStickman` at save time plus three boundary/abuse tests
