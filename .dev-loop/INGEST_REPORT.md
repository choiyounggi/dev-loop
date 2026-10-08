# Knowledge flush — 5 insight(s)

Shell-lock owner PIDs written by a helper's own `$$`, preserving an interrupted run's leftovers before an automated `reset --hard`, multiline form values arriving as CRLF, anchor-killing cases for allowlist regexes, and zod 4 refinements running after a failed check. **5 new pages, 5 back-links. 0 dropped, 3 plan-gaps retired as local-layer.**

Run: auto-flush child, run id `20261008-114912-66559`; 8 rows claimed (5 insights + 3 plan-gaps).

## Verified best-practice

### 1. Owner PID in a shell lock written by a helper script → `verified`
Claim: a lock helper that records its own `$$` records a PID that is dead as soon as the helper exits, so "past TTL and holder dead → reclaim" degrades to TTL-only; record the long-lived holder's PID (passed in), refresh from it, and store PID + start time.
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html — 2.5.2: `$` is "the decimal process ID of the invoked shell".
- https://man7.org/linux/man-pages/man2/kill.2.html — signal 0 performs "existence and permission checks" (EPERM edge row).
- https://man7.org/linux/man-pages/man2/flock.2.html — lock tied to the open file description.
- Source read: dev-loop `scripts/flush-lock.sh:64` writes `$$` in `_write_owner`; line 96 keeps the lock while `age <= TTL || _pid_alive`.
- Local repro (macOS `/bin/sh`): helper-written `$$` → `kill -0` dead right after acquire while the caller ran; caller PID passed in → alive.

### 2. Resetting a reused checkout after an interrupted run → `verified`
Claim: before an automated job's `checkout main && reset --hard origin/main`, inspect `status --porcelain` and unpushed commits, preserve leftovers (WIP branch/commit, or `add -A` + cached patch checked with `apply --check -R`), then reset.
- https://git-scm.com/docs/git-reset — `--hard` overwrites tracked files, "may overwrite untracked files".
- https://git-scm.com/docs/git-apply — `--check`, `-R`.
- https://git-scm.com/docs/git-status — porcelain format, `--ignored`.
- Local repro: `git diff` patch carried only the tracked edit (untracked file omitted); after `reset --hard` the tracked edit was gone, the untracked file stayed.
- Field case: this skill's own step 1 met 19 uncommitted files from a run stopped by the usage limit (shipped later in #259).
- Reviewer fixes applied: unpushed commits on the branch being reset (or a detached HEAD) need a `wip/` branch first; `git clean -x` deletes ignored files that neither preservation path carries.

### 3. Multiline form values arrive with CRLF → `verified`
Claim: multipart/form-data (FormData bodies, server actions) and `<form>` urlencoded submission rewrite lone LF/CR to CRLF in names and string values; normalize before control-char/length checks and test through a FormData round trip.
- https://html.spec.whatwg.org/multipage/form-control-infrastructure.html — 4.10.22.8 Multipart form data steps 1.1/1.2 (names; values that are not File objects), file-name escaping `%0A`/`%0D`/`%22`; 4.10.22.6 Converting an entry list to a list of name-value pairs (same rewrite).
- Local repro (Node v26.7.0): `FormData` `'line1\nline2'` → `"line1\r\nline2"`, `'x\ry'` → `"x\r\ny"`; `URLSearchParams` body unchanged.

### 4. Anchor cases for an allowlist regex → `verified`
Claim: malformed-value reject cases cannot detect a missing `^`/`$`; add a valid-value-with-prefix case per `^` and suffix case per `$`, prove each by deleting the anchor.
- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ — regex mutator maps `^abc` → `abc`, `abc$` → `abc`.
- https://docs.python.org/3/library/re.html — `$` also matches "just before the newline at the end of the string"; `re.fullmatch`.
- Local repro (Node v26.7.0, Python 3.14.6): wrong-ext/short/empty rejected with and without `^`; `../`+valid and `/etc/`+valid rejected only with `^`; Python `re.search` matched `valid+'\n'`; JS `/m` accepted an embedded valid line.
- Reviewer fix applied: under `re.fullmatch` the delete-anchor check is equivalent, so the page gives the alternative check there.

### 5. zod 4 runs later checks after a failed check → `verified`
Claim: in zod 4 a failed continuable check (`.regex`, `.min`) does not stop later refinements, and a refine that throws escapes `safeParse`; fold the test into the refine, pass `{ abort: true }`, or make the refine total.
- https://zod.dev/api — "Zod will execute all checks in sequence, even if one of them causes a validation error"; `abort`; `when` default.
- Local repro (zod 4.6.5): chained `.regex().refine(BigInt…)` threw `SyntaxError` from `safeParse('abc')`; `{ abort: true }` → `invalid_format`; single refine → `custom`; refine call counts 1/1/0 after failed regex/min/type.

## Existing-layer check

