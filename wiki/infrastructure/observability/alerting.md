---
id: infrastructure-observability-alerting
domain: infrastructure
category: observability
applies_to: [general]
confidence: verified
sources:
  - https://sre.google/sre-book/monitoring-distributed-systems/
  - https://sre.google/workbook/alerting-on-slos/
last_verified: 2026-07-10
related: [infrastructure-observability-logs-metrics-signals, infrastructure-deploy-rollout-and-rollback]
---

# Deciding What Pages a Human

## When this applies

Creating or reviewing alerts; the team ignores a noisy pager; deciding whether
a condition should page, open a ticket, or only appear on a dashboard.

## Do this

1. Alert on symptoms users experience — error rate, latency, SLO burn — not on
   causes (CPU%, one instance down behind a load balancer, GC time). Causes go
   on dashboards, consulted for diagnosis after a symptom fires.
2. Every alert must be actionable: when it fires, a human must need to act now.
   Route by required response:

| Condition | Route |
|-----------|-------|
| Users hurting now, or error budget burning fast | Page |
| Needs a fix but not at 3am (slow burn, disk trending toward full) | Ticket |
| Useful only for diagnosing a fired symptom | Dashboard, no notification |

3. Where an SLO exists, alert on burn rate instead of static thresholds:
   fast burn (high rate over a short window) → page; slow burn (low rate over a
   long window) → ticket.
4. Every page links a runbook: what to check first, how to confirm user impact,
   and the rollback command ([infrastructure-deploy-rollout-and-rollback]).
5. Apply the noise policy on every fired alert:

| Observation | Do |
|-------------|----|
| Alert fired but no action was needed | Tune the threshold, demote to ticket, or delete — within the week; an ignored pager trains the team to miss real incidents |
| Alert flaps (fires and resolves repeatedly) | Add a duration condition (breach sustained N minutes) |
| One incident pages five alerts | Keep the symptom alert as the pager; group or silence the dependent cause alerts |

## Edge cases

| Case | Then |
|------|------|
| No SLO defined yet | Interim: static symptom thresholds with duration conditions, set from the current baseline; define the SLO, then convert to burn-rate alerts |
| Single instance down, load balancer keeps user error rate at zero | Ticket or auto-heal, never a page — users are unaffected |
| Batch/cron job with no live traffic to measure | Alert on absence of success ("job has not succeeded within its window"), not only on failure events — a job that never ran emits no failure |
| Low-traffic service where one error spikes the error rate | Add a minimum-request-count condition alongside duration |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Alert on every ERROR log line | Alert on the error-rate symptom with a duration condition | One bad request is not an incident; log-line alerts flap |
| Page on CPU > 80% | Page on latency/error SLO burn; keep CPU on the diagnosis dashboard | High CPU with healthy latency is not user impact |
| Keep an "acknowledge and ignore" alert because it has always existed | Delete it or demote it to a ticket within the week | Every tolerated false page erodes trust in the next real one |
| Page a human for a failure with a known automatic remediation | Automate the remediation; page only when it fails | Pages are for judgment, not for running a script |

## Sources

- https://sre.google/sre-book/monitoring-distributed-systems/ — symptoms vs causes; maximum signal, minimum noise; pages must be actionable
- https://sre.google/workbook/alerting-on-slos/ — burn-rate alerting; fast-burn page vs slow-burn ticket, multiwindow conditions
