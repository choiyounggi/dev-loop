# Knowledge flush — 13 insight(s) (+112 plan-gap rows retired as local-layer)

Run id `20261001-150151-37879` (inherited from the auto-flush parent). Claimed 125 rows: 13
`★ Insight` candidates from 9 session files and 112 `plan-gaps` rows from one project
(`linkly-apply-mate-cuskeel`). Result: 4 new pages, 5 pages amended (one or two rows each),
1 candidate dropped as already covered, 112 plan-gap rows retired as local-layer.

## Verified best-practice

Every quoted sentence below was read in a raw copy fetched with `curl` on 2026-10-01
(not through a summarizing fetch tool).

### 1–3. Line-by-line `while read` loops (hashes `84175dfe5d2fe605`, `a3cea8c2adc4fc61`, `f8bd0457a7c8fad8`)

**Claims.** (a) `while IFS= read -r line` drops a last line that has no trailing newline; write
`|| [ -n "$line" ]`, and start a gate's verdict at "fail". (b) A command in the loop body that reads
stdin (`ssh`, `docker compose exec -T`, `ffmpeg`) eats the rest of the loop's input; give it
`</dev/null` or iterate on fd 3. (c) To insert multi-line text on macOS and Linux use the read loop,
because BSD awk rejects a newline inside a `-v` value.

**Sources checked.**
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/read.html — exit status `>0`:
  "End-of-file was detected or an error occurred."
- https://mywiki.wooledge.org/BashFAQ/001 — "if the last line is not terminated by a newline
  character), then `read` will read it but return false, leaving the broken partial line in the
  `read` variable(s)"; shows `while IFS= read -r line || [[ -n $line ]]`.
- https://mywiki.wooledge.org/BashFAQ/089 — "if a command inside the loop also reads stdin, it can
  exhaust the input file"; fixes `</dev/null`, `ssh -n`, `ffmpeg -nostdin`, `read … <&3` / `done 3< file`.
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html — "A <newline> shall not occur
  within a string constant"; a `-v` assignment is interpreted as a STRING token.
- https://docs.docker.com/reference/cli/docker/compose/exec/ — "By default, Compose will enter
  container in interactive mode and allocate a TTY"; `-T` is "Disable pseudo-TTY allocation".

**How verified.** Reproduced locally 2026-10-01 on macOS under `/bin/bash` 3.2.57 and zsh:
`printf 'one\ntwo' | while IFS= read -r l` ran the body once, with the guard twice; a `cat` in the
body of a 3-line loop left 1 item processed, `</dev/null` and the fd-3 form gave 3;
`awk -v var="$(printf 'a\nb')"` exited 2 with `awk: newline in string`, and the same value read
through `ENVIRON` printed both lines.

**Confidence:** verified.

### 4. TypeScript 6 no longer loads every `@types/*` package (hash `49f7e442c32be5b1`)

**Claim.** On TypeScript 6+, list global type packages in `compilerOptions.types` and declare each as
a devDependency.

**Sources checked.**
- https://devblogs.microsoft.com/typescript/announcing-typescript-6-0/ — section "`types` now
  defaults to `[]`": "In TypeScript 6.0, the default `types` value will be `[]` (an empty array)";
  the new diagnostic "Cannot find name 'describe'. … add 'jest' or 'mocha' to the types field in your
  tsconfig"; `"types": ["*"]` re-enables the old enumeration.
- https://www.typescriptlang.org/tsconfig/#types — "By default `types` is set to `[]`. For versions
  below TypeScript 6.0, by default all _visible_ "`@types`" packages are included".

**How verified.** Both documents read; they agree with the session's reproduction (typescript 6.0.3,
TS2593 on every test file until `"types": ["jest","node"]` was added). **Confidence:** verified.

### 5. NestJS converts multer errors before filters see them (hash `2ac2040c33c44e66`)

**Claim.** Catch `PayloadTooLargeException` / `BadRequestException` in a route-scoped filter;
`@Catch(MulterError)` never matches.

