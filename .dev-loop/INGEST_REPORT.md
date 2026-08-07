# Knowledge flush — 3 candidate(s): 1 ingested, 2 dropped

## Verified best-practice

### 1. A dependency command that resyncs the environment deletes undeclared packages — `confidence: verified`

**Candidate as harvested:** "run `uv add`/`uv remove` only after background jobs
finish; register dev tools like pytest/ruff in a dependency-group instead of
`uv pip install`, so they survive a sync."

**Sources checked (live this session):**

- https://docs.astral.sh/uv/concepts/projects/sync/ — "`uv sync` performs 'exact'
  syncing by default, which means it will remove any packages that are not present
  in the lockfile"; `--inexact` retains them; "`uv run` uses 'inexact' syncing by
  default, ensuring that all required packages are installed but not removing
  extraneous packages."
- https://docs.astral.sh/uv/concepts/projects/dependencies/ — PEP 735
  `[dependency-groups]`; "the `dev` group is synced by default."
- https://docs.astral.sh/uv/reference/cli/ — `uv add`: "The lockfile and project
  environment will be updated to reflect the added dependencies."
- https://peps.python.org/pep-0735/ — dependency groups as a standard manifest field.

**How it was verified — local reproduction, uv 0.11.5 (aarch64-apple-darwin),
throwaway project:**

1. Declared `packaging`, then installed `iniconfig` ad-hoc with `uv pip install`
   (undeclared, absent from `uv.lock`).
2. `uv add typing-extensions` → `iniconfig` **survived**.
3. `uv remove packaging` → `iniconfig` **deleted** along with the intended package.
   Repeated a second time with the same result.
4. `uv remove packaging --no-sync` → `iniconfig` **preserved**.
5. Flag inventory via `uv {add,remove,sync,run} --help`: only `uv sync` exposes
   `--inexact`, only `uv run` exposes `--exact`; `uv add` and `uv remove` expose
   neither. `uv remove --no-sync`: "Avoid syncing the virtual environment after
   re-locking the project."
6. Delayed-failure mechanism: a background process that had imported `iniconfig`
   before the resync kept running and still resolved the cached module, while a
   later `import tomli_w` in that same process raised `ModuleNotFoundError`.

**Correction applied to the candidate.** The candidate treats `uv add` and
`uv remove` as symmetric ("uv add/remove re-syncs the whole environment"). The
reproduction refutes that: `add` is inexact and harmless to undeclared packages,
`remove` is exact and has no `--inexact` escape hatch. The ingested page carries
the measured per-command exactness table rather than the symmetric claim, so the
"wait for the job" directive is scoped to the commands that actually prune.

### 2 & 3. Dropped — see Open-PR check

No independent verification was performed on the two orchestration candidates
because both are pending duplicates; neither is being promoted to a page here.

## Existing-layer check

Routed via `INDEX.md` → `platforms` ("toolchain version pinning", "background
services") rather than the harvested `infrastructure` hint, whose seeded scope is
CI/CD, containers, rollout, observability, path-valued config and multi-agent
orchestration — none of which covers a local package manager mutating a project
virtualenv. Then read the `platforms` domain index and every toolchains/processes
page whose "load when" line overlaps.

Pages read: platforms-toolchains-version-management, platforms-toolchains-compiler-sysroot-on-macos, platforms-processes-background-services, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-worktree-isolated-workers

**Overlaps found.** `platforms-toolchains-version-management` was the only merged
page mentioning uv at all (`uv sync --frozen`, `.python-version`). Its trigger is
*version drift across machines* and its directives are about pinning and
committing lockfiles — it never covers a sync deleting packages, nor the timing
hazard of mutating dependencies mid-run. Different trigger → new page, not a
merge (a merge would have forced two cases onto one page, against the one-case
rule).

**Conflicts flagged:** none. Nothing in the merged wiki asserts the opposite
behavior; `version-management`'s "install from lockfiles (`npm ci`, `uv sync
--frozen`)" line is consistent with the new page and is not modified.

**Created:** `wiki/platforms/toolchains/environment-resync-removes-undeclared-packages.md`
(63 body lines, within the 120 limit; positive-guidance form; the two prohibitions
appear only as paired `Instead of` rows).

**Related links added, both ways:**
`platforms-toolchains-version-management` ↔ new page (lockfile/reproducibility
adjacency), and `platforms-processes-background-services` ↔ new page (the timing
hazard is against a job running in the background).

**Plumbing:** `wiki/platforms/index.md` toolchains table gains a routing row;
`log.md` gains the dated ingest entry.

## Open-PR check

Listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` —
10 open heads: #61, #58, #57, #56, #55, #52, #51, #50, #49, #47. Each head was
fetched and diffed against `origin/main` under `wiki/`.

| Candidate | Overlapping open head | Verdict |
|-----------|----------------------|---------|
| uv / environment resync deletes undeclared packages | none — grepping every one of the 10 heads' `wiki/` diffs for `uv (add\|remove\|sync\|pip)` and `site-packages` returned 0 hits on all 10 | **new** |
| dev-loop `worktree_escape` guardrail escalates read-only cross-worktree access | **#51** — its `infrastructure-agent-orchestration-worktree-isolated-workers` already carries this case, and its local reproduction is *more* accurate than the candidate: reads alone (`grep`, `awk`, `cat`, `git -C … status`) pass; the escalation fires only when a main-root mention survives the strip **and** a write verb or absolute-path redirect also matches | **drop** |
| dev-loop Orca dispatch binding taxonomy (busy pane, `runtime_unavailable` vs `agent_unconfigured`, `--terminal` with `--worktree`) | **#51** — its `infrastructure-agent-orchestration-pane-delivery-confirmation` carries the idle-prompt-before-binding rule and the three-stage field observation verbatim | **drop** |

Both dropped candidates are **recurring re-emissions**, not un-retired rows: they
already appear in `~/.dev-loop/queue/.processed.jsonl` 15× and 10× respectively,
and PRs #56, #57 and #58 each recorded dropping the same pair as in-flight
duplicates of #51. They will keep re-entering the queue from live orchestration
sessions until #51 merges; retiring them again here is correct and cheap.

## Routing decision

| Insight | Domain / category / page | New category? |
|---------|--------------------------|---------------|
| A dependency command resyncing the environment deletes packages absent from the lockfile | `platforms` / `toolchains` / `environment-resync-removes-undeclared-packages` (new page) | No — `toolchains` already owns package/version tooling behavior (`version-management`, `compiler-sysroot-on-macos`). The harvested `infrastructure` hint was re-routed: `infrastructure`'s seeded scope is pipelines, containers, rollout, observability and orchestration, none of which covers a local package manager pruning a project virtualenv. |
| `worktree_escape` guardrail read-vs-write | already at `infrastructure/agent-orchestration/worktree-isolated-workers` in open PR #51 | Not ingested (drop) |
| Orca dispatch binding taxonomy | already at `infrastructure/agent-orchestration/pane-delivery-confirmation` in open PR #51 | Not ingested (drop) |
