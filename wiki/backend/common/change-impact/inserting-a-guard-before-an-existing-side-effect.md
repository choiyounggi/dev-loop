---
id: backend-common-change-impact-inserting-a-guard-before-an-existing-side-effect
domain: backend
category: change-impact
applies_to: [general, shell]
confidence: field-tested
sources:
  - https://www.eiffel.org/doc/eiffel/ET-_Design_by_Contract_(tm)%2C_Assertions_and_Exceptions
  - "Field reproduction (dev-loop t106, 2026-08-17): status-update.sh:19 unconditionally created a default status file for every phase; the plan's proposed guard placement sat after that line, so the guard could never observe the missing file it checked for"
last_verified: 2026-08-17
related: [backend-common-change-impact-call-site-enumeration, qa-exploratory-guard-true-path-coverage]
---

# A New Precondition Guard Inserted Into Code That Already Mutates the Checked State

## When this applies

You are implementing, adopting, or auditing a planned change that adds a
precondition guard ("refuse when the file is missing", "abort when X is absent")
to an existing script or function — and the plan describes the insertion point in
prose ("after the extra is built", "at the start of phase 2") rather than by the
target's actual lines. Especially when an earlier line in the target already has
an unconditional default/auto-create side effect.

## Do this

1. **Trace the target's actual execution order before placing the guard.** Read
   the file and pin the insertion point between named line numbers, not by the
   plan's phase prose. A plan can get the *decision* right while getting the
   *placement* wrong: "after X is built" reads as a natural phase description
   but ignores an unrelated earlier line that already mutated the state.
2. **Confirm the guard sits textually before the first statement that can mutate
   the state it checks.** An earlier `[ -f "$file" ] || create-default` makes a
   later "refuse if file missing" guard dead code — the state it tests for can
   no longer occur. This mirrors precondition doctrine: a precondition is
   checked *on entry*, before any of the body runs (Eiffel monitors
   preconditions "on routine entry").
3. **When the planned placement lands after such a side effect, surface the line
   numbers instead of silently re-planning.** In orchestrated or reviewed work,
   report "guard at plan-position L would run after side effect at line N" and
   let the plan owner move it — the decision itself is unchanged; only the
   placement moves.
4. **Test the guard's negative path against the side effect, not just the exit
   code.** Assert both the refusal (exit code/error) *and* that the earlier side
   effect did not run (the default file was not created). A guard placed after
   the auto-create can return the right code with the wrong state.

## Edge cases

| Case | Then |
|------|------|
| The side effect lives in a sourced helper or a function called earlier | Trace through the call, not just the top-level lines — "textually before" means before in execution order |
| The side effect is itself conditional (runs only for some inputs/phases) | Decide placement per path: the guard must precede it on every path where both can apply |
| The plan's prose position and the correct line position coincide | Still record the line numbers in the plan/PR — the next inserted line inherits the same ambiguity |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Implement the guard at the position the plan's prose describes | Read the target file and pin the insertion between named lines | Prose phases do not map one-to-one onto line order; an earlier unconditional line can precede "phase start" |
| Test the new guard by exit code alone | Also assert the pre-existing side effect did not fire | The refusal can be correct while the state the guard was meant to protect is already mutated |
| Quietly move the guard yourself in delegated/orchestrated work | Escalate with both line numbers and a proposed snippet | The plan owner may know a reason for the ordering; a silent rewrite hides the defect class from review |

## Sources

- https://www.eiffel.org/doc/eiffel/ET-_Design_by_Contract_(tm)%2C_Assertions_and_Exceptions — preconditions are monitored "on routine entry", i.e. before the body executes; a check placed after a mutation is not a precondition
- Field reproduction (dev-loop t106, 2026-08-17): `status-update.sh:19` unconditionally created `{"task":"…"}` for any phase; the originally planned rework-guard placement sat after it. Escalated with line numbers; the revised plan moved the guard between lines 18–19, and the BATS case "rework with no status file → exit 4, **no file created**" passed only with that placement
