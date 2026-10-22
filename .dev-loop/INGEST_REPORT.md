# Knowledge flush — 1 insight(s)

Headless autoflush run, 16 queue rows claimed:
- 1 ingested (merged into an existing page).
- 12 dropped as project-specific `plan-gaps.jsonl` rows (lines 21–32, see Local-layer candidates) and retired.
- 2 released as pending duplicates of open PRs.
- 1 released unread: 97c37473b53e63c2. This run cannot list `~/.dev-loop/queue/`, and its session file could not be located.

## Verified best-practice

**447c9601617b87ca — a regex assertion scanner that a comment can satisfy (merged edge case)**
- Claim: on a unittest-convention file, a `/assert[ \t]/` scanner flags most cases. Any case it passes may be passing only because a comment contains "assert ", so that pass is noise too. Count assertions from the parsed code instead: `ast.parse` → `ast.Assert` nodes plus calls whose function name starts with `assert`. The stdlib AST carries no comments. Check the detector on one unittest file and one pytest file before trusting it.
- Sources checked: https://bugs.python.org/msg315638 (CPython tracker: the built-in AST does not preserve comments or whitespace). https://pypi.org/project/ast-comments/ (a third-party package that adds the `Comment` node type the stdlib tree lacks). https://docs.python.org/3/library/unittest.html (already cited on the page: the assert methods "are used instead of the assert statement").
- Field evidence (from the candidate): `test-floor.sh` 1.32.31 `analyze_pytest` flagged 17 of 18 cases in a unittest file. The 18th passed only on the comment "# surfaced by the assert below". An AST walk found 2–5 `self.assert*` calls in every case.
- Confidence: verified (comment-free AST from the CPython tracker and the ast-comments package; scanner behavior from the field run). The page stays `confidence: verified`.

## Existing-layer check

Pages read: testing-quality-assertion-scanner-false-positive-on-unittest-convention

- `wiki_search` top hits for the candidate trigger: testing-quality-surviving-mutant-equivalence-triage, testing-data-adjacent-tokens-in-extractor-fixtures, testing-quality-source-text-wiring-assertions, testing-mocking-autouse-fixture-shadows-function-under-test, testing-quality-minimum-case-set, testing-quality-assertion-scanner-false-positive-on-unittest-convention. Only the last one has the same trigger.
- Overlap: testing-quality-assertion-scanner-false-positive-on-unittest-convention already covers the main directive (a `/assert[ \t]/` scanner misses `self.assertX`, so fix the checker's pattern instead of the tests). This is a merge, not a new page.
- Added: one Edge-cases row (a scanner "pass" on a unittest file can come from a comment; count from the AST; check on one unittest and one pytest file). Also added two source entries (CPython tracker msg315638 and the 2026-10-15 field evidence) and set `last_verified` to 2026-10-15.
- Conflicts: none. The new row extends the existing "fix the checker's accepted pattern" directive.
- Related links: unchanged (the page already links testing-quality-harness-reverse-controls and testing-quality-checks-that-cannot-pass).

## Open-PR check

13 open `knowledge/*` heads: #282, #280, #279, #275, #274, #273, #272, #271, #270, #269, #268, #266, #265. This headless run cannot diff them, so overlap was judged from each PR's file list (`gh pr list … --json number,files`).

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| 447c9601617b87ca (assertion scanner + comment) | None. No open PR touches `testing/quality/assertion-scanner-false-positive-on-unittest-convention.md`. | new → merged into the existing page |
| 12aa086463fd4e2a (BSD grep: `$` inside a `\|` alternation is literal; use `grep -E`) | #273 edits `wiki/platforms/tools/bsd-vs-gnu-cli.md` and several `platforms/shells/*` pages. #265 adds `platforms/tools/search-evidence-from-a-wrapped-grep.md`. | pending duplicate → claim released |
| 66f97671dfa1b324 (Prisma 7 driver adapter: COMMIT-time error arrives as `DriverAdapterError`, outside the `instanceof Prisma.*Error` branch) | #280 (same source session) adds `testing/mocking/wrapper-label-pinned-by-a-boundary-fault.md` about the same DB-fault wrapper. #269 edits `backend/common/orm/prisma-7-config-env-and-generated-client.md`. | pending duplicate → claim released |
| 12 plan-gap rows (0c90fd21a958c2ab, dfeef858e450c5b0, 114f9e1075e1fca4, b674f3bfc61e5700, 433e853b3f21663a, 1540131bc7298c1f, 9c5a38c3e4cc45fc, 1a43be1064cca84b, 65871aed26d85515, 70ef9f3d9e998b9f, 62ce7fb384a8a33c, ee95968c5b49959c) | Not applicable: project-specific, excluded before the PR check | dropped (local layer) → retired |
| 97c37473b53e63c2 | Not assessable: its queue file could not be located without a directory listing | not handled → claim released for a later run |

## Routing decision

- 447c9601617b87ca → testing / quality / `wiki/testing/quality/assertion-scanner-false-positive-on-unittest-convention.md` (merged as an Edge-cases row plus sources). The trigger is unchanged, so the domain index needs no new row. `log.md` has a `revise` entry.
- No new category or page.

## Local-layer candidates

These 12 rows come from `~/.dev-loop/queue/plan-gaps.jsonl` and belong to the project `linkly-halli-galli-lamprey`. Each is a wiki-plan "no owning wiki page" decision whose directive names that repo's own files, modules and task ids, so it would be wrong in another codebase. They are excluded from this PR and retired. To keep one, run wiki-ingest inside that project.

| Row | Planning decision | Target |
|-----|-------------------|--------|
| 0c90fd21a958c2ab | t4-lobby-server: module layout, composition, ownership | wiki-local/backend/node/lobby-server-module-layout.md |
| dfeef858e450c5b0 | t4-lobby-server: room password storage (keyed HMAC for in-memory room passwords) | wiki-local/security/secrets/in-memory-room-password-hash.md |
| 114f9e1075e1fca4 | t4-lobby-server: auto-start trigger | wiki-local/backend/node/room-auto-start-trigger.md |
| b674f3bfc61e5700 | t5-game-server: module layout | wiki-local/backend/node/game-server-module-layout.md |
| 433e853b3f21663a | t5-game-server: timer slots | wiki-local/backend/node/game-timer-slots.md |
| 1540131bc7298c1f | t5-game-server: countdown schedule | wiki-local/backend/node/game-countdown-schedule.md |
| 9c5a38c3e4cc45fc | t5-game-server: turn timer and auto-flip | wiki-local/backend/node/game-turn-timer.md |
| 1a43be1064cca84b | t5-game-server: bell round | wiki-local/backend/node/game-bell-round.md |
| 65871aed26d85515 | t5-game-server: one ending path | wiki-local/backend/node/game-ending-path.md |
| 70ef9f3d9e998b9f | t5-game-server: leave | wiki-local/backend/node/game-leave.md |
| 62ce7fb384a8a33c | t5-game-server: emit discipline | wiki-local/backend/node/game-emit-discipline.md |
| ee95968c5b49959c | t5-game-server: size and pieces | wiki-local/infrastructure/agent-orchestration/game-server-task-pieces.md |
