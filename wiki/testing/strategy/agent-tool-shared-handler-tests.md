---
id: testing-strategy-agent-tool-shared-handler-tests
domain: testing
category: strategy
applies_to: [general]
confidence: verified
sources:
  - https://developer.chrome.com/docs/ai/webmcp/imperative-api
  - https://developer.chrome.com/docs/devtools/application/webmcp
  - https://developer.chrome.com/docs/ai/webmcp/declarative-api
last_verified: 2026-09-28
related: [frontend-agent-interfaces-agent-facing-tool-surfaces, qa-process-agent-tool-parity-gate, testing-strategy-test-level-choice, testing-strategy-cross-layer-effect-tests, testing-strategy-failing-test-first, testing-strategy-differential-testing]
---

# Testing a UI Action That Is Also a Registered Agent Tool

## When this applies

Writing or reviewing tests for a web UI action (form submit, button handler,
filter, state change) that a WebMCP tool also exposes; fixing a bug in a
handler a tool wraps; deciding whether the tool needs its own test suite.

## Do this

1. Test the handler once, at the function level. The tool's `execute` and
   the UI's event handler call the same named function
   ([frontend-agent-interfaces-agent-facing-tool-surfaces] step 3), so the
   behavior tests — normal case, error case, boundary case — target that
   function, not either entry point — the extract-and-wire rule of
   [testing-strategy-test-level-choice], applied to two entry points. When the
   tool and the UI call different functions, the fix is to extract the shared
   function first; a second test suite for the tool is the symptom of two code
   paths.

2. Add exactly two entry-point tests per imperative tool:

| Test | Asserts |
|------|---------|
| Registration | After the page (or component) mounts with `document.modelContext` present, a tool with the expected `name` is registered, its `inputSchema` names every parameter the handler needs, and it is gone after the component's `AbortSignal` fires (on unmount and on logout, for a tool that touches account data) |
| Wiring | Calling the registered tool's `execute` with a valid input reaches the shared function with those arguments (spy on the function) and returns the value the function produced |

   Run these in a test that stubs `document.modelContext` with a
   `registerTool` recorder; the browser is not needed to prove wiring.

3. For a declarative form tool, replace step 2 with one contract assertion:
   the tool has no `execute` of its own, so its tests are the form's own
   tests plus one assertion that the `<form>` carries `toolname`, `tooldescription`,
   and a `<label>` (or `toolparamdescription`) for every field the schema
   must expose. When the submit handler branches on `event.agentInvoked` and
   answers with `event.respondWith(promise)`, that branch is page code: give
   it the Wiring test from step 2, dispatching a submit event with
   `agentInvoked` set and asserting the promise resolves to the handler's
   result.

4. For a bug fix in the shared function, follow
   [testing-strategy-failing-test-first]: the reproduction is written against
   the shared function, watched red, then fixed. When the fix changes the
   function's input contract (a new required argument, a changed type), the
   Registration test's schema assertion changes in the same commit — a schema
   that still describes the old contract is the regression.

5. Keep one browser-level check per release, not per test: the DevTools
   **Run tool** pass in [qa-process-agent-tool-parity-gate] is where the real
   browser's schema validation and screen effect are observed.

## Edge cases

| Case | Then |
|------|------|
| The runtime has no `document.modelContext` (Firefox, Safari, a CI browser without the flag) | The Registration test runs against the stub only; the feature-detection guard means the page registers nothing there, and a test asserting registration in a real unflagged browser cannot pass |
| The handler's effect spans layers (API call, store update, DOM) | Scope the cross-layer test per [testing-strategy-cross-layer-effect-tests] once, through the shared function — the tool adds no new layer |
| Two implementations must agree (UI path vs tool path during a migration) | Treat them per [testing-strategy-differential-testing] until the shared function exists; then delete the differential harness |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write a parallel suite that drives the tool through a real browser for every case | Test the shared function; keep Registration + Wiring per tool; one DevTools pass per release | The browser proves schema acceptance and screen effect once; per-case browser runs re-prove the same handler slowly |
| Update the handler's behavior test and ship | Diff the `inputSchema` against the handler's new signature before shipping | The agent reads the schema, not the code; a stale schema sends wrong arguments to a correct handler |

## Sources

- https://developer.chrome.com/docs/ai/webmcp/imperative-api — `registerTool({ name, description, inputSchema, execute, annotations }, { signal, exposedTo })`: `execute` is page JavaScript and `signal` unregisters (page dated 2026-09-21)
- https://developer.chrome.com/docs/ai/webmcp/declarative-api — form-attribute tools derive their schema from labels / `toolparamdescription`; no page-side `execute`, but `SubmitEvent.agentInvoked` + `respondWith()` let the submit handler return the tool's output
- https://developer.chrome.com/docs/devtools/application/webmcp — Run tool and schema-violation errors as the browser-level check
