---
id: infrastructure-observability-suppression-key-for-a-recurring-failure
domain: infrastructure
category: observability
applies_to: [general]
confidence: field-tested
sources:
  - https://prometheus.io/docs/alerting/latest/configuration/
  - https://sre.google/sre-book/monitoring-distributed-systems/
  - https://developer.pagerduty.com/docs/events-api-v2/trigger-events/index.html
last_verified: 2026-09-03
related: [infrastructure-observability-alerting, infrastructure-observability-suppression-state-and-delivery-failure, backend-common-reliability-timeouts-and-retries, backend-common-errors-exception-handling]
---

# The Suppression Key When a Retried External Call Keeps Failing the Same Way

## When this applies

A periodic job or client retries against a broker or external API that keeps
rejecting the same way, and every retry re-sends an identical alert, so one
condition repeats on every tick; you are choosing what the notifier's
dedup/suppression key is, and whether to classify error codes as transient or
permanent first. Where the cooldown mark is written relative to the send →
[infrastructure-observability-suppression-state-and-delivery-failure].

## Do this

1. **Key suppression on the rendered alert text that would be sent.** The set
   of failures a retry can resolve at an external dependency is not enumerable
   in advance, so a whitelist of "permanent" codes misses each new failure
   shape on its first day; a message repeated verbatim needs only its first
   delivery whatever its cause. Dedup fields in paging systems accept any
   caller-chosen stable string (PagerDuty `dedup_key`: "a string which
   identifies the alert triggered for the given event").
2. **Suppress the notification only; keep the retry running.** The retry is
   what resumes normal operation on the first cycle after the external side
   recovers; gating it on a classification delays recovery by the time it takes
   to classify.
3. **Re-send once when the calendar date changes**, so a dependency still
   broken tomorrow produces exactly one fresh notification per day.
4. **Put the differentiating identifier (symbol, account, target) in the text**
   so two failing targets render two different messages and therefore two keys.

| You are building | Key on |
|------------------|--------|
| A home-grown cooldown file in a job | The rendered message (or its hash) plus the calendar date |
| Alertmanager | The label set (`group_by`) with `repeat_interval` as the re-send window — its key is labels, so put the target identifier in a label |
| PagerDuty / Opsgenie style API | `dedup_key` / alias set to the rendered message or a stable digest of it |

## Edge cases

| Case | Then |
|------|------|
| The message embeds a timestamp, a retry counter, or a duration | Strip that field before deriving the key, or every tick renders a new key and nothing is suppressed |
| Several distinct alert conditions arrive from one incident | That is grouping, not repetition — [infrastructure-observability-alerting] ("one incident pages five alerts") |
| The suppression state file is shared by parallel jobs | Write it atomically (rename into place) and gate the write on a successful send ([infrastructure-observability-suppression-state-and-delivery-failure]) |
| The daily re-send lands during a maintenance window | Silence at the notifier (Alertmanager silence, PagerDuty maintenance window); keep the job's own key logic unchanged |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Maintain a whitelist of "non-transient" error codes to decide what to suppress | Key on the rendered text and suppress every repeat after the first send, re-sending daily | A new failure mode at an external dependency is missed by any list written before it appeared; the text key covers it with no maintenance |
| Stop retrying because the error looks permanent | Retry every cycle; suppress only the notification | The retry costs nothing while the notification is the noisy part, and it is what resumes operation the moment the dependency recovers |

## Sources

- https://prometheus.io/docs/alerting/latest/configuration/ — `group_by`: "The labels by which incoming alerts are grouped together"; `repeat_interval`: "How long to wait before repeating the last notification" — the reference model of a stable key plus a re-send window (Alertmanager's key is the label set, not text)
- https://sre.google/sre-book/monitoring-distributed-systems/ — "We seldom use rules such as, 'If I know the database is slow, alert for a slow database; otherwise, alert for the website being generally slow'"; "When pages occur too frequently, employees second-guess, skim, or even ignore incoming alerts"
- https://developer.pagerduty.com/docs/events-api-v2/trigger-events/index.html — `dedup_key`: "a string which identifies the alert triggered for the given event"
- Field evidence 2026-08-31 (auto-trading-bot, KIS paper-trading account): losing order permission produced 151 identical rejection alerts over 3 days from the periodic retry; after keying suppression on the message text with a daily re-send, production logged 1 send at 10:42 and 1 suppression at 10:47 (`.order_reject_state.json` count 2) while the retry kept running
