---
id: infrastructure-containers-exec-added-processes-and-the-memory-budget
domain: infrastructure
category: containers
applies_to: [kubernetes, docker, cgroup-v2]
confidence: verified
sources:
  - https://docs.kernel.org/admin-guide/cgroup-v2.html
  - https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
  - https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#exec
  - https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/
last_verified: 2026-08-27
related:
  [
    infrastructure-containers-host-cgroup-visibility,
    infrastructure-containers-resource-limits-and-probes,
    backend-common-concurrency-shared-state-and-pools,
    backend-common-concurrency-distributed-locks,
    infrastructure-observability-missing-container-metrics,
  ]
---

# Running an Extra Process Inside a Container That Already Hosts a Service

## When this applies

You are about to `kubectl exec` (or `docker exec`) a process into a pod that is
already running a service — a CLI invoked as a remote worker, a debug shell, a
side job, an ad-hoc script — and you are judging whether it is safe. Also when
you concluded it was safe because the application's own queue, semaphore, or
worker pool is not saturated.

## Do this

1. **Read the container's own cgroup limit and usage before adding the
   process.** The self-view needs no host cgroup namespace
   ([infrastructure-containers-host-cgroup-visibility]) — inside the container,
   read from `/sys/fs/cgroup/`:

| File | What it tells you | Use it to |
|------|-------------------|-----------|
| `memory.max` | The hard limit; at it "the OOM killer is invoked in the cgroup" | Establish the budget the new process shares |
| `memory.current` | "The total amount of memory currently being used by the cgroup and its descendants" | Compute headroom now |
| `memory.peak` | "The max memory usage recorded for the cgroup … since either the creation of the cgroup or the most recent reset" | See whether the limit has already been reached under normal load |
| `memory.events` → `max` | "The number of times the cgroup's memory usage was about to go over the max boundary" | Detect that reclaim is already fighting the limit |
| `memory.events` → `oom_kill` | "The number of processes belonging to this cgroup killed by any kind of OOM killer" | Confirm kills have already happened |

2. **Treat the application's concurrency control and the cgroup budget as two
   separate limits.** An in-process semaphore (`maxConcurrentAgents: 20`, a
   worker pool, a job queue) counts only the work the application itself
   started. A process attached with `exec` joins the **same cgroup** and spends
   the same memory, while being invisible to that counter — so "the queue has
   free slots" is not a statement about memory at all.

3. **Decide from headroom, not from queue depth**, using one rule: require
   `memory.max − memory.peak` to exceed the new process's expected peak. When
   `memory.peak` already equals `memory.max`, or the `max` event counter is
   non-zero, the container has no proven headroom — run the process elsewhere
   (a separate pod or Job with its own limit), or raise the limit first.

4. **Size the consequence before treating it as a small risk.** The container's
   limit applies to the cgroup, so an OOM kill selects a process in that cgroup
   — which can be the service rather than the process you added. Establish what
   a restart of that service costs: in-flight work lost, and any lock or lease
   the process held ([backend-common-concurrency-distributed-locks]).

5. **When the exec'd work is recurring rather than one-off, give it its own
   cgroup.** A Kubernetes Job or a sidecar with its own `resources.limits`
   makes the budget explicit and keeps a runaway invocation from selecting the
   service as the OOM victim.

## Edge cases

| Case | Then |
|------|------|
| The pod runs cgroup v1 | Read `memory.limit_in_bytes`, `memory.usage_in_bytes`, and `memory.max_usage_in_bytes`; `memory.peak` and `memory.events` are v2 names |
| `memory.peak` was reset by another reader | It reflects "since the most recent reset", so a low value can mean a recent reset rather than low usage — corroborate with `memory.events` and the container's restart count |
| Only `requests` is set, with no `limits` | There is no `memory.max` to read (it reads `max`); the pod can consume node memory until the **node** reclaims, making the blast radius other pods ([infrastructure-containers-resource-limits-and-probes]) |
| The container's restart count is already non-zero | Prior OOM kills are the most likely cause — check the last state's reason before adding load, since the steady state is already over budget |
| The process you add is short-lived but memory-spiky (a compiler, a bundler, a model client) | Peak is what the limit tests, not average; size step 3 against its peak or run it in its own pod |
| You cannot read the cgroup files (restricted mount) | Take the limit from the pod spec (`resources.limits.memory`) and current usage from metrics; do not treat unavailability of the numbers as headroom |
| The service is the only consumer and the exec'd process replaces its work | Headroom still applies — the two overlap until the service's own task drains |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Judge an `exec` safe because the service's queue or semaphore has free slots | Read `memory.current`/`memory.peak` against `memory.max` and decide from headroom | The semaphore counts work the application started; an exec'd process is in the same cgroup and outside that count |
| Add the process and watch for problems | Check `memory.events` first — a non-zero `max` counter means reclaim is already at the boundary | The failure mode is an OOM kill of a process in the cgroup, which can be the service, not a slow response you can observe and cancel |
| Read a non-zero `memory.events: max` as "the container was OOM-killed" | Read `oom_kill` for kills and `max` for approaches to the limit | They are separate counters — `max` counts times usage was about to exceed the boundary, which is a headroom signal rather than a kill record |
| Run a recurring side job by `exec` because it is convenient | Give it a Job or sidecar with its own `resources.limits` | A separate cgroup bounds the blast radius to that work instead of to the service sharing the limit |

## Sources

- https://docs.kernel.org/admin-guide/cgroup-v2.html — `memory.current` is "the total amount of memory currently being used by the cgroup and its descendants"; `memory.peak` is "the max memory usage recorded for the cgroup and its descendants since either the creation of the cgroup or the most recent reset for that FD"; at `memory.max`, "if a cgroup's memory usage reaches this limit and can't be reduced, the OOM killer is invoked in the cgroup"; in `memory.events`, `max` is "the number of times the cgroup's memory usage was about to go over the max boundary" while `oom_kill` is "the number of processes belonging to this cgroup killed by any kind of OOM killer" — the two counters distinguished in the last `Instead of` row
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ — container `resources.limits.memory` is enforced by the container runtime through the cgroup, which is why every process in the container shares one budget
- https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/ — a container exceeding its memory limit is a candidate for termination; the limit is the cgroup's, not any one process's
- https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#exec — `kubectl exec` executes a command in an existing container, so the new process is created inside that container's cgroup rather than in one of its own
- Field measurement 2026-08-26 (an in-cluster review-bot pod, `limits.memory: 3Gi`): `memory.current` 2.54 GiB (85% of the limit), `memory.peak` 3.0 GiB — exactly at the limit — and `memory.events` `max 5`. The application's own `maxConcurrentAgents: 20` semaphore did not count CLI processes started via `exec`, so queue depth reported free capacity while the cgroup had no proven headroom
