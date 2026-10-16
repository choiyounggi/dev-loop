# Knowledge flush — 1 insight(s)

With Prisma 7 on a driver adapter, an error PostgreSQL raises at COMMIT (a deferred constraint or deferred constraint trigger) reached the app as a raw `DriverAdapterError` and skipped an `instanceof Prisma.*Error` fault wrapper. Classify `name === "DriverAdapterError"` too, by `cause.kind`, and test the wrapper with a commit-time fixture next to a statement-time one. **1 new page, 1 index row, 2 back-links (1 with an edge row), 1 log entry. 2 rows released, 0 dropped.**

Headless autoflush run `20261016-141733-16259`. Claimed 3 queue rows with `queue-claim.js claim`: `12aa086463fd4e2a` (macOS BSD grep `$` in a `\|` basic regex), `66f97671dfa1b324` (Prisma 7 commit-time `DriverAdapterError`), `97c37473b53e63c2` (content not read, see Routing decision).

## Verified best-practice

**`66f97671dfa1b324`: errors raised at COMMIT escape an `instanceof Prisma.*Error` wrapper as `DriverAdapterError`** (confidence: **field-tested**)

Claim: in a Prisma 7 app on `@prisma/adapter-pg`, an error raised at COMMIT reached the app's catch block as `DriverAdapterError`, not `PrismaClientKnownRequestError`. The trigger here was a `DEFERRABLE INITIALLY DEFERRED` constraint trigger. A wrapper that classifies by `instanceof Prisma.*Error` therefore calls it "unexpected". Statement-time errors on the same write are classified correctly. Fix: also match the adapter error, and add a commit-time fixture to the wrapper's tests.

Sources checked:

