# Knowledge flush — 1 insight(s)

A wrapper that forwards a lower layer's typed-fault message and prints its own operation label only for other errors cannot have that label pinned by lower-layer fault injection; one generic rejection at the wrapper's boundary (Vitest `vi.mock(path, { spy: true })` + `mockRejectedValueOnce`) does it, and `mockReset()` — not `vi.restoreAllMocks()` — clears the autospy. **1 new page, 1 index row, 1 back-link, 1 log entry. 2 rows released as pending duplicates of open PR #274, 0 dropped.**

Headless autoflush run `20261015-105809-96863`. Claimed 3 queue rows with `queue-claim.js claim`: `86a482be00c360fc` (Vitest autospy, testing), `866175146dd2fc3b` and `ea0574d2686b0169` (both: tsx top-level await needs `"type": "module"`, platforms).

## Verified best-practice

**`86a482be00c360fc` — pin a wrapper's own error label with a fault injected at its boundary** (confidence: **verified**)

Claim: when a wrapper logs the lower layer's typed-fault message for that fault class and its own label for any other error, tests that inject faults only at the lower layer never exercise the label branch, so a renamed label stays green. Inject one generic rejection at the wrapper's boundary — under Vitest `vi.mock("./lower", { spy: true })` keeps every export real while allowing `vi.mocked(lower.fn).mockRejectedValueOnce(new Error("boom"))` in one test — and assert the whole log line. Reset the autospy with `mockReset()`; `vi.restoreAllMocks()` acts on `vi.spyOn` spies and leaves an automock-created override in place. Prove the test with the rename mutant.

Sources checked:

- https://vitest.dev/api/vi — `vi.mock(path, { spy: true })`: Vitest automocks the module but does not override the implementations of its exports (since Vitest 2.1); `vi.restoreAllMocks` restores the original implementations of `vi.spyOn` spies and does not affect mocks created during automocking. Retrieved through WebSearch on 2026-10-15 (WebFetch is not permitted in this headless run, so the wording was read from the search tool's rendering of the official page, not from the raw HTML; the page is cited without verbatim quotes).
- https://vitest.dev/guide/mocking/modules — the `spy` option spies on every export of the module without replacing them with fakes.
- https://pitest.org/quickstart/basic_concepts/ — "Survived: The mutation was not detected by the covering test" (same quote already carried by `testing-mocking-captured-call-arguments`).
- Installed Vitest 5.0.3 (`node_modules/vitest/dist/index.d.ts` in linkly-invitation): `mock(path, factory?: ModuleMockFactoryWithHelper | ModuleMockOptions)` — the `ModuleMockOptions` type the candidate cited is imported from `@vitest/mocker`. The same file's comment on `restoreAllMocks` says it calls `mockRestore()` on "every mocked function", which the reproduction below shows is not what happens to an automock-created spy; the page records that discrepancy next to the official wording.

Local reproduction (Vitest 5.0.3, run with the project's installed `vitest.mjs --root <scratch>`; scratch directory under the checkout's `.dev-loop/` was deleted after the run and is not part of this diff):

| Test | Result |
|---|---|
| Typed lower-layer fault through the wrapper | log = `fault: lower-op[faulty] failed` — the wrapper's label is absent |
| Autospied export called normally | real value returned, `toHaveBeenCalledWith("fine")` green |
| `mockRejectedValueOnce(new Error("boom"))` at the boundary | log = `fault: wrapper-op[createInvite] boom` — the wrapper's own label |
| `mockRejectedValue(new Error("sticky"))`, then `vi.restoreAllMocks()`, then a real call | log = `fault: wrapper-op[createInvite] sticky` — the override survived the restore |
| `mockRejectedValue(...)`, then `mockReset()`, then a real call | log = `[]` — the real implementation came back |

Runner's own marker: `Test Files  1 passed (1)`, `Tests  5 passed (5)`.

Field evidence (originating session, linkly-invitation task t4e, `runAdminWrite` logging `DatabaseFaultError.message`; not re-run here): renaming both action operations kept 8/8 green with faults only at the database layer; after the autospy rejection test, rename mutants 46d and 46e reddened.

**`866175146dd2fc3b`, `ea0574d2686b0169` — tsx compiles a `.ts` file as CommonJS when the nearest package.json lacks `"type": "module"`, so top-level await fails** — not researched further in this run: open PR #274 already carries `wiki/platforms/toolchains/tsx-top-level-await-without-type-module.md` for exactly this trigger (see Open-PR check). No confidence is claimed here.

## Existing-layer check

