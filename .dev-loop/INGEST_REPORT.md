# Knowledge flush — 2 insight(s) + 26 plan-gap rows

Flush run id `20260928-092537-1352` (inherited from the auto-flush hook that spawned this session via `DEV_LOOP_FLUSH_RUN_ID`; step-0 acquire returned `already-owned` — a first attempt with a fresh run id was refused with `held 20260928-092537-1352 81s`, and the process tree showed the holder is this session's own parent `hooks/auto-flush.sh`). Branch `knowledge/choiyounggi-20260928-092831` off `origin/main` at `5986311`. Claimed via `queue-claim.js claim` → 28 ids: 2 session candidates (`f6e9703c7f44b032`, `3693d1c0d6feb6d3`) + 26 `plan-gaps.jsonl` rows.

Outcome: **1 new page, 2 amended pages, 2 domain indexes updated, no new category**; 2 of 2 session candidates ingested; 26 of 26 plan-gap rows excluded as project-specific (Local-layer candidates below).

Gates run on the edited checkout: `node scripts/wiki-structure-checks.js wiki` → `pages: 354, indexes: 13, findings: 0` (untouched baseline: 353 / 0); `node scripts/wiki-lint-prohibitions.js` → `violations: 0` (baseline 0); new page body 76 lines; no banned qualifier in any added line (grep for usually/often/consider/might want/generally/typically/probably/as appropriate over `git diff -U0 -- wiki/` + the new page → 0 hits after two rewrites).

## Verified best-practice

### 1. Park an async orchestrator behind a test-controlled decision to assert on a transient mid-run state (`f6e9703c7f44b032`, repo t3-swap-flake)

- **Claim.** When a test must read a mid-run state that a background finisher/reaper will wipe, drive the system into a state whose only exit is a decision the test controls (unresolved approval gate, withheld ack), assert inside that park, then release and await the finisher. Reuse the gate's own fixture; disable every other exit (tick timeouts); prove by mutating every finisher spawn site and looping.
- **Sources checked (fetched 2026-09-28).**
  - https://martinfowler.com/articles/nonDeterminism.html — "Never use bare sleeps to wait for asynchonous responses: use a callback or polling"; Humble Object so logic "can be tested synchronously". The park is the synchronous-ordering form of that advice for a state that is transient (polling cannot distinguish "not yet" from "already wiped").
  - https://testing.googleblog.com/2021/03/test-flakiness-one-of-main-challenges.html — "You should never need any type of sleep or wait in your test automation … Wait() is as good as Hope()".
  - https://tokio.rs/tokio/topics/testing — paused time makes timer-driven futures deterministic ("any time-related future may become ready early"); it orders timers, not tasks against each other — recorded as an edge row so the page does not overclaim what paused time buys.
  - https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html — destructor-before-`await`-returns guarantee: the handle is the ordering point for the *post*-wipe state; the park is for the *pre*-wipe state.
- **Local reproduction (this flush, Node v26.7.0, script written under the project's `.claude/tmp/` and deleted in the same command):** a startup seeds a `Map` and spawns a finisher that clears it on the next timer turn. Read right after startup → 0/200 failures (looks deterministic). Same read after one scheduler turn of pressure → 200/200 failures. Finisher parked behind a promise the test resolves after the read, same pressure → 0/200 failures and the map is empty after release every run.
- **Field evidence (recorded by the originating session, not re-run here):** `escalation_timeout_ms = 0` disabled the lead's tick branch (`crates/crew-lead/src/dispatch.rs:576`), so a planted violation with `max_rework = 0` held the lead task open until `resolve_gate`; mutating both `tokio::spawn(reap_controls_entry(` sites → `FAILED ... Elapsed(())` at 30.03 s; restored → `ok. 4 passed`; 20/20 stable.
- **Confidence: verified** (official-doc principles + a reproducible local check + field mutation evidence).

### 2. A PASS verdict whose body records a surviving mutant is a finding, not a clearance (`3693d1c0d6feb6d3`, repo t5-proto)

- **Claim.** When a test-quality auditor or reviewer returns PASS but its body notes that a mutation survived (labelled "secondary"), map every surviving mutant to the brief's own requirement list; a guarantee the brief states literally is a missing test whatever label the reviewer gave it — add the killing case and resume the same reviewer to reproduce the kill.
- **Sources checked (fetched 2026-09-28).**
  - https://pitest.org/quickstart/basic_concepts/ — "Survived: the mutation was not detected by the covering test" (verbatim re-fetched); the survivor is a coverage statement independent of any reviewer's verdict scope.
  - https://mutants.rs/using-results.html — "missed — No test failed with this mutation applied, which seems to indicate a gap in test coverage" (verbatim).
  - Local reading of this repo's `agents/test-quality-auditor.md`: the FAIL list is no-assertion / disabled cases / uncovered *changed behavior* / rubber-stamping / the case-count floor, output is `VERDICT: PASS | FAIL` + one justification line — coverage of every stated guarantee is not among the FAIL conditions, so a PASS body can carry a surviving mutant without contradiction. This is the mechanism the candidate's "why" described.
  - Already-cited on the merge target: https://google.github.io/eng-practices/review/reviewer/standard.html (reviewers work from partial context; facts override opinion).
- **Field evidence (recorded by the originating session, not re-run here):** `cargo test -p crew-proto` 12→13 tests; under the `deny_unknown_fields` mutant `unknown_entry_fields_are_tolerated ... FAILED`; under a `.rev()` mutant `malformed_entry_is_dropped_and_valid_sibling_kept ... FAILED`; restored → 82 passed; the resumed auditor reproduced both kills and returned PASS.
- **Confidence:** the survivor semantics are **verified** against the tool docs; the review-process directive is **field-tested** (one production incident + the auditor contract). Merged into pages that already carry `field-tested` (evaluating-review-feedback) and `verified` (surviving-mutant-equivalence-triage, whose new row is a routing pointer plus field evidence, not a new mechanism claim); neither page's confidence was changed.

## Existing-layer check

Pages read: testing-async-async-testing, testing-flaky-diagnosing-flaky-tests, testing-quality-tests-that-cannot-fail, testing-quality-narration-based-ordering-assertions, testing-quality-proving-a-critical-section-is-lock-protected, testing-quality-surviving-mutant-equivalence-triage, testing-quality-harness-reverse-controls, testing-quality-minimum-case-set, qa-process-evaluating-review-feedback, qa-process-fresh-context-code-review, qa-process-completion-claims, testing-async-transient-state-behind-a-controlled-gate

Semantic dedupe (`wiki_search`, k=5) top hits — candidate 1: infrastructure-agent-orchestration-control-signals-vs-primary-artifacts (0.729), testing-async-async-testing ×2 (0.728, 0.725), qa-environments-test-environment-parity (0.722), testing-data-testcontainers-reaper-on-docker-desktop-macos (0.720). Candidate 2: testing-quality-tests-that-cannot-fail ×2 (0.764, 0.762), testing-quality-narration-based-ordering-assertions (0.758), qa-process-completion-claims (0.758), testing-quality-unasserted-return-fields (0.747). No hit's "When this applies" describes either candidate's situation.

| Candidate | Overlap found | Decision |
|-----------|---------------|----------|
| 1 park | `testing-async-async-testing` covers waiting for a *final* state (condition wait, fake timers, completion handle) — the transient-state case is absent; `testing-flaky-diagnosing-flaky-tests` sleep row says "wait on the completion condition", which a transient state has no form of. No conflict. | **New page** `wiki/testing/async/transient-state-behind-a-controlled-gate.md`. Back-link: `async-testing` gains a table row + `related:`; `testing/index.md` async section gains the row. `related:` one-way to diagnosing-flaky-tests, tests-that-cannot-fail, narration-based-ordering-assertions, proving-a-critical-section-is-lock-protected. Reciprocal `related:` on diagnosing-flaky-tests and tests-that-cannot-fail **deliberately deferred**: open PR #223 rewrites both pages' `related:` lines, and a second edit here would conflict on merge (see Open-PR check). |
| 2 PASS+survivor | `testing-quality-surviving-mutant-equivalence-triage` classifies a survivor on code you own but has no row for "reported inside a passing review"; `qa-process-evaluating-review-feedback` is the page for "findings arrived, decide what to implement" and already carries the partial-context mechanism. `qa-process-fresh-context-code-review` step 4 ("return only the verdict") is not a conflict — it concerns what flows *back* into the producing session's next round, while this candidate reads the reviewer's own report body. | **Merge** into `evaluating-review-feedback` (trigger sentence, edge row, instead-of row, 2 sources + local reading + field evidence, `related:` +surviving-mutant-equivalence-triage +fresh-context-code-review) and a reciprocal edge row + field evidence + `related:` on `surviving-mutant-equivalence-triage`; `qa/index.md` load-when widened. |

Conflicts flagged: none.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` → two open heads: **#223** `knowledge/choiyounggi-20260927-220735` and **#225** `knowledge/choiyounggi-20260928-082803`. Both fetched; `git diff --name-only origin/main origin/<head> -- wiki/` read for each, plus the full diff hunks on the pages nearest to each candidate.

| Head | Files touching either candidate's area | Overlap | Verdict |
|------|----------------------------------------|---------|---------|
| #223 | `wiki/testing/flaky/diagnosing-flaky-tests.md` (+row: when the test *holds the finisher's JoinHandle*, await it between write and read to force the bad interleaving red, before the write for green; +edge row on stress-loop reproduction rates; +tokio JoinHandle source), `wiki/testing/mocking/fake-server-forward-before-reply.md` (new), `tests-that-cannot-fail.md` + `captured-call-arguments.md` (`related:` only) | Complementary, not duplicate: #223's row forces a *reproduction* of the race via a completion handle the test already owns; candidate 1 is the case where the pre-wipe state must be observed *green* and no handle helps because the state must still be present — the new page's "no external decision point" row routes to #223's technique, and the JoinHandle guarantee is cited as the ordering point for the post-wipe state. No text on candidate 2's topic. | candidate 1 **new**; candidate 2 **new** |
| #225 | `wiki/testing/quality/alias-table-contract-tests.md`, `wiki/testing/mocking/fake-intersection-observer-for-viewport-animations.md` (new), `wiki/testing/index.md` (rows in quality/mocking) | Its only mutation-related text is a "hardcode the defaults and require red" step and PIT/Google citations on alias tables — a different trigger from "PASS body records a survivor". Nothing on transient async state. | candidate 1 **new**; candidate 2 **new** |
| #223 / #225 | 26 plan-gap rows | none (disjoint hash set from #223's 100 and #225's 77 retired rows) | **drop** — project-specific (below), not pending-duplicate |

Merge-conflict note for the owner: this PR and #223 both add a row to `wiki/testing/index.md` (different sections) and #223 also touches `wiki/qa/index.md` on a different line; `diagnosing-flaky-tests.md` and `tests-that-cannot-fail.md` were left untouched here for that reason.

## Routing decision

| Candidate | Layer | Domain/category | Page | Why here |
|-----------|-------|-----------------|------|----------|
| 1 park | bundled | testing / async | **new** `testing-async-transient-state-behind-a-controlled-gate` | The directive is about how to test an async ordering deterministically, the `async` category's charter; `flaky` is for a test that is already intermittent, and this page is the design that keeps it from becoming one. No new category. |
| 2 PASS+survivor | bundled | qa / process (+ testing / quality pointer) | **merge** `qa-process-evaluating-review-feedback`; reciprocal row on `testing-quality-surviving-mutant-equivalence-triage` | The trigger is "a review verdict arrived and you are deciding what it means", i.e. the process page; the testing page owns what to do with the survivor once you accept it is one. No new category. |

## Local-layer candidates

All 26 `plan-gaps.jsonl` rows are wiki-plan Phase B decisions of the form "Planning tN: deciding X (no owning wiki page)" whose directives name one repository's own files, symbols, values, or route tables (Kotlin `LinklyTextStyle`/`LinklyColor` alias tables, `ScreenContainer.kt`, `dispatch.rs :520-537`, `mock-source.ts:445`, `chat.css` selectors). They fail the layer test (wiki-ingest step 3: would be wrong in another codebase) and are excluded from this PR; run `wiki-ingest` inside the named project to file them. Disposition recorded on each retired row: `dropped: project-specific plan-gap`.

| Hash | Project (cwd) | Decision | wiki-local target |
|------|---------------|----------|-------------------|
| 1bfe8ff35d7ba96d | dace (`~/Desktop/workspace/linkly-calendar/dace`) | t5-screen-restyle: full legacy-name grep-to-zero set | `wiki-local/frontend/design-system/legacy-token-grep-to-zero-set.md` |
| 8085b35b918b9ccc | dace | t5-screen-restyle: alias-to-role rename mapping | `wiki-local/frontend/design-system/alias-to-role-rename-mapping.md` |
| cfa1be9fd8184e59 | dace | t5-screen-restyle: AppRoot.kt's 2 legacy references | `wiki-local/frontend/design-system/approot-legacy-reference-rename.md` |
| fac0e3b1760305fa | dace | t5-screen-restyle: floating tab dock geometry | `wiki-local/frontend/design-system/floating-tab-dock-geometry.md` |
| 86daa209438f656c | dace | t5-screen-restyle: per-tab-item pill styling | `wiki-local/frontend/design-system/tab-item-pill-styling.md` |
| 4d3301ae5c046220 | dace | t5-screen-restyle: tab-hosted-screen bottom inset | `wiki-local/frontend/design-system/tab-hosted-screen-bottom-inset.md` |
| 2c6aa03262ad25b3 | dace | t5-screen-restyle: tab-hosted-screen bottom inset (corrected against verified call sites) | same page as 4d3301ae5c046220 — the corrected revision supersedes it |
| ab0c5d54ca599d04 | dace | t5-screen-restyle: ChatScreen composer inset | `wiki-local/frontend/design-system/chat-composer-bottom-inset.md` |
| ecf4bac7d47b8f02 | dace | t5-screen-restyle: MainTabScaffold structural change | `wiki-local/frontend/design-system/main-tab-scaffold-overlay-dock.md` |
| c94ce34b34a9aff9 | dace | t5-screen-restyle: LinklyChatBubble v2 shape | `wiki-local/frontend/design-system/chat-bubble-v2-shape.md` |
| 9d255cdb6b4cb743 | dace | t5-screen-restyle: LinklyChatBubble partner avatar | `wiki-local/frontend/design-system/chat-bubble-partner-avatar.md` |
| cfb4d875e927de2d | dace | t5-screen-restyle: bubble timestamp text style | `wiki-local/frontend/design-system/chat-bubble-timestamp-style.md` |
| b48f6b37879ac956 | dace | t5-screen-restyle: CoupleSetupScreen invite-avatar | `wiki-local/frontend/design-system/couple-invite-avatar-initial.md` |
| dd1fe7e62611c5d5 | dace | t5-screen-restyle: SettingsScreen couple-avatar header visibility rule | `wiki-local/frontend/design-system/couple-avatar-header-visibility.md` |
| 9d23ccad0e9090fa | dace | t5-screen-restyle: CoupleTogetherDaysCalculator | `wiki-local/frontend/design-system/couple-together-days-calculator.md` |
| dc85e01d2df70e0f | dace | t5-screen-restyle: CoupleAvatarDayHeader placement and content | `wiki-local/frontend/design-system/couple-avatar-day-header.md` |
| d7353fab12a4f0fb | dace | t5-screen-restyle: PhotosScreen scope | `wiki-local/frontend/design-system/photos-screen-token-migration-scope.md` |
| 8e19059c33c9018e | dace | t5-screen-restyle: ChatImageViewer hardcoded literals | `wiki-local/frontend/design-system/chat-image-viewer-scrim-tokens.md` |
| 54462465e1d06013 | dace | t5-screen-restyle: ChatBannerCenter.kt (no change, verified carve-out) | `wiki-local/frontend/design-system/chat-banner-center-carve-out.md` |
| 80edbc00c185b6f3 | handfish (`~/Desktop/workspace/linkly-crew/handfish`) | t6-lead-artifacts-ondisk: same-name entries; dedup across DodCheck::Artifact and artifacts_expected | `wiki-local/backend/lead-judge/artifact-name-dedup-across-dod-and-expected.md` |
| 5e8b85977b985e26 | handfish | t6-lead-artifacts-ondisk: how dispatch passes the cwd | `wiki-local/backend/lead-judge/role-cwd-resolved-once-in-on-envelope.md` |
| 2c8dbcd839163f67 | handfish | t6-lead-artifacts-ondisk: sync vs async filesystem calls | `wiki-local/backend/lead-judge/sync-std-fs-in-judge.md` |
| 0f78e800933d2aaa | handfish | t6-lead-artifacts-ondisk: symlink and special-file fixtures | `wiki-local/backend/lead-judge/symlink-and-fifo-fixtures.md` |
| 1a92fa259582f25b | handfish | t8-fe-conversation: global developer-mode raw-JSON switch (not added) | `wiki-local/frontend/chat/developer-mode-raw-json-switch.md` |
| 180e2831e117e7aa | handfish | t8-fe-conversation: mock-source additions for the 4 missing kinds | `wiki-local/frontend/chat/mock-source-showcase-scenario.md` |
| 5a4cb7ace8c18a04 | handfish | t8-fe-conversation: where the new CSS for mention chips, the "응답 필요" badge, and the thread-side answer widget lives | `wiki-local/frontend/chat/chat-css-ownership-blocks.md` |

Two rows in this set are near-general and were still excluded: `0f78e800933d2aaa` (UnixListener::bind rejected because the fixture path exceeds macOS's 104-byte `sun_path`) is already covered by the bundled `platforms-filesystems-unix-domain-socket-path-length`; `1a92fa259582f25b` (decline an optional settings surface the brief leaves open) is a product-scope call whose reasoning is the brief's, not a reusable trigger.
