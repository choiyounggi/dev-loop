# infrastructure — Domain Index

Route here for: CI/CD pipeline design, secrets in build/deploy flows, container
image builds, container resource limits and health probes, per-environment
configuration (env vars, config drift, startup validation), rollout/rollback
strategy, observability (logging, metrics, alerting), datastore backup/restore
and data-loss planning, and orchestrating parallel worker sessions over one
repository (status signals, liveness verdicts, run-scoped shared state).

Match your situation to a "load when" line; load only matching pages.

## ci-cd

| Page | Load when |
|------|-----------|
| [pipeline-structure](ci-cd/pipeline-structure.md) | Creating or restructuring a CI pipeline; CI is slow, unreliable, or reports failures too late; deciding where a new check/stage belongs |
| [secrets-handling](ci-cd/secrets-handling.md) | A build or deploy step needs credentials (registry, cloud, private packages, signing); reviewing how secrets flow through CI; a secret leaked (log/chat/commit) and deciding the response |

## config

| Page | Load when |
|------|-----------|
| [environment-config](config/environment-config.md) | Adding configuration that differs per environment; a bug traced to a dev/stg/prd config difference; config sprawled across hardcoded values, files, and env vars; reviewing how a service gets its settings |

## containers

| Page | Load when |
|------|-----------|
| [host-cgroup-visibility](containers/host-cgroup-visibility.md) | A container must read the host's full cgroup v2 hierarchy (other pods' CPU/memory stats) via a hostPath/`-v` mount of `/sys/fs/cgroup`; the mounted directory is missing the `kubepods` subtree with no error |
| [image-builds](containers/image-builds.md) | Writing or reviewing a Dockerfile; images rebuild everything on small changes, build slowly, or are too large; choosing an image tagging scheme |
| [resource-limits-and-probes](containers/resource-limits-and-probes.md) | Writing or reviewing Kubernetes-style deployment manifests; pods OOMKilled, evicted, or CPU-throttled; a dependency outage triggered a restart storm; traffic hitting pods that are not ready |

## data

| Page | Load when |
|------|-----------|
| [backup-and-restore](data/backup-and-restore.md) | Setting up backups for a datastore; auditing existing backups; planning for data-loss scenarios (deletion, corruption, bad migration, ransomware/account compromise, region loss) |

## deploy

| Page | Load when |
|------|-----------|
| [rollout-and-rollback](deploy/rollout-and-rollback.md) | Designing how a service reaches production (rollout strategy, health gating); preparing a risky release; a deploy involves a schema change, data migration, or feature flag and you need rollback mechanics |

## orchestration

| Page | Load when |
|------|-----------|
| [control-signals-vs-primary-artifacts](orchestration/control-signals-vs-primary-artifacts.md) | An orchestrator is about to restart, discard, merge, or keep waiting on a worker based on a status file, a watcher's exit code, or a heartbeat; a monitor reports a worker dead while it is committing; a worker's status write produced no output and you must decide whether it landed; deciding what identifier a worker should report itself by; distinguishing alive-and-progressing from stalled from dead |
| [shared-run-state](orchestration/shared-run-state.md) | Several agent/worker sessions coordinate through files in one repository (status directory, briefs, escalations, claim files); choosing the path layout for that state; starting an orchestration in a repo that may already have one running; a watcher woke on a task id it did not create; the default branch moved during a run |

## observability

| Page | Load when |
|------|-----------|
| [logs-metrics-signals](observability/logs-metrics-signals.md) | Instrumenting a new or existing service (logs, metrics, correlation ids); an incident revealed you couldn't see what happened; choosing between a log line and a metric; a metric label would carry unbounded values (user ids/UUIDs) |
| [missing-container-metrics](observability/missing-container-metrics.md) | Prometheus `container_*` CPU/memory series are empty or pod dashboards blank while kubelet scrape targets all report up (common on embedded/VM Kubernetes like OrbStack); deciding between cAdvisor and kubelet `/metrics/resource` scraping |
| [alerting](observability/alerting.md) | Creating or reviewing alerts; the team ignores a noisy pager; deciding whether a condition pages, tickets, or stays on a dashboard |
