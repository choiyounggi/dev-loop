# Knowledge flush — 7 insight(s) claimed: 1 ingested, 6 dropped

Run id (inherited from `hooks/auto-flush.sh`): `20260917-224552-43083`. Claimed ids:
`dbedb1f0f153ea80`, `a0f287cdc70eac92`, `4b3490c5bb95a48a`, `62e2909c3f9f7f5e`,
`e5b99a9fc624776f`, `bf8a6eee857f7808`, `5306e2de6142b95e`.

## Verified best-practice

### 1. `dbedb1f0f153ea80` — inherited lock owner id in a spawned session → **ingested, `confidence: verified`**

**Claim.** When a session is spawned by a hook/parent that already holds a
run-id-keyed single-flight lock, acquire under the id exported in the
environment rather than a freshly generated one; when an acquire reports `held`
seconds after session start, compare the holder id with the inherited env before
concluding a foreign run is live.

**Sources checked (fetched 2026-09-18):**
- https://man7.org/linux/man-pages/man2/flock.2.html — "Locks created by flock() are associated with an open file description … duplicate file descriptors (created by, for example, fork(2) or dup(2)) refer to the same lock"; "If a process uses open(2) … to obtain more than one file descriptor for the same file, these file descriptors are treated independently by flock(). An attempt to lock the file using one of these file descriptors may be denied by a lock that the calling process has already placed via another file descriptor." — the OS-level form of the same failure (a re-opened path is a stranger to its own lock).
- https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/locks/ReentrantLock.html — "A ReentrantLock is owned by the thread last successfully locking, but not yet unlocking it"; `lock()` "will return immediately if the current thread already owns the lock" — re-entrancy is defined by *identity equality with the recorded owner*.
- https://www.gnu.org/software/make/manual/html_node/Job-Slots.html — the parent make provides jobserver access "through the environment to its children, in the MAKEFLAGS environment variable" via `--jobserver-auth=`; "Only the last instance is relevant" — a documented case of a parent handing a coordination token to children through the environment.

**Reproduction (this session, 2026-09-17 22:46 KST):** `flush-lock.sh acquire`
under a freshly generated `RUNID=flush-20260917-224603-43624` →
`held 20260917-224552-43083 11s`, exit 3. `env | grep DEV_LOOP` showed
`DEV_LOOP_FLUSH_RUN_ID=20260917-224552-43083` exported by `auto-flush.sh`
(lines 77–79: acquire, `export DEV_LOOP_FLUSH_RUN_ID`, spawn). Re-running
acquire under the inherited id → `already-owned 20260917-224552-43083`, exit 0.
`flush-lock.sh` lines 76–86 implement the re-entrant branch by comparing the
owner-file id to `$DEV_LOOP_FLUSH_RUN_ID`. Matches the candidate's own evidence
from the 17:16 run (`held 20260917-171642-20541 19s` → `already-owned`).

Both the official semantics (ownership = identity match; inheritance via env /
open file description) and a two-way local reproduction (known-bad: fresh id →
held; known-good: inherited id → already-owned) confirm the directive → `verified`.

### 2–7. Plan-gap rows from `dev-loop-cockle` → **dropped (project-specific)**

| id | Decision | Why it is not reusable knowledge |
|----|----------|----------------------------------|
| `a0f287cdc70eac92` (t7-usage README tree line + log.md entry) | drop | Names one repo's README line and log grammar; no directive applies outside `dev-loop` |
| `4b3490c5bb95a48a` (t9 fail-open sentence identical in three skills) | drop | The directive is one repo's skill wording; the cited sources (near-dup thresholds, MCP token cost) do not support the wording decision |
| `62e2909c3f9f7f5e` (t9 wiki-ingest dedupe via `wiki_search`) | drop | A step-ordering edit to one skill in one repo; the sources cited are about cosine thresholds, unrelated to the decision |
| `e5b99a9fc624776f` (t9 `neardup` subparser spec) | drop | A CLI design that has not shipped — `git ls-tree origin/main` finds no `scripts/wiki-index.py`, and the cockle worktree's `scripts/` has none either; the generic kernel (dot product on L2-normalised vectors = cosine) is textbook, and the threshold sources say "calibrate", which yields no page-grade directive |
| `bf8a6eee857f7808` (t9 README subsection) | drop | Documentation layout for one repo |
| `5306e2de6142b95e` (t9 combined log.md line) | drop | One repo's log convention ("one entry per task") |

## Existing-layer check

