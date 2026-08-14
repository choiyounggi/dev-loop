# Review — {TASK} round {N}

**Verdict:** approve | rework

## Per-lens results

Every row must be filled in every round — a lens that was not run and a lens
that passed clean are different outcomes; an omitted row reads as a passed
one unless you say otherwise.

| Lens | Result |
|---|---|
| 1. Plan conformance | `clean — <what was checked>` or `findings: F1, F2` or `not run — <why>` |
| 2. Wiki re-route from the diff | `clean — <what was checked>` or `findings: F1, F2` or `not run — <why>` |
| 3. Execution-environment reality | `clean — <what was checked>` or `findings: F1, F2` or `not run — <why>` |
| 4. Multi-object write ordering | `clean — <what was checked>` or `findings: F1, F2` or `not run — <why>` |

## Findings

Each finding must state a concrete failure scenario. If it cannot, it belongs
in **Non-blocking** below, not here.

### F1

- **Observation** — <what the diff does, quoted at `file:line`>
- **Failure scenario** — <the concrete inputs/state that make it wrong>
- **Question** — <"why this way?" — never a directive telling the worker what
  to do instead>

## Non-blocking

Observations that cannot state a concrete failure scenario — worth asking,
not worth blocking approval on.

### N1

- **Observation** — <what the diff does, quoted at `file:line`>
- **Question** — <"why this way?">
