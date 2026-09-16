---
id: infrastructure-agent-orchestration-escape-hatch-uses-as-a-knowledge-gap-signal
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: field-tested
sources:
  - https://docs.github.com/en/code-security/code-scanning/managing-code-scanning-alerts/resolving-code-scanning-alerts
  - https://github.blog/changelog/2025-07-01-delegated-alert-dismissal-for-code-scanning-is-now-generally-available/
last_verified: 2026-09-16
related: [infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-autonomous-decision-rulings, qa-document-verification-spec-document-gates, backend-common-llm-binding-instructions-for-agents]
---

# Recording Every Use of a Grounding Gate's Escape Hatch

## When this applies

You are building or reviewing a gate that requires each decision to cite a
source — a wiki page, an ADR, a spec section — and that offers a marker letting
an uncitable decision through (`[no-wiki]`, `# noqa`, a dismissal reason). Also
when the knowledge base behind such a gate stops growing while plans keep
meeting situations it does not cover.

## Do this

1. **Emit one record at the point the gate grants the pass.** In the gate
   script, the line before the `continue`/`return 0` that skips validation
   appends a row to a gap queue — not the pass/fail line the gate already
   prints. The hatch is the only place that knows a decision had no source, and
   the gate is the only actor present at every use of it.

2. **Put the decision's own text in the record**, with the run or plan id and a
   timestamp, so the row is routable into an ingest pipeline without reopening
   the plan:

   ```sh
   if [ "$basis" = "[no-wiki]" ]; then
     printf '%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$PLAN_ID" "$decision" >> "$GAP_QUEUE"
     continue
   fi
   ```

3. **Make the hatch's reason a required, enumerated field**, and keep the
   reasons that mean different things apart: *no page exists* is a knowledge gap,
   *a page exists but was not found* is a routing defect, *out of scope for the
   knowledge base* is neither. A single undifferentiated marker merges the three
   into one unreadable pile.

4. **Keep the hatch passing.** Its value is the honest signal it collects;
   turning it into a failure buys a plan that cites the nearest unrelated page
   instead, which the gate cannot detect.

5. **Reconcile the two counts on a schedule.** Count hatch uses over a period
   and compare against rows in the gap queue; the emitter is wired only while
   the numbers match. A gate whose hatch fires and whose queue stays empty is
   the failure this page exists to catch.

## Edge cases

| Case | Then |
|------|------|
| The gate's stdout is parsed by its caller | Append the record to a file path from the environment, never stdout — a new line in a parsed stream is a protocol change |
| The gate runs in a subshell or a pipeline | Write with `>>` to an absolute path; a variable accumulated in a subshell is discarded at its exit |
| The gate is a prose instruction in a skill document rather than a script | Move the recording into whichever script runs the check; an instruction to "note this as an ingest candidate" is executed only when the author remembers |
| Several runs write the queue concurrently | Append single lines under the platform's atomic-append size and let the reader de-duplicate; a read-modify-write of the whole queue loses rows |
| The same gap recurs every run | Keep the duplicates and de-duplicate at ingest time — repetition count is the priority signal for which page to write first |
| The hatch is used because the knowledge exists but the author did not find it | Record it under the routing-defect reason; the fix is an index trigger line, not a new page |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Document in the skill's prose that an escape-hatch use should be filed as an ingest candidate | Emit the row from the gate script at the moment it grants the pass | Prose relies on the author who was just let off to do extra work; the gate is already running and already has the decision text |
| Have the gate print a warning line for an ungrounded decision | Append it to a durable queue as well | A warning scrolls past with the rest of the run output and is gone by the time anyone writes pages |
| Count the gate's pass/fail results as the health metric for the knowledge base | Count hatch uses per run, and the gap queue's depth and age | Pass/fail measures whether plans satisfied the gate; only the hatch count measures what the knowledge base does not yet cover |

## Sources

- https://docs.github.com/en/code-security/code-scanning/managing-code-scanning-alerts/resolving-code-scanning-alerts — the canonical shape of a recorded escape hatch: dismissing an alert requires choosing a reason, "the dismissal comment is added to the alert timeline", the comment is readable as `dismissed_comment` on the alerts API, and dismissed alerts stay in the Closed list for later review
- https://github.blog/changelog/2025-07-01-delegated-alert-dismissal-for-code-scanning-is-now-generally-available/ — each dismissal request carries a mandatory rationale, and the dismissal/approval process appears on the alert timeline, in the audit log, and through the REST API and webhooks
- Field evidence 2026-09-16 (dev-loop 1.22.0): `skills/wiki-plan/scripts/plan-gate.sh:166` passes an ungrounded decision with `[ "$basis" = "[no-wiki]" ] && continue` and records nothing, while `skills/wiki-plan/SKILL.md:135` asks in prose for the decision to be "noted as an ingest candidate". Measured against a wiki of 276 non-index pages, `log.md` carries exactly one `gap` entry, dated 2026-07-11 — the prose instruction produced one record in two months of planning
