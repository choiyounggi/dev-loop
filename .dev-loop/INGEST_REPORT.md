# Knowledge flush — 12 candidates: 3 ingested as new pages, 1 page amended, 9 plan-gaps retired as local-layer

## Verified best-practice

**1. A file-level import cycle under NestJS decorator DI** (session insight `f60900a83428b15e`, plus nothing folded)
- Claim: when a plain helper exported from one `*.service.ts` is imported by a service that the first one injects, Nest boot fails with `can't resolve dependencies … index [n]` while typecheck and unit tests pass. Fix: move the helper to its own file with no service imports, and keep a root-module compile test.
- Sources checked: https://docs.nestjs.com/faq/common-errors (source `content/faq/errors.md` grepped verbatim: "A circular file import … two files end up importing each other", "move the constants to a separate file"); https://docs.nestjs.com/fundamentals/circular-dependency ("The order of instantiation is indeterminate", barrel files); https://www.typescriptlang.org/docs/handbook/decorators.html (metadata emitted as `Reflect.metadata("design:type", …)` decorator calls); https://github.com/pahen/madge.
- Reproduced in a scratch project (`@nestjs/core` 11.2.7, TypeScript 5.9.3, Node 26.7.0, CommonJS): `tsc --noEmit` rc=0, a direct `ResearchService` call worked, boot printed `design:paramtypes [ undefined ]` + `Nest can't resolve dependencies of the ResumeService (?) … index [0]`. **New finding beyond the candidate:** swapping two import lines in `app.module.ts` made it boot, so load order decides it. Moving the helper to its own file booted in both orders. Under SWC (`@swc/core` 1.x, `decoratorMetadata`) the same cycle throws `ReferenceError: Cannot access 'ResearchService' before initialization` during load, so the page lists both symptoms. `madge --circular` exited 1 on the cyclic tree and 0 on the fixed tree (known-bad + known-good); a cycle made only of `import type` lines was reported until `.madgerc` set `skipTypeImports: true` (README example), and the real cycle was still caught with it set. An `import type` injected class compiles to `design:paramtypes [Function]` under tsc 5.9.3.
- Confidence: **verified**.

**2. `response.json()` on a no-body response** (general kernel of plan-gap `26496c99f792f56c`)
- Claim: a `fetch` wrapper that always ends with `response.json()` rejects on `204`/`205` and on an empty `200`; guard on status or on empty `text()`. A `304` is not `ok` (200–299), so it must be checked before the `!response.ok` branch.
- Sources checked: https://fetch.spec.whatwg.org/ (verbatim: "A null body status is a status that is 101, 103, 204, 205, or 304"; "The json() method steps are … parse JSON from bytes. The above method can reject with a SyntaxError."); https://developer.mozilla.org/en-US/docs/Web/API/Response/json ("SyntaxError — The response body cannot be parsed as JSON."); https://www.rfc-editor.org/rfc/rfc9112#section-6.2 ("A sender MUST NOT send a Content-Length header field in any message that contains a Transfer-Encoding header field."); https://www.rfc-editor.org/rfc/rfc7540#section-8.1.2.4 ("HTTP/2 does not define a way to carry the version or reason phrase …" — why the error fallback uses `HTTP ${status}` instead of `statusText`).
- Reproduced on Node v26.7.0: `new Response(null,{status:204}).json()` → `SyntaxError: Unexpected end of JSON input`; `new Response('',{status:200}).json()` → `SyntaxError`; `new Response(null,{status:304}).ok` → `false`.
- Confidence: **verified**.

**3. Unused-code review findings on one slice of dependency-ordered work** (session insight `f3252df541e0b23d`)
- Claim: a zero-caller / "every caller passes the same value" rule applied per task of a producer-before-consumer plan (or per change of a stacked series) fires on correct seams; exempt elements a later slice consumes, and require 2+ call sites before the same-value observation counts.
- Sources checked: https://google.github.io/eng-practices/review/developer/small-cls.html (stacked CLs, "shared code or stubs that help isolate changes between layers", tell reviewers about the other CL); https://google.github.io/eng-practices/review/reviewer/looking-for.html (the over-engineering rule being scoped); https://github.com/choiyounggi/dev-loop/pull/246 (merged; lens 6 in `skills/orchestrate/SKILL.md` carries the exemption and the two-call-site rule; `tests/orchestrate-review-pass.bats` 37/37 ok on this branch).
- No external source states the staged-work exemption itself, so it rests on field evidence. Confidence: **field-tested**.