**Sources checked.**
- https://github.com/nestjs/nest/blob/master/packages/platform-express/multer/multer/multer.utils.ts —
  `transformException` maps `LIMIT_FILE_SIZE` → `PayloadTooLargeException`, the other limit codes and
  busboy multipart errors → `BadRequestException`, and returns an existing `HttpException` unchanged.
- https://github.com/nestjs/nest/blob/master/packages/platform-express/multer/interceptors/file.interceptor.ts —
  `const error = transformException(err); return reject(error);`
- https://github.com/nestjs/docs.nestjs.com/blob/master/content/http/file-upload.md and
  https://docs.nestjs.com/exception-filters — interceptor package, Fastify support since v12.1,
  `@Catch()` taking a list.

**How verified.** Source read at `master`; it matches the installed v12.1.1 files the session cited.
My first draft said the interceptors were Express-only — the docs source says otherwise (Fastify
"fail[s] with the same error responses"), and the page now quotes that. **Confidence:** verified.

### 6. Test files inside an Expo Router `app/` directory (hash `6351fb01402f3072`)

**Claim.** Keep tests outside `app/`, set `testMatch`, gate with `find`.

**Sources checked.**
- https://docs.expo.dev/router/reference/testing/ — "do not put your test files inside the **app**
  directory. All files inside your **app** directory must be either routes or layout files."
- https://github.com/expo/expo/blob/main/packages/expo-router/_ctx-shared.js — `EXPO_ROUTER_CTX_IGNORE`
  excludes only `+api`, `+html`, `+native-intent` files.

**How verified.** Docs and source read; agree with the session's bundle check (0 matches after the
move). **Confidence:** verified.

### 7. A production default built when no dependency is injected (hash `a04affcb8f9efcba`)

**Claim.** Add one no-deps test with an option-sensitive module mock; assert options and result.
**Sources.** https://nodejs.org/api/dns.html — `all`: "When `true`, the callback returns all resolved
addresses in an array. Otherwise, returns a single address." Field reproduction from the session
(208 injected-fake tests stayed green when `all: true` was dropped; the new test went red).
**Confidence:** verified for the API fact; the testing directive is field-tested and the row says so.

### 8–9. Absence assertions and pending-timer counts in RN tests (hashes `db7200205af493f5`, `e29ba497975c6095`)

**Claims.** Await the replacing element before asserting absence; measure the `getTimerCount()`
baseline before using zero as cleanup proof.
**Sources.** https://testing-library.com/docs/guide-disappearance/ (`waitFor` for disappearance,
`queryBy` for absence); https://jestjs.io/docs/jest-object — `getTimerCount()` "Returns the number of
fake timers still left to run". Field evidence: 1/14 failure → 15/15; baseline count 3 right after
render. **Confidence:** verified API facts + field-tested numbers (stated in the source bullets).

### 10. A PreToolUse hook's `ask` under bypass mode (hash `34ac020d10e2f021`)

**Claim.** Treat `ask` as a real prompt; return no decision when nothing must be blocked.
**Sources.** https://code.claude.com/docs/en/hooks — "`"ask"` prompts the user to confirm"; "A hook's
`"ask"` also forces a permission prompt in auto mode". The docs do **not** name `bypassPermissions`
for this; that part rests on the session's measurement (252 `ask` calls, median 33.1 s vs 1.6 s for
3,708 calls with no decision, Claude Code 2.1.285). **Confidence:** field-tested for the bypass-mode
behaviour — the row and its source bullet say this in plain words.

### 11. A test title that promises an unasserted side effect (hash `3ba02839a99afd2a`)

No external source; one field case (a 502 e2e case titled "…and nothing is saved" with no list
assertion). **Confidence:** field-tested; added as one edge row.

### 12. Approving a worker's `git reset --soft HEAD~1` (hash `b5e05605ba940bd`)

**Source.** https://git-scm.com/docs/git-reset — `--soft`: "Leave your working tree files and the
index unchanged." Field evidence: worktree HEAD was another task's merged commit; request refused.
**Confidence:** verified git semantics + field-tested procedure.

