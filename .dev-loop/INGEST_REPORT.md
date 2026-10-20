# Knowledge flush — 2 insight(s)

Headless auto-flush, claim run `20261020-151535-5268`. 6 queue rows claimed: **2 ingested as new pages, 4 released** as plausible duplicates of open knowledge PRs (left for the manual flush to diff). 1 existing page gained a `related:` link. Nothing was folded into another branch.

## Verified best-practice

**`1107bc36bfcbfe79` — wait for every moving axis (or the animation's end signal) before capturing an animated element** (confidence: **verified**)

- **Claim:** a wait that polls one coordinate of an animated element's box fires mid-travel when that axis moves only a little. Wait on `Promise.all(el.getAnimations().map((a) => a.finished))` or the library's completion signal. Otherwise compare every axis with non-zero travel, set the tolerance below the smallest travel, and require two equal readings one frame apart.
- **Sources:**
  - https://developer.mozilla.org/en-US/docs/Web/API/Animation/finished — "returns a Promise which resolves once the animation has finished playing", plus the `Promise.all(elem.getAnimations().map((animation) => animation.finished))` example. Fetched 2026-10-20.
  - https://developer.mozilla.org/en-US/docs/Web/API/Element/getAnimations — "This array includes CSS Animations, CSS Transitions, and Web Animations"; the `subtree` option. Fetched 2026-10-20.
  - https://playwright.dev/docs/actionability — Stable = "the same bounding box for at least two consecutive animation frames". Found through search results on playwright.dev; a direct fetch was not permitted in this run.
  - https://playwright.dev/docs/api/class-locator — "Assuming the page is static, it is safe to use bounding box coordinates to perform input". Screenshot `animations: "disabled"` fast-forwards finite animations and resets infinite ones; the locator screenshot defaults to `"allow"`. Found through playwright.dev search results.
- **How verified:** local reproduction (Node 26.7.0): a 600 ms ease-out tween moving `left` 192 px and `top` 13 px, sampled every 16 ms.

  | Wait rule | First passes at | `left` then (target 698.25) |
  |---|---|---|
  | top-only ±6 px | 144 ms | 782.5 |
  | both axes ±6 px | 416 ms | 703.8 |
  | both axes ±1 px | 496 ms | 699.2 |
  | end of animation | 608 ms | 698.3 |

  The field case from the originating session (shot at `top 651.1`, `left ≈ 750`; fixed rule captured `left 700.5`) agrees.
- **Removed while drafting:** 2 edge rows I could not source in this run: a transform's effect on `boundingBox()`, and an empty `getAnimations()` right after a trigger. Neither is on the page.

**`0480b14856db7f7c` — exact mid-window values from an independent oracle pin tuned constants; shape checks do not** (confidence: **verified**)

- **Claim:** tests that check only the curve's shape ("overshoots 1", "ends near 1") pass for every spring, easing or duration in the same family. To pin the constants:
  - sample mid-window points;
  - compute the expected values independently (closed form, a separate semi-implicit Euler run, easing control points by hand);
  - set the tolerance between the integrator error and the gap to the sibling preset;
  - require red on each one-constant swap.
- **Sources:**
  - https://learn.microsoft.com/en-us/dotnet/core/testing/mutation-testing and https://pitest.org/quickstart/basic_concepts/ — what a surviving mutant means.
  - https://testing.googleblog.com/2014/07/testing-on-toilet-dont-put-logic-in.html — logic in tests is hard to check by reading. This is the reason for the edge row that gives the oracle helper its own known-answer test, and it resolves the apparent conflict with "compute the expected value in the test".
  - https://splishsplash.readthedocs.io/en/2.10.0/api/class_s_p_h_1_1_time_integration.html — the semi-implicit Euler update order.
- **How verified:** local reproduction (Node 26.7.0):
  - Setup: a spring integrated at 1 ms with presets `bounce {k:300,c:12}` and `settle {k:170,c:14}`. The oracle is the closed-form underdamped solution, tolerance 0.02.
  - The shape check passed for the correct code and for all 3 mutants (`bounce`→`settle`, `k 300→250`, `c 12→16`).
  - Exact values at 100/200/300 ms passed for the correct code (0.8346/1.3095/1.0297 vs oracle 0.8273/1.3114/1.0336) and failed for all 3 mutants.
  - The originating session's audit (26 survivors under shape-only tests, all killed after exact-value tests) agrees.
- The scratch scripts used for both reproductions are in `/Users/choeyeong-gi/.dev-loop/scratch-flush/`, outside the repo. This run was not allowed to delete them.

## Existing-layer check

Pages read: testing-e2e-e2e-stability, qa-environments-element-crop-screenshots, testing-quality-default-values-under-test, testing-mocking-captured-call-arguments, testing-quality-tests-that-cannot-fail, frontend-design-pointer-attracted-particle-fields, testing-quality-path-resolver-fixtures-with-coincident-cwd

- **Routing input:** `wiki/testing/index.md`, read in full.
- **`wiki_search` (k=6) for candidate 1:** top hits were `qa-environments-element-crop-screenshots` (0.80, about clip coordinates, not animation waits) and the `e2e-stability` edge row "Entry animation makes clicks land on a moving element" (0.78). That row covers Playwright's auto-wait before an *action*, not a hand-written box poll before a *capture*.
- **Repo-wide `grep -rl` for candidate 1** (`animation.*finished|getAnimations|transitionend|animationend|end pose|mid-travel|one axis`): 0 pages.
- **Candidate 1 verdict:** new page.
- **`wiki_search` (k=6) for candidate 2:** top hits were `captured-call-arguments` (0.73) and `pointer-attracted-particle-fields` (0.72, a spring *implementation* edge row). Neither covers asserting tuned curves.
- **Repo-wide `grep -rl` for candidate 2** (`qualitative|overshoot|stiffness|damping|easing token|same family`): 7 pages. The 3 testing/frontend hits were read at the matching lines; they use "overshoot" in another sense (a path-resolver mutant), "same family" in another sense (spec documents), or describe a spring implementation.
- **Closest existing page for candidate 2:** `default-values-under-test`. It covers a single numeric constructor default asserted at a boundary. A curve shaped by a preset table needs mid-window samples and an oracle, so this is a new page. The new page's "When this applies" points single-default cases back to `default-values-under-test`.
- **Conflicts:** none.
- **Related links:**
  - `testing-quality-default-values-under-test` now lists `testing-quality-tuned-constant-assertions`.
  - The new e2e page links one way to `testing-e2e-e2e-stability`, `qa-environments-element-crop-screenshots` and `testing-quality-completion-predicates`. Back-links on the first two were left out because open PRs #279/#270 edit those files.
- **Checks on this tree:**
  - `node scripts/wiki-structure-checks.js wiki` → `pages: 430, indexes: 13, findings: 0`.
  - `node scripts/wiki-lint-prohibitions.js wiki` → `violations: 0`; its 1 info line is the pre-existing one in `infrastructure/config/keys-ahead-of-their-consumer.md`.
  - New page bodies are 76 and 89 file lines.

## Open-PR check

18 open `knowledge/*` heads: #287, #286, #285, #284, #283, #282, #280, #279, #275, #274, #273, #272, #271, #270, #269, #268, #266, #265. This headless run cannot git-diff them. I read their changed wiki file lists (`gh pr list --json files`) and grepped `gh pr diff` output for each candidate's key terms.

| Candidate | Overlapping open head | Verdict |
|---|---|---|
| `97c37473b53e63c2` — String.prototype.replace `$` patterns with a string pattern | #282 adds `backend-node-language-string-replace-replacement-patterns` (same insight) | pending duplicate → **released** |
| `12aa086463fd4e2a` — BSD grep `\|` alternation with `$` anchors on macOS | #273 edits `platforms-tools-bsd-vs-gnu-cli` and `platforms-shells-escapes-in-shell-string-literals`; #265 adds `platforms-tools-search-evidence-from-a-wrapped-grep` | plausible overlap → **released** |
| `0a0ccc4ca0904514` — e2e failure that moves between tests under CPU contention | #275 adds a "different subset of files fails each run" (Docker-VM exhaustion) row to `testing-flaky-diagnosing-flaky-tests`; #285 covers headless software-GL stalls breaking DOM timing tests | plausible overlap → **released** |
| `d631595a0e889652` — judging a colour-role rule with exact hex and selectors | #265 adds `qa-process-blind-llm-judgment-of-a-visual-rule` | plausible overlap → **released** |
| `1107bc36bfcbfe79` — polling one axis of an animated element | #279/#270 edit `e2e-stability` for a blur-driven shift and reduced motion; #270's `proving-nothing-moves-under-reduced-motion` covers `getAnimations()` under reduced motion. No head covers waiting for an element's end position | **new** |
| `0480b14856db7f7c` — exact-value tests for tuned constants | #270/#269 edit `surviving-mutant-equivalence-triage`; no head mentions tuning, springs, easing or shape-only assertions (grep of #268/#269/#270/#280/#283 diffs) | **new** |

## Routing decision

| Candidate | Target |
|---|---|
| `1107bc36bfcbfe79` | `testing/e2e/polling-an-animated-element-for-its-end-position.md` (new). It sits in `e2e` beside `e2e-stability`, because the defect is in the test's wait, not the product. QA screenshot cropping stays in `qa/environments` |
| `0480b14856db7f7c` | `testing/quality/tuned-constant-assertions.md` (new). `quality` owns "can this test detect the defect" pages (`default-values-under-test`, `tests-that-cannot-fail`) |

`wiki/testing/index.md` gained one row in `e2e` and one in `quality`. `log.md` gained 2 `ingest` entries. The root `INDEX.md` testing row already covers both ("cases/assertions", "browser E2E selector/wait/setup strategy"), so it is unchanged.

## Local-layer candidates

none — every ingested candidate is general (no project files, modules or conventions in its directive).
