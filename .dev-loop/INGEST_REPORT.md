# Knowledge flush — 2 insight(s)

Run `20261006-223928-57385` (auto-flush). Claimed 19 queue rows: 2 insights were verified and merged into 2 existing pages, and 17 plan-gap rows were dropped as project-specific (listed under Local-layer candidates). No new pages.

## Verified best-practice

### 1. Two mutants that change a Python file's size by the same amount reuse each other's bytecode; a fresh `PYTHONPYCACHEPREFIX` per run fixes it (row `c9bfb85cd7820c7e`)

- **Claim:** a harness that rewrites a `.py` file and imports it in a fresh subprocess each time can load the previous mutant's `.pyc`. This happens when two different mutations land in the same second and have the same size as each other, even if that size differs from the original's. Remedy: give each run its own new `PYTHONPYCACHEPREFIX` directory.
- **Sources checked:**
  - https://docs.python.org/3/using/cmdline.html — `PYTHONPYCACHEPREFIX`: "If this is set, Python will write .pyc files in a mirror directory tree at this path, instead of in `__pycache__` directories within the source tree"; "Added in version 3.8". I fetched the live page and grepped it on 2026-10-06.
  - https://docs.python.org/3/library/sys.html#sys.pycache_prefix — "write bytecode-cache .pyc files to (and read them from) a parallel directory tree … Any `__pycache__` directories in the source code tree will be ignored". I fetched the live page on 2026-10-06.
  - https://docs.python.org/3/reference/import.html — already cited on the page: validation compares the stored mtime and size.
- **How verified:** reproduced on Python 3.14.6 / macOS in a scratch dir under `~/.dev-loop/scratch/`, deleted afterwards.
  - Known-bad: `X = "orig"`, then mutant A `X = "aa"`, then mutant B `X = "zz"`, both pinned to the same mtime. With the default cache, B printed `aa` (stale).
  - Known-good: B under a fresh prefix printed `zz`, even though the in-tree `__pycache__` still held A.
  - Reused prefix: mutant C `X = "yy"` under the same prefix printed `zz` (stale again). Under a new prefix it printed `yy`.
- **Confidence:** verified.

### 2. A completion gate that identifies the worker by tmux session name also matches processes that are not the worker (row `10454e0809cda9c3`)

- **Claim:** a Stop hook that treats "`cwd` matches and `tmux display-message -p '#S'` equals the recorded session" as "this is the managed worker" also matches other processes:
  - any process started from the worker's pane, because it inherits `TMUX`/`TMUX_PANE`;
  - when `TMUX` is unset, whatever the most recently used session is.
- **Fix, gate side:** bind identity to a per-process id. Launch with `claude --session-id <uuid>`, record that id, and compare it with the hook input's `session_id`.
- **Fix, receiving side:** before acting on a block, compare the parent command's prompt with the task the status entry names. If they differ, report it and stop.
- **Sources checked:**
  - https://man7.org/linux/man-pages/man1/tmux.1.html — "If a session is omitted, the current session is used if available; if no current session is available, the most recently used is chosen"; the pane ID "is passed to the child process of the pane in the TMUX_PANE environment variable".
  - https://man7.org/linux/man-pages/man7/environ.7.html — "When a child process is created via fork(2), it inherits a copy of its parent's environment".
  - https://code.claude.com/docs/en/hooks — the common input fields include `session_id` ("Current session identifier"). I fetched the live page.
  - `claude --help` lists `--session-id <uuid>`.
- **How verified:**
  - Isolated `tmux -L kfprobe<pid>` server (tmux 3.7b, killed afterwards), two detached sessions `worker-a` and `worker-b`:
    - A grandchild `sh -c "sh -c 'tmux display-message -p #S'"` started inside pane `worker-a` printed `worker-a`.
    - The same query with `TMUX` unset printed `worker-b`, not an error.
  - On the real server, this flush session itself (parent `hooks/auto-flush.sh`, `TMUX` unset) got `lo-17-oi1002` back from `tmux display-message -p '#S'`.
  - The candidate's field evidence: `hooks/loop-gate.sh` blocked a knowledge-flush `claude -p` child with phase=implementing for task `tmain`.
- **Correction to the candidate:** its stated mechanism, that inherited `TMUX` is the only path, is incomplete. The fallback to the most recently used session is a second path. `loop-gate.sh:90` guards on `[ -n "$TMUX" ]`, which closes the second path but not the first.
- **Confidence:** verified.

## Existing-layer check

