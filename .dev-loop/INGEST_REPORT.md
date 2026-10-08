# Knowledge flush — 9 insight(s)

Headless auto-flush run `20261008-063235-83293`. It finishes run `20261008-045232-51216`, which researched and ingested six rows and then hit the account session limit ("You've hit your session limit · resets 6:30am") before its reviews, commit and PR. That run's uncommitted work was kept (local WIP commit; its `git diff` saved and checked with a reverse-apply) and reviewed here, not redone. This run claimed all nine queued rows: the six above (claims had passed their TTL) and three new ones.

Result: 10 new pages, 1 merge, 2 existing pages amended with one edge row each, related back-links on 10 existing pages, 0 dropped. Two rows are project-specific plan gaps: their general parts became 4 of the new pages, and their project parts are listed under Local-layer candidates.

Four fresh-context review passes ran, two adversarial and two general, one of each per page set. Every finding was checked against a primary source or a reproduction before it was fixed. The fixes made after the last pass were verified the same way and were not reviewed a fifth time.

| Queue row | Outcome |
|-----------|---------|
| `1124f25ced48e661` | new page testing-mocking-call-counts-under-render-retries |
| `9d71d422e3a2e30d` | new page platforms-toolchains-agent-files-written-by-next-dev (directive corrected, 16.3 vs 16.4 split) |
| `858a5651dc998329` | new page frontend-accessibility-contrast-of-interactive-states |
| `3582e1637a1ff6e8` | new page platforms-processes-signalling-a-remembered-pid |
| `58382508a3d239a8` | new page testing-quality-json-manifest-edit-gates (directive strengthened) |
| `fb34dcab3ed3a729` | merged into qa-process-scope-purity-checks |
| `14e92454416b9ceb` | new page testing-quality-schema-rejection-key-coverage (directive corrected) |
| `0a7dbb3835a8161a` | plan gap: general part → backend-common-orm-prisma-7-config-env-and-generated-client, backend-node-runtime-env-files-with-process-loadenvfile; project part → local layer |
| `67547272867dc570` | plan gap: general part → infrastructure-containers-postgres-18-image-data-volume, infrastructure-containers-published-ports-bind-all-interfaces; project part → local layer |

## Verified best-practice

### 1-6. Rows from run `20261008-045232-51216`

That run's per-row research (sources opened, reproductions, corrections) is unchanged and summarised here; see the page Sources sections for every quote.

1. **Render retries (`1124f`) → verified.** React v19.3.0 source (`recoverFromConcurrentError` → `renderRootSync`; `ReactAct.js` rethrow), testing-library/react-testing-library#1291, isolated reproduction (React 19.3.0, RTL 16.3.3, Vitest 5.0.3): sequential `render()` calls ran the guard `[3,2,2,2,2]` times, a direct call once.
2. **`next dev` agent files (`9d71`) → verified, corrected.** Next.js `agentRules` and AI-agents docs, vercel/next.js#92910 and #99043, installed 16.3.8 source. Corrected: the write needs a detected agent and a missing or stale block, and deleting a hand-written file loses content.
3. **Contrast of interactive states (`858a`) → verified.** CDP `CSS.forcePseudoState`, Playwright CDP docs, WCAG 2.2 1.4.3 / 1.4.11, CSS UI 4; reproduction on Playwright 1.59.1 + Chromium 147: painted (143,90,99) vs canvas (143,90,98) for `brightness(0.95)`, forced states, transitions, ring diff.
4. **Remembered PID (`3582`) → verified.** pidfd_send_signal(2) NOTES, XNU `PID_MAX 99999`, lsof(8), Claude Code resume docs, macOS pgrep(1)/ps(1).
5. **JSON manifest edit gates (`5838`) → verified, strengthened.** RFC 8259 §4, git-diff, jq manual; reproduction (git 2.50.1, jq 1.7.1): append-last 3 lines vs insert-first 1, a known-bad edit with the same 3, the parsed gate exit 0 vs 1.
6. **Tool state vs scope gate (`fb34`) → verified, merged.** gitignore and rev-parse docs, loop-implement SKILL.md; reproduction with a repo plus a linked worktree.

