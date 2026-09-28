# Knowledge flush — 1 insight (1 new page; 7 plan-gap rows retired as local-layer candidates)

Run id `20260928-103002-67743` (auto-flush child; lock inherited via `DEV_LOOP_FLUSH_RUN_ID`).
Claimed 8 queue rows: `27c34a17ce1d6612` (bun native addon) and 7 `plan-gaps` rows for the
`dace` Android repo (`30c9b935faa64ba8`, `639657eea8ef0550`, `2b1e21589c1987ea`,
`a81012fb435b7e21`, `79f42a83701cab51`, `86a1fcda7460b479`, `3deebdb303656afe`).

## Verified best-practice

### 1. A native addon has no `.node` binary after `bun install` — `confidence: verified`

**Harvested claim (row `27c34a17ce1d6612`):** a `bun install -g` CLI dies with "Could not
locate the bindings file" because bun skips lifecycle scripts for packages not in
`trustedDependencies`; remedy: run `prebuild-install` / `node-gyp rebuild` by hand or
reinstall with `--trust`.

**Verification changed the claim.** The stated cause is refuted for the harvested case and
the page states the corrected mechanism:

- `bun pm default-trusted` (bun 1.3.11, run in `~/.bun/install/global`) lists 367 packages and
  **includes `better-sqlite3` (line 117) and `sqlite3`**; the upstream
  `src/install/default-trusted-dependencies.txt` confirms both. `bun pm untrusted` in that
  install root lists tree-sitter-* and node-llama-cpp as blocked but **not better-sqlite3**.
  So bun ran its script; it was the `prebuild-install || node-gyp rebuild --release` chain
  (better-sqlite3's own `package.json` install script) that produced no binary.
- Reproduction (scratch project under the seagrass `.claude/tmp/`, deleted afterwards):
  a trusted `file:` dep whose install script exits 1 → `bun install` exits 1 with
  `error: install script from "failing-dep" exited with 1`, leaves `build/Release/obj`,
  writes no lockfile (`bun pm untrusted` → `error: Lockfile not found`). An unlisted dep →
  exit 0 with `Blocked 1 postinstall. Run \`bun pm untrusted\` for details.`; `bun pm trust
  blocked-dep` ran the script and wrote `trustedDependencies`. The "only obj dirs, no .node"
  state in the harvested evidence matches the *failed* branch, not the *blocked* branch.
- Official docs checked (context7 `/oven-sh/bun` + WebFetch): https://bun.com/docs/pm/lifecycle
  (default-secure allowlist; default list applies to npm sources only; `--ignore-scripts`),
  https://bun.com/docs/pm/cli/pm (`untrusted` / `trust` / `default-trusted` / `ls --trusted`;
  a set `trustedDependencies` **replaces** the default list),
  https://bun.com/docs/guides/install/trusted (same replace-not-extend note),
  https://github.com/nodejs/node-gyp#installation (Xcode CLT + supported Python; `--python`,
  `npm_config_python`, `PYTHON`; `rebuild` = clean+configure+build).
- Field half kept as evidence in the page's Sources: the qmd MCP server (global bun install,
  better-sqlite3 12.8.0, launcher `#!/bin/sh` → Node 26.7) had no prebuilt for that ABI;
  `node-gyp rebuild --release --python=<3.11>` produced `better_sqlite3.node` and the server
  connected (originating session transcript `d5eb45d9…`, `claude mcp list` output).
- Not substantiated and therefore left out: the harvested `--trust` remedy for a
  default-listed package (it would re-run the same failing compile and, by writing
  `trustedDependencies`, drop the rest of the default allowlist — recorded as an *Instead of*
  row).

### 2–8. Seven `plan-gaps` rows (t6b-calendar-trip-integration, repo `dace`) — not ingested

Each directive names the dace repository's own types and files (`CalendarBarItem`,
`CalendarWeekSegmentLayout`, `CalendarViewModel`/`TripApi`, `MonthGridPanel`,
`CalendarWeekRow`, `PendingInAppRouteBox`, `AppContainer`, `MainTabScaffold`, `TripTabRoot`)
and would be wrong in any other codebase. Layer test (wiki-ingest step 3) → local layer; see
`## Local-layer candidates`. Their general residue is already covered:
`mobile/navigation/deep-links-and-entry-points` (pending-route ownership, cited by the rows
themselves) and `testing/mocking/what-to-mock`.

## Existing-layer check

Pages read: platforms-toolchains-version-management, platforms-toolchains-compiler-sysroot-on-macos, platforms-environment-path-resolution, security-dependencies-supply-chain, platforms-tools-plugin-mcp-server-registration, qa-deliverables-documented-behavior-of-a-third-party-tool

- Routing via `INDEX.md` → `wiki/platforms/index.md` (toolchains; also read shells/tools rows),
  `wiki/infrastructure/index.md`, `wiki/backend/node/index.md`, `wiki/debugging/index.md`.
