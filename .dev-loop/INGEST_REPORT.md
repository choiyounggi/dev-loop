# Knowledge flush — 31 candidate(s): 6 promoted (4 new pages, 1 amended), 25 retired as local-layer

All 31 claimed rows were wiki-plan `plan-gap` rows (decisions a plan made with no owning wiki page) from three projects. Five carried a reusable lesson under their project-specific wording; one more folded into one of those pages. The other 25 are design decisions about one codebase's own files and are listed under Local-layer candidates.

## Verified best-practice

| Row | Claim as ingested | Sources checked | Confidence |
|-----|-------------------|-----------------|------------|
| b945d6a09e715fed | TanStack Query `invalidateQueries` matches by key **prefix**, so a new key's first segment decides which existing invalidations reach it. Nest a key when parent writes change the data. Give it its own first segment when its lifecycle is independent (polled status). `exact: true` spares children. `setQueryData` takes an exact key. | https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation (prefix + `exact: true` examples, quoted); https://tanstack.com/query/latest/docs/reference/QueryClient (`removeQueries`/`cancelQueries` take filters, `setQueryData` takes a key) | verified |
| 826966de8ee380ab | A top-level `from x import y` that closes a module cycle fails on a partially initialized module. Pick the fix by case: a function-local import when the name is used in one function or branch, a third module when it is needed at top level, or `import module` plus attribute access. Use `TYPE_CHECKING` only when no annotation is evaluated at run time. Prove the fix by importing each module in the cycle first, one at a time. | https://docs.python.org/3/faq/programming.html (both import FAQ entries, quoted); https://docs.python.org/3/library/typing.html#typing.TYPE_CHECKING (wording re-extracted with curl). Row evidence: the import broke before the fix and worked after, confirmed by running it. | verified |
| 0a31e356f0392835 (+0726f9fdc05d6353 folded) | Inside a workspace package, import sibling modules by relative path. A self-import by package name resolves through `"exports"`. When `"exports"` points at `dist/`, that copy is absent before the first build and stale under test runners. Moving a module: repoint importers and leave no re-export shim. | https://nodejs.org/api/packages.html#self-referencing-a-package-using-its-name (3 sentences quoted). The `dist/` consequences are labelled field evidence from one pnpm + vitest package. | verified (mechanism) + field-tested (consequences) |
| a93d54e87f9f4708 | With no reachable database, produce a Prisma migration with `migrate diff` between the previous and current schema files, using `--script`. Flags by major version: 6.x `--from-schema-datamodel`/`--to-schema-datamodel`; 7.x `--from-schema`/`--to-schema`. A shadow DB is needed only for `--from-migrations`. | https://github.com/prisma/prisma/blob/6.19.0/packages/migrate/src/commands/MigrateDiff.ts (help text and branch code read through `gh api` at tag 6.19.0); https://www.prisma.io/docs/orm/reference/prisma-cli-reference#migrate-diff (v7 options + removed-flags note) | verified |
| 7c71d321f8c54228 | React Native's global `URL` has no `URL.canParse`, and its constructor without a base does not validate. A shared module calling `canParse` therefore throws on device, and `try { new URL() }` is no fallback. Use a WHATWG polyfill or keep the call out of mobile-imported functions. | `facebook/react-native` `Libraries/Blob/URL.js` at v0.86.0 and v0.87.1 (only `createObjectURL`/`revokeObjectURL` statics; no-base branch assigns `this._url = url`); `Libraries/Core/setUpXHR.js:35` `polyfillGlobal('URL', ...)`; `gh search code canParse --repo facebook/react-native` returned 0 hits; MDN browser-compat-data `api/URL.json` `canParse_static` (Chrome 120, Safari 17, Firefox 115, Node 18.17–18.x and 19.9+); charpeni/react-native-url-polyfill README | verified |

A fresh-context adversarial reviewer checked every cited URL against the claims and returned CHANGES with 8 findings. All 8 were fixed (see the last `log.md` entry). The `setQueryData` exact-key point and the Prisma `loadEnvFile` branch were re-verified before the fix.

Checks on the final tree:
- `node scripts/wiki-lint-prohibitions.js` reports `directives: 80`, `violations: 0`. The baseline on `origin/main` is 79, measured in a temp worktree, so the pin in `tests/wiki-lint-prohibitions.bats` moves 79→80.
- `bats tests/wiki-*.bats tests/bash-version-guard.bats` under bash 5 reports `1..239`, 239 `ok`, 0 `not ok`.

## Existing-layer check

Pages read: frontend-data-fetching-query-state-vs-fetch-state, platforms-toolchains-flag-availability-at-the-execution-site, databases-schema-design-online-schema-changes, databases-schema-design-verifying-additive-migrations, testing-strategy-import-time-side-effects, backend-common-change-impact-widening-a-closed-value-table, backend-common-change-impact-call-site-enumeration

- **Grep for each topic across `wiki/`.**
  - `invalidateQueries|queryKey`: 0 hits.
  - `self-referenc|self-import`: 2 unrelated hits (agent-orchestration self-reference, gated document).
  - `migrate diff|prisma migrate`: 1 hit, online-schema-changes. It covers the CONCURRENTLY-in-a-transaction edge, not producing the SQL.
  - `circular import|lazy import`: 1 hit, widening-a-closed-value-table. It is an Instead-of row about an inlined copy, not the cycle fix.
  - `canParse`: 0 hits.
