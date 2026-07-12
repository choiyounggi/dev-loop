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
  - https://owasp.org/www-community/attacks/Path_Traversal
last_verified: 2026-07-10
related: [security-authz-resource-level-checks, frontend-security-xss-safe-rendering]
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
| Webhook provider offers no signature | Require a shared-secret token in the URL/header, and act on provider state re-fetched from the provider's API rather than on payload fields |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Sanitize/mutate input (strip quotes, escape "dangerous" characters) to make it storable-safe | Validate-reject at the boundary + encode/parameterize at each output sink | No single stored form is safe for every sink; mutation corrupts data and gives false safety |
| Re-validate the same fields deep in the service layer, per use | One schema validation at the entry point; inner code trusts the type | Scattered checks drift apart and get skipped on new call paths |
| Blocklist known-bad patterns (`<script>`, `' OR 1=1`) | Allowlist known-good type/length/range/format | Attackers iterate past any blocklist; allowlists fail closed |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html — allowlist validation at the boundary; validation is not injection defense
- https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html — bound parameters as the primary defense
- https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html — avoid shell; argv-form execution
- https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html — content-based type checks, storage outside webroot, generated names
- https://owasp.org/www-community/attacks/Path_Traversal — canonicalize-then-prefix-check
