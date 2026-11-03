# Knowledge flush — 3 insight(s)

This headless run claimed 7 queue rows. 3 were ingested, 2 were released because an open PR plausibly overlaps them, and 2 were released unread: this run could not list the queue directory to find their session files.

## Verified best-practice

1. **Re-runnable multi-artifact release job** (row `bd858de0ec8c6e55`). Claim: give each artifact (tag, GitHub Release, npm version, version-bump commit) its own "already exists?" check. On a re-run, start commit steps from the remote default branch.
   - Sources:
     - https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs. A re-run uses the same `GITHUB_SHA`/`GITHUB_REF` as the original event.
     - https://docs.npmjs.com/cli/v6/commands/npm-publish/. A name and version already in the registry cannot be published again.
     - PRs and issues showing the per-artifact guards and their pitfalls: open-stl/openstellar-tool-search#20, tangentyh/pi-collections#30, rnw-community/mobile-ci#140.
   - Session evidence: the check block was run under `bash -e` against the released `v0.4.1` (every check said "exists") and the missing `v9.9.9` (every check said "missing").
   - Confidence: **verified**.
2. **Status endpoint returns the server's decision** (row `a9ff749662182795`). Claim: a client that shows a router's or gateway's decision should display a decision field the server builds with its own decision function, and should use `generatedAt` as its clock.
   - Source: https://phauer.com/2015/restful-api-design-best-practices/ ("Keep Business Logic on the Server-Side"; duplicated client logic couples client and server).
   - Session evidence: a counterexample showed `limitPct: 90` and a full per-model window displayed as `ok`. A pool test that compares `available` with `ranked()` went red when `available` was replaced by a constant.
   - Confidence: **field-tested**. The source is a reputable reference, not official documentation.
3. **REA process capture under `env -i`** (row `cbb9ecffb814606a`). Claim: pass `REA_PROCESS_RUN_ID` through, or clear only selected variables with `env -u`. Otherwise REA cannot prove it owns the processes, ends with `cleanup_incomplete`, and leaves them running.
   - Source: https://github.com/morluto/rea/blob/HEAD/docs/process-capture.md. `REA_PROCESS_RUN_ID` is the reserved run token. There is no bare-PID kill fallback, so processes REA cannot verify are left alone and reported via `cleanup_incomplete`.
   - Related upstream items: morluto/rea#1856, #4282, #4322.
   - Session evidence: the result listed 4 PIDs with "ownership token mismatch", and the target was still alive 50 minutes later.
   - Confidence: **verified**.

## Existing-layer check

Pages read: infrastructure-agent-orchestration-reference-study-in-a-plan, infrastructure-ci-cd-chaining-workflows-past-a-github-token-event, backend-common-jobs-idempotent-handlers, backend-common-api-design-api-versioning-and-breaking-changes

- **wiki_search top hits considered:**
  - Release candidate: `infrastructure-ci-cd-chaining-workflows-past-a-github-token-event`, `platforms-tools-version-keyed-artifact-cache`, `infrastructure-agent-orchestration-shared-run-state`, `platforms-toolchains-version-management`. None covers re-running a partly failed release, so this is a **new page**. It links both ways with the chaining page, which covers the "publish workflow never starts" case.
  - Status-endpoint candidate: `testing-quality-checks-that-cannot-pass`, `frontend-state-concurrent-optimistic-updates`, `qa-exploratory-behavioral-spec-from-a-reference-product`. None covers it, so this is a **new page** in backend/common/api-design. It is related to api-versioning (backlink added) and to optimistic-updates (the server object is the truth).
  - REA candidate: no direct hit. `reference-study-in-a-plan` already owns how the REA MCP is used, so the candidate was **merged** there as an Edge-cases row, and the index load-when line was extended.
- Conflicts flagged: none.

## Open-PR check

There are 18 open `knowledge/*` PRs: #328, #324, #319, #318, #317, #315, #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. This headless run cannot diff them, so overlap was judged from each PR's title and touched-file list (`gh pr list --json number,title,files`).

| Candidate | Overlapping PRs | Verdict |
|-----------|-----------------|---------|
| `bd858de0ec8c6e55` re-runnable release | No PR touches `infrastructure/ci-cd`. #301's `idempotency.md` is about API idempotency keys, a different trigger | **new** |
| `a9ff749662182795` server decision in status response | No PR touches a status-endpoint or decision-display page | **new** |
| `cbb9ecffb814606a` REA `env -i` | No PR touches REA or process capture. #328 covers environment inheritance for a child `claude`, a different trigger | **new** |
| `b5863e2d758c98fb` gateway base URL + leftover claude.ai login sends bootstrap calls to api.anthropic.com | #328 (gateway proxy env in `spawning-an-agent-cli-from-a-server`), #298 (gateway alias resolution) | **pending duplicate → claim released** |
| `126503dbe78559da` claude-code-action `--allowedTools` does not restrict `Agent`; use `--disallowedTools` | #300 (`deny-rules-under-bypassed-permissions`), #328 (subagent pages) | **pending duplicate → claim released** |

## Routing decision

- `bd858de0ec8c6e55` → `wiki/infrastructure/ci-cd/rerunnable-multi-artifact-release.md` (new page, existing category).
- `a9ff749662182795` → `wiki/backend/common/api-design/server-decisions-in-status-responses.md` (new page, existing category).
- `cbb9ecffb814606a` → Edge-cases row in `wiki/infrastructure/agent-orchestration/reference-study-in-a-plan.md`. REA is a public tool (morluto/rea), so the candidate is general, not local-layer.
- The infrastructure and backend `index.md` files and `log.md` are updated.
- `fc76dc4dfa08ecde` and `df1515d721c90d64` were released unread. This run could not list `~/.dev-loop/queue` to find their session files, so a later flush will pick them up.

## Local-layer candidates

none
