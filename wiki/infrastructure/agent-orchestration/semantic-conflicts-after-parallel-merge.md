---
id: infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge
domain: infrastructure
category: agent-orchestration
applies_to: [general, git]
confidence: verified
sources:
  - https://martinfowler.com/bliki/SemanticConflict.html
  - https://git-scm.com/docs/git-merge
  - https://doc.rust-lang.org/error_codes/E0004.html
  - https://pnpm.io/cli/install
  - https://www.prisma.io/docs/orm/prisma-client/setup-and-configuration/generating-prisma-client
last_verified: 2026-09-06
related: [infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-autonomous-decision-rulings, backend-common-change-impact-cross-module-consumer-census, backend-common-change-impact-widening-a-closed-value-table, qa-process-completion-claims]
---

# Merging Parallel Branches That Each Pass on Their Own

## When this applies

A coordinator is integrating two or more branches produced in parallel (worktree
workers, sibling tasks of one wave); each branch is green in isolation; the merge
reports no textual conflict; dependent work is about to be dispatched on top of
the merged tree. The sharpest form: one branch **consumes** a shared type (adds a
`match`/`switch` arm, a mapping row, a handler) while another **extends** it (adds
an enum variant, a field, a case).

## Do this

1. **Read "no conflict" as a statement about text, not about the program.**
   Git's merge incorporates non-overlapping hunks verbatim and stops only where
   both sides edited the same area. A pair of changes that are textually
   independent yet change what each other means is a *semantic conflict*, which
   version control cannot detect; only compiling and testing the union can.

2. **Build and run the full suite on the merged tree before any dependent
   dispatch**, in the integration worktree, and act on the result:

| Merged-tree result | Do |
|--------------------|----|
| Green, with the test total the branches together imply | Dispatch dependents |
| Compile error naming a type both branches touched (Rust `E0004` non-exhaustive patterns, an exhaustiveness error in TypeScript/Kotlin) | Write the resolution commit on the integration branch as coordinator (cover the new variant) and re-run — neither branch is wrong on its own, so sending it back to a worker has no owner |
| Green, but the total dropped | A module failed to load; read it as red ([qa-process-completion-claims]) |
| `Cannot find module <pkg>` across many suites, or a generated client missing a model the merge added (`prisma.<model>` undefined) | Re-sync the integration worktree's installed dependencies and generated code first (`pnpm install` and `prisma generate`, or the stack's equivalent) and re-run; read the result as a regression only when it survives the re-sync — each worker worktree bootstrapped its own `node_modules` and generated client, while the integration worktree still holds the pre-merge install |
| A test neither branch changed fails | A behavior conflict: revert one branch's merge, re-run to attribute it, then resolve on the integration branch |

3. **Predict the conflict from the branch pair before merging.** Two diffs that
   touch the same type or closed table from opposite sides (consume vs extend)
   are the semantic-conflict shape; merge that pair first and budget a
   resolution commit. The closed-table variant of the same hazard:
   [backend-common-change-impact-widening-a-closed-value-table].

4. **Commit the resolution on its own, naming both branches in the message**
   (`fix(integration): cover RunEvent::Presence (t2) in t1's match`), so the
   run's ledger explains a change no task brief asked for
   ([infrastructure-agent-orchestration-autonomous-decision-rulings]).

5. **Re-run the merged-tree gate after every further branch lands.** A third
   branch can re-open the conflict a first resolution closed.

## Edge cases

| Case | Then |
|------|------|
| The language has no exhaustiveness check (a JS `switch` with `default`, a Python `if/elif` chain) | The compiler stays silent and the missing arm is a runtime gap; add a test that enumerates the type's cases and asserts each is handled, then run it on the merged tree |
| The full suite is too slow to run per merge | Run the compile/typecheck step per merge and the full suite once per wave, and record in the ledger which merges were compile-gated only |
| CI already runs on the merge commit | That run is this gate; read its result before dispatching — two green branch badges are not a green merge |
| The resolution needs a decision (which handling of the new variant is right) | Adding the arm is the coordinator's mechanical fix; its semantics are a ruling to record, or a question for the human when it falls in a stop category |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Dispatch dependents as soon as `git merge` exits 0 | Build and test the merged tree first | Exit 0 means no overlapping text; the compiler is what checks meaning |
| Send the compile error back to the worker whose branch "broke" | Resolve on the integration branch | Neither branch is defective in isolation; the conflict exists only in the union |
| Cite two green branch runs as a green integration | Cite the merged tree's own run | Green and green does not imply green for the merge when the branches share a type |
| Diagnose `Cannot find module` or an undefined generated model on the merged tree as a broken merge | Re-install and re-generate in the integration worktree, then re-run | The failure names the install, not the code: the merge brought a dependency or schema model that the worktree's `node_modules` predates |

## Sources

- https://martinfowler.com/bliki/SemanticConflict.html — changes "which can be safely merged on a textual level but cause the program to behave differently"; version control "will only protect you from textual conflicts"; the defenses named are self-testing code and frequent integration
- https://git-scm.com/docs/git-merge — the 3-way merge takes non-overlapping changes verbatim and asks for resolution only where both sides changed the same area; no compile or test step is part of the merge
- https://doc.rust-lang.org/error_codes/E0004.html — a `match` that does not cover every variant of an enum fails to compile with "non-exhaustive patterns"
- Field reproduction 2026-09-02 (linkly-crew orchestration run slk1): t1 added a `match` over `RunEvent`, t2 added `RunEvent::Presence`; both branches green, the merge had no textual conflict and failed with E0004; the merged-tree integration test caught it and a one-line coordinator commit `fix(integration): cover RunEvent::Presence` resolved it
- https://pnpm.io/cli/install — with `--frozen-lockfile` (the CI default) install "fails to install if the lockfile is out of sync with the manifest"; a merge that changed the manifest leaves the integration worktree's install behind until `pnpm install` runs again
- https://www.prisma.io/docs/orm/prisma-client/setup-and-configuration/generating-prisma-client — run `prisma generate` "whenever you add models, change fields, or update generator settings"; the generated client in the integration worktree predates the merged schema until then
- Field reproduction 2026-09-02 (linkly-calendar orchestration run trip3): right after merging the worker branches into the main worktree, 7 unit suites failed with `Cannot find module 'undici'` and 2 e2e cases with `prisma.trip` undefined; `pnpm install` + `pnpm prisma:generate` in the main worktree, with no code change, restored the suites to 318/1 (unit) and 16/16 (e2e)
