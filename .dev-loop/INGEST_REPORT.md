# Knowledge flush — 3 insight(s) (29 claimed rows: 2 ingested as new pages, 1 folded onto open PR #225, 26 plan-gap rows retired as local-layer)

Run id `20260928-134800-34863` (inherited from the auto-flush parent; lock held under that id). Branch `knowledge/choiyounggi-20260928-134840` off `origin/main` 5986311.

## Verified best-practice

### 1. Deleting a resource that spawned async tasks still use — `testing-async-teardown-after-aborted-tasks` (NEW, confidence: verified)

**Claim.** In a test (or shutdown path) that spawned tokio tasks, put teardown on the single path every outcome takes (record the outcome, tear down, then assert / `?`), and inside teardown abort **and await** every reachable `JoinHandle` before deleting the directory/socket; keep `Drop` only as the net for failures before the runtime/handles exist.

**Sources checked (fetched this run).**
- https://docs.rs/tokio/latest/tokio/task/index.html#cancellation — "the task is signalled to shut down next time it yields at an `.await` point"; "calls to `JoinHandle::abort` just schedule the task for cancellation, and will return before the cancellation has completed".
- https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html — "It is guaranteed that the destructor of the spawned task has finished before task completion is observed via `JoinHandle` await"; dropping a handle "detaches the associated task"; `abort` on a started `spawn_blocking` task "will not have any effect".
- https://docs.rs/tokio/latest/tokio/runtime/struct.Runtime.html#shutdown — on drop, tasks "keep running until they yield. Then they are dropped. They are not guaranteed to run to completion".
- https://doc.rust-lang.org/book/ch11-01-writing-tests.html#using-resultt-e-in-tests — section confirmed present ("We can also write tests that use `Result<T, E>`!").

