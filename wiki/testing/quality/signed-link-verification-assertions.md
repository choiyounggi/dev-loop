---
id: testing-quality-signed-link-verification-assertions
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html
  - https://docs.python.org/3/library/hmac.html
last_verified: 2026-08-11
related: [testing-quality-tests-that-cannot-fail, testing-quality-guard-shape-vs-consequence, testing-quality-write-path-assertions, testing-quality-harness-reverse-controls]
---

# Testing Code That Assembles a Signed or Tokenized Link

## When this applies

You are choosing the assertions for code that builds a URL carrying its own
credential — an approval or magic link with `?t=<signature>`, an object-storage
presigned URL, a webhook callback URL, an unsubscribe link — and the obvious
assertion is that the parameter is present in the string. Also when such a test
is green while the link the product actually sends is rejected by its receiver.

Whether a source-text-shaped assertion is the right level at all →
[testing-quality-behavior-not-implementation].

## Do this

1. **Assert through the verifier the receiver runs, passing the subject the link
   is supposed to authorize.** Hand the built URL's token plus that subject (row
   id, batch id, object key, HTTP method) to the production verification
   function and assert it accepts. A signature is opaque and fixed-width for
   every key and every payload, so only recomputation separates a correct token
   from a wrong one — this is why Python's `hmac` docs tell verification routines
   to compare `digest()` output with `compare_digest()` rather than `==`.

2. **Put both rejection arms in the same test**: the same token against a
   *different* subject, and a token produced under a *different* key. Assert each
   is rejected. One accept plus two rejects is the smallest set that pins the
   token to its key and its subject
   ([testing-quality-minimum-case-set]).

3. **When the receiver is reachable from the suite, issue the real request** —
   in-process test client, or the app bound to a port — and assert the success
   status. Add the control in the same test: the identical path with the token
   removed must be rejected.

4. **Assert every field the receiver folds into the signature**, one per
   assertion. A presigned URL is built from "your security credentials" plus a
   bucket, an object key, "An HTTP method", and "An expiration time interval";
   AWS's own remedy for `SignatureDoesNotMatch` is to "verify that all request
   parameters — including the HTTP method, headers, and query string — match
   exactly between URL generation and usage". A test that reads only the query
   string checks none of that match.

5. **Prove the assertions can fail before citing them.** Mutate the assembly
   twice — sign with another key, sign over another subject — and require the
   verifier assertion (and the live-request assertion) to redden, with a no-op
   mutation that stays green ([testing-quality-harness-reverse-controls]).

## Edge cases

| Case | Then |
|------|------|
| The verifier lives in another service or language | Pin one known-good `(key, subject, token)` vector produced by that service as a literal fixture, and assert the builder reproduces it byte for byte; keep the wrong-key/wrong-subject arms against your own verifier |
| The token is opaque and stored (a DB row, not a keyed digest) | Assert the row exists with the expected subject and single-use state, then assert the receiver accepts the link once and rejects the second use |
| The link only ever appears inside a rendered message (Slack block, email body) | Extract the URL from the rendered payload in the test and run steps 1–3 on it, so the notification test covers the link rather than the sentence around it |
| Expiry is enforced by the receiver | Inject the clock and assert accept before the boundary and reject after it ([testing-quality-injected-clock-duration-assertions]) |
| The token is a live credential for a real environment | Assert the verifier's verdict, never the token value, and keep test tokens keyed to a test-only secret so failure output carries no usable credential |
| The builder is the only signer and the test wants an expected value | Take the expected token from a committed vector, not from a second call into the signer — an expectation routed through the symbol under test drifts with it and pins nothing |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `assert "?t=" in url` (or a regex for the parameter's shape) | Pass the token and its subject to the verifier and assert accept, plus wrong-subject and wrong-key rejects | A hardcoded placeholder satisfies the pattern, and the pattern is identical for a token signed with the wrong key |
| Compute the expected token in the test by calling the same signing helper | Assert via the verifier, and pin one literal vector for the byte-level check | Expectation and implementation move together, so the assertion survives any change to either |
| Skip the real request because the receiver needs a server | Bind the app in-process (test client) and GET the built URL, with a token-stripped control | The assembly and the receiver disagree about scope or encoding exactly where no test crosses the boundary |
| Assert the link is present in the notification body and stop | Extract the URL and verify its token | A message can carry a link whose token was never signed over the right subject — the receiver rejects it and the send path reports success |

## Sources

- https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html — "When you create a presigned URL, you must provide your security credentials, and then specify the following: An Amazon S3 bucket / An object key / An HTTP method / An expiration time interval"; "Amazon S3 checks the expiration date and time of a signed URL at the time of the HTTP request"; on `SignatureDoesNotMatch`: "verify that all request parameters—including the HTTP method, headers, and query string—match exactly between URL generation and usage"
- https://docs.python.org/3/library/hmac.html — "When comparing the output of `digest()` to an externally supplied digest during a verification routine, it is recommended to use the `compare_digest()` function instead of the `==` operator"; `compare_digest` "uses an approach designed to prevent timing analysis by avoiding content-based short circuiting behaviour" — verification is a recomputation, not an inspection of the token's shape
- Field reproduction 2026-08-11 (Python, HMAC-signed approval link): six mutations of the link-assembly path, scored against the same suite. Signing with a different key and signing over a different batch id both left the `?t=` parameter present and well-formed, so every format assertion stayed green; the assertion that ran the token through `auth.verify` with the expected batch, plus three assertions that GET the link against the live receiver, reddened on both. The no-op control mutation stayed green
