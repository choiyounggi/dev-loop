---
id: testing-data-testcontainers-python-community-namespace
domain: testing
category: data
applies_to: [python, testcontainers]
confidence: verified
sources:
  - https://github.com/testcontainers/testcontainers-python/blob/main/src/testcontainers/redis.py
  - https://github.com/testcontainers/testcontainers-python/blob/main/src/testcontainers/community/redis/__init__.py
  - https://github.com/testcontainers/testcontainers-python/commit/ab6cca8e99e9b564aefddfa14edbc48a27d5a7bc
  - https://github.com/testcontainers/testcontainers-python/releases/tag/testcontainers-v4.15.0
  - https://pypi.org/pypi/testcontainers/json
last_verified: 2026-09-06
related: [testing-data-test-data-and-isolation, testing-strategy-test-level-choice]
---

# Importing Testcontainers-python Modules After the `community` Namespace Move

## When this applies

Writing or maintaining Python tests that start a service container through
testcontainers-python (`RedisContainer`, `PostgresContainer`, `KafkaContainer`,
…) with `testcontainers>=4.15.0` installed; a test run prints
`DeprecationWarning: testcontainers.<module> is deprecated, use
testcontainers.community.<module> instead`; a suite that runs with
`-W error::DeprecationWarning` (or `filterwarnings = error`) fails at import.

## Do this

1. **Import every service container from `testcontainers.community.<module>`.**
   Since 4.15.0 the service modules live under `testcontainers/community/` and
   the old top-level modules are shims that re-export the same class and emit a
   `DeprecationWarning` at import:

   ```python
   from testcontainers.community.redis import RedisContainer      # 4.15.0+
   ```

   The class is the same object (`testcontainers.redis.RedisContainer is
   testcontainers.community.redis.RedisContainer`) and the constructor is
   unchanged — `RedisContainer(image="redis:latest", port=6379, password=None, **kwargs)`
   — so the change is the import line only.
2. **Move the whole suite in one commit, then run it once with
   `-W error::DeprecationWarning`** so a leftover old-path import fails
   instead of printing once per collection.
3. **When the suite must also run on `<4.15.0`**, resolve the path once in a
   shared helper and import the class from there:

   ```python
   try:
       from testcontainers.community.redis import RedisContainer
   except ModuleNotFoundError:
       from testcontainers.redis import RedisContainer
   ```

## Edge cases

| Case | Then |
|------|------|
| The warning is attributed to the test file, not to testcontainers | The shim calls `warnings.warn(..., stacklevel=2)`, so the reported location is your import line — grep the tree for `from testcontainers\.[a-z0-9_]+ import` (no `community`) to list every site |
| `pytest` shows the warning in the summary and the run passes | The suite has no warnings-as-errors filter; the import still works on this version and a later release can drop the shim |
| The module is `core` (`testcontainers.core.container`, `DockerContainer`) | `core` did not move; only the service modules gained the `community` prefix |
| `pip show testcontainers` reports `<4.15.0` and `testcontainers.community` is absent | Upgrade first, or keep the fallback import from step 3 |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Silence the warning with a `filterwarnings` ignore for `testcontainers` | Change the import path | The shim exists to be removed; the ignore hides the removal until the suite fails on an upgrade |
| Pin `testcontainers<4.15` to keep the old paths | Move to `community` and unpin | The class and constructor are identical; only the module path changed |

## Sources

- https://github.com/testcontainers/testcontainers-python/blob/main/src/testcontainers/redis.py — the shim: `warnings.warn("testcontainers.redis is deprecated, use testcontainers.community.redis instead", DeprecationWarning, stacklevel=2)`
- https://github.com/testcontainers/testcontainers-python/blob/main/src/testcontainers/community/redis/__init__.py — the module's new home exporting `RedisContainer`
- https://github.com/testcontainers/testcontainers-python/commit/ab6cca8e99e9b564aefddfa14edbc48a27d5a7bc — "feat(main): make legacy imports available with deprecation notice" (2026-06-05), shipped in `testcontainers-v4.15.0` (https://github.com/testcontainers/testcontainers-python/releases/tag/testcontainers-v4.15.0; released 2026-07-24 per https://pypi.org/pypi/testcontainers/json)
- Local reproduction 2026-09-06 (fresh venv, Python 3.13, `testcontainers==4.15.0`): `from testcontainers.redis import RedisContainer` printed the DeprecationWarning and resolved to `testcontainers.community.redis`; the two names were the same class; `inspect.signature` gave `(self, image: str = 'redis:latest', port: int = 6379, password: Optional[str] = None, **kwargs: object)`; 45 top-level shim modules (`postgres.py`, `kafka.py`, …) mirror 45 `community/` packages, `core` unchanged