### Review of rows 1-6 in this run, and what changed

Two fresh-context reviewers (one adversarial, one general) failed the six pages on 5 + 3 medium findings and 14 low ones. Each finding was checked before it was fixed:

- **`next dev` page, rewritten.** npm `latest` is 16.4.0 (registry dist-tags). Its `generate-agent-files.js` never names `CLAUDE.md`, writes only `AGENTS.md`, and checks currency only there. `syncAgentRulesForDev` calls `removeAgentRulesFiles` when `agentRules` is false, before agent detection, inside `if (isDev)`. The docs say the removal runs "even when no agent is detected". The block heading changed from `#` (16.3.8) to `##` (16.4.0), so a committed block is rewritten after an upgrade. The page now splits 16.3.x and 16.4.0+, snapshots `git status` before the run, and deletes only files whose content is exactly the generated text.
- **Contrast page.** Reproduced on Chromium 147: `CSS.forcePseudoState(['hover'])` on a child left `.g:hover .c` and `li:hover > a` unmatched, while forcing the ancestor or a real `page.hover()` matched (Selectors 4: an element "also matches :hover if one of its descendants … matches"). The page now forces ancestor states and requires a forced sample to differ from the unforced one. The UA-ring exception of SC 1.4.11 was added. The unsupported "4.46 → 4.42" causal claim was removed: a one-unit blue change moves the ratio by about 0.005, computed.
- **PID page.** Next 16.3.8/16.4.0 `start-server.js` sets `process.title = next-server (v…)` unconditionally, so a command check cannot tell two sessions' dev servers apart. Identity is now launch-time `lstart` + command + working directory (`lsof -a -p <pid> -d cwd -Fn`, run on macOS). The field case is marked as not proving which process was hit.
- **JSON gate page.** Reproduced from `apps/web` in a monorepo layout: bare `HEAD:package.json` read the root manifest. The gate now uses `HEAD:./package.json`, `// {}` (the old form exited 5 "null (null) has no keys" on a first dependency), and asserts the value. JSONC through `--argjson` exits 2 "invalid JSON text passed to --argjson".
- **Scope-purity merge.** `git check-ignore -q --no-index` exited 0 for a committed ledger that `--porcelain` still listed; without `--no-index` it exited 1 (git 2.50.1). The flag was dropped and git-check-ignore cited.
- **Render-retries page.** The unsourced "`act()` runs a further pass" clause was replaced by "the cause of the extra pass on the first render was not isolated". The rethrow citation moved to `ReactAct.js` lines 187 and 228-232. The snippet was made valid JS.
- Smaller fixes: the regeneration edge row wording plus RFC 8259 in its Sources; index rows for agent files, PID, contrast and regeneration; a vague "rarely"; an unclosed `<span>`; a macOS edge row with no action.

### 7. Rejection tests for every key of a multi-field schema (`14e92454416b9ceb`) → verified, corrected

Claim: loop every key of a multi-key zod schema through six bad-input kinds and assert through the `parseX`/`isX` entry points callers use.

- https://zod.dev/api and https://zod.dev/basics (curl + grep): `.catch()` "Use .catch() to define a fallback value to be returned in the event of a validation error"; `.optional()` / `.nullable()` "to allow undefined / null inputs"; `.default()` "the default value is eagerly returned"; `z.enum`; strict objects "throws an error when unknown keys are found" vs default stripping; `z.coerce.string(); // String(input)`; `.parse()` throws a `ZodError` whose issues carry `path`; `Dog.shape.name`.
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ and https://pitest.org/quickstart/basic_concepts/: survived = all tests passed with the mutant active.
- Reproduction (Node 26.7.0, zod 4.6.5, `node --test`; built by a research agent and re-run independently here): a one-key schema-level test passed under 5 mutants (`.catch`, `.optional`, `z.string()` on another key, an inverted `isRecord`, a passthrough `parseRecord`), and the every-key loop through the wrappers failed under all 5. A per-kind probe of 12 mutants found that five kinds are each the only detector of some mutant: case/whitespace → trim/lowercase preprocess; `null` → `.nullable()`; sibling value → merged enum; deletion → `.optional()`/`.default()`. `.catch` was exposed only on its own key. The unmutated schema was exposed by no input.
- Field evidence, read in the source session's audit transcript: "`.default` replaced by `.catch` on 9 of 13 fields" survived the sampled tests, and after the fix "each [of 7 re-applied mutants] now fails".
- Corrected from the candidate: "a different type" must be the valid value in another type (`['owner-1']`, `'5'`). `42` into a regex-checked string is rejected with or without `z.coerce`, and the coercion mutant survived every original kind. Added: an extra key is the only input that exposes `z.strictObject` relaxed to `z.object`.

