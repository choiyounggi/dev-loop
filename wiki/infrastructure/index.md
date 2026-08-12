# infrastructure — Domain Index

Route here for: CI/CD pipeline design, secrets in build/deploy flows, container
image builds, container resource limits and health probes, per-environment
configuration (env vars, config drift, startup validation), rollout/rollback
strategy, observability (logging, metrics, alerting), datastore backup/restore
and data-loss planning.

Match your situation to a "load when" line; load only matching pages.

## agent-orchestration

| Page | Load when |
|------|-----------|
| [control-signals-vs-primary-artifacts](agent-orchestration/control-signals-vs-primary-artifacts.md) | An orchestrator is about to restart, discard, merge, or keep waiting on a worker based on a status file, a watcher's exit code, or a heartbeat; a monitor reports a worker dead while it is committing; a worker's status write produced no output and you must decide whether it landed; distinguishing alive-and-progressing from stalled from dead |
| [shared-run-state](agent-orchestration/shared-run-state.md) | Several agent/worker sessions coordinate through files in one repository (status directory, briefs, escalations, claim files); choosing the path layout for that state; starting an orchestration in a repo that may already have one running; a watcher woke on a task id it did not create; the default branch moved during a run |
| [pane-delivery-confirmation](agent-orchestration/pane-delivery-confirmation.md) | An orchestrator drives another program through a terminal multiplexer (`tmux send-keys` + `capture-pane`) and must decide whether the input was consumed, retry, or escalate; a pane diff is being used as delivery evidence; the target echoes but never runs the input |
| [session-completion-gates](agent-orchestration/session-completion-gates.md) | Writing a Stop/completion hook that blocks a worker session from ending while its phase is non-terminal; the gate fires on a worker that followed its own prompt; deciding the terminal phase set, the unknown-phase default, and how the gate bounds its own repetition |
| [worktree-isolated-workers](agent-orchestration/worktree-isolated-workers.md) | Authoring the brief/output contract for parallel workers each confined to its own git worktree; workers stall at the same phase with no task-level error; deciding where shared or produced artifacts live and which direction (read vs write) a worktree guardrail stops |

## ci-cd

| Page | Load when |
|------|-----------|
| [pipeline-structure](ci-cd/pipeline-structure.md) | Creating or restructuring a CI pipeline; CI is slow, unreliable, or reports failures too late; deciding where a new check/stage belongs |
| [secrets-handling](ci-cd/secrets-handling.md) | A build or deploy step needs credentials (registry, cloud, private packages, signing); reviewing how secrets flow through CI; a secret leaked (log/chat/commit) and deciding the response |

## config

| Page | Load when |
|------|-----------|
| [environment-config](config/environment-config.md) | Adding configuration that differs per environment; a bug traced to a dev/stg/prd config difference; config sprawled across hardcoded values, files, and env vars; reviewing how a service gets its settings |
| [path-valued-config](config/path-valued-config.md) | A config key or env var holds a filesystem path (spool/input/output directory, data file, socket) for a process whose working directory is set by launchd/systemd/cron/a container entrypoint/CI; deciding whether to accept a relative path, expand `~`, or crash at startup; a correctly-deployed service processes nothing and reports no error; writing the loader's rejection tests |
| [keys-ahead-of-their-consumer](config/keys-ahead-of-their-consumer.md) | Adding a config key that a component outside your repository parses, for a version of it that has not shipped yet; reviewing a change justified by "older versions ignore unknown keys"; deciding whether a parser drops or rejects an unknown key (path query vs permissive binding vs strict schema); pre-declaring a key that carries a security control |

## containers

| Page | Load when |
|------|-----------|
| [host-cgroup-visibility](containers/host-cgroup-visibility.md) | A container must read the host's full cgroup v2 hierarchy (other pods' CPU/memory stats) via a hostPath/`-v` mount of `/sys/fs/cgroup`; the mounted directory is missing the `kubepods` subtree with no error |
| [image-builds](containers/image-builds.md) | Writing or reviewing a Dockerfile; images rebuild everything on small changes, build slowly, or are too large; choosing an image tagging scheme |
| [resource-limits-and-probes](containers/resource-limits-and-probes.md) | Writing or reviewing Kubernetes-style deployment manifests; pods OOMKilled, evicted, or CPU-throttled; a dependency outage triggered a restart storm; traffic hitting pods that are not ready |
| [failing-pod-on-a-repo-synced-cluster](containers/failing-pod-on-a-repo-synced-cluster.md) | A pod will not start or keeps restarting (`Pending`, `ContainerCreating`, `CrashLoopBackOff`) on a cluster whose manifests a GitOps controller (Argo CD, Flux) applies; choosing between editing the live object and committing the manifest; reading `lastState.terminated` exitCode/reason before logs to separate an OOM kill from an application exit; you hold no cluster access and must hand the diagnosis over |

## data

| Page | Load when |
|------|-----------|
| [backup-and-restore](data/backup-and-restore.md) | Setting up backups for a datastore; auditing existing backups; planning for data-loss scenarios (deletion, corruption, bad migration, ransomware/account compromise, region loss) |

## deploy

| Page | Load when |
|------|-----------|
| [rollout-and-rollback](deploy/rollout-and-rollback.md) | Designing how a service reaches production (rollout strategy, health gating); preparing a risky release; a deploy involves a schema change, data migration, or feature flag and you need rollback mechanics |

## observability

| Page | Load when |
|------|-----------|
| [logs-metrics-signals](observability/logs-metrics-signals.md) | Instrumenting a new or existing service (logs, metrics, correlation ids); an incident revealed you couldn't see what happened; choosing between a log line and a metric; a metric label would carry unbounded values (user ids/UUIDs) |
| [missing-container-metrics](observability/missing-container-metrics.md) | Prometheus `container_*` CPU/memory series are empty or pod dashboards blank while kubelet scrape targets all report up (common on embedded/VM Kubernetes like OrbStack); deciding between cAdvisor and kubelet `/metrics/resource` scraping |
| [alerting](observability/alerting.md) | Creating or reviewing alerts; the team ignores a noisy pager; deciding whether a condition pages, tickets, or stays on a dashboard |