## Existing-layer check

Pages read: qa-process-evaluating-review-feedback, qa-process-llm-review-pipelines, qa-process-adversarial-change-review, testing-quality-cross-task-stub-assertions, backend-node-boundaries-runtime-validation, backend-common-change-impact-call-site-enumeration, backend-common-reliability-timeouts-and-retries, backend-common-api-design-error-responses, testing-strategy-import-time-side-effects

Also read: `INDEX.md`, `wiki/backend/node/index.md`, `wiki/backend/index.md` (integrations + api-design rows), `wiki/qa/index.md`.

- Searches run over all of `wiki/`: `circular|import cycle|forwardRef` (3 hits, all SQL foreign-key or value-table pages, none about module imports); `\b204\b|No Content|response.json()` (no fetch-wrapper page; one Python `response.json()["a"]` row about shape validation); `zero call|no call site|unused code|dead code|call sites` and `per-task review|later task|stacked|dependency-ordered` (no page about unused-code findings on staged work).
- Overlaps: `qa-process-evaluating-review-feedback` step 4 ("search for actual usage first; when nothing uses the capability, propose removing") would delete a producer slice's seam when applied to one slice. It is not a contradiction: I added an edge-case row that scopes the usage search to the whole series and links the new page. `testing-quality-cross-task-stub-assertions` is the testing-side sibling (stubs a later task replaces) and is linked.
- Merged vs created: 3 new pages, 1 amended page (`qa-process-evaluating-review-feedback`: edge row + `related:` id). No conflicts with existing directives.
- Related links added: NestJS page → import-time-side-effects (same "move the pure helper out of the heavy module" fix, Python side), runtime-validation; no-body page → error-responses, timeouts-and-retries, runtime-validation; qa page → evaluating-review-feedback, adversarial-change-review, cross-task-stub-assertions; evaluating-review-feedback → the new qa page.
- Checks run on this branch: `node scripts/wiki-lint-prohibitions.js wiki` → `directives: 80`, `violations: 0` (same as the untouched-tree baseline, so the bats pin stays 80). `bats tests/wiki-*.bats tests/verify-role-lint.bats` → `1..265`, 265 ok, 0 not ok. `orchestrate-dispatch-contracts.bats` 69/69, `orchestrate-review-pass.bats` 37/37, `send-prompt.bats` 100/100. Body lengths 62 / 57 / 51 lines.