`wiki_search` (k=5) per candidate — top hits considered: inherited-lock-ownership-in-a-spawned-session, process-identity-by-path-and-hash (#1); control-signals-vs-primary-artifacts, worktree-isolated-workers, tests-that-cannot-fail, shared-run-state, unattended-worker-questions (#2); error-responses, write-path-assertions, exposing-an-origin-http-api, object-key-persistence, validation-timing (#3); escapes-in-shell-string-literals, xss-safe-rendering, exposing-an-origin-http-api (#4); checks-that-cannot-pass, event-loop-blocking (#5). None shares a trigger with a candidate, so all 5 are new pages (no merge).

Pages read: infrastructure-agent-orchestration-inherited-lock-ownership-in-a-spawned-session, backend-common-jobs-scheduled-job-overlap, backend-common-concurrency-distributed-locks, backend-node-boundaries-runtime-validation, testing-quality-harness-reverse-controls, infrastructure-agent-orchestration-shared-run-state, security-input-validation-at-trust-boundaries, testing-quality-checks-that-cannot-pass, testing-quality-tests-that-cannot-fail, platforms-filesystems-paths-case-and-line-endings, infrastructure-agent-orchestration-usage-limit-paused-workers

Overlap notes:
- distributed-locks owns TTL watchdog refresh for Redis-style locks; the new lock page links to it for step 3 instead of restating it.
- inherited-lock-ownership owns run-id inheritance; the new page covers the PID field of the same owner record.
- runtime-validation owns "validate at the boundary with zod"; the new zod page covers check-chain semantics only.
- No conflicts flagged.

Back-links added (`related:`): inherited-lock-ownership-in-a-spawned-session, distributed-locks, scheduled-job-overlap → lock page; shared-run-state → reset page; harness-reverse-controls → anchor page.

Deferred back-links (pages an open PR rewrites the `related:` line of): runtime-validation → zod page (#233 edits that line); validation-at-trust-boundaries → CRLF/anchor pages (#228); paths-case-and-line-endings → CRLF page (#228); tests-that-cannot-fail → anchor page (#223/#258). The lock page's link to `platforms-processes-signalling-a-remembered-pid` is deferred because that page exists only on #259.

## Open-PR check

Open `knowledge/*` heads diffed (`git diff origin/main...origin/<head> -- wiki/`): #223, #225–#231, #233–#239, #241, #244, #249, #253–#259 (25 heads).

| Candidate | Overlapping open PR | Verdict |
|---|---|---|
| 1 lock owner PID | #259 `platforms/processes/signalling-a-remembered-pid` is adjacent (verify a remembered PID before signalling) but covers a different trigger | new |
| 2 reset reused checkout | none | new |
| 3 FormData CRLF | none (#233 NestJS multer errors, #241 headless upload — different triggers) | new |
| 4 regex anchors | none | new |
| 5 zod 4 continuable checks | #259 `schema-rejection-key-coverage` (per-key rejection tests) and #257 `structured-output-schema-from-zod` — different triggers | new |

Merge check (`git merge-tree --write-tree` against every head): the only conflicts this branch adds are the shared `log.md` append and `.dev-loop/INGEST_REPORT.md`, which every flush branch already conflicts on. A `wiki/backend/node/index.md` conflict with #233 was removed by placing the zod row above the `runtime-validation` row.

## Routing decision

| Insight | Target |
|---|---|
| 1 | platforms/processes/lock-owner-pid-from-the-holding-process.md (new) — process/PID mechanics, next to background-services |
| 2 | infrastructure/agent-orchestration/resetting-a-reused-checkout-after-an-interrupted-run.md (new) — automated agent jobs reusing a checkout |
| 3 | backend/common/api-design/multiline-form-values-arrive-with-crlf.md (new) — HTML-spec behavior, not Node-specific, so `common` |
| 4 | testing/quality/anchor-cases-for-allowlist-regexes.md (new) |
| 5 | backend/node/boundaries/zod-4-checks-continue-after-a-failure.md (new) — next to runtime-validation |

No new categories. Index rows added in `wiki/platforms/index.md`, `wiki/infrastructure/index.md`, `wiki/backend/index.md`, `wiki/backend/node/index.md`, `wiki/testing/index.md`; 5 `log.md` ingest entries. Lint: `wiki-structure-checks.js wiki --layer bundled` → 0 findings; `wiki-lint-prohibitions.js` → no violations in the new pages (8 pre-existing elsewhere). Adversarial review (feature-dev:code-reviewer): 3 findings (2 HIGH, 1 LOW), all fixed before commit.

## Local-layer candidates

| Row | Project | Target |
|---|---|---|
| Planning t213: deciding Exact rejection message | linkly (linkly-dartfish worktree) | wiki-local/backend/common/t213-rejection-message.md — run wiki-ingest inside that project |
| Planning t214: deciding Byte-identity for inputs with no Password-family key | linkly (linkly-dartfish worktree) | wiki-local/backend/common/t214-password-family-byte-identity.md — run wiki-ingest inside that project |
| Planning t214: deciding Which entities decide Password-family | linkly (linkly-dartfish worktree) | wiki-local/backend/common/t214-password-family-entities.md — run wiki-ingest inside that project |

All three are wiki-plan Phase B decisions naming one repository's own tasks; excluded from this PR and retired.
