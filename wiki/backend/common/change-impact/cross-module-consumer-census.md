---
id: backend-common-change-impact-cross-module-consumer-census
domain: backend
category: change-impact
applies_to: [general]
confidence: verified
sources:
  - https://knip.dev/guides/handling-issues
  - https://knip.dev/reference/configuration
last_verified: 2026-08-11
related: [backend-common-change-impact-call-site-enumeration, testing-quality-tests-that-cannot-fail, infrastructure-agent-orchestration-worktree-isolated-workers]
---

# Counting the Production Consumers of a Symbol Your Task Just Added

## When this applies

Your task added a public function, endpoint, export, or hook whose consumer
belongs to a *different* task — parallel work split by file ownership, a backend
change whose UI wiring is another ticket, an agent worker producing a seam for a
sibling worker. You are deciding whether the task is done. Also when a feature is
typed, tested, reviewed, and merged, and changes nothing at runtime.

Enumerating the callers of a symbol whose contract you are *changing* →
[backend-common-change-impact-call-site-enumeration].

## Do this

1. **Take the new public symbols from the diff, not from memory**: names added by
   `git diff origin/main...HEAD` in the files you own. That list is the census's
   subject.

2. **Count references outside the defining module, excluding the symbol's own
   tests.** Grep the bare name across the repo, drop hits in the defining file
   and in test paths, and record the remaining file list per symbol. The tests
   are what make an orphan look alive — a symbol its own test calls has a
   non-zero reference count and no production reachability
   ([testing-quality-tests-that-cannot-fail]).

3. **Count references, not calls.** Search the bare name as well as `name(`:
   seam injection (`estimate_fn=estimate.estimate`), callback registration,
   decorator tables, and registry entries all pass the symbol as a value, and a
   paren-anchored search reports those wirings as dead.

4. **Classify each zero-consumer symbol by declared intent, and treat only the
   intent-bearing ones as defects.** The defect is a symbol whose docstring, plan,
   task brief, or PR body states that another module consumes it. A zero count on
   its own is the normal shape of a same-module helper. Unused-export tooling
   encodes the same three populations: knip's `ignoreExportsUsedInFile` exists
   because "In files with multiple exports, some of them might be used only
   internally", and its `includeEntryExports` exists because "By default, Knip
   does not report unused exports in entry files" — internal helpers and entry
   points are the two populations a raw count cannot separate from real orphans.

5. **Run the census at each task's review, not at integration.** At integration
   every task is already approved, so the missing wiring has no owner; at review
   the owning session is still open.

6. **When the consumer task already finished, open a follow-up task naming the
   file and the insertion point** — that task is the only thing standing between a
   complete implementation and dead code.

## Edge cases

| Case | Then |
|------|------|
| The symbol is dispatched dynamically (`getattr`, a name in YAML/config, a route string) | Search the string form too, and record in the task that this class of site is not statically enumerable |
| The symbol is itself an entry point (CLI command, HTTP route handler, hook) | Its consumer is a registration, not a call — assert the registration file lists it (route table, plugin manifest, entry map) instead of counting references |
| A working language server exists | Use find-references for the count and state that as the method; text search stays the fallback for aliased re-exports |
| The consumer lives in another repository or a published package | The census cannot see it: record the consuming repo and the version that will adopt it, and keep the symbol out of the defect list |
| The symbol is re-exported through a package `__init__` or facade | Count references to the re-exported name as well, or every facade consumer reads as zero |
| The census returns zero for every new symbol | Suspect the search, not the code: confirm the pattern matches one symbol you know is wired before reading any zero as a finding |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Report every symbol with no reference outside its defining file as dead code | Filter that list by declared cross-module intent, and report those | Internal helpers dominate the raw list; measured on one module, 14 of 14 zero-consumer functions were reported and exactly 1 was a defect, so the unfiltered list buries the finding |
| Search `name(` to find consumers | Search the bare name as well | Seam injection and callback registration pass the symbol as a value and never write the paren |
| Treat "type-check, tests, and CI all green" as proof the wiring landed | Run the consumer census before calling the task done | Nothing in a type system or a test suite requires a new public symbol to have a production caller |
| Defer the census to the integration branch | Run it in each task's review | After every task is approved, the missing 3 lines belong to nobody |

## Sources

- https://knip.dev/guides/handling-issues — a surprising unused-export report "is usually a real finding or a configuration gap, not a false positive to silence"; before deleting, check whether the export is in an entry file, re-exported from another entry point, or tagged for external use — the report is a candidate list that intent resolves
- https://knip.dev/reference/configuration — `ignoreExportsUsedInFile`: "In files with multiple exports, some of them might be used only internally. If these exports should not be reported, there is a `ignoreExportsUsedInFile` option available"; `includeEntryExports`: "By default, Knip does not report unused exports in entry files"
- Field measurement 2026-08-11 (Python module set, 6 tasks split across parallel workers by file ownership): a census of every public function counted cross-module production references; 14 came back zero. Exactly one was a real gap — a URL-building helper whose docstring named its consumer ("the caller puts this in the Slack body") and which no producer of that message ever called, leaving the notification's approval link unsigned. The other 13 were same-module helpers. All 6 tasks had passed review, 402 tests were green, and the merge had no conflicts
