---
id: backend-common-api-design-server-decisions-in-status-responses
domain: backend
category: api-design
applies_to: [general]
confidence: field-tested
sources:
  - https://phauer.com/2015/restful-api-design-best-practices/
last_verified: 2026-11-03
related: [backend-common-api-design-api-versioning-and-breaking-changes, frontend-state-concurrent-optimistic-updates]
---

# A Client Tool That Displays a Server's Decision

## When this applies

A server makes a decision from its own state and settings — a router or
gateway picks an account, marks a quota as exhausted, excludes a backend — and
a separate client (CLI status command, dashboard, tray app) shows the user that
decision through a status or listing endpoint.

## Do this

1. **Put the decision itself in the response.** Build the field (`available`,
   `selected`, `excluded` with a `reason`) by calling the same function the
   server uses when it decides, not a second implementation of it. The client
   prints that field as it is.
2. **Send the raw inputs only as context.** Scores, percentages and limits may
   stay in the response for display, but the client does not combine them into
   its own verdict.
3. **Stamp the response with the server's clock.** Include `generatedAt` and
   compute every relative time the client shows ("resets in 12 min") from that
   value, not from the client's clock.
4. **Test that the field and the decision cannot drift.** One server-side test
   asserts that the response's decision field equals the decision function's
   result for the same state, and it must go red when the field is replaced by
   a fixed value.

| Response field | Client does |
|----------------|-------------|
| Decision (`available`, `selected`, `reason`) | Shows it unchanged |
| Inputs (score, usage %, limit) | Shows them as detail only |
| `generatedAt` | Uses it as "now" for every relative time |

## Edge cases

| Case | Then |
|------|------|
| The decision depends on the request (model, tenant, size) | Accept that input as a query parameter and return the decision for it, or return one decision per value (`availableByModel`) |
| An older server lacks the decision field | The client says the decision is unknown and shows the raw inputs; it does not fall back to computing a verdict |
| The decision changes between the status call and the next real request | Label the display as a snapshot at `generatedAt`; the real request still decides on its own |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Recompute "ok / limited" in the client from scores and limits | Return the server's decision field and display it | The copy misses server settings (a limit below 100 %) and per-model rules, so it shows an excluded account as `ok` |
| Compute "resets in N min" from the client's clock | Compute it from the response's `generatedAt` | Client and server clocks differ, and the server's clock decided the reset |

## Sources

- https://phauer.com/2015/restful-api-design-best-practices/ — "Keep Business Logic on the Server-Side": when logic moves to the client it is often duplicated between client and server, which couples them so a new rule needs changes on both sides; adding fields is a backward-compatible change for tolerant clients
- Field case 2026-11-03: a router's status endpoint returned per-account scores and limits and a separate CLI judged `ok` from them. A counterexample review showed accounts the router had excluded (a configured `limitPct: 90`, a full per-model window) displayed as `ok`. After the endpoint returned `available` from the router's own ranking function, a pool test asserted that the `available` list equals the `ranked()` result, and the test went red when `available` was fixed to a constant
