---
id: backend-common-api-design-multiline-form-values-arrive-with-crlf
domain: backend
category: api-design
applies_to: [general, nodejs, web]
confidence: verified
sources:
  - https://html.spec.whatwg.org/multipage/form-control-infrastructure.html
  - "Local reproduction 2026-10-08 (Node v26.7.0, undici FormData/Request)"
last_verified: 2026-10-08
related: [security-input-validation-at-trust-boundaries, backend-node-boundaries-runtime-validation, platforms-filesystems-paths-case-and-line-endings, backend-common-api-design-error-responses]
---

# Multiline Form Values Arrive With CRLF

## When this applies

A server validates or stores a multiline text field (a textarea, notes, an
address) that arrives as form data — a `FormData` body sent with `fetch`, a
framework server action, a `<form>` submission — and it rejects control
characters, enforces a length limit, or compares or hashes the value.

## Do this

1. **Normalize line breaks before any check:** `value.replace(/\r\n?/g, '\n')`,
   then run the control-character check, the length limit, and any comparison on
   the result. Store the normalized value.
2. **Test through the real encoding, not a string literal.** Build a `FormData`
   with `'a\nb'`, round-trip it (`await new Request(url, { method: 'POST', body:
   fd }).formData()`), and assert the validator accepts it; add `'a\r\nb'` and
   `'a\rb'` cases too.
3. **Know which encodings rewrite line breaks:**

| How the value is sent | What the server receives for `'a\nb'` |
|-----------------------|----------------------------------------|
| `multipart/form-data` (a `FormData` body, `<form enctype="multipart/form-data">`, server actions built on `FormData`) | `'a\r\nb'` — names and string values: every lone LF and lone CR becomes CRLF |
| `<form>` submission as `application/x-www-form-urlencoded` | `'a\r\nb'` — the same rewrite happens while the browser builds the name-value pairs |
| A `URLSearchParams` body sent with `fetch` | `'a\nb'` — unchanged (local check) |
| A JSON body | Unchanged |

## Edge cases

| Case | Then |
|------|------|
| A length limit shared with the client | Each line break arrives one character longer; apply the server limit after normalizing, or a value the client accepted is rejected |
| File parts in the same multipart body | File contents are not rewritten; only string values and names are |
| A file name with CR, LF or `"` | The multipart encoder escapes them as `%0D`, `%0A`, `%22` instead of converting them |
| A value that must keep CRLF (a signed payload, an email body) | Do not send it as a form field — send it as a file part or as JSON, where line breaks are left alone |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Reject `\r` in a multiline field as a control character | Normalize CRLF and lone CR to LF first, then reject the remaining control characters | The client sent only `\n`; the form encoding added the `\r`, so every multiline value fails |
| Unit-test the validator only with `'a\nb'` | Also feed it the value after a `FormData` round trip | The literal never contains the `\r` the server actually receives |

## Sources

- https://html.spec.whatwg.org/multipage/form-control-infrastructure.html — 4.10.22.8 Multipart form data: replace "every occurrence of U+000D (CR) not followed by U+000A (LF), and every occurrence of U+000A (LF) not preceded by U+000D (CR)" in each entry's name, and in its value "if entry's value is not a File object", "by a string consisting of a U+000D (CR) and U+000A (LF)"; file names escape LF, CR and `"` as `%0A`, `%0D`, `%22`. 4.10.22.6 Converting an entry list to a list of name-value pairs applies the same rewrite to names and values
- Local reproduction 2026-10-08 (Node v26.7.0): a `FormData` with `'line1\nline2'`, `'x\ry'`, `'p\r\nq'` round-tripped through `new Request(...).formData()` came back as `"line1\r\nline2"`, `"x\r\ny"`, `"p\r\nq"`; a `URLSearchParams` body with `'line1\nline2'` came back unchanged
