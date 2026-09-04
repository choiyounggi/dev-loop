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
| [control-signals-vs-primary-artifacts](agent-orchestration/control-signals-vs-primary-artifacts.md) | An orchestrator is about to restart, discard, merge, or keep waiting on a worker based on a status file, a watcher's exit code, or a heartbeat; a monitor reports a worker dead while it is committing; a worker's status write produced no output and you must decide whether it landed; distinguishing alive-and-progressing from stalled from dead; several workers went quiet at once while every liveness check passes (usage-limit pause); a dispatch issued right after a worker's done signal fails runtime-unavailable |
| [shared-run-state](agent-orchestration/shared-run-state.md) | Several agent/worker sessions coordinate through files in one repository (status directory, briefs, escalations, claim files); choosing the path layout for that state; starting an orchestration in a repo that may already have one running; a watcher woke on a task id it did not create; the default branch moved during a run; a coordinator is about to reset a task's status file while re-delivering a prompt |
| [pane-delivery-confirmation](agent-orchestration/pane-delivery-confirmation.md) | An orchestrator drives another program through a terminal multiplexer (`tmux send-keys` + `capture-pane`) and must decide whether the input was consumed, retry, or escalate; a pane diff is being used as delivery evidence; the target echoes but never runs the input; deciding *where* in a pane capture to search for a collapsed paste marker whose position depends on payload size, or what to report when the pane's input-box chrome cannot be located at all |
| [session-completion-gates](agent-orchestration/session-completion-gates.md) | Writing a Stop/completion hook that blocks a worker session from ending while its phase is non-terminal; the gate fires on a worker that followed its own prompt; deciding the terminal phase set, the unknown-phase default, and how the gate bounds its own repetition; you are the worker the gate repeats on at an instructed pause and are deciding whether to advance your phase to silence it |
| [dispatching-after-a-completion-report](agent-orchestration/dispatching-after-a-completion-report.md) | A worker reported completion and the orchestrator wants to hand that same terminal or runtime slot its next task; a start/dispatch call fails with a runtime-unavailable-class error moments after a completion report; a task reached a terminal `failed` status with no worker having worked on it; deciding a settled dispatch's next owner (transfer, release, or retain) and how to retry a failed start without spending the task's attempt budget |
| [unattended-worker-questions](agent-orchestration/unattended-worker-questions.md) | A worker agent raises a question through its own interactive UI (a numbered chooser, a confirmation/trust/re-auth screen) with no human at that terminal; a worker is flagged stalled with a live terminal and no task-level error; a worker reports a decision it assumed rather than asked; designing the channel a worker uses to ask its coordinator for a decision |
| [usage-limit-paused-workers](agent-orchestration/usage-limit-paused-workers.md) | Several workers billed to one account go quiet within minutes of each other while every liveness check passes; a worker's terminal shows a `You've hit your session/weekly/Opus limit · resets …` notice; deciding whether to restart, replace, or wait on a worker with no task-level error; writing the prompt that resumes a worker after a usage window resets |
| [worktree-isolated-workers](agent-orchestration/worktree-isolated-workers.md) | Authoring the brief/output contract for parallel workers each confined to its own git worktree; workers stall at the same phase with no task-level error; deciding where shared or produced artifacts live and which direction (read vs write) a worktree guardrail stops; a guardrail escalates on read-only access to another worktree; the isolation guard is a Bash-command hook while workers also edit files with native Edit/Write tools |
| [autonomous-decision-rulings](agent-orchestration/autonomous-decision-rulings.md) | An unattended agent hits a decision its plan does not answer and must choose between stopping to ask and proceeding; a run stalls on questions no human needed to see; deciding which decision categories require a human; recording autonomous decisions for audit; resuming after interruption/compaction without re-dispatching completed work |
| [checkable-claims-in-an-adopted-plan](agent-orchestration/checkable-claims-in-an-adopted-plan.md) | A worker adopts a coordinator-authored plan that states derived numbers (contrast ratios, orderings, hex arithmetic), a fixed symbol contract other tasks consume, or a deliverable file downstream tasks read; deciding what to recompute before encoding the plan's claims in tests; a declared deliverable turns out gitignored; a discrepancy with the plan is found and you are deciding whether to correct it locally or escalate; adopting a multi-task plan with a "Task order / Depends on" table before implementing any task in it, to check the table against each task's own Steps prose for the real dependency direction |
| [session-context-token-budget](agent-orchestration/session-context-token-budget.md) | Planning or running long-lived coordinator/worker agent sessions and deciding when to compact or clear context; a run's cost is dominated by cache reads; screenshots or large file reads are entering a long-lived session; choosing slot counts / per-phase token budgets for an orchestrated run |

## ci-cd

| Page | Load when |
|------|-----------|
| [pipeline-structure](ci-cd/pipeline-structure.md) | Creating or restructuring a CI pipeline; CI is slow, unreliable, or reports failures too late; deciding where a new check/stage belongs |
| [secrets-handling](ci-cd/secrets-handling.md) | A build or deploy step needs credentials (registry, cloud, private packages, signing); reviewing how secrets flow through CI; a secret leaked (log/chat/commit) and deciding the response |
| [changed-files-only-gates](ci-cd/changed-files-only-gates.md) | A CI step builds a changed-files list in the shell and passes it to `prettier`/`eslint`/a checker as operands; deciding whether a green gate means "no violations" or "nothing examined"; the list is empty because a base ref did not resolve; the script runs under zsh where an unquoted variable does not word-split; placing a probe file to prove the gate can fail |

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
| [exec-added-processes-and-the-memory-budget](containers/exec-added-processes-and-the-memory-budget.md) | About to `kubectl exec`/`docker exec` an extra process into a pod already running a service (remote CLI worker, debug shell, side job); judging it safe because the app’s own queue or semaphore has free slots; reading `memory.current`/`memory.peak`/`memory.events` as a headroom preflight; deciding between exec and a Job/sidecar with its own limits |
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
| [feature-flag-lifecycle](deploy/feature-flag-lifecycle.md) | Adding a feature flag/toggle and deciding its category (release, experiment, ops, permissioning) and expected lifetime; a flag has outlived the rollout/experiment that created it; deciding when and how to remove a flag and its dead code path; a flag is checked in many places |

## observability

| Page | Load when |
|------|-----------|
| [logs-metrics-signals](observability/logs-metrics-signals.md) | Instrumenting a new or existing service (logs, metrics, correlation ids); an incident revealed you couldn't see what happened; choosing between a log line and a metric; a metric label would carry unbounded values (user ids/UUIDs) |
| [missing-container-metrics](observability/missing-container-metrics.md) | Prometheus `container_*` CPU/memory series are empty or pod dashboards blank while kubelet scrape targets all report up (common on embedded/VM Kubernetes like OrbStack); deciding between cAdvisor and kubelet `/metrics/resource` scraping |
| [alerting](observability/alerting.md) | Creating or reviewing alerts; the team ignores a noisy pager; deciding whether a condition pages, tickets, or stays on a dashboard |
| [suppression-state-and-delivery-failure](observability/suppression-state-and-delivery-failure.md) | Adding notification suppression to a script or service (cooldown file, "last alerted at" timestamp, sent-marker key) and choosing where the mark is written relative to the send; a condition stayed live while the channel went quiet for the whole cooldown window; writing the tests for that marker against a stub whose send always fails |
| [suppression-key-for-a-recurring-failure](observability/suppression-key-for-a-recurring-failure.md) | A retried job or client keeps hitting the same external rejection and every retry re-sends an identical alert; choosing the dedup/suppression key (rendered text vs an error-code whitelist), the daily re-send, and keeping the retry running while only the notification is suppressed |
