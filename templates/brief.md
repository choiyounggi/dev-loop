<!-- briefs/<task>.md — the orchestrator writes one per task (orchestrate Phase 3
     step 2) and the worker reads it as the whole statement of its work.
     Replace every <...> placeholder. Drop a section only when the skill says it
     does not apply (e.g. Design spec for a backend-only task). -->

# <task-id> — <one-line goal>

## Goal
<What this task must achieve, in the user's terms. One paragraph, no solutioning.>

## Scope
- Worktree: <absolute path — do all work here, never in the main worktree>
- Branch: <branch>
- Affected files: <the paths this task owns; no other task in this Wave writes them>

## Outputs
<What this task newly creates — component / schema / endpoint / type — written as
the exact signature other tasks will consume. This is what gets injected into a
later Wave's dependencies, so make it copy-pasteable.>

## Consumes
<dependencies>
<!-- Phase 3 step 0. The EXACT signatures this task depends on: from the approved
     preceding Wave, and from any already-completed (partial-resume) child. Paste
     the real signature, never a paraphrase — loose text invites drift. Leave the
     block empty for a Wave 1 task with no dependencies. -->
</dependencies>

## Tools
<tools_guidance>
<!-- The resolved tool profile for this task, role by role: knowledge, tacit,
     verify, explore, design. Name the actual tool per role so the worker inherits
     it even if it cannot re-read the config; write "default" for an unset role.
     The plan step is NOT a role — it is fixed to wiki-plan. -->
</tools_guidance>

## Design spec
<design_spec>
<!-- Only for a UI-facing task whose source issue references a design: the spec
     pulled with the `design` role (not the bare link). Omit this whole section
     for a backend-only task or when `design` is unset. -->
</design_spec>

## Done criteria
- <verifiable condition — a command whose output proves it, not an opinion>
- Tests cover normal + error + boundary; no existing test is weakened or deleted.
- The worktree diff contains only this task's affected files.