Pages read: backend-python-language-bytecode-cache-staleness, testing-quality-mutation-harness-file-custody, infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-inherited-lock-ownership-in-a-spawned-session

- **Insight 1:** `backend-python-language-bytecode-cache-staleness` already covers the timestamp+size collision, `__pycache__` purge, mtime bump, hash-based `.pyc`, `-B`, `copy2`, and fresh-spec imports. Its 2026-08-11 field row even shows consecutive mutants loading the first mutant's value.
  - What was new: the `PYTHONPYCACHEPREFIX` remedy, and the explicit "same size as each other, not as the original" mutant-to-mutant case.
  - **Merged, not created:** extended step 2 with the prefix option and added one edge row (including "reusing one prefix brings the collision back"). Also added two source lines plus the reproduction, a `When this applies` clause, and a `related:` link to `testing-quality-mutation-harness-file-custody` (that page is about backup/restore custody, not cache invalidation, so no duplicate).
  - No conflict with existing directives (body line count after review fixes is below).
- **Insight 2:** `infrastructure-agent-orchestration-session-completion-gates` owns the Stop/completion-gate topic. It already had a "several workers share one status directory → match by `cwd`" row, but nothing on session identity.
  - `infrastructure-agent-orchestration-inherited-lock-ownership-in-a-spawned-session` covers inherited env used *on purpose* (lock ownership). It does not cover inherited env misread as identity, so it is related, not a duplicate.
  - **Merged, not created:** two edge rows (gate side, receiving side), one Instead-of row, a `When this applies` clause, and three source lines (tmux man, environ(7), reproduction). No conflict (cap 120; count after review fixes is below).
- **Index rows extended:** `session-completion-gates` in `wiki/infrastructure/index.md` and `bytecode-cache-staleness` in `wiki/backend/python/index.md`. Two `revise` lines appended to `log.md`.
- **Lint:**
  - `node scripts/wiki-structure-checks.js <repo>/wiki --layer bundled` → `pages: 359, indexes: 13, findings: 0`.
  - `node scripts/wiki-lint-prohibitions.js <repo>` → 3 violations, all already on main and none in the changed files (`plans/harvest-dedupe-processed/...`, `skills/graph-setup/SKILL.md`, `wiki/infrastructure/config/keys-ahead-of-their-consumer.md`).

**Independent adversarial review:** `feature-dev:code-reviewer`, read-only, ran before commit and returned FAIL with 7 findings. All were fixed:

