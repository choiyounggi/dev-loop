---
id: infrastructure-observability-suppression-state-and-delivery-failure
domain: infrastructure
category: observability
applies_to: [general]
confidence: verified
sources:
  - https://pkg.go.dev/github.com/prometheus/alertmanager/notify
  - https://runbooks.prometheus-operator.dev/runbooks/general/watchdog/
  - https://prometheus.io/docs/alerting/latest/configuration/
last_verified: 2026-08-10
related: [infrastructure-observability-alerting, infrastructure-observability-logs-metrics-signals, backend-common-jobs-idempotent-handlers, testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, infrastructure-observability-suppression-key-for-a-recurring-failure]
---

# Where the Cooldown Mark Is Written Relative to the Send

## When this applies

You are adding notification suppression to a script or service — a cooldown
file, a "last alerted at" timestamp, a sent-marker key — so a repeating
condition does not notify on every tick. Also when the code has such a marker
and you are choosing where its write goes, or writing the tests for it against
a stub whose send always fails. Also when a condition stayed live while the
channel went quiet for the whole cooldown window.

Choosing *whether* a condition notifies at all →
[infrastructure-observability-alerting].

## Do this

1. **Write the suppression mark only on a send that reported success**, so a
   failed send leaves the condition unmarked and the next tick sends again. Alertmanager
   states the same precondition on the stage that records delivery:
   `SetNotifiesStage` "sets the notification information about passed alerts. The
   passed alerts should have already been sent to the receivers", while
   `RetryStage` "notifies via passed integration with exponential backoff until it
   succeeds". The package docs describe the stages without stating an order; the
   ordering follows from that precondition, and from `DedupStage` filtering
   "based on a notification log" that only a delivered notification writes.

2. **Give the send its own exit status, and put the marker write inside the
   success branch.** In a shell notifier that is `if notify "$@"; then <write
   mark>; fi`; in a service, a send that returns an error instead of logging and
   continuing. A notifier that always succeeds gives the marker nothing to
   condition on.

| Shell shape | Behaviour |
|---|---|
| `if notify "$@"; then <write mark>; fi` | The marker is unreachable on failure, at top level and inside a function alike, and the caller's status is unchanged |
| `notify "$@" \|\| return 1` inside a function whose caller checks the status | Equivalent, and it also stops the rest of that function — under `set -e` the nonzero status propagates and aborts the caller, so use it only where aborting is the intent |
| `notify "$@" \|\| return 1` at the top level of a script | `return` outside a function is an error; execution falls through to the marker line and the script still exits 0 — the defect this page is about, hidden behind a success code |

3. **Make the send path injectable** — a command name, a function reference, or
   an interface the test substitutes — so the suppression logic can be exercised
   against both a succeeding and a failing sender.

4. **Assert both worlds, as the three tests below:**

| Test world | Assert |
|---|---|
| Send succeeds | The mark exists, and a second tick within the window sends nothing |
| Send fails | No mark exists, and the next tick attempts the send again |
| Send fails, then succeeds | Exactly one delivery total, and the mark dates from the successful attempt |

5. **Keep the suppression window shorter than the time you are willing to be
   blind**, and pair it with a heartbeat that proves the delivery path still
   works — the Watchdog pattern is "an alert meant to ensure that the entire
   alerting pipeline is functional", always firing, so that "if not firing then
   it should alert external systems that this alerting system is no longer
   working" ([infrastructure-observability-alerting]).

6. **When the stub in an existing suite always fails, treat any test that
   asserts the mark exists as a specification of the defect** and rewrite it
   before changing the code — otherwise the correct fix arrives as a red suite
   and reads as a regression ([testing-quality-tests-that-cannot-fail]).

## Edge cases

| Case | Then |
|------|------|
| The transport is fire-and-forget (UDP, a webhook whose 202 means "queued") | Mark on the strongest acknowledgement the transport gives, and state in the code comment what that acknowledgement does and does not prove |
| A retry inside the send already covers transient failure | Keep the mark after the retry loop's overall result, not after the first attempt |
| The failure is a permanent 4xx (bad webhook URL, revoked token) | Retrying every tick emits an unbounded error stream — mark it, and route the send-failure itself as its own condition so the broken channel is visible |
| The condition and the notifier fail together (one network partition, one dead cluster) | Delivery cannot be repaired from inside the failing system; the heartbeat in step 5 is what makes the silence visible from outside |
| The mark is a file whose write can fail | A failed mark write repeats the notification; a failed send that marks suppresses it — prefer the repeat, and log the mark-write failure |
| Several processes share one mark | The mark is shared state; give it an atomic write (rename-into-place) so a partial write is not read as a valid recent send |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write the cooldown mark before calling the notifier | Call the notifier, check its status, write the mark on success | A delivery failure then buys silence for the whole window, at the moment the condition is live |
| Let the notifier swallow its own error and always return 0 | Return the send's status and put the mark inside `if notify "$@"; then … fi` | With no status there is no way to distinguish "sent" from "attempted" |
| Accept a suite that only ever runs the always-failing stub | Add the succeeding-sender world as a second harness fixture | A single-world harness reports the same verdict for correct and defective ordering ([testing-quality-harness-reverse-controls]) |
| Widen the cooldown window because the channel is noisy | Group or route at the alert level and keep the window short | A long window and a lost send compound: the first failure hides the condition for the full window |

## Sources

- https://pkg.go.dev/github.com/prometheus/alertmanager/notify — stage contracts: `RetryStage` "notifies via passed integration with exponential backoff until it succeeds. It aborts if the context is canceled or timed out."; `SetNotifiesStage` "sets the notification information about passed alerts. The passed alerts should have already been sent to the receivers."; `DedupStage` "filters alerts. Filtering happens based on a notification log." — dedup reads the log that is written only after delivery
- https://runbooks.prometheus-operator.dev/runbooks/general/watchdog/ — the Watchdog is "an alert meant to ensure that the entire alerting pipeline is functional", "always firing", and "if not firing then it should alert external systems that this alerting system is no longer working" — the external heartbeat of step 5
- https://prometheus.io/docs/alerting/latest/configuration/ — `repeat_interval` is "How long to wait before repeating the last notification"; the suppression clock is described in terms of a notification, and the page states nothing about delivery attempts (so the attempt-vs-delivery distinction rests on the notify-package citation above, not on this one)
- Field measurement 2026-08-07 (rtb-mac-server-k8s, `bin/gitops-deploy.sh`): the `alert-main-fetch` marker was written after a send whose webhook lookup had failed, so the following invocation suppressed the alert as "in cooldown". Moving the marker inside `if slack "$@"; then printf '%s' "$now" > "$f"; fi`, in a copy outside the repo, turned three existing tests red — the suite's always-failing stub had fixed the pre-send ordering as the expected contract