- Installed `@prisma/adapter-pg` **7.10.0** `dist/index.mjs` (the originating project's own `node_modules`, read 2026-10-16):
  - `PgTransaction.commit()` (lines 676-680) only calls `cleanup` and `client.release()`. It sends no SQL, so Prisma's `COMMIT` goes through `executeRaw`.
  - `executeRaw` → `performIO` → `onError` (lines 631-667) throws `new DriverAdapterError(convertDriverError(error))`.
  - `convertDriverError` (lines 420-540) maps `23505`/`23503`/`23502`/`40001`/`40P01` and others to named kinds. Its `default` branch returns `kind: "postgres"` with `code`, `severity`, `message`, `detail`, `column` and `hint`.
- Installed `@prisma/driver-adapter-utils` **7.10.0** `dist/index.mjs` lines 5-15:
  - `DriverAdapterError` sets `name = "DriverAdapterError"` and `this.cause = payload`.
  - `isDriverAdapterError(error)` checks the name plus an object `cause`.
  - The package sits only under `node_modules/.pnpm/…`. `node_modules/@prisma/driver-adapter-utils` does not exist, so app code cannot import the helper without a direct dependency.
- `@prisma/client` in the originating project is **7.10.0**, read from `node_modules/@prisma/client/package.json`.
- https://www.prisma.io/changelog/2026-04-27 (read through WebSearch): before prisma/prisma#29512, an unmapped raw driver error was rethrown. After it, the error surfaces as a catchable P2039 `PrismaClientKnownRequestError`; the 7.9.0 release notes say the same. This covers the query path. The field case on 7.10.0 shows the commit path still delivering the raw adapter error.
- https://www.postgresql.org/docs/current/sql-set-constraints.html ("DEFERRED constraints are not checked until transaction commit") and https://www.postgresql.org/docs/current/sql-createtrigger.html (constraint triggers, whose timing `SET CONSTRAINTS` adjusts), both via WebSearch. The SET CONSTRAINTS quote is the one already carried by `databases-transactions-multi-row-reorder-on-a-shared-resource`.

How verified: the mechanism (every adapter SQL error, `COMMIT` included, is thrown as `DriverAdapterError`) was confirmed by reading the installed 7.10.0 source above. The end-to-end behaviour (Prisma Client does not convert the commit-time error) is the originating session's reproduction: a deferred constraint trigger logged `[admin] unexpected error in setTheme`, and a BEFORE trigger on the same `setTheme` logged `database fault in setTheme (P20xx)`. **This flush did not re-run that reproduction** (no database or script execution is available in this headless run), so the page is `field-tested`, not `verified`. The page states which parts come from source and which from the field run.

**`12aa086463fd4e2a`: macOS grep and `$` before `\|`.** Not researched further in this run; released as a pending duplicate (see Open-PR check). No confidence is claimed.

**`97c37473b53e63c2`.** Not read; released (see Routing decision).

## Existing-layer check

Route: `INDEX.md` → backend (ORM error mapping in application code) → `wiki/backend/index.md` → `common/orm`. Databases owns the deferred-constraint mechanics.

Pages read: backend-common-orm-prisma-7-config-env-and-generated-client, databases-transactions-multi-row-reorder-on-a-shared-resource, backend-common-errors-exception-handling, platforms-tools-bsd-vs-gnu-cli

- `wiki_search` (k=8) on "Prisma error classification instanceof PrismaClientKnownRequestError driver adapter commit-time deferred constraint": the top hits are all Prisma 7 config/env sections, plus migration-sql-without-a-database and semantic-conflicts-after-parallel-merge. None covers runtime error classes.
- `wiki_search` (k=8) on "wrapper that maps ORM database errors to a domain error class; errors raised at transaction commit escape the mapping": the top hit is JPA raw-JDBC exception translation (Spring, a different stack), then unrelated pages.
- `wiki_search` (k=6) on "deferred constraint violation reported at COMMIT": the top hit is `multi-row-reorder-on-a-shared-resource`, which recommends `DEFERRABLE INITIALLY DEFERRED` and says nothing of how the commit-time error reaches the app.
- **Created new** `wiki/backend/common/orm/prisma-driver-adapter-errors-at-commit.md` (id `backend-common-orm-prisma-driver-adapter-errors-at-commit`). It is not merged into the Prisma 7 page because that page is a setup/config page (env loading, generator, postinstall) with a different trigger, 64 body lines and 20 sources. The new page has its own trigger: runtime error classification at COMMIT.
- **Back-links:**
  - `multi-row-reorder-on-a-shared-resource` gets one Edge-cases row (deferred constraint + Prisma 7 adapter → the error comes from COMMIT as `DriverAdapterError`) and a `related:` entry.
  - `exception-handling` gets a `related:` entry.
  - The back-link on `prisma-7-config-env-and-generated-client` is deferred, because open PR #269 edits that page's `related:` line.
- `wiki/backend/index.md`: one row added to the `orm` table.
- Conflicts with existing directives: none. The page adds the consequence of the existing "make it DEFERRABLE INITIALLY DEFERRED" directive and does not change it.
- `scripts/wiki-structure-checks.js` and `scripts/wiki-lint-prohibitions.js` were **not run**: this headless run may execute only `queue-claim.js` and `gh pr list`. Manual check instead:
  - The page follows `templates/page.md`.
  - Its "When this applies" section is 4 lines.
  - Every "Instead of" row pairs the anti-pattern with a replacement.
  - The body is under 120 lines.
  - Every `related:` and inline page id resolves to an existing page under `wiki/`.

  Please run both scripts before merging.

## Open-PR check

14 open `knowledge/*` heads, listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/" --json number,title,files`: #283, #282, #280, #279, #275, #274, #273, #272, #271, #270, #269, #268, #266, #265. This run has no git access, so overlap was judged from each PR's title and changed-file list. For #269, #273 and #280 it was also judged from the full PR body (`gh pr list … --json number,body`).

| Candidate | Overlapping open PR | Verdict |
|---|---|---|
| `66f97671dfa1b324` (Prisma commit-time `DriverAdapterError`) | No head touches `backend/common/orm/` except #269, which only adds a `related:` link on the Prisma 7 config page. No PR body mentions `DriverAdapterError`, deferred constraints or commit-time errors. #280 (wrapper label pinned by a boundary fault) comes from the same project's fault wrapper but covers a different trigger: which fault *depth* reaches the wrapper's own log label in a Vitest test, not which error class the adapter delivers at COMMIT | **new** |
| `12aa086463fd4e2a` (BSD grep `$` before `\|`) | #273 merges a BSD-vs-GNU row (`wc -l` padding) into `wiki/platforms/tools/bsd-vs-gnu-cli.md` and touches four `platforms/shells/*` pages. This candidate's natural target is that same page (BSD vs GNU userland behaviour of one command); #265 and #270 also edit regex-anchor pages (`anchor-cases-for-allowlist-regexes`). Its body does not carry the grep insight itself, but the domain and target page plausibly overlap | **pending duplicate → released** (headless rule: never fold into another branch) |
| `97c37473b53e63c2` | Not judged (content not read) | **released** |

Expected textual overlap with open heads: `wiki/backend/index.md` (#265, #268, #269 and #272 add rows to other tables; this PR appends one row to `orm`) and `log.md` (every flush appends at the end).

## Routing decision

| Candidate | Layer | Target | Action |
|---|---|---|---|
| `66f97671dfa1b324` | bundled | `backend/common/orm/prisma-driver-adapter-errors-at-commit.md` | created; index row + 2 back-links + log entry; queue row retired |
| `12aa086463fd4e2a` | bundled (when its turn comes) | most likely `platforms/tools/bsd-vs-gnu-cli.md` (a grep row), after #273 merges | released to `pending`, not ingested |
| `97c37473b53e63c2` | unknown | none | released to `pending`, not ingested. This run could not locate its queue file: directory listing and search outside the session's working directory are blocked in the headless sandbox, and its session-file name was not among those recoverable from `~/.claude/history.jsonl`. A manual `/dev-loop:knowledge-flush` can read it |

No new category: `backend/common/orm` already owns ORM behaviour in application code, and it holds the sibling Prisma 7 page. Layer test: the directive names no repository-specific file. `setTheme`, `runAdminWrite` and `withDatabaseFault` appear only in the field-evidence line as the originating case, so the page is general knowledge.

## Local-layer candidates

none