### 8. Prisma config and generated client — plan gap (`0a7dbb3835a8161a`) → general part verified

- https://github.com/prisma/orm/releases/tag/7.0.0 (gh api): "we're no longer automatically loading environment variables when invoking the Prisma CLI"; the post-install and post-`migrate` generate "has been removed"; the `prisma` block in `package.json` "has been removed".
- https://www.prisma.io/docs/guides/upgrade-prisma-orm/v7, config reference, generators, CLI reference, generating-prisma-client (each downloaded and grepped): env not loaded by default; `output` required; `prisma-client-js` deprecated; "Every Prisma CLI command loads the prisma.config.ts file"; `env()` throws; `process.env.DATABASE_URL ?? ''` as the documented fallback (needed only before 7.2.0, see the review notes below); config detection (`pnpm prisma` from subdirectories, `npx`/`bunx` only from the root); `/generated/prisma` in the `prisma init` `.gitignore`.
- Source: `packages/config/src/loadConfigFromFile.ts` at 7.10.0 lines 229-230 `dotenv: false`; `env.ts` `if (!value) throw new PrismaConfigEnvError(name)`.
- pnpm v10.0.0 release notes and a run on pnpm 10.30.2: `--frozen-lockfile` ran the root package's `postinstall`, while `--lockfile-only` did not.
- Two v7 docs pages still claim auto-loading (quoted on the page as stale).
- Node `process.loadEnvFile`: v24/v22/v20 docs (history, stability, `NODE_OPTIONS`), the CLI `--env-file` docs (later file wins; `NODE_OPTIONS` applied), `util.parseEnv`, `node_dotenv.cc` lines 74-75 and 228 at a pinned commit, the test file's `ENOENT` case. All measured on Node 26.7.0: layering both ways, shell precedence, `delete` / `parseEnv` past it, literal `$`, `NODE_OPTIONS` through each path (heap limit 219 MB vs 4192 MB), relative paths.

### 9. Local PostgreSQL — plan gap (`67547272867dc570`) → general part verified

- docker-library/postgres at the commit that builds `18.6-alpine` (`e00e1bd`): Dockerfile lines 202-205 (`PGDATA /var/lib/postgresql/18/docker`, `VOLUME /var/lib/postgresql`). `docker-entrypoint.sh` lines 244-264 (old data or a mount at `/var/lib/postgresql/data`, default `PGDATA` only) and 140-166 (the "in 18+" error, `exit 1`).
- The Hub docs (docker-library/docs `content.md`), #1259, #37, the PostgreSQL upgrading and pg_upgrade docs, docker/docs#23789.
- https://docs.docker.com/reference/compose-file/services/: "If you do not specify a host IP (such as 127.0.0.1), Docker binds to all interfaces (0.0.0.0), bypassing host firewall rules."; quoted `HOST:CONTAINER`.
- https://docs.docker.com/engine/network/port-publishing/: "insecure by default"; localhost publishing; the pre-28.0.0 L2 caveat. The Compose interpolation docs cover `${VAR:-default}`.
- No container was started; the entrypoint behaviour is read from source.

### Review of rows 7-9

Two fresh-context reviewers checked the five new pages and their plumbing. The general one failed them on 7 medium findings and the adversarial one on 5 medium findings; some overlapped. All were fixed after checking:

