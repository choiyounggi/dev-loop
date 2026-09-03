---
id: testing-quality-write-path-assertions
domain: testing
category: quality
applies_to: [general, python, httpx]
confidence: verified
sources:
  - https://github.com/encode/httpx/blob/master/httpx/_content.py
  - https://www.python-httpx.org/quickstart/
last_verified: 2026-08-05
related: [testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, backend-python-boundaries-runtime-validation, testing-quality-signed-link-verification-assertions, testing-quality-store-assertions-after-a-rolled-back-run]
---

# Testing an Endpoint That Writes: Asserting Past the Status Code

## When this applies

You are writing an HTTP-level test for an endpoint that persists something —
a form submit, a create/update call, an onboarding step — and the test's
assertion is the response status. Also when such a test is green while the
records it should have written are empty or defaulted.

## Do this

1. **Assert the persisted state, not the status code.** After the request,
   read the row/document/file back through the application's own read path or
   the DB session and assert the specific values you sent. A write endpoint's
   status reports that the handler ran, not that your payload reached it.
2. **Include one field the request must supply and the schema does not
   default.** A payload that never arrives validates as an empty form and
   passes every default, so a test built only on defaultable fields stays green
   for a request that carried nothing.
3. **Encode repeated form fields as a dict of lists**, which is what a form
   encoder expands into repeated keys:

   ```python
   client.post(url, data={"preferred_types": ["a", "b"], "partner": ["x"]})
   ```

4. **Keep `data=` a mapping.** httpx form-encodes `data` only when it is a
   `Mapping`; any other value (a list of tuples, a pre-built string) is treated
   as raw body content — it is sent with no
   `application/x-www-form-urlencoded` header, the server parses an empty form,
   and the handler returns its normal success status.
5. **Confirm the encoding once per payload shape**, at the request level, by
   asserting `request.headers["content-type"]` and the encoded body — cheaper
   than rediscovering it from a mis-saved record.

## Edge cases

| Case | Then |
|------|------|
| The endpoint redirects on success (303/302) | The redirect proves the handler completed a branch, not which one — follow it and assert the resulting page's content plus the persisted row |
| The framework's validation silently coerces a missing field to a default | That default is the failure mode this page exists for: assert a non-defaultable field |
| The payload is JSON, not a form | Pass `json=` and let the client serialize; the same rule applies — assert the persisted values, not the status |
| Repeated fields must be sent as multipart (file inputs alongside them) | Use `files=` with `data=` as a mapping; the mapping rule for `data` is unchanged |
| A `DeprecationWarning` appears about `content=<...>` during the test run | That warning IS the misencoded-payload signal — turn warnings into errors for the test suite so it fails instead of passing green |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| End the test at `assert response.status_code == 303` | Read the record back and assert the values you sent | A request whose body never decoded still produces the success status |
| Pass repeated fields as `data=[("k", "a"), ("k", "b")]` | Pass `data={"k": ["a", "b"]}` | httpx form-encodes only a `Mapping`; a list of tuples is sent as raw content and the server receives an empty form |
| Debug a "saved as empty" record by reading the handler | Assert the outgoing request's content-type and body first | The record is empty because the form decoded to nothing, not because the handler dropped it |

## Sources

- https://github.com/encode/httpx/blob/master/httpx/_content.py — `encode_request`: `if data is not None and not isinstance(data, Mapping): warnings.warn("Use 'content=<...>' to upload raw bytes/text content.", DeprecationWarning); return encode_content(data)`. `encode_urlencoded_data` expands a `list`/`tuple` value into repeated `(key, item)` pairs and sets `Content-Type: application/x-www-form-urlencoded`
- https://www.python-httpx.org/quickstart/ — `data={...}` sends form-encoded data; raw bodies belong to `content=`
- Field reproduction: an onboarding step-3 smoke test sent repeated fields as a list of tuples and received 303 while `preferred_types`, `residence_history`, and `partners` all persisted empty; the identical request with a dict of lists persisted correctly. The status code was identical in both runs
