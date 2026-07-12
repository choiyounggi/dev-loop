---
id: backend-python-boundaries-runtime-validation
domain: backend
category: boundaries
applies_to: [python, pydantic, fastapi]
confidence: verified
sources:
  - https://docs.python.org/3/library/typing.html
  - https://pydantic.dev/docs/validation/latest/concepts/models/
  - https://pydantic.dev/docs/validation/latest/concepts/strict_mode/
  - https://pydantic.dev/docs/validation/latest/concepts/pydantic_settings/
  - https://fastapi.tiangolo.com/tutorial/body/
last_verified: 2026-07-10
related: [backend-common-api-design-error-responses, backend-common-jobs-idempotent-handlers]
---

# Runtime Validation of External Data in a Type-Hinted Python Service

## When this applies

Typing or validating request bodies, env/config, queue messages, or external
API responses in a Python service; code treats type hints as guarantees on
data that crossed a process boundary; choosing where validation happens and
where hints alone suffice.

## Do this

1. The Python runtime does not enforce type annotations — a parameter hinted
   `int` accepts anything at runtime. Data that crosses a process boundary
   gets **runtime validation at that boundary**; hints describe only what the
   type checker verified inside the process.

2. Validate with a pydantic-style model: parsing untrusted input yields a
   typed object whose fields are guaranteed to conform, and a failed parse
   raises one `ValidationError` enumerating every bad field with its location.
   The model class is the single source of the type — annotate downstream
   functions with the model, never a parallel `TypedDict`/dataclass copy.

3. Apply per boundary:

| Boundary | Do |
|----------|----|
| HTTP request body | Validate with a model at the endpoint — FastAPI runs this from the parameter's type annotation and rejects invalid bodies with per-field errors (422). Error body shape and status-code choice → [backend-common-api-design-error-responses] |
| Env vars / config | Load through a settings model (pydantic `BaseSettings`) validated **once at startup** — invalid config crashes at boot, not on the first request that reads the value |
| Third-party API response | Parse the response into a model before any field access — declare only the fields you use |
| Queue / event message | Parse before handling; a message that fails parsing is a poison message — route it per [backend-common-jobs-idempotent-handlers], never retry-loop it |
| Internal function-to-function | Type hints + a type checker (mypy/pyright) suffice — data already validated at the boundary needs no re-validation on every hop |

4. Choose strict vs lax coercion per field, deliberately. Lax mode (default)
   coerces `"1"` → `1`; strict mode errors on the wrong type.

| Field | Mode |
|-------|------|
| Source is stringly-typed by nature (env vars, query params, form fields) | Lax — coercion from string is the mechanism doing the parsing |
| The type distinguishes meaning (numeric id vs string code, `bool` flag in a JSON body, money amounts) | Strict — `Field(strict=True)` / `StrictInt`; silent coercion here masks a caller sending the wrong shape |

## Edge cases

| Case | Then |
|------|------|
| Response model has fields the provider added recently | Default pydantic ignores unknown fields — parsing stays stable when the provider adds fields; declare new fields when you start using them |
| Endpoint must accept a body your model rejects (legacy clients) | Widen the model explicitly (`Optional`, unions, defaults) — the model stays the contract; bypassing it for one client forks the type in two |
| Validation cost on a hot path with large payloads | Measure before optimizing; keep boundary validation and remove internal re-validation (row 5 above) — the duplicate hops are the overhead, not the boundary parse |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `cast()` or `# type: ignore` on external data to satisfy the checker | Parse it with a model at the boundary | `cast` changes what the checker believes, not what arrives at runtime — the mismatch surfaces later as an `AttributeError`/`TypeError` far from the boundary |
| Access `response.json()["a"]["b"]` fields directly | Parse into a response model first | A provider shape change becomes one `ValidationError` naming the field, not a scattered `KeyError` |
| Read `os.environ` ad hoc across modules | Centralize in a startup-validated settings model | Bad config fails at boot with the field named, instead of mid-traffic |
| Re-validate the same model on every internal call | Validate once at the boundary; pass the typed object through | Inside the process the type checker already guarantees the shape |

## Sources

- https://docs.python.org/3/library/typing.html — "The Python runtime does not enforce function and variable type annotations"; hints are for type checkers/IDEs
- https://pydantic.dev/docs/validation/latest/concepts/models/ — untrusted data parsed into a model is guaranteed to conform to the field types; one `ValidationError` reports all errors with field locations; `model_validate`
- https://pydantic.dev/docs/validation/latest/concepts/strict_mode/ — lax mode coerces (`"123"` → `123`) by default; strict mode errors instead; per-field via `Field(strict=True)` / `StrictInt`
- https://pydantic.dev/docs/validation/latest/concepts/pydantic_settings/ — `BaseSettings` reads fields from the environment and raises `ValidationError` on invalid/missing values
- https://fastapi.tiangolo.com/tutorial/body/ — FastAPI reads, converts, and validates the body from the pydantic model annotation and returns errors indicating exactly where the data was wrong
