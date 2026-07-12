---
id: qa-process-regression-scope
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://martinfowler.com/articles/rise-test-impact-analysis.html
last_verified: 2026-07-10
related: [qa-process-release-gates, qa-bug-reports-reproducible-reports]
---

# Choosing What to Re-Test for a Change

## When this applies

Choosing what to re-test for a release or change — full regression is too
expensive, gut feeling is too thin. Also applies when reviewing someone
else's proposed regression scope.

## Do this

Derive scope from the change itself, ring by ring. Every ring whose condition
holds is in scope; a ring is never dropped because an inner ring passed.

| Scope ring | What it contains | Test when |
|------------|------------------|-----------|
| Direct | The changed features/endpoints themselves | Always — every change |
| Adjacency | Features sharing code, data, or state with the change: same module, same table, same cache, same session | The change **writes to** the shared surface (a read-only consumer of shared state cannot corrupt its neighbors) |
| Integration | Consumers and producers of changed contracts: API request/response shape, DB schema, event/message shape | The contract changed — then test **every** consumer of that contract, not a sample |
| Blast radius | All critical flows, breadth-first | The change is a framework/dependency upgrade or cross-cutting (auth, logging, serialization middleware): run a broad smoke across all critical flows instead of deep single-feature testing — cross-cutting changes break anywhere, so depth in one feature buys nothing |

Two standing practices that make the rings work:

1. **Keep a living critical-flows list** — the top N user journeys, maintained
   as a document. It is the minimum regression floor for ANY release,
   including releases whose rings all come up empty.
2. **Record where regression bugs were actually found** (which ring, which
   adjacency). When a "shared table" adjacency keeps producing bugs, test it
   on every touch; when an adjacency has never broken across many releases,
   record that evidence and narrow it. Tune the map with evidence, not memory.

## Edge cases

| Case | Then |
|------|------|
| The change is in code with no test coverage and unclear callers | Trace callers before scoping (text pointer wiki/testing/ for coverage tooling); an adjacency you cannot enumerate defaults into scope |
| Data migration or backfill ships with the release | Add the migrated data's read paths to the direct ring — the "change" is the data, and its consumers are the changed feature |
| Two changes in one release touch the same adjacency | Test that adjacency once, after both changes are in the release build — testing between them validates a build that will never ship |
| Config-only or copy-only change | Direct ring only: verify the changed value/text where it surfaces, plus the critical-flows floor if the config gates a critical flow |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Re-test "the usual areas" from habit | Walk the four rings against this change's actual diff | Habit scope drifts from the code; the ring conditions are checkable against the diff |
| Deep-test one feature after a dependency upgrade | Broad smoke across all critical flows | Cross-cutting changes fail anywhere; one deep feature pass leaves every other flow unexamined |
| Skip regression because the automated suite passed | Apply the rings; automated coverage narrows ring depth only where the ring's paths are demonstrably covered | The suite covers what was anticipated when it was written — regression scope exists for what wasn't |

## Sources

- https://martinfowler.com/articles/rise-test-impact-analysis.html — selecting what to re-test from a map of what the change actually affects
