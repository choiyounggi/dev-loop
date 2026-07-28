---
id: infrastructure-containers-host-cgroup-visibility
domain: infrastructure
category: containers
applies_to: [kubernetes, docker, cgroup-v2]
confidence: field-tested
sources:
  - https://man7.org/linux/man-pages/man7/cgroup_namespaces.7.html
  - https://docs.docker.com/reference/cli/docker/container/run/
  - https://man7.org/linux/man-pages/man1/nsenter.1.html
  - https://github.com/kubernetes/kubernetes/issues/103363
last_verified: 2026-07-28
related: [infrastructure-containers-resource-limits-and-probes, infrastructure-observability-missing-container-metrics]
---

# Reading Other Pods' cgroup v2 Stats from Inside a Container

## When this applies

A container needs to read the host's full cgroup v2 hierarchy — other pods'
CPU/memory/PSI stats under `kubepods/` — via hostPath or `docker -v` mounting
of `/sys/fs/cgroup`. The mount succeeds but the `kubepods` subtree is missing,
with no error (empty or partial listing, silently wrong results).

## Do this

Mounting the path is not sufficient; the cgroup namespace decides the view.
On cgroup v2, container runtimes default to a **private cgroup namespace**
(dockerd `--default-cgroupns-mode` default: `private`), and the cgroup2
filesystem mounted for the container in that namespace shows only the
container's own subtree — the host hierarchy is simply absent.

| Case | Do |
|------|----|
| Docker/standalone container | Run with `--cgroupns=host` in addition to the `-v /sys/fs/cgroup:...` mount — the container then gets the host's cgroup namespace and the full hierarchy |
| Kubernetes pod | There is no first-class host-cgroupns pod option (kubernetes#103363, open); use a privileged pod, or `hostPID: true` + `nsenter -t 1 -C` (`--cgroup`) to run the reading command inside PID 1's cgroup namespace |
| Verifying before trusting the data | List the mount for `kubepods/` (or the equivalent top-level slice) explicitly; treat its absence as a namespace problem, never as "those pods have no stats" |

Mechanism: cgroup namespaces virtualize the cgroup view — `/proc/[pid]/cgroup`
paths and the cgroupfs contents are shown relative to the namespace's root,
fixed by the cgroup namespace in effect when that cgroup2 filesystem mount was
created (cgroup_namespaces(7)). The runtime creates the container's cgroup
mount inside the private namespace, so what looks like "the host's
/sys/fs/cgroup" is a namespaced view rooted at the container's own cgroup.

## Edge cases

| Case | Then |
|------|------|
| Files are visible but writes fail (`cgroup.procs`: no such file / EPERM) | A different restriction: the `nsdelegate` mount option (systemd default) blocks cross-namespace-boundary writes even when reads work — reading stats is fine, migrating processes is not |
| Reading only the container's OWN limits/usage | No host namespace needed — the default namespaced view is exactly right for self-monitoring |
| Sizing decisions based on the stats you read | Limits/QoS interpretation: [infrastructure-containers-resource-limits-and-probes] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude "cgroup data isn't there" from an empty mounted directory | Check the cgroup namespace first (`--cgroupns=host` / `nsenter -t 1 -C`), then re-list | Measured (OrbStack VM, 2026-07-22): identical `-v /sys/fs/cgroup` mount showed no `kubepods` without `--cgroupns=host` and the full `kubepods/burstable/pod<UID>/` tree with it — the failure mode is silent |
| Parse per-pod stats from inside a default (non-privileged) pod | Read via a host-namespace-capable agent (privileged/hostPID DaemonSet) or consume kubelet metrics endpoints instead: [infrastructure-observability-missing-container-metrics] | The default pod cgroupns cannot see sibling pods at all |

## Sources

- https://man7.org/linux/man-pages/man7/cgroup_namespaces.7.html — cgroup namespaces virtualize the cgroup view; cgroupfs contents depend on the namespace of the mount's creator; nsdelegate write restrictions
- https://docs.docker.com/reference/cli/docker/container/run/ — `--cgroupns=host` runs the container in the host's cgroup namespace; private is the cgroup v2 default
- https://man7.org/linux/man-pages/man1/nsenter.1.html — `-C/--cgroup` enters the target process's cgroup namespace
- https://github.com/kubernetes/kubernetes/issues/103363 — no first-class host cgroupns for pods; nsenter-based workaround pattern (as used by Cilium)
- Field context: 2026-07-22 OrbStack VM measurement — `docker run -v /sys/fs/cgroup:/hostcg alpine`: `kubepods` absent; adding `--cgroupns=host`: full `kubepods/burstable/pod<UID>/` hierarchy visible