Route: `INDEX.md` → testing ("mock decisions", "cases/assertions") → `wiki/testing/index.md` → mocking. The platforms index was read for the two tsx rows (toolchains category; no merged page covers tsx/ESM module-format detection — the page in flight is on PR #274).

Pages read: testing-mocking-what-to-mock, testing-mocking-captured-call-arguments, testing-quality-tests-that-cannot-fail, testing-quality-surviving-mutant-equivalence-triage

- `wiki_search` (k=8) on the candidate's trigger/directive: extracted-method-this-binding 0.772, what-to-mock 0.744 and 0.710, typescript-6-global-types 0.733, captured-call-arguments 0.730, test-data-and-isolation 0.721, behavior-not-implementation 0.715. None describes the same situation: what-to-mock's edge row "test your code's handling of a provider's failure modes → stub at your wrapper boundary" is the general rule this page specialises (which fault *depth* reaches which log line), and no page mentions `spy: true`, automock reset behaviour, or a wrapper label hidden behind a forwarded message.
- `wiki_search` (k=8) on the tsx trigger returned no page about tsx/esbuild module format (top hit typescript-6-global-types 0.700 is a different situation), consistent with the page living only on PR #274.
- **Created new**: `wiki/testing/mocking/wrapper-label-pinned-by-a-boundary-fault.md` (body 75 lines; 0 banned qualifiers; every prohibition is paired in its own cell). Merging into what-to-mock was rejected: that page is a general decision table at 60+ body lines and is held by open PR #268; the new situation has its own trigger (fault depth vs. the wrapper's own line) and a framework-specific reset trap.
- Conflicts with existing directives: none. The page agrees with what-to-mock ("stub at the boundary you own") and with tests-that-cannot-fail (one mutation per assertion).
- Related links: forward links to what-to-mock, captured-call-arguments, tests-that-cannot-fail, surviving-mutant-equivalence-triage. Back-link added on **captured-call-arguments only** (no open PR touches it). Back-links on what-to-mock and tests-that-cannot-fail (both edited by open PR #268) and surviving-mutant-equivalence-triage (edited by #269 and #270) are deferred to a later flush to keep this PR conflict-free on those pages; the log entry records this.
- `wiki/testing/index.md`: one row added at the end of the mocking table (maintenance invariant 1). This index file is also edited by #268, #269, #270, #275 and #279, as every testing-domain flush is.
- Checks on this checkout: `node scripts/wiki-structure-checks.js wiki` → `pages: 427, indexes: 13, findings: 0`; `node scripts/wiki-lint-prohibitions.js wiki` → `violations: 0` (1 pre-existing info line in infrastructure/config/keys-ahead-of-their-consumer.md).

## Open-PR check

11 open `knowledge/*` heads listed with `gh pr list --repo choiyounggi/dev-loop --state open --json number,title,headRefName,files --search "head:knowledge/"`: #279, #275, #274, #273, #272, #271, #270, #269, #268, #266, #265. This headless run has no git access, so overlap was judged from each PR's changed-file list and title, plus `gh pr diff <n>` grepped for the candidate's terms (`spy: true`, autospy, automock, restoreAllMocks, mockReset, mockRejectedValueOnce, "operation name") on the five heads that touch `wiki/testing/` (#268, #269, #270, #275, #279).

| Candidate | Overlapping open PR | Verdict |
|---|---|---|
| 86a482be00c360fc (Vitest autospy boundary fault) | None carries it. The only hit was #270, whose new page `testing/mocking/proving-a-value-never-reaches-the-console.md` has an edge row about `afterEach(() => vi.restoreAllMocks())` ordering for console spies — a different trigger (`vi.spyOn` on console, restore-before-assert), and it does not mention automocking or `spy: true`. #268 (`what-to-mock` fs-mock default export), #269 (pull probe, lock control), #275 (Testcontainers workers), #279 (coincident fixtures) are different situations | **new** |
| 866175146dd2fc3b (tsx top-level await, `"type": "module"`) | #274 adds `wiki/platforms/toolchains/tsx-top-level-await-without-type-module.md` and its title names "tsx top-level await without type:module" — the same trigger and directive | **pending duplicate → released** (headless rule: never fold into another branch; the row returns to `pending` and the next flush will drop it against the merged page) |
| ea0574d2686b0169 (same tsx insight, second session) | #274, as above | **pending duplicate → released** |

No `git merge-tree` check was possible in this run. Expected conflicts with the open heads are limited to `wiki/testing/index.md` (one appended row) and `log.md`, the two files every knowledge PR appends to.

## Routing decision

| Candidate | Layer | Target | Action |
|---|---|---|---|
| 86a482be00c360fc | bundled | `testing/mocking/wrapper-label-pinned-by-a-boundary-fault.md` (id `testing-mocking-wrapper-label-pinned-by-a-boundary-fault`) | created; index row + log entry + 1 back-link |
| 866175146dd2fc3b | bundled | `platforms/toolchains/tsx-top-level-await-without-type-module.md` (on PR #274) | released, not ingested |
| ea0574d2686b0169 | bundled | same as above | released, not ingested |

No new category: testing/mocking already owns "mock decisions" and holds the sibling pages (what-to-mock, captured-call-arguments). Layer test: the directive names no repository-specific file or module — `runAdminWrite`/`DatabaseFaultError` appear only in the field-evidence line as the originating case — so it is general knowledge.

## Local-layer candidates

none

🤖 Generated with [Claude Code](https://claude.com/claude-code)
