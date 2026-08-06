# Knowledge flush — 2 insight(s) ingested, 1 dropped as duplicate

Queue drained: 3 pending rows harvested 2026-08-06 (sessions `679c6a1a`, `b5539d9b`, `d89cad63`).

## Verified best-practice

**1. ESM DI + PATH tripwire for "no real child process spawned" (testing)**

- Claim: in an ESM Node project using named imports of `node:child_process`, monkey-patching cannot intercept the import, so inject every spawn behind a deps interface; in the test, empty `process.env.PATH` as a tripwire and deep-equal the full stub-recorded call sequence — a clean exit fully explained by stubs proves no PATH-resolved spawn could have succeeded.
- Sources checked:
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/import — confirms imported bindings are *read-only live bindings*; "cannot be re-assigned by the importing module" (reassignment throws `TypeError`).
  - https://nodejs.org/api/test.html + nodejs/node issue tracker — confirms `mock.module()` requires the `--experimental-test-module-mocks` CLI flag and remains Stability 1 (experimental) through Node v26.x.
- How verified: both mechanism claims match official docs fetched this session. The tripwire pattern itself was reproduced in the harvesting session: the boundary test passed with `PATH=""` while a real `spawnSync("npm")` under the same emptied PATH returned ENOENT (negative control), 365/365 suite green.
- Confidence: mechanism **verified** (MDN + Node docs); the tripwire test pattern **field-tested** — stated as such in the page's Sources block.

**2. Independent GitHub credential channels in non-interactive automation (infrastructure)**

- Claim: `gh` CLI token, git remote auth (SSH keys / credential helper), and a configured API/MCP integration token are three independent credential stores; when `gh auth status` reports an invalid token in a non-interactive session, probe the others (`git push --dry-run` for push auth, an `author:@me` search for the API token's identity) before declaring the run blocked, and combine push-via-git with PR-via-API when they belong to the same account.
- Sources checked:
  - https://cli.github.com/manual/gh_auth_login — `gh` stores its OAuth token "securely in the system credential store" (plain-text file fallback), and the git protocol (ssh/https) is configured separately from the API token.
  - https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests — `@me` works as a value for user qualifiers (`author:@me`, `commenter:@me`) and resolves to the authenticated account.
- How verified: store-separation and `@me` semantics match official docs fetched this session. The end-to-end combination was exercised twice for real: the 2026-08-06 morning session (gh 401 → SSH dry-run OK → MCP `search_issues author:@me` → PR choiyounggi/dev-loop#42 opened via API), and again by this very flush (same gh-401 state; this PR was pushed over SSH and opened via the GitHub MCP API).
- Confidence: store separation and `@me` **verified** (official docs); the diagnose-then-combine workflow **field-tested** — stated as such in the page's Sources block.

**3. OAuth token requests bypassing a client-side throttle (backend) — DROPPED as duplicate**

- Claim: token/credential-issuance HTTP requests fired from header builders / auth interceptors must be routed through the client-side throttle, timestamp stamped immediately before the send, and the initial `last_request_at = 0` state must not defeat the spacing check.
- Not re-verified here: this exact insight (same KIS `stock-trader` field incident, same log timeline :00.354 / :00.495 / :00.543) was already ingested by the 2026-08-06 morning flush into `wiki/backend/common/reliability/timeouts-and-retries.md` and is sitting in **open PR #42** (`knowledge/dch0202-20260806-100222`). Re-ingesting on a second branch would create a merge conflict with a pending PR carrying identical content. Retired from the queue as a duplicate; no wiki edit in this PR.

## Existing-layer check

Pages read: root `INDEX.md`; `wiki/testing/index.md` + `mocking/what-to-mock.md`, `quality/tests-that-cannot-fail.md` (frontmatter); `wiki/infrastructure/index.md` + `ci-cd/secrets-handling.md`; the full diff of open PR #42 (`origin/knowledge/dch0202-20260806-100222` vs `origin/main`), which touches `backend/common/reliability/timeouts-and-retries.md`, `backend/index.md`, four testing/platforms pages, and both relevant domain indexes on lines disjoint from this PR's edits.

- Insight 1: `what-to-mock.md` already owns the mock/DI decision (trigger overlap) but lacked the ESM-binding mechanism and the prove-a-negative tripwire → **merged** as two Edge-cases rows + two source lines + field-evidence line. No conflict with existing directives (the page already prefers DI at owned boundaries; this adds a language-level reason it is mandatory under ESM). Related-link added both ways with `testing-quality-tests-that-cannot-fail` (that page already listed `what-to-mock`; the back-link was the missing direction, added in `what-to-mock` frontmatter).
- Insight 2: `secrets-handling.md` owns credentials-in-automation (trigger overlap) but only covered storage/exposure/rotation, not multi-channel diagnosis → **merged** as one Edge-cases row + two source lines + field-incident line. No conflicting directive found.
- Insight 3: exact duplicate of content in open PR #42 → **dropped**, no edit (see Routing).
- Conflicts flagged: none.

## Routing decision

| Insight | Domain/category | Page | New category? |
|---------|-----------------|------|---------------|
| ESM DI + PATH tripwire | testing/mocking | `wiki/testing/mocking/what-to-mock.md` (merge) | No — mocking already covers replace-vs-real decisions; the harvested `testing` hint was correct |
| Independent GitHub credential channels | infrastructure/ci-cd | `wiki/infrastructure/ci-cd/secrets-handling.md` (merge) | No — ci-cd/secrets-handling already owns credentials in automated jobs; the harvested `infrastructure` hint was correct. Considered `platforms/processes/non-interactive-cli-invocation` (non-interactive angle) but the substance is credential-store separation, not CLI invocation mechanics |
| OAuth throttle bypass | backend/common/reliability | already in `timeouts-and-retries.md` via open PR #42 | Dropped as duplicate — no edit in this PR |

Plumbing updated: `testing/index.md` and `infrastructure/index.md` "load when" lines extended (both on lines untouched by PR #42, so the two PRs merge cleanly in either order); `log.md` ingest entry appended.
