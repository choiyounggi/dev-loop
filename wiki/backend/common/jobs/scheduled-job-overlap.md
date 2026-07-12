---
id: backend-common-jobs-scheduled-job-overlap
domain: backend
category: jobs
applies_to: [general, kubernetes, cron]
confidence: verified
sources:
  - https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
  - https://man7.org/linux/man-pages/man1/flock.1.html
last_verified: 2026-07-10
related: [backend-common-jobs-idempotent-handlers, backend-common-concurrency-distributed-locks]
---

# Preventing Scheduled-Job Overlap

## When this applies

A scheduled job (cron, Kubernetes CronJob, in-app scheduler) might still be running
when its next scheduled start arrives, or you are debugging doubled effects from a
batch (settlement charged twice, duplicate rows at schedule boundaries).

## Do this

1. **Assume the scheduler starts overlapping runs.** cron fires on time regardless
   of the previous run; Kubernetes CronJob defaults to `concurrencyPolicy: Allow`.
   A job that is not overlap-safe WILL eventually run concurrently with itself.
2. Add overlap prevention matched to the topology:

| Case | Do |
|------|----|
| Single host, cron | Wrap the command: `flock -n /var/lock/<job>.lock <command>` — `-n` makes the second run exit immediately instead of queueing |
| Kubernetes CronJob | `concurrencyPolicy: Forbid` (skip while previous Job runs); `Replace` only when killing the stale run is safe |
| Same job scheduled on multiple hosts/schedulers | One shared lock ([backend-common-concurrency-distributed-locks]) or elect a single scheduler — per-host flock cannot see the other host |
| In-app scheduler on a multi-replica service | The scheduler library's distributed lock (e.g. ShedLock-style) or move the schedule out of the replicas |

3. **Pair skip-on-overlap with a hang guard.** `Forbid`/`flock -n` converts overlap
   into skips — a hung previous run then blocks the schedule forever. Bound every
   run: Kubernetes `activeDeadlineSeconds` on the Job; plain cron `timeout <max> <command>`
   inside the flock. Hung run dies → next schedule proceeds.
4. **Make the job idempotent anyway** ([backend-common-jobs-idempotent-handlers]): process
   by stable ids/checkpoints so a duplicated or resumed run re-produces the same
   state instead of doubling effects. Overlap prevention lowers the probability;
   idempotency removes the damage — retries, manual re-runs, and clock skew get past
   prevention eventually.

## Edge cases

| Case | Then |
|------|------|
| `Forbid` + a run was skipped | Kubernetes counts it as a miss; set `startingDeadlineSeconds` so a late start within the window still runs, and alert on repeated skips (the job is outgrowing its interval) |
| Job duration approaches the schedule interval | Widen the interval or split the job — permanent near-overlap means every hiccup skips a cycle |
| Batch must catch up after downtime | Design catch-up explicitly (process a time range from a checkpoint), not by letting missed schedules stack into concurrent runs |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust the schedule spacing ("it only takes 5 minutes, runs hourly") | flock/Forbid + timeout from day one | The one slow day (locked table, slow API) is exactly when it overlaps |
| Fix doubled batch effects by only adding a lock | Also make the handler idempotent | Locks skip runs; they don't make a re-run safe |

## Sources

- https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/ — concurrencyPolicy (Allow default/Forbid/Replace), startingDeadlineSeconds
- https://man7.org/linux/man-pages/man1/flock.1.html — flock -n for non-blocking overlap guard
