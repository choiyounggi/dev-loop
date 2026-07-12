---
id: qa-bug-reports-reproducible-reports
domain: qa
category: bug-reports
applies_to: [general]
confidence: verified
sources:
  - https://bugzilla.mozilla.org/page.cgi?id=bug-writing.html
last_verified: 2026-07-10
related: [qa-exploratory-exploratory-sessions, qa-process-severity-and-priority]
---

# Writing a Bug Report a Stranger Can Reproduce

## When this applies

Writing a bug report, or triaging incoming reports that cannot be acted on
as written.

## Do this

The test of a report: a stranger with no context can reproduce the bug
without asking you anything. Include every section:

| Section | Content |
|---------|---------|
| Steps to reproduce | Numbered, exact steps starting from a known state: the URL/screen you start on, the account/role used, and any data preconditions (e.g. "cart contains 1 item"). Each step is an action, not an outcome |
| Expected | One line, factual: what the requirement says happens. State the requirement, not your preference |
| Actual | One line, factual: what happened instead |
| Environment | Build/version/commit; browser/OS/device; environment (prod/stg); timestamp **with timezone**; request/correlation id when available (correlating it in logs → wiki/debugging/) |
| Evidence | Captured at the failure point: screenshot or recording, console/network errors, server log excerpt |

Rules that keep reports actionable:

1. **One bug per report.** Two symptoms → two reports, cross-linked. A report
   with two bugs gets closed when one is fixed.
2. **Minimize the reproduction before filing**: remove steps one at a time
   until every remaining step is necessary to trigger the bug. Ten necessary
   steps beat three steps plus "it sometimes needs other stuff".
3. **Intermittent bug**: state the observed frequency as counts ("3 of 10
   tries") and list the variations you attempted (other account, other
   browser, after cache clear). "Sometimes" without counts gives triage
   nothing to weigh.

## Edge cases

| Case | Then |
|------|------|
| You cannot reproduce it yourself | File it labeled not-reproduced, with everything you observed once (environment, timestamp, correlation id, evidence) — the timestamp+id may be enough for log-side diagnosis |
| The bug needs specific data you cannot share (PII, prod records) | Reference the record by internal id and environment instead of pasting contents; state which property of the data triggers it |
| Failure only occurs for one account/role | The account/role is a data precondition — put it in step 0, and test one other role to record whether it reproduces there |
| You found it during an exploratory session | File it through this structure, then link the report from the session notes ([qa-exploratory-exploratory-sessions]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| File "it doesn't work" plus a screenshot | Fill every section of the table above | Each missing field costs one question-and-answer round trip; five missing fields is a week of latency |
| Write expected behavior as your preference ("it would be nicer if…") | State what the requirement/spec defines as correct | Preference disputes stall in triage; requirement violations get scheduled |
| Bundle two symptoms found together into one report | Two reports, cross-linked | Fix and verification are tracked per report; a half-fixed report can be neither closed nor kept open honestly |
| File 12 unminimized steps because "that's how I hit it" | Strip steps until each remaining one is necessary | Every unnecessary step multiplies the assignee's search space for the cause |

## Sources

- https://bugzilla.mozilla.org/page.cgi?id=bug-writing.html — precise steps from a known state, expected vs actual results, one bug per report
