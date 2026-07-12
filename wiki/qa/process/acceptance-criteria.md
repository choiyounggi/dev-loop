---
id: qa-process-acceptance-criteria
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://martinfowler.com/bliki/GivenWhenThen.html
  - https://cucumber.io/docs/gherkin/reference/
  - https://www.agilealliance.org/glossary/acceptance/
  - https://www.agilealliance.org/glossary/definition-of-ready/
last_verified: 2026-07-10
related: [qa-process-regression-scope, qa-process-release-gates]
---

# Writing Acceptance Criteria That Settle "Done" Before Development

## When this applies

Writing or reviewing a feature ticket/user story before development starts;
"done" is disputed at QA time; or a delivered feature technically works but
misses what the requester wanted.

## Do this

Acceptance criteria are **testable statements agreed before implementation**.
The test of each criterion: a person who did not write it can read it, run the
product, and answer pass or fail — a binary answer, no interpretation. Pick
the form by what the requirement describes:

| Requirement kind | Write it as |
|------------------|-------------|
| Behavioral flow (user does something, system responds) | `Given <starting state> When <action> Then <observable outcome>` — one scenario per rule, concrete values over abstractions: "Given a cart with 2 items", not "Given some items" |
| Non-flow quality (performance, compatibility, limits) | Checklist item with a measurable threshold: "list loads under 2s at 10k rows", not "fast"; "works on the two newest major iOS versions", not "works on mobile" |

Three rules that make the set complete:

1. **Every criterion gets its negative/edge twin decided.** For each happy-path
   rule, write down what happens on invalid input, empty state, and limit
   exceeded. An edge left undecided at ticket time becomes a production
   surprise or a QA dispute — deciding it costs one question now.
2. **Run a vague-word audit before development starts.** Flag "properly",
   "user-friendly", "handles errors gracefully", "etc." in the ticket — each
   hides an undecided decision. Resolve each flagged word with the requester
   into a Given/When/Then or a threshold; a vague word left in the ticket is a
   dispute scheduled for QA time.
3. **Criteria seed the test plan.** They become the direct-ring cases of
   regression scope ([qa-process-regression-scope]) and the checklist items of
   the release gate ([qa-process-release-gates]); their automated variants go
   to the automated-test backlog (wiki/testing/).

Scope-creep guard: work not covered by a criterion is a **new ticket**, not a
silent extension of this one. The criteria set is the ticket's boundary in
both directions — it defines what must be done and what is out.

## Edge cases

| Case | Then |
|------|------|
| Delivered feature meets every criterion but misses the intent | The criteria were wrong, not the verdict: the ticket is done. Fix the criteria set (add the missing rule) in a follow-up ticket, and record what the review missed — the feedback loop improves the next ticket, relitigating "done" improves nothing |
| Requester cannot name a threshold ("just make it fast") | Propose a concrete number from current behavior or a comparable flow and get it confirmed — a wrong proposed number gets corrected in review; "fast" ships a dispute |
| An undecided edge surfaces mid-development | Decide it with the requester and add the criterion before the code path is built — the same rule as at ticket time, applied late |
| The ticket is a bug fix | The report's expected-vs-actual pair ([qa-bug-reports-reproducible-reports]) is the criterion: Given the report's preconditions, When its steps run, Then the expected line holds |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Accept "works as expected" as a criterion | Spell the expectation out as Given/When/Then with concrete values | "Expected" points at a picture in the author's head; the picture in the tester's head differs, and the difference surfaces as a dispute after the code is written |
| Let disputes surface at QA time | Review criteria as part of ticket readiness (definition of ready): binary-testable, edge twins decided, vague words resolved — before development starts | The same question costs one conversation before coding and a rework cycle after |
| Leave "handles errors gracefully" in the ticket | Enumerate the error cases and write each one's Then | "Gracefully" is a decision the developer will make alone at 5pm; enumerating makes it the requester's decision |
| Fold newly requested behavior into the in-flight ticket | Open a new ticket with its own criteria | Silent extensions have no criteria, so they ship untested and unreviewed |

## Sources

- https://martinfowler.com/bliki/GivenWhenThen.html — Given/When/Then structure: preconditions, action, observable outcome (Specification by Example)
- https://cucumber.io/docs/gherkin/reference/ — Given = initial context, When = event, Then = expected outcome; one scenario per rule
- https://www.agilealliance.org/glossary/acceptance/ — acceptance tests as formal behavior descriptions with binary pass/fail outcomes
- https://www.agilealliance.org/glossary/definition-of-ready/ — explicit readiness criteria a story meets before work starts