- **Prisma.**
  - Prisma 7.2.0 runs `prisma generate` without a URL (7.2.0 announcement). In 7.10.0 `url?: string` is optional, and `validatePrismaConfigWithDatasource.ts` accepts any string, so `?? ''` defeats its "datasource.url property is required" error. The page now uses a bare `process.env.DATABASE_URL` on 7.2.0+ and `?? ''` only before 7.2.0. environment-config gained a linked exception row; rule 5 is unchanged.
  - The env-file load is guarded and anchored to the config file's directory.
  - Rows added for a manifest-first Dockerfile (Prisma's Fly.io guide) and `--ignore-scripts` (npm config docs).
  - Prisma 6.19.2 also skips `.env` once a config file exists (`loadEnvFile.ts`).
  - Claims are bounded to 7.0–7.10 and pnpm 10, because npm `latest` is 8.0.0-rc.21 and pnpm 11 defaults `strictDepBuilds` to true.
- **loadEnvFile.**
  - Rows are scoped to the function, plus a row for repeated flags. Measured on Node 26.7.0: the later file wins, and `NODE_OPTIONS` is applied (heap limit 219 MB vs 4192 MB).
  - A working way past shell precedence (`delete` or `util.parseEnv`, measured).
  - Experimental boundaries per Node line (22.21.0, 24.10.0, and 20.x "Stability: 1.1").
  - Node 20.12's parser also expands `\r` (v20.12.0 `node_dotenv.cc` lines 124-125). Line numbers corrected.
- **zod page.** Measured: one combined `' GOLD '` input exposes only a normalizer that does both trim and lowercase, so the kind now uses two single-change inputs. Rows added for keys that coerce or accept `null` by design. The coercion row is limited to enum or pattern keys, since `z.coerce.string()` accepts `null` as `"null"`.
- **Postgres page.** The old-path detection dates from docker-library/postgres `5ec8931` (2025-10-15) and, for Alpine, `3b6b5fc` (2026-04-21). Older 18 builds start without the error and write to an anonymous volume, so a check row was added (`docker inspect` mounts, `SHOW data_directory`). Rows now say "with the default `PGDATA`", per the Hub's opt-in sentence.
- **Ports page.** The firewall bypass is now scoped to Linux, per the packet-filtering docs. A Docker Desktop row was added ("By default, docker run -p listens on all network interfaces (0.0.0.0)"; host firewalls filter `com.docker.backend`).

Lint, run on this branch after the last fix:

- `node scripts/wiki-structure-checks.js wiki` gave `pages: 369, indexes: 13, findings: 0` (baseline on `origin/main`: 359 pages, 0 findings).
- `node scripts/wiki-lint-prohibitions.js wiki` gave `violations: 0` (baseline 0).
- Both checkers flagged defects injected into a scratch copy of a new page (a bare "Never …" directive, exit 1; a `related:` id that resolves nowhere, exit 3).

## Existing-layer check

Pages read: qa-process-scope-purity-checks, testing-quality-unchanged-function-gates, platforms-toolchains-regeneration-silently-drops-hand-edited-state, testing-quality-checks-that-cannot-pass, frontend-accessibility-interactive-elements, frontend-design-lightness-steps-on-dark-surfaces, frontend-design-anti-slop-visual-design, testing-quality-behavior-not-implementation, testing-mocking-what-to-mock, frontend-state-effects-usage, security-incident-response-process-identity-by-path-and-hash, platforms-processes-background-services, infrastructure-agent-orchestration-autonomous-decision-rulings, infrastructure-agent-orchestration-worktree-isolated-workers, testing-quality-minimum-case-set, testing-quality-unasserted-return-fields, testing-quality-surviving-mutant-equivalence-triage, testing-quality-expectation-sets-with-one-distinct-value, testing-quality-harness-reverse-controls, testing-quality-mutation-harness-file-custody, backend-node-boundaries-runtime-validation, backend-python-boundaries-runtime-validation, backend-common-change-impact-widening-a-closed-value-table, security-input-validation-at-trust-boundaries, qa-process-agent-tool-parity-gate, testing-quality-json-manifest-edit-gates, infrastructure-config-environment-config, security-secrets-secrets-in-code, infrastructure-ci-cd-secrets-handling, platforms-shells-env-var-off-switches, security-dependencies-supply-chain, infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge, databases-schema-design-online-schema-changes, security-api-exposure-exposing-an-origin-http-api, infrastructure-containers-image-builds, qa-environments-test-environment-parity, infrastructure-data-backup-and-restore, testing-data-testcontainers-reaper-on-docker-desktop-macos, testing-data-testcontainers-python-community-namespace, testing-mocking-destructive-operations-on-shared-daemons, testing-mocking-captured-call-arguments, testing-quality-default-values-under-test

| # | Hits considered (wiki_search k=5 and grep) | Outcome |
|---|------------------|---------|
| 1-6 | as recorded by run `20261008-045232-51216` (per-row wiki_search tables in its report) | 5 new pages, 1 merge into qa-process-scope-purity-checks; no conflicts |
| 7 | backend-node-boundaries-runtime-validation (3 sections), security-input-validation-at-trust-boundaries, qa-process-agent-tool-parity-gate; plus testing/quality pages on case selection and mutation | None covers rejection-test key coverage. minimum-case-set is general case selection; unasserted-return-fields audits output fields, not input keys → new page |
| 8 | grep `loadEnvFile` 0, `dotenv` 0, `prisma.config` 0 files; security-secrets-secrets-in-code (env-file hygiene only); semantic-conflicts-after-parallel-merge (stale client after a merge) | Not covered → two new pages. The `?? ''` question against environment-config rule 5 is resolved: on 7.2.0+ no fallback is needed, and a linked exception row there covers older versions (rule unchanged) |
| 9 | grep `PGDATA` 0, `/var/lib/postgresql` 0, `docker-compose` 0 files; exposing-an-origin-http-api (app bind behind an edge); captured-call-arguments (testing a bind host) | Not covered → two new pages |

- Merged: 1 (qa-process-scope-purity-checks). Conflicts flagged: none left. The environment-config tension above is an explicit, linked exception, not a change to rule 5.
- Related back-links added, both ways where no open PR edits the target line: environment-config ↔ Prisma and loadEnvFile pages; image-builds ↔ postgres-18 page; exposing-an-origin-http-api ↔ published-ports page.
- One way only, to avoid same-line conflicts:
  - the zod page → minimum-case-set / unasserted-return-fields / surviving-mutant-equivalence-triage / runtime-validation (open PRs #233, #258 and #226 edit those `related:` lines or the line above);
  - the regeneration page carries the RFC citation in its body Sources (#255 rewrites its `related:` line).

## Open-PR check

Listed 24 open `knowledge/*` heads (#223–#258) with `gh pr list --repo choiyounggi/dev-loop --state open --search head:knowledge/`. The list was unchanged from run `20261008-045232-51216`'s check. For the new rows, each head's added `wiki/` lines were grepped (`gh pr diff`), and the overlapping heads were read in full.

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| 1-6 | as recorded by the earlier run (#255 Next 16 build page, #254/#256 PID mentions, #258 markup exact-sets, #223/#225/#253/#257 contrast mentions: different triggers) | new ×5, merge ×1 |
| 7 zod key coverage | #257 adds a zod → structured-output schema page (conversion, not rejection testing); #225's alias-table contract tests share "every member, not a sample" for a different trigger | new |
| 8 Prisma / loadEnvFile | #244 adds a Prisma 6 migration-SQL page (no env, generator or config rows); no head adds `loadEnvFile` or `prisma.config` guidance | new |
| 9 Postgres volume / ports | no head adds `PGDATA`, `/var/lib/postgresql`, port publishing or `127.0.0.1` guidance; #233's `docker compose exec` row is stdin handling | new |

Expected merge friction: index rows sit near rows other open PRs insert. The orm table row sits next to #238's edit of transaction-boundaries' row. `log.md` appends conflict with every open PR, as usual.

## Routing decision

| Candidate | Target | Why |
|-----------|--------|-----|
| 1-6 | as recorded by the earlier run: testing/mocking, platforms/toolchains, frontend/accessibility, platforms/processes, testing/quality (new); qa/process/scope-purity-checks (merge) | unchanged |
| 7 | `testing/quality/schema-rejection-key-coverage.md` (new) | Test design and the proof of a suite by mutation; sibling of minimum-case-set and unasserted-return-fields |
| 8 | `backend/common/orm/prisma-7-config-env-and-generated-client.md`, `backend/node/runtime/env-files-with-process-loadenvfile.md` (new) | ORM setup and the Node runtime API are separate triggers; the Prisma page links to the Node page |
| 9 | `infrastructure/containers/postgres-18-image-data-volume.md`, `infrastructure/containers/published-ports-bind-all-interfaces.md` (new) | Container runtime settings; one case per page |

- No new category.
- Layer test: rows 1-7 are general. Rows 8-9 name one project's files, ports, database name and rulings (C3, C4, C12), so their directives go to the local layer. The facts any project would want went to the bundled wiki, worded without the project.

## Local-layer candidates

- `0a7dbb3835a8161a` (project `linkly-invitation`, task t2) → `wiki-local/backend/common/orm/prisma-config-and-generated-client.md` (id `local-backend-common-orm-prisma-config-and-generated-client`, `reference_impl: [prisma.config.ts, prisma/schema.prisma, src/server/db/.gitignore, package.json]`). It records the root config, the `.env.local` → `.env` load order, `output ../src/server/db/generated`, the postinstall, and its `?? ''` fallback, which Prisma 7.2.0+ no longer needs (the bundled page explains why dropping it keeps the required-URL error). Run wiki-ingest inside that project.
- `67547272867dc570` (project `linkly-invitation`, task t2) → `wiki-local/infrastructure/containers/local-postgres-compose.md` (id `local-infrastructure-containers-local-postgres-compose`, `reference_impl: [docker-compose.yml, .env.example]`). It records the image tag, credentials placeholders, the `LINKLY_DB_PORT` default 55432 and why 5432 is not used, the volume name, and the healthcheck numbers. Run wiki-ingest inside that project.

## Run notes (for the owner; outside this PR)

1. **Step 0 run id.** knowledge-flush step 0 mints a fresh `RUNID` even when `hooks/auto-flush.sh` exported `DEV_LOOP_FLUSH_RUN_ID`. The first acquire was refused as `held`, and re-acquiring with the inherited id returned `already-owned`. Both this run and the previous one hit it.
2. **Step 1 reset.** Step 1's reset of `~/.dev-loop/repo` to `origin/main` would have destroyed the previous run's uncommitted ingest (19 files). This run checked `git status --porcelain`, saved the diff and kept the work in a local commit instead. Suggest a dirty-tree check before the reset.
3. **Lock owner PID.** `scripts/flush-lock.sh` records its own short-lived `$$` as the owner PID, so the PID-alive check never protects a running flush; only the 900 s TTL does. Both runs needed a keep-alive loop. Suggest recording a long-lived PID, such as the spawned `claude` process.
4. **Claim TTL.** The one-hour claim TTL is shorter than a real flush (this one ran well past an hour), and `queue-claim.js` has no refresh. This run re-claimed its own expired rows after confirming the claimable set equalled its nine.
5. **Inherited worker identity.** `auto-flush.sh` spawns the headless flush with the triggering worker's cwd and its `TMUX`/`TMUX_PANE`. `hooks/loop-gate.sh` gate 1 therefore treated this flush as the managed t3b worker (`tmux display-message -p '#S'` = `lo-5-inv1`, phase `implementing`) and blocked each stop. The PreToolUse escalation gate also sent two of this run's `curl … | perl` commands to the t3b coordinator. No t3b state was changed and no status was emitted. Same mechanism as #254's tmux-session-name insight. Suggest `unset TMUX TMUX_PANE` and `cd "$HOME/.dev-loop/repo"` before spawning, or exit early on `DEV_LOOP_FLUSHING=1`.
6. **Routing gap.** `INDEX.md`'s infrastructure line names "container image builds" but not runtime settings for local services. After #225, which edits that line, merges, extend it with "container runtime settings for local services (published ports, data volumes)". That missing route is likely why the t2 planner found no page.
7. From the earlier run: `skills/loop-implement/SKILL.md:321-322` says to add `.dev-loop/` to the project's `.gitignore`. Inside a scoped task that is itself a tracked change the task's gate flags; `info/exclude` is the in-task route.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
