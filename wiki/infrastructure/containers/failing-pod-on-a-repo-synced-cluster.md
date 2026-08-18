---
id: infrastructure-containers-failing-pod-on-a-repo-synced-cluster
domain: infrastructure
category: containers
applies_to: [kubernetes, argocd, flux]
confidence: verified
sources:
  - https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
  - https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/
  - https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/
  - https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/
  - https://man7.org/linux/man-pages/man1/bash.1.html
last_verified: 2026-08-11
related: [infrastructure-containers-resource-limits-and-probes, infrastructure-deploy-rollout-and-rollback, infrastructure-observability-missing-container-metrics]
---

# Diagnosing a Failing Pod on a Cluster Reconciled From a Repo

## When this applies

A pod will not start or keeps restarting — `Pending`, `Waiting`/
`ContainerCreating`, `CrashLoopBackOff` — on a Kubernetes cluster whose manifests
are applied by a GitOps controller (Argo CD, Flux) rather than by hand. Also when
you have the fix and are choosing between editing the live object and committing
the manifest.

Sizing limits and probes while *authoring* the manifest →
[infrastructure-containers-resource-limits-and-probes].

## Do this

1. **Branch on the pod's phase and container state before reading any logs:**

| State | Read first | What it tells you |
|-------|-----------|-------------------|
| `Pending` | `kubectl describe pod` plus namespace events | "There should be messages from the scheduler about why it can not schedule your pod" — insufficient CPU/memory, `hostPort`, taints |
| `Waiting` / `ContainerCreating` | the same `describe` output | "The most common cause of `Waiting` pods is a failure to pull the image"; then secret/volume mounts named in the events |
| `CrashLoopBackOff` | `status.containerStatuses[].lastState.terminated` — `exitCode` and `reason` | `exitCode: 137` with `reason: OOMKilled` is the runtime enforcing the memory limit; any other nonzero code is the process itself exiting |
| Running but not serving | readiness state and the Service's endpoints | A failing readiness probe removes the pod from endpoints while the container stays up |

2. **Read the terminated state before the log for a crashed container.** An OOM
   kill is delivered by the kernel/runtime, so the application's own last lines
   look ordinary — the Kubernetes docs' worked example shows
   `exitCode: 137` / `reason: OOMKilled` under `lastState.terminated` with the
   text "The output shows that the Container was killed because it is out of
   memory (OOM)". For an application-side exit, read the previous container's log:
   `kubectl logs -p` prints "the logs for the previous instance of the container
   in a pod if it exists".

3. **Land the fix as a manifest change in the repo, through a PR.** On Argo CD,
   "By default, changes that are made to the live cluster will not trigger
   automated sync", so a hand-applied fix never reaches Git; with `selfHeal: true`
   the controller syncs "when the live cluster's state deviates from the state
   defined in Git", which realigns the live object to the unfixed manifest. Both
   settings make the live object the wrong home for the change.

4. **Put the evidence in the PR body**: the phase, the `exitCode`/`reason` pair,
   and the events line you acted on. That is what lets a reviewer judge the patch
   without cluster access.

5. **When you have no cluster access, hand over the command list instead of
   retrying.** Give the read-only commands to run (`describe pod`, the
   `lastState` jsonpath, `logs -p`) and the manifest patch the symptoms imply, so
   whoever holds access produces the diagnosis in one pass.

## Edge cases

| Case | Then |
|------|------|
| `exitCode: 137` with a `reason` other than `OOMKilled` | Read it as an external `SIGKILL`: a process killed by signal *n* reports 128+*n*, and 137 is 128+9 — check node events for eviction and pressure rather than the memory limit |
| The pod object never appears at all | The failure is above the pod: check the controller's sync status for that Application/Kustomization — the manifest may never have been applied |
| `ImagePullBackOff` against a private registry | The fix is `imagePullSecrets`/registry credentials *in the manifest*, so it follows the same PR path |
| The controller reports Synced while the pod runs old code | A mutable tag was re-pushed; pin the digest and let the reconcile roll it ([infrastructure-deploy-rollout-and-rollback]) |
| Container metrics are empty, so "measure the peak" has no data | Fix the metrics path first ([infrastructure-observability-missing-container-metrics]) — sizing a limit from no data reproduces the OOM |
| The mitigation genuinely cannot wait for the pipeline | Apply it live, then open the PR in the same session and state the live change in its body, so the next reconcile does not silently erase an undocumented mitigation |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Open `kubectl logs` first on a `CrashLoopBackOff` pod | Read `lastState.terminated.exitCode` and `reason` first | An OOM kill leaves no application log line, so the log sends you into the app for an infrastructure limit |
| `kubectl edit`/`apply` the fix on the live object | Commit the manifest patch and let the controller sync it | Either self-heal reverts it on the next reconcile, or it survives as drift Git cannot see |
| Loop on cluster access until it works | Hand over the read-only command list plus a symptom-based patch | The retry loop consumes the incident window and produces no diagnosis |
| Raise the memory limit because the pod was OOMKilled | Read the exit reason, then size the limit from the measured peak of the real workload | A limit raised without a measurement moves the same kill later, and hides a leak as a capacity number |

## Sources

- https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/ — "The first step in debugging a Pod is taking a look at it. Check the current state of the Pod and recent events with the following command: `kubectl describe pods ${POD_NAME}`"; Pending: "There should be messages from the scheduler about why it can not schedule your pod"; Waiting: "The most common cause of `Waiting` pods is a failure to pull the image"
- https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/ — the worked over-limit example prints `lastState: terminated: exitCode: 137 … reason: OOMKilled` under "The output shows that the Container was killed because it is out of memory (OOM)"
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/ — `-p, --previous`: "If true, print the logs for the previous instance of the container in a pod if it exists"
- https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/ — "By default, changes that are made to the live cluster will not trigger automated sync"; self-heal is "To enable automatic sync when the live cluster's state deviates from the state defined in Git"; "Disabling self-heal does not guarantee that live cluster changes in multi-source applications will persist"
- https://man7.org/linux/man-pages/man1/bash.1.html — "The return value of a *simple command* is its exit status, or 128+*n* if the command is terminated by signal *n*" — the convention that makes 137 read as 128+9 (`SIGKILL`)