- **`wiki_search` top-5 per candidate.** No hit described the same trigger. The closest were:
  - query-state-vs-fetch-state and infinite-scroll for the query key;
  - import-time-side-effects for circular imports;
  - online-schema-changes and verifying-additive-migrations for Prisma;
  - call-site-enumeration for self-import.
- **Merged rather than created:** the RN `URL.canParse` candidate is the "API method exists locally but not where it runs" case, so it became an edge row plus a trigger sentence on flag-availability-at-the-execution-site, not a new page.
- **Conflicts:** none.
- **Back-links added:**
  - query-state-vs-fetch-state → query-key-prefix-invalidation;
  - import-time-side-effects → circular-imports;
  - online-schema-changes → migration-sql-without-a-database;
  - flag-availability → self-import-inside-a-workspace-package and migration-sql-without-a-database.

## Open-PR check

There are 17 open `knowledge/*` heads: #223, #225–#231, #233–#239, #241, #243. `git diff --stat origin/main...origin/<head> -- wiki/` was read for each.

| Candidate | Overlapping open PR | Verdict |
|-----------|--------------------|---------|
| query-key prefix invalidation | none. #225 adds frontend/state/concurrent-optimistic-updates (different trigger: overlapping PATCHes) | new |
| circular imports | none. No open head touches backend/python | new |
| self-import in a workspace package | none. #233 adds platforms/toolchains/typescript-6-global-types (different trigger) | new |
| Prisma migration SQL without a DB | none. #237 touches databases/schema-design/nullability-and-defaults only | new |
| RN `URL.canParse` | none. No open head edits flag-availability-at-the-execution-site | new |
| 25 local-layer rows | not applicable: excluded from the bundled wiki | drop (local-layer) |

Expected merge friction: index files that other open PRs also append rows to (`wiki/platforms/index.md` with #233/#234/#235/#241/#243, `wiki/frontend/index.md` with #225/#243), plus the directive pin in `tests/wiki-lint-prohibitions.bats` if another PR changes the count. Resolve as a union.

## Routing decision

| Insight | Target |
|---------|--------|
| query-key prefix invalidation | `frontend/data-fetching/query-key-prefix-invalidation.md` (new). data-fetching already holds the TanStack Query pages |
| circular imports | `backend/python/language/circular-imports.md` (new). language is the existing category for Python semantics traps |
| self-import in a workspace package | `platforms/toolchains/self-import-inside-a-workspace-package.md` (new). Module resolution is a toolchain concern, and backend/node's categories (runtime, async, boundaries) do not fit |
| Prisma migration SQL without a DB | `databases/schema-design/migration-sql-without-a-database.md` (new), next to online-schema-changes and verifying-additive-migrations |
| RN `URL.canParse` | `platforms/toolchains/flag-availability-at-the-execution-site.md` (amended: edge row, trigger sentence, index line) |

No new category was created.

## Local-layer candidates

Each of these 25 rows names one repository's own files, symbols, or conventions, so it would be wrong in another codebase. Each is retired from the queue; to keep one, run wiki-ingest inside that project.

**dev-loop (plan `excess-lens-and-lint-gate`)**
- 1be43ea678bd96b1, 11f6761d13238033 → `wiki-local/qa/review/excess-lens-tiers-and-criteria.md`
- 2636dac86f322f93 → `wiki-local/infrastructure/config/verify-role-covers-lint.md`
- 0fe4cb95c61e849b → `wiki-local/infrastructure/agent-orchestration/agent-tier-variant-generation.md`

**linkly apply-mate (plans t4, t1, t2)**
- ed3d7a82a7fb7506 (`apiFetch` 204 handling) → `wiki-local/frontend/data-fetching/api-client-204-responses.md`
- d6af686e4e7eefb5, 7066ec589fc2741f, c851d691fdc77ec1 (labels, route guard, entry button) → `wiki-local/mobile/navigation/research-screen-wiring.md`
- 34e11cda59d7420c, e18abc22b500ee83 (byte-identical module move, importer switch) → `wiki-local/backend/common/change-impact/moving-a-module-into-shared.md`
- 04c96225f4826a63 (research-status read order) → `wiki-local/backend/common/concurrency/research-status-read-order.md`
- c6e2539be231730b (controller routing) → `wiki-local/backend/common/api-design/research-routes.md`

**linkly seaslug / lnpl (plans t187, t188)**
- 1466a1cd9fe36485, e9984f74aba73d27, 9cd42b874b1635ba, ef2d1539f440fdf3, 82a82989dccf175e (LNPL_* env tiers, docs sync, blackboard) → `wiki-local/infrastructure/config/build-app-env-surface.md`
- eb324849094385ed, c3eb6a5f7976cd37, 53dc27028decd5f1, d3b2a281bb475794, 1999cc86ec62daf0, 37281da0abd1c80e, 861e7f25434d14f7, f92fe637897f0db3 (`cached` read-through clause) → `wiki-local/backend/common/caching/cached-read-clause.md`
