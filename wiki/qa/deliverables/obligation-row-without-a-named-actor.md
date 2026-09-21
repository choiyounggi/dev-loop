---
id: qa-deliverables-obligation-row-without-a-named-actor
domain: qa
category: deliverables
applies_to: [general]
confidence: verified
sources:
  - https://www.incose.org/docs/default-source/working-groups/requirements-wg/guidetowritingrequirements/incose_rwg_gtwr_v4_summary_sheet.pdf
  - https://www.jamasoftware.com/legacy/requirements-management-guide/writing-requirements/incose-requirements-writing-guide/
  - https://www.altium.com/documentation/altium-365/requirements-systems-portal/valiassistant/quality-assessment
  - https://alistairmavin.com/ears/
  - http://principles-wiki.net/principles:don_t_repeat_yourself
last_verified: 2026-09-17
related: [qa-deliverables-exclusivity-and-absence-claims, qa-document-verification-spec-document-gates, backend-common-llm-binding-instructions-for-agents]
---

# A Table Row That States an Obligation Another Contract Already Fixes

## When this applies

You are writing or reviewing a row in a tier, profile, matrix, or policy table
(risk tier → pipeline profile, environment → required checks, role → duties) whose
row label names an obligation — "test audit", "security review", "sign-off" — that a
second document also governs and pins as mandatory: a worker protocol, a
checksum-pinned prompt, a CI policy, a compliance checklist. Also when a plan handed
you the table already carrying such a row, and when a reviewer reports two contracts
that disagree on the same obligation.

## Do this

1. **Before committing the row, grep every sibling contract for the obligation
   noun** (`grep -rn 'audit' skills/ templates/ docs/`) and read each hit for who
   it binds. An obligation that exists in two documents is one piece of knowledge
   with two representations, and DRY's warning is exactly that "at some point in
   time the different representations diverge which is a fault".
2. **Name the actor as the subject of the row label and of every cell.** INCOSE
   rule R2 for requirement statements: use the active voice "with the responsible
   entity clearly identified as the subject of the sentence"; EARS gives every
   requirement one shape, `the <system name> shall <system response>`. "Test audit:
   floor only" binds nobody; "Coordinator auditor cross-call: none (floor only)"
   binds the coordinator and leaves the worker's own obligation untouched.
3. **Add the one clause that states the other contract is unchanged**, next to the
   table: "the worker's own step-6.5 auditor call is unchanged at every tier — this
   row states only the coordinator's Phase-4 obligation". The clause is what stops
   a reader from reconciling the two documents by taking the weaker one.
4. **Choose the row's form by what the two contracts share:**

| The row's obligation, relative to the other contract | Write the row as |
|------------------------------------------------------|------------------|
| Same actor, same obligation, this table varies only its intensity | One row whose cells vary the intensity, plus a pointer to the contract that makes the obligation mandatory — the table tunes, the contract binds |
| A different actor performing a same-named step (coordinator cross-call vs worker self-call) | A row labelled with this actor, plus the unchanged-clause of step 3 |
| This table intends to relax the other contract | An edit to the other contract in the same commit, with the relaxation named in the PR — a relaxing table row alone leaves the pinned contract binding |
| The other contract's obligation is conditional and this table restates the condition | A citation of the contract in place of the restatement ([qa-deliverables-exclusivity-and-absence-claims] on writing the rule rather than the enumeration) |

5. **When reviewing, read the row against the sibling contract, not against the
   plan.** A plan-conformance pass succeeds when the plan itself carried the
   ambiguity; the defect is visible only when the row and the other document are
   read side by side ([qa-document-verification-spec-document-gates],
   cross-reference axis).

## Edge cases

| Case | Then |
|------|------|
| The other contract is checksum-pinned or otherwise unmodifiable in this change | The row must be additive: name your actor and add the unchanged-clause; a relaxation waits for the change that can move the pin |
| Both documents bind the same actor and genuinely differ | Treat it as a contradiction to resolve by test or ruling, not by wording ([qa-document-verification-spec-document-gates]); record which document changed |
| A cell reads "none" or "optional" for some tier | Spell out whose call is none — "coordinator: none" — because a bare "none" is read as a waiver of every actor's obligation |
| The table is loaded by an agent as a binding instruction | Write the cells as predicate-keyed rules per actor ([backend-common-llm-binding-instructions-for-agents]); an actor-less row is the exemption clause that page warns leaves the boundary to improvisation |
| A grep for the obligation noun returns nothing in sibling contracts | Record that null result in the PR ("no other contract names `audit`"); a stated null and an omitted check read the same to the next reviewer |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Label the row with the obligation alone ("test audit") | Label it with actor + obligation ("coordinator auditor cross-call") | The label is the subject of every cell; without an actor each cell reads as the whole obligation's level |
| Rely on the plan-conformance review to catch the overlap | Grep the sibling contracts yourself before committing | The plan carried the ambiguity, so conformance to it passes the defect through |
| Reconcile the two documents by taking the one that reads as more lenient | Name the actor and add the unchanged-clause, or edit the pinned contract explicitly | Two contracts on one obligation are not a menu; the lenient reading silently waives the mandatory one |

## Sources

- https://www.incose.org/docs/default-source/working-groups/requirements-wg/guidetowritingrequirements/incose_rwg_gtwr_v4_summary_sheet.pdf — INCOSE Guide to Writing Requirements v4 summary sheet, rule R2 (Active Voice): "Use the active voice in the need or requirement statement with the responsible entity clearly identified as the subject of the sentence" (the PDF refused a non-browser fetch on 2026-09-17; wording confirmed via the Jama page below and Altium's rule list, which restates R2 as "Use the active voice in the main sentence structure of the need or requirement statement with the responsible entity clearly identified as the subject of the sentence")
- https://www.jamasoftware.com/legacy/requirements-management-guide/writing-requirements/incose-requirements-writing-guide/ — "Active voice under R2 puts the responsible entity in the subject position. 'The system shall use a 20 V electrical input' names an owner, while 'A 20 V electrical input shall be used' names nobody."
- https://alistairmavin.com/ears/ — EARS basic structure: "While <optional pre-condition>, when <optional trigger>, the <system name> shall <system response>"; one system name is a required element of every requirement
- http://principles-wiki.net/principles:don_t_repeat_yourself — "Every piece of knowledge must have a single, unambiguous, authoritative representation within a system"; with several representations "there is the danger that at some point in time the different representations diverge which is a fault"
- Field evidence 2026-09-16 (dev-loop, task t5-risk-tier, review round 1 finding F1): a tier→profile table row labelled "test audit" carried the cells "test-floor.sh only" (R0) and "floor, auditor when tests look weak" (R1), while the checksum-pinned worker protocol (session-prompt.md §2) and loop-implement step 6.5 make the worker's own auditor call mandatory at every tier. Plan conformance (lens 1) passed — the plan carried the row as written; the finding came from reading the row against the worker protocol. Fix: row relabelled "coordinator auditor cross-call" with cells none (floor only) / when tests look weak / mandatory / mandatory, plus the clause "the worker's own step 6.5 auditor call is unchanged at every tier"; the 61/61 dispatch-contract and review-pass bats stayed green