**Local reproduction (this run, scratch crate under the project's `.claude/tmp/`, removed afterwards).** tokio 1.53.1 from the cargo registry cache, cargo 1.98.0, macOS, `multi_thread` runtime with 4 workers; a spawned task loops `create_dir_all` → `write` → `yield_now` with ~400 µs of non-yielding work per iteration.
- `abort()` then `remove_dir_all` immediately: directory left behind **148/200** runs.
- `abort()`, `await` the handle, then `remove_dir_all`: **0/200**.
The candidate's "why" said an aborted task "still gets one more poll"; the docs say cancellation is scheduled and a running task continues to its next `.await` — the page uses the documented wording, and the reproduction confirms the effect the candidate observed.

**Field evidence (from the harvested row, not re-run).** handfish crew-run task t3-swap-flake: `RunHandle::shutdown` aborted every task but awaited only the bus; leftover `.crew-test/<uuid>` dirs 1/3 (pass path) and 2/3, 3/3 (panic path) before, 0/12 after.

### 2. A path ending in a separator passed to realpath / canonicalize — `platforms-filesystems-trailing-separator-under-realpath` (NEW, confidence: verified)

**Claim.** When a path that may end in `/` (or `/.`) is resolved through `realpath(3)` and the result decides containment or file-vs-directory, check the raw string before resolving and decide by intent (reject, or require `is_dir()` after resolving); the resolver's `ENOTDIR` is platform-dependent.

**Sources checked (fetched this run).**
- https://pubs.opengroup.org/onlinepubs/9699919799/functions/realpath.html — ERRORS, "shall fail": `[ENOTDIR]` "… ends with one or more trailing <slash> characters and the last pathname component names an existing file that is neither a directory nor a symbolic link to a directory".
- https://doc.rust-lang.org/std/fs/fn.canonicalize.html — "corresponds to the `realpath` function on Unix and the `CreateFile` and `GetFinalPathNameByHandle` functions on Windows".
- https://doc.rust-lang.org/std/path/index.html — "Several methods in this module perform basic path normalization by disregarding repeated separators, non-leading `.` components, and trailing separators"; "`Path::join` and `PathBuf::push` also disregard trailing slashes".
- https://www.gnu.org/software/coreutils/realpath — "It ignores trailing slashes" (the coreutils *command*; text seen in the search result excerpt of that page — the direct fetch hit HTTP 429 this run).

**Local reproduction (this run).** libc `realpath` called through Python `ctypes` on a regular file `out/report.md`:
- macOS Darwin 25.1.0: `out/report.md/` → `Ok(out/report.md)`, `out/report.md/.` → `Ok(out/report.md)`.
- `python:3-slim` (glibc 2.41, docker): both → `errno 20 Not a directory`.
- `python:3-alpine` (musl, docker): both → `errno 20 Not a directory`.
- Rust (cargo 1.98.0, macOS, scratch crate): `base.join("out/report.md/")` keeps the slash (`ends_with(is_separator) == true`), `std::fs::canonicalize` → `Ok(…/out/report.md)`; `Path::new("out/report.md/") == Path::new("out/report.md")` → `true`.
The `/.` suffix divergence (missed by `ends_with(is_separator)`) was found in the reproduction and added as an edge row.

**Field evidence (from the harvested row).** handfish t3-swap-flake: containment accepted `…/out/report.md/` on macOS; guard pinned by test `path_entry_with_trailing_slash_is_missing_file_not_found`; an auditor's mutation removing the guard turned it red.

### 3. Kotlin top-level helper shadowed by a receiver member inside `apply {}` — FOLDED onto open PR #225

**Claim.** Name fixture helpers so they cannot collide with members of the fakes they are used against, or call them outside the `apply` block. Already carried by PR #225's page `backend-java-kotlin-implicit-receiver-shadowing-in-scope-functions` (sources: kotlinlang overload-resolution spec, scope-functions docs; verified there). The candidate's unique addition — a `suspend` member called *inside `runTest`* compiles cleanly and fails only at runtime with the fake's stub error (`NotImplementedError`) — was not in that page (its edge row covered only the non-coroutine caller, which is a compile error). Pushed as one commit to that PR's branch: `0708082` on `knowledge/choiyounggi-20260928-082803` (one edge row + one field-evidence line: `CalendarViewModelTest`, 3 failures → `trip()` renamed `makeTrip()` → 14/14). Not re-ingested here.

## Existing-layer check

Pages read: testing-async-async-testing, testing-data-artifact-leakage-from-a-suite, testing-data-test-data-and-isolation, security-input-validation-at-trust-boundaries, infrastructure-config-path-valued-config, platforms-tools-bsd-vs-gnu-cli, platforms-filesystems-paths-case-and-line-endings, platforms-filesystems-unix-domain-socket-path-length

Also read: `INDEX.md`, `wiki/testing/index.md`, `wiki/platforms/index.md`, `wiki/security/index.md`, `wiki/backend/index.md` (routing), `templates/page.md`, `AGENTS.md` format rules, `log.md` tail.

Semantic dedupe (`wiki_search`, k=5):
- Insight 1 trigger → top hits: artifact-leakage-from-a-suite (edge "Cleanup exists but does not run on failure", 0.780), test-data-and-isolation (0.772), testcontainers-reaper (0.770), artifact-leakage directive rows (0.770, 0.764). None covers the async-runtime mechanism (abort is asynchronous; a running task recreates the path). artifact-leakage's edge row covers the *panic-skips-trailing-cleanup* half only and points at a fixture teardown as the fix — which is the racy `Drop` in the async case. **Verdict: new page**, with an edge row on artifact-leakage and on async-testing pointing to it. No conflicting directive found: the new page extends "teardown that runs on failure too" with the ordering the runtime requires.
- Insight 2 trigger → top hits: paths-case-and-line-endings (0.801, "use the language's path API"), validation-at-trust-boundaries (0.785, "Canonicalize … then verify the resolved path starts with the base prefix"), unset-versus-empty-parameters (0.775), paths-case edge (0.760), unix-domain-socket-path-length (0.751). validation-at-trust-boundaries prescribes canonicalize-then-prefix-check; the new page does not contradict it — it adds the trailing-separator rule the canonicalize step needs to be platform-independent. **Verdict: new page**; edge rows added on validation-at-trust-boundaries and bsd-vs-gnu-cli (the libc divergence, as opposed to the coreutils one already on that page).
- Grep sweep of merged `wiki/` for `JoinHandle|abort()|tokio`, `canonicalize|realpath|trailing (slash|separator)|path traversal|ENOTDIR`: no page owns either trigger (hits were unrelated mentions in frontend/node/testing-quality pages, bsd-vs-gnu-cli's `readlink -f` row, unix-domain-socket-path-length's "realpath can lengthen a path" row).

Merged vs created: 2 pages created; 0 merged. Amended: async-testing (edge row), artifact-leakage-from-a-suite (edge row + related), validation-at-trust-boundaries (edge row + related), bsd-vs-gnu-cli (edge row + related), test-data-and-isolation (related), paths-case-and-line-endings (related), path-valued-config (related). Domain indexes: testing (async section), platforms (filesystems section). `log.md`: 2 ingest lines.

Deferred back-link: `async-testing.md`'s `related:` line is rewritten by open PR #226 — not touched here (the new page links to async-testing one way; the edge row on async-testing carries the inline `[id]` link). Expected merge overlap: `wiki/testing/index.md` async section — PR #226 also appends one row after `async-testing`; both rows are keepable, adjacent-line conflict only.

Lint run on the checkout (this branch): `node scripts/wiki-structure-checks.js wiki` → `pages: 355, indexes: 13, findings: 0` (after removing a `related:` id that pointed at PR #226's not-yet-merged page — that cross-link is deferred until #226 lands); `node scripts/wiki-lint-prohibitions.js` → `directives: 79, compliant: 79, violations: 0`; `node scripts/wiki-lint-model-era.js wiki` → 6 pre-existing `revalidate` rows on other pages, none on the two new ones. Banned-qualifier grep on both new pages: no hits. Body lines: 74 and 76 (≤120).

## Open-PR check

Open `knowledge/*` heads (listed with `gh pr list --search "head:knowledge/"`, then `git fetch` + `git diff --stat origin/main origin/<head> -- wiki/`):
- #227 `knowledge/choiyounggi-20260928-103056` — platforms/toolchains native-addon page + back-links. No overlap with any candidate. Touches `wiki/platforms/index.md` (toolchains section) — different section from my filesystems row.
- #226 `knowledge/choiyounggi-20260928-092831` — testing/async `transient-state-behind-a-controlled-gate` (parking a transient state behind a test-controlled gate; tokio sources) + edits to `async-testing.md` (Do-this table row + `related:`) and `testing/index.md`. Read the page: it covers *observing* mid-run state before a finisher wipes it, not tearing down after tasks; its edge row on the `JoinHandle` await guarantee is the *post-wipe* ordering point, which my page cites for the opposite direction (delete after the await). **Insight 1 verdict: new** (related-linked both ways from my side only; their `related:` line is theirs to rewrite). Insight 2/3: no overlap.
- #225 `knowledge/choiyounggi-20260928-082803` — 12 insights incl. `backend/java/kotlin/implicit-receiver-shadowing-in-scope-functions`. **Insight 3 verdict: fold** — same trigger and directive; pushed the unique `runTest`/`suspend` edge row + second field evidence to that branch (commit `0708082`). Insight 1/2: no overlap (its testing pages are fake-intersection-observer and alias-table-contract-tests).
- #223 `knowledge/choiyounggi-20260927-220735` — 15 insights (gitignore, jq, shell redirection, hook fields, fake-server, shared-helper invariant, WebMCP retirements). No overlap with any candidate; touches `wiki/platforms/index.md` (shells/tools sections) and `wiki/testing/index.md` (strategy/quality sections), none of the pages I amended.

Per-candidate: insight 1 → **new**; insight 2 → **new**; insight 3 → **fold** (#225).

## Routing decision

- Insight 1 → `testing/async/teardown-after-aborted-tasks.md` (id `testing-async-teardown-after-aborted-tasks`, `applies_to: [rust, general]`). Category `async` ("testing async code") fits; `data` (artifact leakage) is the symptom page and now links here. General layer: the directive names tokio's documented primitives, no repository files.
- Insight 2 → `platforms/filesystems/trailing-separator-under-realpath.md` (id `platforms-filesystems-trailing-separator-under-realpath`, `applies_to: [general, rust]`). `platforms` owns "OS-level differences that break code moving between macOS, Linux"; `filesystems` is the existing category (no new category). Not `security/input` because the mechanism is a libc divergence that also bites non-security file/dir checks; security's page gets the edge row instead. Not `backend` because backend has no rust subtree and the divergence is language-independent (reproduced through ctypes and Rust).
- Insight 3 → no page here; folded to #225's `backend/java/kotlin/implicit-receiver-shadowing-in-scope-functions.md`.

No new category.

## Local-layer candidates

26 `plan-gap` rows (all `wiki-plan Phase B found no wiki page for this decision`), each a one-repository design record whose directive names that repo's own files, constants, RFC numbers or Gradle pins; retired as local-layer, none ingested here. Run `wiki-ingest` inside each project if the team wants them in its `wiki-local/`:

seagrass (linkly), task t177-numeric-guard-predicate — 8 rows:
- 857a9c208d359757 AST `NumericPredicate` + `NUMERIC_PREDICATE_KINDS` table relocation → `wiki-local/backend/dsl/numeric-predicate-ast-and-reserved-words.md`
- a682672e179db2c9 predicate allowed inside `and` → `wiki-local/backend/dsl/numeric-predicate-inside-and.md`
- 4e812c39753bdfdb mode A truth table / collector entry / `And`-loop dispatch → `wiki-local/backend/dsl/numeric-predicate-runtime-truth-table.md`
- 4d2e49a35884f3a2 RFC-0050 Draft status and Updates chain → `wiki-local/qa/rfc-process/draft-rfc-updates-chain.md`
- 7ea992c6e8d75ee1 vocab manifest exposure of both kind tables → `wiki-local/backend/dsl/vocab-manifest-keyword-tables.md`
- c2e7bd7c0e686db2 RFC_ROUTES / README x2 / CHANGELOG registries → `wiki-local/qa/document-verification/rfc-registry-edits.md`
- c1590d9a2589c4e4 golden-adjacent example as RFC prose + interp fixture → `wiki-local/testing/strategy/rfc-prose-example-over-committed-example.md`
- 65455353e647d7b7 parser/spec need no change → `wiki-local/backend/change-impact/generic-condition-call-sites.md`

handfish (linkly-crew), t3b-agent-ctrl-drain — 1 row:
- a5df88a34fb09359 unserved control answered per exit arm → `wiki-local/backend/concurrency/unserved-control-reply-per-exit-kind.md`

handfish, t7-run-gitflow — 7 rows:
- c5a56580a3d35022 `role_harness_cfg` flag flip site + unit test → `wiki-local/backend/config/role-harness-cfg.md`
- 4ac881caab90c7e5 sprint merge site and preconditions → `wiki-local/infrastructure/gitflow/sprint-merge-preconditions.md`
- 49365920900bd98a `-c core.hooksPath=/dev/null` on every git call → `wiki-local/infrastructure/gitflow/disable-hooks-per-invocation.md` (general kernel — "when automation commits on a user's repo, disable all hooks per invocation with `core.hooksPath=/dev/null`, not `--no-verify`" — is worth a future general candidate once a session emits it with its own evidence; the row as harvested is a design record)
- cdad68524684790e push policy (fast-forward only, lfs check) → `wiki-local/infrastructure/gitflow/push-policy.md`
- 16f783345eb7467f `project_root None` issues zero git commands → `wiki-local/testing/quality/git-call-counter-seam.md`
- 6e256af812509084 resolving the main branch → `wiki-local/infrastructure/gitflow/resolve-main-branch.md`
- a298a037475db1c0 merged agent files that self-execute (residual risk) → `wiki-local/security/agent-exposure/merged-agent-files-residual-risk.md`

dace (linkly-calendar Android), t6a-trip-ui — 10 rows:
- 7068f2146ea1e6b9 Maps key gate `isValidKey`/`readManifestKey` → `wiki-local/mobile/maps/google-maps-key-gate.md`
- 3042cba1f8844f84 who constructs `TripViewModel` → `wiki-local/mobile/architecture/tab-root-receives-viewmodel.md`
- d771e774c84744e2 `OPTIMIZE_APPLY_FAILED_MESSAGE` constant + local state → `wiki-local/mobile/presentation/local-error-message-constant.md`
- c3868b8e8b2fab3b `moveItem`/`removeItem` pure functions → `wiki-local/mobile/presentation/itinerary-move-remove.md`
- 772f3a2a727f3cfe `tripDatesInRange`/`tripShortDisplay` on `LocalDate` → `wiki-local/mobile/presentation/trip-date-helpers.md`
- 07729881a03fce5f `MarkerComposable` badges → `wiki-local/mobile/maps/marker-composable-badges.md`
- 25c323dfe8e9f66c hand-rolled `decodePolyline` + test file → `wiki-local/mobile/maps/decode-polyline.md`
- 8979225a66711966 maps-compose 6.6.0 / play-services-maps 20.0.0 pins from Gradle Module Metadata → `wiki-local/mobile/dependencies/maps-compose-pins.md` (general kernel — verify a transitive floor from the artifact's `.module` `requires` vs `strictly`, not from an HTTP 200 — is a future general candidate)
- eef21f20e6149557 `MapStyle.light` null on parse failure → `wiki-local/mobile/maps/map-style-null-fallback.md`
- 081eb80b1695e007 `.orchestration-notes/t6a-trip-ui.md` contents → `wiki-local/infrastructure/agent-orchestration/task-notes-file.md`

Count check: 8 + 1 + 7 + 10 = 26.