Pages read: backend-common-concurrency-distributed-locks, infrastructure-agent-orchestration-shared-run-state, backend-common-jobs-scheduled-job-overlap, testing-data-test-data-and-isolation, databases-selection-vector-search-engine-selection

Also read: `INDEX.md`, `wiki/infrastructure/index.md` (agent-orchestration section, rows 15–26), `AGENTS.md` lines 90–116, `templates/page.md`.

Search evidence (whole `wiki/`, untruncated): `grep -rniE 're-?entran|inherited (run|owner|id|env)|RUN_ID|owner id|holder id|already-owned|lock owner|lockfile|lock file|flock'` → 46 lines, all in: dependency lockfiles (supply-chain, image-builds, uv), `flock -n` for cron overlap (scheduled-job-overlap, background-services), `ReentrantLock` vs `synchronized` (java threads-and-memory), and the `LO_RUN_ID` env-leak test incident (test-data-and-isolation). None covers a spawned session inheriting a lock owner id. `grep -rliE 'cosine|embedding|near-?dup'` → 5 files, all datastore selection — no near-dup page (moot after the drop).

- **Overlap / merge candidates:** `distributed-locks` (owner token, atomic release-if-mine) is the parent concept and is linked, not merged into — its trigger is multi-instance services, not a spawned child session; adding a re-entrancy section there would violate one-case-per-page. `shared-run-state` covers "a repo that may already have a run" (foreign-run detection) — the new page is the complement: the holder that is *not* foreign. `scheduled-job-overlap` documents `flock -n` — the new page's flock edge case links back. `test-data-and-isolation` holds the `LO_RUN_ID` env-inheritance incident — same mechanism, opposite direction (env leaking into tests vs. env intentionally carrying the owner id).
- **Conflicts:** none — no existing directive tells a spawned session to mint its own id.
- **Created new:** `wiki/infrastructure/agent-orchestration/inherited-lock-ownership-in-a-spawned-session.md` (69 body lines).
- **Related links added both ways:** distributed-locks, scheduled-job-overlap, shared-run-state, test-data-and-isolation → new page; new page → all four.
- **Lint:** `node scripts/wiki-lint-prohibitions.js` → `directives: 75, compliant: 75, violations: 0` (the 1 info item is pre-existing in keys-ahead-of-their-consumer). Vague-qualifier grep on the new page → none. All 4 `related:` ids resolve to exactly one `id:` line each.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` → 17 open heads: #210 (…-171731), #209 (…-160110), #208 (…-150057), #207 (…-135945), #205 (…-100145), #191, #190, #189, #188, #187, #186, #185, #183, #182, #181, #180, #179.

Every head fetched; `git diff origin/main origin/<head> -- wiki/` grepped for added lines matching `re-?entran|inherited (run|owner|id|env)|RUN_ID|owner id|holder id|already-owned|foreign holder|near-?dup|cosine|embedding`: 16 heads → 0 hits; #209 → 3 hits, all "embedding store" in `input-manifest-freshness-with-skipped-inputs` (derived-index freshness — unrelated). Page names across all heads matching `lock|env|inherit|spawn|parent|child|dedup|similar|vector|hook` were also inspected: #189's `testing-quality-proving-a-critical-section-is-lock-protected` (testing a mutex-guarded increment — unrelated) and #208's `environment-config.md` change (a `related:` link only).

| Candidate | Overlapping open head | Verdict |
|-----------|-----------------------|---------|
| `dbedb1f0f153ea80` inherited lock owner id | none | **new** — ingested here |
| `a0f287…`, `4b3490…`, `62e290…`, `e5b99a…`, `bf8a6e…`, `5306e2…` | none | **drop** (project-specific, see above; not pending-duplicates) |

## Routing decision

| Insight | Domain / category / page | Why here |
|---------|--------------------------|----------|
| `dbedb1f0f153ea80` | `infrastructure/agent-orchestration/inherited-lock-ownership-in-a-spawned-session` (new page) | The trigger is a spawned agent/hook session coordinating with its parent through a single-flight lock — the `agent-orchestration` category already holds the sibling cases (`shared-run-state`, `session-completion-gates`, `worktree-isolated-workers`). `backend/common/concurrency` was rejected because its pages are about service instances contending for a resource, not a parent/child pair sharing one identity. No new category needed. `INDEX.md` infrastructure route line and `wiki/infrastructure/index.md` updated; `log.md` entry appended. |
| 6 plan-gap rows | — (dropped) | No layer: not reusable outside `dev-loop-cockle` |
