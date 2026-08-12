---
title: good fixture
---

# Good fixture

## Do this
- Never retry a 500 without a backoff — the server may be transiently overloaded.
- Do not cache the response. The upstream marks it no-store.

## Instead of
| Anti-pattern | Replacement |
|---|---|
| Retrying blindly | Never retry blindly — always confirm the response is safe to retry |

## Notes
A function that never-fails still needs input validation.

## State values
| Key | Behavior |
|---|---|
| Unknown key | Never read |