1. The receiving-side `ps -o command= -p $PPID` step was unproven. It is now scoped to headless `claude -p` (interactive workers get their prompt by paste, so argv holds none), backed by this session's own reproduction.
2. Identity bound to `session_id` alone was incomplete. Added an edge row: subagents share the parent's `session_id`, `agent_id` is "Present only when the hook fires inside a subagent call", and relaunch with `--resume` keeps the id while `--fork-session` mints a new one. Sources: hooks + cli-reference pages.
3. The `session_id` / `--session-id` claims were moved into their own source bullets, citing hooks and https://code.claude.com/docs/en/cli-reference.
4. `When this applies` on the gates page is back to 4 lines.
5. Added the cost trade-off for the prefix option: full recompile including stdlib (the reproduction's prefix held an `opt/` tree) plus one directory per run. It now says when to choose the prefix and to delete each prefix directory.
6. Step 5 on the bytecode page no longer implies that a length-changing mutant is safe. The index row was reworded to match. A re-check found one more gap (N1: the two-mutant edge row offered only the prefix). It now offers the purge first and refers to step 2 for when to prefer the prefix; the re-check confirmed findings 1–7 resolved.
7. The tmux reproduction text no longer claims "most recently used" over "most recently created". A second isolated-server try (`send-keys` to `worker-a`) did not update session activity, so that run cannot separate the two; the rule is cited from the man page.

Body lines after the fixes: 85 (bytecode) and 118 (gates). Both lints were re-run: structure 0 findings; prohibitions 3, all already on main, 0 in changed files.

## Open-PR check

Open `knowledge/*` heads listed via `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`: #253, #249, #244, #241, #239, #238, #237, #236, #235, #234, #233, #231, #230, #229, #228, #227, #226, #225, #223 (19 heads). I fetched all of them and searched every `+` line of `git diff origin/main...origin/<head> -- wiki/` for `pyc|pycache|bytecode|PYTHONPYCACHEPREFIX|mtime|TMUX|display-message|#S|session name`.

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| c9bfb85cd7820c7e pyc mutant collision | none. No head touches `bytecode-cache-staleness.md`. #244 edits `wiki/backend/python/index.md` but a different row (circular-imports); none of the 19 heads' diffs add or remove a line naming `bytecode-cache-staleness` | new (merged into existing page) |
| 10454e0809cda9c3 tmux identity in a Stop gate | none. #234 adds `platforms/processes/driving-a-tui-in-a-tmux-pane` (send-keys delivery confirmation, a different trigger). No head touches `session-completion-gates.md`. #223/#225/#239/#241 edit `wiki/infrastructure/index.md` but not the `session-completion-gates` row | new (merged into existing page) |

`log.md` and `.dev-loop/INGEST_REPORT.md` conflict with every open head, as usual for these flushes.

## Routing decision

| Insight | Target | Action |
|---------|--------|--------|
| pyc mutant collision / `PYTHONPYCACHEPREFIX` | backend/python/language → `wiki/backend/python/language/bytecode-cache-staleness.md` | amend: step 2 + edge row + sources |
| tmux session-name identity in a completion gate | infrastructure/agent-orchestration → `wiki/infrastructure/agent-orchestration/session-completion-gates.md` | amend: 2 edge rows + Instead-of row + sources |

No new category. Both insights fit an existing page whose trigger already owns the situation. The tmux lesson was also tested against `platforms/processes`, but its trigger is "a gate deciding which session is the worker", which `session-completion-gates` owns.

## Local-layer candidates

All 17 rows come from linkly (`/Users/choeyeong-gi/Desktop/workspace/linkly-seaslug`). They are wiki-plan Phase B "no owning wiki page" decisions for tasks t194 and t188, and each names linkly's own files, RFCs, or test layout. Run wiki-ingest inside that project if any are worth keeping.

| Row | Decision | Target |
|-----|----------|--------|
| dbc435945b66cdc4 | t194 gateway port allocation for the new test | wiki-local/testing/data/gateway-test-port-allocation.md |
| 4d8c8a66275a32b6 | t194 .orchestration/changelog/t194.md | wiki-local/infrastructure/agent-orchestration/task-changelog-entries.md |
| d3ec9f1ff0551f33 | t194 final verification order (check_doc_snippets, suite, dev_doctor) | wiki-local/qa/process/final-verification-order.md |
| f596944b2430ea3f | t188 clause keyword and position | wiki-local/backend/common/language-design/cached-clause-syntax.md |
| fc9097e4cd761b9f | t188 hit and miss mechanics in mode A | wiki-local/backend/common/caching/cached-clause-mode-a.md |
| c0fb97a87b805464 | t188 a workflow that writes what it reads with cached | wiki-local/backend/common/caching/cached-read-write-workflow.md |
| 0c882f9626778c78 | t188 trace and metrics | wiki-local/backend/common/observability/cached-clause-trace.md |
| f611967725ff1bae | t188 spec observation | wiki-local/testing/strategy/spec-observation-of-cache.md |
| c47f84db67956bd8 | t188 IR schema and validate_ir | wiki-local/backend/common/language-design/ir-schema-validate-ir.md |
| df5ebd6825225b41 | t188 ENFORCEMENT-MATRIX.md | wiki-local/qa/document-verification/enforcement-matrix.md |
| 7a2c28929298bb40 | t188 RFC-0062 scope and Updates | wiki-local/qa/document-verification/rfc-updates-chain.md |
| 625fd9411f9ca01e | t188 mutation anchors | wiki-local/testing/quality/mutation-anchors.md |
| 120e5d1addd2df5d | t188 idempotency and vocabulary exports | wiki-local/backend/common/language-design/vocabulary-exports.md |
| 295657db0e29ce85 | t188 interaction with main's new features | wiki-local/backend/common/change-impact/cached-clause-feature-interaction.md |
| cbf1c446a26683a0 | t188 where the tests live | wiki-local/testing/strategy/test-placement.md |
| b1d8effce181f9d8 | t188 changelog, blackboard, follow-up | wiki-local/infrastructure/agent-orchestration/task-closeout-artifacts.md |
| fe85641fd860dd7f | t188 docs/backends.md | wiki-local/qa/document-verification/backends-doc.md |

Separately, for the owner: `hooks/loop-gate.sh:86-95` is the real-world instance of insight 2. A headless child started under a worker's pane gets blocked as that worker. This PR records only the general lesson; the hook fix belongs in its own issue.
