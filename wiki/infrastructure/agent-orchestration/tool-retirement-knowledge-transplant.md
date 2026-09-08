---
id: infrastructure-agent-orchestration-tool-retirement-knowledge-transplant
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/choiyounggi/dev-loop/pull/130
last_verified: 2026-09-08
related: [infrastructure-agent-orchestration-session-context-token-budget]
---

# Retiring a Plugin or Tool That Carries Methodological Value

## When this applies

About to disable, uninstall, or stop loading a plugin, skill library, or tool
because of its token, context, or maintenance cost, and that tool's
skills/instructions encode development methodology rather than only mechanical
automation; deciding whether to just turn it off or preserve what it teaches
first.

## Do this

1. **Inventory before disabling.** Read every skill/instruction text the tool
   ships in full — not just titles or descriptions — before deciding what to
   keep.
2. **Gap-analyze at trigger granularity, not tool granularity.** Compare each
   inventoried item against your own knowledge base by the specific situation
   that invokes it. A skill can be covered for one trigger and missing for
   another inside the same tool, so comparing whole tools against whole
   knowledge bases hides partial gaps.
3. **Port only confirmed gaps (merge-before-create).** Create a new page/entry
   only where the gap analysis found nothing covering that trigger. Where your
   base already owns the trigger but the retired tool's version is deeper
   (a sharper edge case, a measured failure mode), merge that content into the
   existing entry instead of creating a second one.
4. **Record every already-covered item in a skip list.** Log the item and the
   reason it was skipped (which existing page/id already owns its trigger) so
   the same comparison is not silently re-run later and a duplicate is not
   created by a future pass that forgets the first one happened.
5. **Verify the port before disabling the tool.** Run an automated structural
   or duplication check (a wiki/docs lint, a link/id validator) over the
   ported material and only disable the tool once that check passes — a port
   that has not been checked is not yet complete.

## Edge cases

| Case | Then |
|------|------|
| The retired tool's item is deeper or more specific than your existing entry (a benchmark result, a worked failure-mode table) | Merge the stronger content into the existing entry rather than keeping both versions side by side |
| An item's trigger only partially overlaps an existing entry (some situations match, some don't) | Split the comparison at trigger granularity and port only the uncovered sub-trigger, not the whole item |
| No independent reviewer is available to check the port | Run a scripted structural/duplication check as the minimum bar before treating the port as complete |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Disable a plugin/tool outright because of its token or maintenance cost | Inventory its skills, gap-analyze them against your knowledge base at trigger granularity, and port only what's missing | Removing the tool without porting loses methodology it uniquely covered; nothing else in your base captures it once it's gone |
| Port a retired tool's material wholesale into your knowledge base | Compare at trigger granularity first and skip items your base already covers, recording them in a skip list | Wholesale porting creates duplicate entries that pollute the knowledge base and make future lookups less precise |

## Sources

- https://github.com/choiyounggi/dev-loop/pull/130 — merged PR: inventoried superpowers 6.3.0 (14 skills) and compound-engineering 2.63.1 (~30 skills + review-persona heuristics) in full before disabling either plugin for context budget; gap-analyzed at trigger granularity, found 8 real gaps, ported them as 8 new pages plus 3 amendments; already-covered items recorded in a skip list (log.md); verified with `node scripts/wiki-lint-prohibitions.js` (71/71 compliant, 0 violations) and `node scripts/wiki-structure-checks.js wiki` (260 pages / 13 indexes / 0 findings) before treating the port as done
