---
id: backend-python-language-dict-subclass-attribute-loss-on-copy
domain: backend
category: language
applies_to: [python]
confidence: verified
sources:
  - https://docs.python.org/3/reference/expressions.html#dictionary-displays
  - https://docs.python.org/3/library/copy.html
  - "Local reproduction (python3 3.14.6, 2026-09-08): dict(obj, **{...}) and {**obj, ...} on a dict subclass both yield type(...) == dict with the subclass's instance attribute gone; copy.copy(obj) yields the original subclass with the attribute intact"
last_verified: 2026-09-08
related: [backend-python-language-mutable-state-traps, databases-transactions-optimistic-vs-pessimistic-locking]
---

# Dict Subclass Attributes Lost When Building a New Dict From It

## When this applies

You hold an instance of a `dict` subclass that carries extra instance
attributes alongside its key/value contents — an ORM/driver row wrapper
storing optimistic-lock version info, an ETag, or similar out-of-band
metadata — and you need to add or override a key on it before passing it
onward (to a serializer, a cache, an UPDATE builder).

## Do this

| Case | Do |
|------|----|
| The mutation must not be visible to other holders of the same reference | `copy.copy(obj)`, then mutate the copy — `copy.copy()` "normally returns an instance of the same type", preserving the subclass and its instance attributes; the top-level container is independent of the original |
| The original may be safely changed temporarily and must be restored before anything else observes it | Mutate in place — `obj[key] = value` — then revert in a `finally`: `obj.pop(key, None)` |
| The receiver is verified to never read the subclass's instance attributes | `dict(obj, **{key: value})` / `{**obj, key: value}` is fine — but the verification has to happen first, not be assumed |

`dict(obj, **{...})` and `{**obj, ...}` are dictionary displays, and "a
dictionary display yields a new dictionary object" — always plain `dict`,
regardless of the runtime type of `obj`; `**` unpacking only copies key/value
pairs into that new object, never `__class__` or `__dict__`/`__slots__`. Reach
for them only in the third row's case.

## Edge cases

| Case | Then |
|------|------|
| Downstream code reads the attribute via `getattr(row, "x", None)` | The loss is silent — `getattr` returns the default with no exception, so the bug shows up as wrong behavior far from the copy site, not a stack trace at it |
| Downstream code reads the attribute directly (`row.x`) | The loss is loud — a plain `dict` raises `AttributeError: 'dict' object has no attribute 'x'` immediately, which is why this trap survives in codebases that always use `getattr` defensively |
| The subclass nests further mutable state (a cache, a list) that must also stay independent of the original | `copy.copy()` is shallow — nested mutable values still alias the original object; only the top-level container and its own attributes are independent |
| The subclass defines `__copy__` | `copy.copy()` calls it — confirm the override also copies instance attributes before relying on it as the fix |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build `dict(row, **{key: value})` or `{**row, key: value}` from a `dict` subclass carrying instance attributes | `copy.copy(row)` then mutate the copy, or mutate `row` in place and revert in a `finally` | Dictionary displays always construct a plain `dict`; the subclass type and every attribute that lived only on the instance are silently dropped |

## Sources

- https://docs.python.org/3/reference/expressions.html#dictionary-displays — "A dictionary display yields a new dictionary object"
- https://docs.python.org/3/library/copy.html — slicing and `.copy()` methods "can create an instance of the base type when copying an instance of a subclass, whereas copy.copy() normally returns an instance of the same type"
- Local reproduction (python3 3.14.6, 2026-09-08): a `VersionedRow(dict)` with instance attribute `observed_version=42`; `dict(row, **{"_schema_gen": "abc"})` and `{**row, "_schema_gen": "abc"}` both produced `type(...) == dict`, `hasattr(..., "observed_version") == False`; `copy.copy(row)` produced `type(...) == VersionedRow`, `observed_version == 42`, and mutating the copy left `row` untouched; `getattr(dict_instance, "observed_version", "DEFAULT")` returned `"DEFAULT"` while `dict_instance.observed_version` raised `AttributeError`
- Field incident (a Python SQLite repository driver): `_read` returns a `_VersionedRow(dict)` carrying `.observed_version` for a conditional UPDATE; `dict(row, **{"_schema_gen": digest})` silently dropped `.observed_version`, turning every conditional UPDATE unconditional — caught by failing concurrency/retry-conflict tests (`1 != 10` on a concurrent-increment test), not by an exception