### 13. Guard hook fires on the English word "truncate" (hash `527ded4a9b379b6d`) — dropped

The trigger is one plugin's regex, and the wiki already owns the situation with a different, more
general directive (see Existing-layer check). Not ingested.

## Existing-layer check

Pages read: testing-async-async-testing, testing-quality-default-values-under-test, testing-quality-minimum-case-set, platforms-tools-deny-rules-under-bypassed-permissions, infrastructure-agent-orchestration-worktree-isolated-workers, platforms-shells-command-text-inspected-before-execution, platforms-processes-non-interactive-cli-invocation

Read in full: `INDEX.md` and the `platforms`, `testing`, `infrastructure`, `mobile`, `frontend`,
`backend/node` indexes; the `backend` and `qa` indexes by table rows. The seven pages above were
opened at the sections that matter (trigger, edge-case and instead-of tables, sources). Grepped only,
not read: `portable-shell-scripts`, `bsd-vs-gnu-cli`, `tests-that-cannot-fail`,
`checkable-claims-in-an-adopted-plan`, `completion-claims`, `what-to-mock`.

`wiki_search` (k=5) per candidate found no page with the same trigger; top hits were
`checks-that-cannot-pass` (0.736) for the read loop, `scope-purity-checks` (0.742) for multer,
`compiler-as-call-site-inventory` (0.732 / 0.696) for TypeScript and Expo, `what-to-mock` (0.781) for
the default dependency, `async-testing` (0.770) for the RN test rows,
`deny-rules-under-bypassed-permissions` (0.723) for the hook, `scope-purity-checks` (0.797) for the
title/reset pair, `command-text-inspected-before-execution` (0.765) for the dropped candidate.

Overlaps and decisions:
- `non-interactive-cli-invocation` already teaches `cmd </dev/null` for a tool that can prompt. The
  loop-drain case is a different trigger (a loop losing its items), so it went on the new page with a
  two-way link.
- `async-testing` already says "poll the condition" and "fail teardown when `jest.getTimerCount() > 0`".
  The two new edge rows refine those (absence needs a positive wait first; zero is not the baseline
  under RN test libraries). Merged as rows, not a new page.
- `default-values-under-test` covers numeric defaults; the default-collaborator case was merged there
  as one edge row.
- `minimum-case-set` already has "a guarantee in Steps prose that is not in the Verify list"; the
  title-clause case sits next to it as one row.
- **Conflict avoided, not created:** `command-text-inspected-before-execution` tells the author to
  move scanner-tripping prose into a file "rather than reshaping the sentence". Candidate 13 says the
  opposite (respell the word). The existing directive is the general one; candidate dropped.
- New `related:` links added both ways on `non-interactive-cli-invocation`, `runtime-validation`,
  `deep-links-and-entry-points`. Back-links on `portable-shell-scripts`, `bsd-vs-gnu-cli` and
  `version-management` are deferred: open PRs #223, #228 and #227 rewrite those files.

Checks run: `node scripts/wiki-structure-checks.js wiki` → `pages: 359, indexes: 13, findings: 0`;
`node scripts/wiki-lint-prohibitions.js wiki` → `violations: 0`.

## Open-PR check

Open `knowledge/*` heads listed with `gh pr list … --search "head:knowledge/"` (8): #223
`…20260927-220735`, #225 `…20260928-082803`, #226 `…20260928-092831`, #227 `…20260928-103056`, #228
`…20260928-134840`, #229 `…20260928-145025`, #230 `…20260928-155239`, #231 `…20260928-191901`.

For each head I listed `git diff --name-status origin/main...origin/<head> -- wiki/` and searched its
added lines for each candidate's key terms (multer, `awk -v`, `|| [ -n`, TypeScript 6, getTimerCount,
expo-router, permissionDecision, `exec -T`, `reset --soft`, …): no hits in any head.

