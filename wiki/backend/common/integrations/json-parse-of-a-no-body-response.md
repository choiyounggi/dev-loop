---
id: backend-common-integrations-json-parse-of-a-no-body-response
domain: backend
category: integrations
applies_to: [fetch-api, javascript, typescript]
confidence: verified
sources:
  - https://fetch.spec.whatwg.org/
  - https://developer.mozilla.org/en-US/docs/Web/API/Response/json
  - https://www.rfc-editor.org/rfc/rfc9112#section-6.2
  - https://www.rfc-editor.org/rfc/rfc7540#section-8.1.2.4
last_verified: 2026-10-06
related: [backend-common-api-design-error-responses, backend-common-reliability-timeouts-and-retries, backend-node-boundaries-runtime-validation]
---

# Parsing JSON From a Response That Has No Body

## When this applies

A shared HTTP client wrapper built on `fetch` (browser, Node 18+, Bun, Deno)
ends every successful call with `return response.json()`, and an endpoint
answers with no body — `204 No Content` on a PUT/DELETE/upsert, `205`, or a
`200` with an empty body. Also when a call the server logged as successful
rejects on the client with `SyntaxError: Unexpected end of JSON input` (V8
wording; Firefox and Safari word the same `SyntaxError` differently).

## Do this

1. **Branch on the body before parsing**, inside the one shared wrapper, after the
   `!response.ok` branch:

| Case | Do |
|------|----|
| The endpoint's contract answers success with `204`/`205` | `if ([204, 205].includes(response.status)) return undefined;` and type that call's result as `void`/`undefined` |
| The endpoint can answer `200` with either JSON or an empty body | `const text = await response.text(); return text === '' ? undefined : JSON.parse(text);` |
| A `HEAD` request | Return without reading the body |

2. **Apply the same branch to the error path**: when the wrapper reads an error
   message from the body of a non-ok response, read `text()` and fall back to
   `` `HTTP ${response.status}` `` when it is empty — `statusText` is `''` over
   HTTP/2 and HTTP/3, which carry no reason phrase.
3. **Test each no-body shape with a real `Response`**:
   `new Response(null, { status: 204 })` and `new Response('', { status: 200 })`,
   asserting the wrapper resolves to `undefined`.

**Mechanism.** The Fetch Standard defines "a null body status is a status that
is 101, 103, 204, 205, or 304", and `json()` "can reject with a SyntaxError" —
parsing an empty body is a parse failure. `response.ok` is true only for
200–299, so a guard placed after the `!response.ok` branch sees `204`/`205`
but never `304`. The rejection arrives after the
server already applied the write, so the caller reports an error for a change
that succeeded, and a retry layer repeats it.

## Edge cases

| Case | Then |
|------|------|
| A test mocks `fetch` with `{ ok: true, json: async () => ({}) }` | Replace the mock body with a real `Response` (step 3); the hand-written `json()` never rejects, so the suite stays green on the bug |
| The caller sends conditional requests (`If-None-Match`, `If-Modified-Since`) and can get `304` | Check `response.status === 304` **before** the `!response.ok` branch and return a "not modified" result the caller maps to its cached copy; after that branch a `304` is reported as an error |
| You want to decide by `Content-Length: 0` | Use the `text()` branch instead; a chunked response carries no `Content-Length` at all (RFC 9112 §6.2), so the header cannot tell you the body is empty |
| The retry layer retries on any thrown error | Fix the parse first; a no-body success that throws turns a non-idempotent POST into a repeated write (see [backend-common-reliability-timeouts-and-retries]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Wrap the parse in `response.json().catch(() => undefined)` | Branch on status or empty text (step 1) | The catch also swallows a malformed JSON body from a broken server and returns `undefined` as success |
| Add a sibling `requestNoBody()` that copies the error mapping | Add the one status/empty-text branch to the shared wrapper | Two copies of error handling drift apart; the guard is one line in one place |

## Sources

- https://fetch.spec.whatwg.org/ — "A null body status is a status that is 101, 103, 204, 205, or 304"; "An ok status is a status in the range 200 to 299, inclusive."; "The json() method steps are to return the result of running consume body with this and parse JSON from bytes. The above method can reject with a SyntaxError."
- https://developer.mozilla.org/en-US/docs/Web/API/Response/json — Exceptions: "SyntaxError — The response body cannot be parsed as JSON."
- https://www.rfc-editor.org/rfc/rfc9112#section-6.2 — "A sender MUST NOT send a Content-Length header field in any message that contains a Transfer-Encoding header field."
- https://www.rfc-editor.org/rfc/rfc7540#section-8.1.2.4 — "HTTP/2 does not define a way to carry the version or reason phrase that is included in an HTTP/1.1 status line." (RFC 9113, which obsoletes it, likewise carries only the `:status` code)
- Reproduction 2026-10-06 (Node v26.7.0): `new Response(null, { status: 204 }).json()` rejects with `SyntaxError: Unexpected end of JSON input`; `new Response('', { status: 200 }).json()` rejects with `SyntaxError`; `new Response(null, { status: 304 }).ok` is `false`, `new Response(null, { status: 204 }).ok` is `true`
- Field evidence 2026-10-06 (a TypeScript CLI's API client, plan t3 spike S1): `response.json()` rejected on the API's `204` reply to `PUT …/failure`; one `if (response.status === 204) return undefined;` line after the `!response.ok` branch fixed it