- Repo-wide grep for `bun|native addon|node-gyp|prebuild-install|lifecycle script|postinstall|trustedDependencies|bindings file`
  across `wiki/` (no truncation): 3 files — `frontend/design/design-canvas-workflow.md` (bun as
  a prerequisite only), `security/dependencies/supply-chain.md` (one directive: review
  install scripts, allowlist them — same *principle*, no diagnostic/remedy), `qa/deliverables/
  documented-behavior-of-a-third-party-tool.md` (`npm ls -g` lookup only). No page covers the
  blocked-vs-failed distinction, `bun pm untrusted/trust`, or the ABI/runtime rebuild.
- `wiki_search` (k=5) on the trigger sentence: qa-deliverables-documented-behavior-of-a-third-party-tool (0.75),
  infrastructure-containers-image-builds ×4 (0.72–0.75) — none describes this situation, so
  **created new**: `wiki/platforms/toolchains/native-addon-binary-missing-after-bun-install.md`
  (id `platforms-toolchains-native-addon-binary-missing-after-bun-install`, 90 lines total).
- Conflicts: none. `security-dependencies-supply-chain` says "disable install scripts by
  default and allowlist"; the new page is the downstream diagnostic when that allowlist (or a
  failed script) leaves a native addon without its binary — complementary, linked both ways.
- Related links added both ways: platforms-toolchains-version-management,
  platforms-toolchains-compiler-sysroot-on-macos (node-gyp compile on macOS),
  platforms-environment-path-resolution (which `node` the launcher resolves),
  security-dependencies-supply-chain, platforms-tools-plugin-mcp-server-registration (MCP
  server dying at connect).
- Plumbing: `wiki/platforms/index.md` toolchains row; `INDEX.md` platforms route line
  extended (no open PR rewrites that row — checked #223/#225/#226 diffs on `INDEX.md`);
  `log.md` ingest entry.
- Lint: `node scripts/wiki-lint-prohibitions.js` — no finding on the new page; no banned
  qualifiers in directive sentences.

## Open-PR check

Open `knowledge/*` heads (`gh pr list --state open --search "head:knowledge/"`):
#226 `knowledge/choiyounggi-20260928-092831`, #225 `knowledge/choiyounggi-20260928-082803`,
#223 `knowledge/choiyounggi-20260927-220735`. Each fetched and diffed against `origin/main`
under `wiki/` with the overlap grep above:

| Candidate | #226 | #225 | #223 | Verdict |
|-----------|------|------|------|---------|
| `27c34a17ce1d6612` bun native addon | 0 hits | 1 hit (`postinstall` in an unrelated Kotlin/Gradle page) | 1 hit (unrelated `bun` mention) | **new** |
| 7 dace plan-gap rows | — | — | — | not general; local-layer (see below), no wiki edit here |

#223 touches `wiki/platforms/index.md` (shells and tools rows) and `INDEX.md`; my edits are in
the toolchains table and the platforms route line, which none of the three PRs rewrite.

## Routing decision

| Insight | Target | Why this category |
|---------|--------|-------------------|
| bun native addon without `.node` | `platforms/toolchains/native-addon-binary-missing-after-bun-install` (new page) | The fault sits between a package manager's script policy and a compiler toolchain (node-gyp, Python, Xcode CLT, runtime ABI) — the toolchains category already holds `compiler-sysroot-on-macos`, `version-management`, `environment-resync-removes-undeclared-packages`. Not `backend/node` (no application code) and not `security/dependencies` (that page owns the policy, not the diagnosis). No new category. |

## Local-layer candidates

Project `dace` (`/Users/choeyeong-gi/Desktop/workspace/linkly-calendar/dace`, task
t6b-calendar-trip-integration) — run `wiki-ingest` inside that project:

| Row | Target |
|-----|--------|
| `30c9b935faa64ba8` CalendarBarItem sealed union + id prefixes | `wiki-local/mobile/presentation/calendar-bar-item-union.md` |
| `639657eea8ef0550` shared greedy lane layout over mixed bar items | `wiki-local/mobile/presentation/calendar-week-lane-layout.md` |
| `2b1e21589c1987ea` asymmetric error isolation for parallel events/trips fetch | `wiki-local/mobile/networking/calendar-parallel-fetch-error-isolation.md` |
| `a81012fb435b7e21` trip bar color/icon parity with iOS | `wiki-local/mobile/presentation/calendar-trip-bar-rendering.md` |
| `79f42a83701cab51` trip-bar tap routing (`onTripTap`, isCenter-only) | `wiki-local/mobile/navigation/calendar-trip-bar-tap-routing.md` |
| `86a1fcda7460b479` PendingInAppRouteBox owned by AppContainer | `wiki-local/mobile/navigation/pending-in-app-route-ownership.md` |
| `3deebdb303656afe` 5th tab index/icon + TripTabRoot stub consumption | `wiki-local/mobile/navigation/trip-tab-and-pending-route-consumption.md` |

All 8 claimed rows are retired in the queue by this run (1 ingested, 7 local-layer).
