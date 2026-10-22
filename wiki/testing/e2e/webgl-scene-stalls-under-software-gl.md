---
id: testing-e2e-webgl-scene-stalls-under-software-gl
domain: testing
category: e2e
applies_to: [chromium, playwright, threejs, webgl2]
confidence: field-tested
sources:
  - https://threejs.org/docs/pages/WebGLRenderer.html
  - https://developer.mozilla.org/docs/Web/API/KHR_parallel_shader_compile
  - https://developer.mozilla.org/en-US/docs/Web/API/WebGL2RenderingContext/getSyncParameter
  - https://chromium.googlesource.com/chromium/src/+/da170c2267b2201954efe1c8fa5d2d89ab09f7bf/docs/gpu/swiftshader.md
  - https://groups.google.com/a/chromium.org/g/blink-dev/c/yhFguWS_3pM/m/oLrB5up_BwAJ
  - https://www.khronos.org/webgl/public-mailing-list/public_webgl/1005/msg00219.php
last_verified: 2026-10-18
related: [testing-e2e-e2e-stability, frontend-state-effects-usage, testing-flaky-diagnosing-flaky-tests]
---

# A WebGL Scene That Freezes the Main Thread Under Software GL (Headless Chromium, SwiftShader)

## When this applies

A page mounts a WebGL scene (three.js, react-three-fiber, raw WebGL2) and its
browser E2E suite runs in headless Chromium with no GPU, so Chromium renders
WebGL with SwiftShader and composites in software. The main thread freezes for
hundreds of milliseconds to seconds after the scene mounts, and DOM tests with
timing (timers, animations, "visible within N ms") fail, while a GPU machine
passes.

## Do this

1. **Confirm the cause before changing code.** Record a Chrome trace of the
   failing flow (Playwright `browser.startTracing` or DevTools Performance) and
   look at the long tasks. The signature is a long task whose stack is the
   frame commit waiting on a GPU readback (`Commit → GLES2::ReadPixels`). With
   software compositing the browser reads a visible WebGL canvas back on every
   commit, and the readback waits for every queued GPU command, including
   SwiftShader's shader JIT. A program's first use also queries its compile
   status synchronously, which blocks the same way.
2. **Warm the shaders up while the canvas is hidden.** Keep the canvas at
   `visibility: hidden` (it keeps its size and its context; `display: none`
   gives it no size) until the warm-up finishes, then show it:

| Phase | Do |
|-------|----|
| Compile | `renderer.compile(scene, camera)` (or `await renderer.compileAsync(scene, camera)`), plus each post-processing pass's fullscreen material, each compiled against the render target it draws to (`null` = the canvas) |
| Wait | Put a fence behind that work, `gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0)` then `gl.flush()`, and poll `gl.getSyncParameter(sync, gl.SYNC_STATUS) === gl.SIGNALED` once per frame; never call a blocking query while waiting |
| Pre-render | Render the scene once into an offscreen render target (shadow-map programs, texture uploads), then fence and poll again |
| Ready | `deleteSync`, dispose the offscreen target, make the canvas visible, start the normal render loop |

3. **Bound every wait** (for example 300 frames) and continue when the bound is
   reached, so a driver that never signals cannot hide the scene forever.
4. **Prove the fix with the same trace and the suite.** Expect zero long tasks
   from the commit readback, then run the E2E suite several times in a row.

## Edge cases

| Case | Then |
|------|------|
| The context is WebGL1 (no `fenceSync`) | Skip the fence waits and fall back to `compileAsync` plus one hidden frame; check the trace again |
| three.js chooses a program variant from the current render target, camera type, and geometry attributes | Compile each pass against its own target with an orthographic camera and a quad that has no `normal` attribute, like the pass's fullscreen triangle; otherwise the first visible frame compiles a new variant |
| Chromium refuses to create the WebGL context in headless mode | Automatic SwiftShader fallback is being removed; launch with `--use-gl=angle --use-angle=swiftshader-webgl --enable-unsafe-swiftshader` (test machines only, never for untrusted content), and keep the page's context-loss and no-WebGL fallback |
| `compileAsync` alone does not remove the stall | `KHR_parallel_shader_compile` support is uneven and later `get*` calls can still block; keep the hidden canvas and the fence wait |
| The scene must stay hidden longer than the test allows | Keep the scene, and wait in the test for the readiness signal (canvas visible, a `data-ready` attribute) before timing assertions start |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Raise the E2E timeouts until the run passes | Find the long task in a trace and warm up behind a hidden canvas | The freeze stays; a longer timeout only hides it until the machine is busier |
| Show the canvas, then compile on the first frame | Compile and fence while the canvas is `visibility: hidden` | Each visible commit reads the canvas back and waits for the compile |
| Poll compile status with `getProgramParameter(LINK_STATUS)` in the loop | Poll a fence with `getSyncParameter(SYNC_STATUS)` | The status query waits for the compile; the fence check does not |

## Sources

- https://threejs.org/docs/pages/WebGLRenderer.html — `compileAsync` resolves when the scene can be rendered "without unnecessary stalling due to shader compilation" and is the recommended form of `compile()`
- https://developer.mozilla.org/docs/Web/API/KHR_parallel_shader_compile — `COMPLETION_STATUS_KHR` exists so that compile and link status can be queried without stalls; not Baseline
- https://developer.mozilla.org/en-US/docs/Web/API/WebGL2RenderingContext/getSyncParameter — `fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0)` and `getSyncParameter(sync, gl.SYNC_STATUS)` returning `SIGNALED`/`UNSIGNALED`; WebGL2 only
- https://chromium.googlesource.com/chromium/src/+/da170c2267b2201954efe1c8fa5d2d89ab09f7bf/docs/gpu/swiftshader.md — automatic SwiftShader fallback is being removed; `--use-gl=angle --use-angle=swiftshader-webgl --enable-unsafe-swiftshader` opts in for headless testing
- https://groups.google.com/a/chromium.org/g/blink-dev/c/yhFguWS_3pM/m/oLrB5up_BwAJ — Intent to Remove: SwiftShader Fallback (deprecation from Chrome 130)
- https://www.khronos.org/webgl/public-mailing-list/public_webgl/1005/msg00219.php — browsers copy each WebGL frame back (`glReadPixels`) to composite it in software (2010; background for step 1, not current Chromium internals)
- Field measurement 2026-10-18 (a three.js + react-three-fiber + postprocessing scene, Playwright headless Chromium on SwiftShader): the trace showed long tasks `Commit → GLES2::ReadPixels` of 556 ms and 658 ms; with the canvas hidden during a compile → fence → offscreen render → fence warm-up the trace had 0 long tasks, and the E2E suite passed 36/36 three times in a row