- Independent adversarial review (fresh-context reviewer agent, read-only) returned FIX with 3 blocking findings, all applied: a `304` in a guard placed after `!response.ok` could never run (moved to its own edge row, checked before `!ok`); the `statusText` fallback is empty over HTTP/2/3 (now `HTTP ${status}`); the back-link misattributed a "whole series" rule to step 4 of evaluating-review-feedback (reworded to "widened"). Important findings applied: backend `node` routing row, the helper-file edge row, the step-3 spec condition (first project import is `AppModule`, `.overrideProvider` for connections), the unsourced "third provider" option removed, and the qa page renamed from `…-in-staged-changes` (reads as git staging) to `qa-process-unused-code-findings-in-dependency-ordered-work`. Two reviewer claims were wrong when tested, and the pages follow the tests: an `import type` class records `Function`, not `Object`, under tsc 5.9.3; SWC/CommonJS throws a `ReferenceError` instead of recording `Object`. A second pass by the same reviewer over the revised diff returned **PASS** (all blocking and important findings resolved; the one leftover — citing SWC's observed emit shape — was then added to the reproduction line).

## Open-PR check

Listed 17 open `knowledge/*` heads (#223, #225–#231, #233–#239, #241, #244). Fetched each and grepped its `wiki/` diff additions for `nestjs.*(cycle|circular)`, `circular (file )?import`, `import cycle`, `204`, `null body`, `response.json`, `zero call`, `no call sites`, `unused code`, `later task's`, `stacked`, `dependency-ordered`, `toLocaleTimeString`.

- Only hit: #244 (`knowledge/choiyounggi-20261006-130905`) adds `backend-python-language-circular-imports`. It covers Python's `ImportError … partially initialized module` (fix: function-local import, third module, `TYPE_CHECKING`). It does not cover TypeScript, decorator metadata, or Nest DI, so there is nothing to fold. It is not on `main` yet, so it is not linked here. After both merge, link the two pages to each other.
- Verdicts: insight 1 (NestJS cycle) → **new**; insight 2 (no-body JSON) → **new**; insight 3 (staged unused-code findings) → **new**. No candidate was folded or dropped as a pending duplicate.

## Routing decision

| Candidate | Target | Why |
|-----------|--------|-----|
| `f60900a83428b15e` NestJS import cycle | `backend/node/runtime/import-cycle-under-decorator-di.md` (new) | Node stack mechanics of module evaluation at startup; `runtime` is the closest existing node category (event loop, shutdown). A new `modules` category for one page is not justified |
| `26496c99f792f56c` (general kernel) `response.json()` on no-body | `backend/common/integrations/json-parse-of-a-no-body-response.md` (new) | Consuming another service's HTTP responses is `common/integrations`; it is language-agnostic within the Fetch API (browser, Node, Bun, Deno) |
| `f3252df541e0b23d` unused-code findings on staged work | `qa/process/unused-code-findings-in-dependency-ordered-work.md` (new) + edge row in `qa/process/evaluating-review-feedback.md` | Review-process rule; `qa/process` already owns review practice (evaluating feedback, adversarial review, LLM review pipelines) |

No new category was created. `INDEX.md` route lines for backend (node subtree) and qa were widened to name the new pages' situations.

## Local-layer candidates

These 9 plan-gap rows are decisions that only make sense inside one repository's plan. They are excluded from this PR and retired from the queue. To keep any of them, run wiki-ingest inside that project.

| Row | Project | Decision | Target |
|-----|---------|----------|--------|
| `dbc435945b66cdc4` | linkly-seaslug | reuse `_PORT_COUNTER` for the gateway test port | `wiki-local/testing/data/test-port-allocation.md` |
| `4d8c8a66275a32b6` | linkly-seaslug | `### Changed` block for the t194 changelog | `wiki-local/infrastructure/process/changelog-section-choice.md` |
| `d3ec9f1ff0551f33` | linkly-seaslug | final verification order (`check_doc_snippets.py` → full suite → `dev_doctor.sh`) | `wiki-local/qa/process/final-verification-order.md` |
| `ec44fa217ef02206` | linkly-apply-mate-sunfish | `HH:MM:SS` log timestamp built from components. The general kernel was checked on Node 26.7.0 (`toLocaleTimeString('ko-KR',{hour12:false})` → `"9시 5분 7초"`, `en-US` → `"09:05:07"`), but it is too thin for a bundled page | `wiki-local/backend/observability/log-line-format.md` |
| `f51af49971c60133` | linkly-apply-mate-sunfish | failure reason cut at the contract's 2000 chars | `wiki-local/backend/api-design/research-failure-reason.md` |
| `3987b541a0cb513a` | linkly-apply-mate-sunfish | `watch --once` exit code (1 on a transient error) | `wiki-local/backend/cli/watch-once-exit-code.md` |
| `ce78f7240c2d3484` | linkly-apply-mate-sunfish | `parseArgs` union + `parseWatchArgs` messages | `wiki-local/backend/cli/watch-subcommand-parsing.md` |
| `060afa16a34aae8f` | linkly-apply-mate-sunfish | `watch` / `prewatch` package scripts | `wiki-local/platforms/toolchains/collector-package-scripts.md` |
| `e54d4d57077f00f7` | linkly-apply-mate-sunfish | 409 `RESEARCH_ALREADY_READY` treated as done | `wiki-local/backend/api-design/research-already-ready-409.md` |

`26496c99f792f56c` (the 204 guard in `createApiClient`) is also project-specific as written. Its general kernel was ingested as candidate 2 above, so it is not listed again here.
