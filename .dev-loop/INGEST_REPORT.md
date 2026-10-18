# Knowledge flush — 1 insight(s)

Headless autoflush run `20261018-232423-76361`. Claimed 8 candidates: 1 ingested, 4 retired as local-layer plan-gaps, 3 released back to pending (2 plausible duplicates of open PRs, 1 whose queue file this run could not locate).

## Verified best-practice

**0d334673a1a799d2 — a WebGL scene that freezes the main thread under software GL (headless Chromium, SwiftShader)**

- Claim: under headless Chromium with SwiftShader and software compositing, a visible WebGL canvas is read back on every frame commit (`Commit → GLES2::ReadPixels`), and the readback waits for all queued GPU work, including shader JIT. The first frames of a three.js scene therefore freeze the main thread and break DOM timing tests. Fix: compile the scene and each post-processing pass, poll a WebGL2 fence, render once offscreen, poll the fence again, and keep the canvas `visibility: hidden` until both fences signal.
- Sources checked:
  - https://threejs.org/docs/pages/WebGLRenderer.html — `compileAsync` exists so the scene renders "without unnecessary stalling due to shader compilation", and the docs recommend it.
  - https://developer.mozilla.org/docs/Web/API/KHR_parallel_shader_compile — compile and link status can be polled without stalls only through `COMPLETION_STATUS_KHR`; the extension is not Baseline.
  - https://developer.mozilla.org/en-US/docs/Web/API/WebGL2RenderingContext/getSyncParameter — `fenceSync(SYNC_GPU_COMMANDS_COMPLETE, 0)` and `getSyncParameter(sync, SYNC_STATUS)` return `SIGNALED`/`UNSIGNALED`; WebGL2 only.
  - https://chromium.googlesource.com/chromium/src/+/da170c2267b2201954efe1c8fa5d2d89ab09f7bf/docs/gpu/swiftshader.md and https://groups.google.com/a/chromium.org/g/blink-dev/c/yhFguWS_3pM/m/oLrB5up_BwAJ — automatic SwiftShader fallback is being removed; `--enable-unsafe-swiftshader` opts back in for headless testing.
  - https://www.khronos.org/webgl/public-mailing-list/public_webgl/1005/msg00219.php — browsers read each WebGL frame back to composite it in software (2010; background only).
- How verified: the session's own Chrome trace showed long tasks `Commit → GLES2::ReadPixels` of 556 ms and 658 ms. With the hidden-canvas warm-up there were 0 long tasks, and the E2E suite passed 36/36 three runs in a row. I also read the session's implementation (`three/shader-warmup.ts`: compile → fence → offscreen render → fence, bounded at 300 frames) so the page's steps match what was proven. The external sources confirm the APIs and the per-commit readback model. No current Chromium document describes the exact `Commit → ReadPixels` wait, so that mechanism rests on the field trace.
- Confidence: **field-tested**. The WebGL1 and `data-ready` edge rows are not measured; they are phrased as "check the trace again" or as fallbacks.

## Existing-layer check

Pages read: testing-e2e-dynamic-file-input-uploads-in-headless-chromium, testing-e2e-e2e-stability

- `wiki_search` top hits for the trigger: frontend-design-html-in-canvas, frontend-design-theme-swap-propagation-check, frontend-design-token-mapping-under-scoped-theme-overrides, qa-environments-offscreen-render-capture-without-screen-recording, frontend-accessibility-contrast-of-interactive-states. A second query (Playwright / WebGL / main thread blocked) returned debugging-concurrency-intermittent-failures, frontend-rendering-rerender-and-memoization, frontend-state-effects-usage, frontend-design-anti-slop-visual-design. None of them covers WebGL readback stalls, shader warm-up, or SwiftShader, so no merge target exists.
- I read the `testing/e2e` index rows and both e2e pages. e2e-stability is about generic selector and wait strategy, and the file-input page is a different headless-Chromium quirk. Created new: `wiki/testing/e2e/webgl-scene-stalls-under-software-gl.md`.
- Related links on the new page: testing-e2e-e2e-stability, frontend-state-effects-usage, testing-flaky-diagnosing-flaky-tests. I did not add backlinks on those pages: open PRs #279 and #270 edit `testing/e2e/e2e-stability.md`, and a frontmatter edit there risks a conflict. The owner can add the backlink after those PRs land.
- No conflicts flagged.

## Open-PR check

Open `knowledge/*` heads listed: #284, #283, #282, #280, #279, #275, #274, #273, #272, #271, #270, #269, #268, #266, #265. This headless run cannot diff their contents, so I compared titles and touched file lists, and released any candidate that plausibly overlaps.

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| 0d334673a1a799d2 (WebGL under SwiftShader) | none: no open PR touches WebGL, shaders, or SwiftShader. #279 and #270 edit `testing/e2e/e2e-stability.md` for blur layout shift and reduced motion, a different trigger | **new** |
| 12aa086463fd4e2a (BSD grep `$` in `\|` alternation) | #273 (`platforms/tools/bsd-vs-gnu-cli.md`, shell pages); #265 (`platforms/tools/search-evidence-from-a-wrapped-grep.md`) | released (pending duplicate) |
| d631595a0e889652 (colour-role rule judged from screenshots) | #265 (`qa/process/blind-llm-judgment-of-a-visual-rule.md`) | released (pending duplicate) |
| 444a0a15e38e04d9, e7fbe0b415a7759a, 2061ccd070f93ead, a2c6a0c5368e9dec | n/a (project-specific) | retired as local-layer |
| 97c37473b53e63c2 | not assessed: this run could not locate its queue file (no directory listing is allowed headless) | released unread |

## Routing decision

- 0d334673a1a799d2 → `testing/e2e/webgl-scene-stalls-under-software-gl.md` (new page; id `testing-e2e-webgl-scene-stalls-under-software-gl`). The trigger is a browser E2E suite that fails only under headless software GL, and the existing `e2e` category covers headless-Chromium quirks (see the file-input page). The fix is rendering code, but the situation you route on is the failing E2E run. The candidate's `domain: frontend` hint was overridden for that reason. The row was added to `wiki/testing/index.md` under `## e2e`, and the entry to `log.md`.
- No new category.

## Local-layer candidates

All four are linkly-halli-galli-lamprey plan-gaps for task t3-scene3d. Their directives name that repo's files (`three/psx.ts`, `club-room.tsx`, `club-geometry.ts`, `sceneGeometry`), so run wiki-ingest inside that project:

- 444a0a15e38e04d9 (Lights and triangle budget) → `wiki-local/frontend/rendering/club-scene-lights-and-triangle-budget.md`
- a2c6a0c5368e9dec (Lights and triangle budget, later revision with off-centre spot) → same page as above (newer revision supersedes)
- e7fbe0b415a7759a (Table layout) → `wiki-local/frontend/rendering/club-scene-table-layout.md`
- 2061ccd070f93ead (Static world content) → `wiki-local/frontend/rendering/club-scene-static-world-content.md`

Separately: 444a/a2c6 contain one general three.js lesson. When `SpotLight.distance` is 0, the spot shadow camera keeps its default `far` (500), so receivers farther from the light are never shadowed; set `shadow.camera.near`/`far` explicitly. It would make a good bundled-wiki candidate if emitted as its own ★ Insight with a source.
