---
id: infrastructure-containers-resource-limits-and-probes
domain: infrastructure
category: containers
applies_to: [kubernetes, general]
confidence: verified
sources:
  - https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
  - https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
  - https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/
last_verified: 2026-07-10
related: [infrastructure-deploy-rollout-and-rollback, backend-java-runtime-threads-and-memory]
---

# Resource Limits and Health Probes in Deployment Manifests

## When this applies

Writing or reviewing Kubernetes-style deployment manifests; pods are
OOMKilled, evicted, or CPU-throttled; a dependency outage triggered a restart
storm; traffic reaches pods that are not ready to serve.

## Do this

1. Give each probe exactly its one question:

| Probe | Answers | Checks | On failure |
|-------|---------|--------|------------|
| liveness | "is THIS process irrecoverably stuck?" | ONLY the process itself — a lightweight in-process endpoint, zero dependency calls | Container is killed and restarted |
| readiness | "can this pod serve traffic NOW?" | The process, plus critical dependencies when the pod cannot serve without them | Pod is removed from endpoints; container keeps running |
| startup | "has the app finished booting?" | Same endpoint as liveness, with a high failureThreshold covering worst-case boot | Liveness and readiness are held off until it passes |

2. Keep the DB and downstream services out of the liveness probe. During a
   dependency outage the process is fine and restarting it fixes nothing — a
   dependency-checking liveness probe converts the outage into a cluster-wide
   restart storm. Put the dependency in readiness instead: pods leave the
   endpoints, traffic stops, and they rejoin when the dependency recovers.
   Readiness gating is also what makes gradual rollouts safe
   ([infrastructure-deploy-rollout-and-rollback]).
3. Give slow-booting apps a startup probe, and size liveness timing for
   steady state only. `failureThreshold × periodSeconds` is the tolerance
   window before action — set it above the app's p99 pause (GC, checkpoint,
   burst load), or the probe restarts healthy pods.
4. Set resources from measurement, not from another service's manifest:

| Setting | Rule |
|---------|------|
| memory request | Set equal to the memory limit — memory is not reclaimable, and request=limit gives a predictable footprint instead of overcommit-eviction surprises |
| memory limit | Measured peak usage + headroom; exceeding it = OOMKilled. The runtime's total footprint (JVM heap + metaspace + threads + buffers) must fit inside the limit: [backend-java-runtime-threads-and-memory] |
| cpu request | Measured p99 usage + headroom; requests drive scheduling — unset requests mean the scheduler packs blind (node overcommit, noisy neighbors) |
| cpu limit | Throttles, never kills; heavy throttling appears as request latency while node CPU graphs look idle |

5. Know the QoS class your settings produce — it is the eviction order under
   node pressure:

| Requests/limits set | QoS class | Under node pressure |
|---------------------|-----------|---------------------|
| requests = limits for CPU and memory, every container | Guaranteed | Evicted last |
| Any request or limit set, not all equal | Burstable | Evicted after BestEffort |
| Nothing set | BestEffort | Evicted first |

## Edge cases

| Case | Then |
|------|------|
| Restart storm already underway during a dependency outage | Remove dependency calls from the liveness probe; readiness carries the dependency check from now on |
| Latency is high but node CPU looks idle | Read the container CPU-throttling metrics — throttling is invisible in node-level CPU utilization |
| Runtime OOMKilled while its configured heap is below the limit | Non-heap memory (metaspace, thread stacks, direct buffers) pushed the total over: [backend-java-runtime-threads-and-memory] |
| Pod evicted rather than OOMKilled | Node memory pressure evicting by QoS order — set memory request = limit to move the workload to Guaranteed |
| App has no HTTP server to probe | Use an exec or TCP probe against the process itself; the process-only rule for liveness is unchanged |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Point the liveness probe at a /health that pings the DB | Liveness checks the process only; dependency health belongs in readiness | A dependency outage becomes a restart storm that restarts healthy processes |
| Copy resource limits from a blog post or another service | Measure this service's usage; set requests from p99 + headroom | Limits sized for someone else's workload produce OOMKills or throttling for yours |
| Leave requests unset "for flexibility" | Set requests on every container | Unset requests = BestEffort: first evicted, and the scheduler overcommits the node |
| Stretch liveness timeouts so the app survives boot | Add a startup probe sized for worst-case boot; keep liveness at steady-state timing | Boot-sized liveness leaves real steady-state hangs undetected for the whole boot window |

## Sources

- https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ — probe purposes, failureThreshold/periodSeconds, startup probes protecting slow boots, readiness removes from endpoints without restart
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ — requests drive scheduling, limits enforced at runtime; memory over limit = OOM kill, CPU over limit = throttling
- https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/ — Guaranteed/Burstable/BestEffort assignment and eviction order