| Candidate | Overlapping open PR | Verdict |
|-----------|--------------------|---------|
| 1–3 read loops | none (#223 edits `portable-shell-scripts`, #228 edits `bsd-vs-gnu-cli`, neither on this topic) | new |
| 4 TypeScript 6 types | none | new |
| 5 NestJS multer | none | new |
| 6 Expo Router tests | none (#229 adds an unrelated `mobile/state` page) | new |
| 7 default collaborator | none | new (row) |
| 8–9 RN test rows | none on topic; #226 and #228 edit other lines of `async-testing` | new (rows placed away from their hunks; frontmatter untouched) |
| 10 hook `ask` | none (#223's hook-input-fields page is about input fields) | new (row) |
| 11 test title | none | new (row) |
| 12 reset approval | none; #223 changes only `last_verified` of `worktree-isolated-workers` | new (row; frontmatter untouched) |
| 13 truncate false positive | #230 edits `command-text-inspected-before-execution` on heredocs | drop (covered by the merged page) |

Expected merge friction: `log.md` (every open PR appends to it) and one index row each in
`wiki/platforms/index.md` / `wiki/mobile/index.md`, inserted at lines the open PRs do not touch.

## Routing decision

| Insight | Target | New or merged |
|---------|--------|---------------|
| 1–3 | `platforms/shells/line-by-line-read-loops` | new page (three candidates, one trigger) |
| 4 | `platforms/toolchains/typescript-6-global-types` | new page |
| 5 | `backend/node/boundaries/nestjs-multer-upload-errors` | new page |
| 6 | `mobile/navigation/test-files-in-expo-router-app-directory` | new page |
| 7 | `testing/quality/default-values-under-test` | +1 edge row, +1 source |
| 8–9 | `testing/async/async-testing` | +2 edge rows, +2 sources |
| 10 | `platforms/tools/deny-rules-under-bypassed-permissions` | +1 edge row, +2 sources |
| 11 | `testing/quality/minimum-case-set` | +1 edge row, +1 source |
| 12 | `infrastructure/agent-orchestration/worktree-isolated-workers` | +1 edge row, +1 source |
| 13 | — | dropped |

No new category. The NestJS page went under `backend/node/boundaries` (the request boundary of a Node
service); the Expo page under `mobile/navigation` because the rule comes from the file-based router.

## Local-layer candidates

112 `plan-gaps` rows, all from `linkly-apply-mate-cuskeel`, all with a trigger of the form
"Planning <task>: deciding … (no owning wiki page)" (t1-api-foundation 15, t1d-llm-schema-error 4,
t2-mobile-foundation 11, t3-profile 16, t4-posting-ingest 23, t5-company-insight 16,
t6-resume-tailor 21, t7-interview-guide 6). I read a sample of 8 in full; each directive names that
repository's own files and module wiring (`apps/api/src/profile/profile.module.ts`,
`apps/mobile/app/profile/edit.tsx`, …). The other 104 were classified by the shared trigger shape
and repo tag, not read one by one. Target for any worth keeping:
`wiki-local/<domain>/<category>/<slug>.md` in `linkly-apply-mate-cuskeel` — run wiki-ingest inside
that project.

## Independent review

A fresh-context adversarial reviewer (read-only) ran the three checks of
`.github/wiki-agent-gate-prompt.md` against the diff before the commit: **VERDICT: pass**, 0 blockers,
5 advisories. It re-fetched or grepped every added quote, and reproduced the shell, awk,
`docker compose exec -T` (real container: 1 of 3 iterations without `</dev/null`, 3 of 3 with) and
`git reset --soft` claims. Advisories and what was done:
1. hook `ask` under bypass mode is field-measured only on a `verified` page → the row now says so in its own text.
2–3. one-way links to `version-management`, `portable-shell-scripts`, `bsd-vs-gnu-cli` → left deferred (open PRs #227, #223, #228 rewrite those files); add the back-links after they merge.
4. Fastify row was more cautious than the docs → now quotes "fail with the same error responses".
5. "TS2593" was not in the cited source → removed from the trigger; it remains only in the field-evidence bullet where it was observed.

