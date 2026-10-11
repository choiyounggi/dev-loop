---
id: testing-quality-host-disguise-fixtures-for-url-allowlists
domain: testing
category: quality
applies_to: [javascript]
confidence: verified
sources:
  - https://url.spec.whatwg.org/
  - "Local reproduction 2026-10-11 (Node v26.7.0 WHATWG URL): parsed protocol, hostname, port and username for 15 URLs (the step-1 fixtures, the apex, two explicit ports); the step-2 check and six weak implementations run against the fixture lists"
  - "Field case 2026-10 (a URL allowlist test, linkly-invitation task t5b; recorded by the originating session)"
last_verified: 2026-10-11
related: [testing-quality-anchor-cases-for-allowlist-regexes, frontend-security-xss-safe-rendering, security-input-validation-at-trust-boundaries]
---

# Host-Disguise Fixtures for a URL Allowlist

## When this applies

You are writing or reviewing tests for code that accepts a URL only when its
scheme and host match a rule — `https:` plus `example.com` or `*.example.com` —
after parsing it with the WHATWG `URL` parser (`new URL()` in browsers and
Node): outbound links, redirect targets, webhook or image URLs.

## Do this

1. **Put fixtures in both lists whose raw text and parsed host disagree.** A
   refuse list of wrong-scheme URLs is refused by every implementation —
   raw-text matching, `startsWith`, a fixed host list, a regex allowing one
   label — so it cannot tell them apart. Each row below separates the parsed
   check from at least one of those:

| Fixture | Example | WHATWG `URL` parses it as | List |
|---------|---------|---------------------------|------|
| Allowed host as userinfo | `https://a.example.com@evil.test/` | `hostname` `evil.test`, `username` `a.example.com` | refuse |
| Backslash before the suffix | `https://evil.test\.example.com/` | `hostname` `evil.test` | refuse |
| `?` or `#` before the suffix | `https://evil.test?.example.com`, `https://evil.test#.example.com` | `hostname` `evil.test` | refuse |
| `%2F` inside the host | `https://evil.test%2F.example.com/` | throws `ERR_INVALID_URL` | refuse |
| Non-numeric port | `https://a.example.com:abc/` | throws `ERR_INVALID_URL` | refuse |
| Allowed host as a leading label | `https://example.com.evil.test/` | `hostname` `example.com.evil.test` | refuse |
| Allowed name without the dot boundary | `https://evilexample.com/` | `hostname` `evilexample.com` | refuse |
| Another scheme on the allowed host | `http://a.example.com/`, `javascript:alert(1)//a.example.com` | `protocol` `http:` / `javascript:` with an empty `hostname` | refuse |
| Mixed-case scheme and host | `HTTPS://A.Example.COM/` | `protocol` `https:`, `hostname` `a.example.com` | accept |
| A deeper subdomain | `https://b.a.example.com/` | `hostname` `b.a.example.com` | accept when the rule allows any depth; refuse when it allows one label — write the rule's choice into the test name |

2. **Check the parsed fields the fixtures target.** Compare `url.protocol`
   exactly, and match `url.hostname` exactly or as a suffix on a dot boundary
   (`host === base || host.endsWith('.' + base)`); return the refuse result when
   `new URL()` throws.

3. **Prove the list by swapping in each weak implementation** — a raw-string
   `includes`/`startsWith` check, a fixed host list, a one-label regex, a
   `hostname.endsWith(base)` without the dot — and require at least one red
   test per swap. A swap that stays green names the fixture row still missing.

## Edge cases

| Case | Then |
|------|------|
| The allowlist is a regex over the raw string instead of the parsed host | Parse first and run the rule on `hostname`; while a raw-string regex remains, add its anchor cases too ([testing-quality-anchor-cases-for-allowlist-regexes]) |
| A fixture makes `new URL()` throw (`%2F` in the host, a non-numeric port) | Assert the function returns the refuse result for it; a check that lets the exception escape fails the caller instead of refusing |
| The rule allows the bare apex (`example.com`) besides its subdomains | Add `https://example.com/` to the accept list and keep `https://evilexample.com/` in the refuse list: `host.endsWith('.' + base)` alone refuses the apex, and `host === base` is the part that accepts it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Fill the refuse list with other-scheme URLs only | Add the disguised-host rows from step 1 | Every weak implementation refuses a wrong scheme too, so those tests pass for all of them |
| Check `url.href.startsWith('https://a.example.com')` | Compare `url.protocol` and `url.hostname` | `https://a.example.com@evil.test/` and `https://a.example.com.evil.test/` both start with the allowed text |
| Match with `hostname.endsWith('example.com')` | Match `host === base \|\| host.endsWith('.' + base)` | `evilexample.com` ends with `example.com` |

## Sources

- https://url.spec.whatwg.org/ — authority state: at U+0040 (`@`) the text read so far becomes the username/password; for a special scheme U+005C (`\`) ends the host the way U+002F (`/`) does; port state: a non-digit is "port-invalid validation error, return failure"; host parser: the domain is "the result of running UTF-8 decode without BOM on the percent-decoding of input", and the domain parser returns failure when the result "contains a forbidden domain code point" — U+002F (`/`) is a forbidden host code point
- Local reproduction 2026-10-11 (Node v26.7.0, `new URL()`): each fixture in the step-1 table parsed to the `protocol`, `hostname` and `username` shown there; `https://evil.test%2F.example.com/` and `https://a.example.com:abc/` threw `ERR_INVALID_URL` (`TypeError`). Against 4 accept fixtures (mixed case, deeper subdomain, apex, plain) and the 10 refuse rows, the step-2 check misclassified none, and every weak implementation was red on at least one fixture: raw-text `includes('.example.com')` 8, a raw-text prefix regex 8, protocol only 6, a fixed host list 1, a one-label regex 1, `hostname.endsWith(base)` without the dot 1. With a refuse list holding only the two other-scheme fixtures, the prefix regex, protocol-only and dot-less `endsWith` versions passed every test
- Field case 2026-10 (linkly-invitation task t5b, `account-links.test.ts`; recorded by the originating session): four audit rounds each found raw-text or scheme mutants passing the suite; 16 added fixtures turned 17 such mutants red, each checked against the previous test file
