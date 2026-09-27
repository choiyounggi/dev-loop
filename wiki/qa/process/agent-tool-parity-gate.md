---
id: qa-process-agent-tool-parity-gate
domain: qa
category: process
applies_to: [general]
confidence: verified
sources:
  - https://developer.chrome.com/docs/devtools/application/webmcp
  - https://developer.chrome.com/docs/ai/webmcp/secure-tools
  - https://learn.chatgpt.com/docs/webmcp
  - https://webmachinelearning.github.io/webmcp/
last_verified: 2026-09-28
related: [frontend-agent-interfaces-agent-facing-tool-surfaces, security-agent-exposure-in-session-tool-exposure, testing-strategy-agent-tool-shared-handler-tests, qa-process-release-gates, qa-process-regression-scope, backend-common-api-design-agent-tool-granularity]
---

# Release Gate for a Web UI's Agent Tool Surface (WebMCP Parity)

## When this applies

QA-ing or gating a release of a web app whose development standard is an
additive WebMCP tool layer over every user action; deciding whether a
feature, fix, or release is done when its UI actions must also be callable
as registered tools; reviewing a QA plan that covers the human UI only.

## Do this

1. Build the parity table before testing. List every user action in scope
   (each form, button flow, search/filter, state change) in one column and
   the registered tool that performs it in the next. A row with an action and
   no tool is a gate failure unless the action is on the documented exclusion
   list (an action with no agent use case, recorded with its reason). The
   human UI is the primary surface and stays fully working — the gate checks
   that the tool layer keeps up with it, not the reverse. The table is the
   release-time reading of the capability map that
   [backend-common-api-design-agent-tool-granularity] builds at design time.

2. Verify each tool in Chrome DevTools → Application → WebMCP, with the page
   loaded the way a user would load it:

| Check | Pass when |
|-------|-----------|
| Registration | The tool appears under **Available Tools** with the name and description the parity table names |
| Schema | **Run tool** with valid parameters returns without a schema error; a call with a missing required parameter or a wrong type produces the error in the output pane |
| Effect | After **Run tool**, the output pane shows the return value and the same screen state the human action produces is visible (cart updated, results filtered) |
| Text budgets | Tool and parameter names ≤ 30 characters, tool descriptions ≤ 500, parameter descriptions ≤ 150, each output ≤ 1.5K characters — Chrome's recommended limits, applied as pass/fail by this standard |
| Consequence class | State-changing tools omit `toolautosubmit` / show the in-page confirmation; money or irreversible tools carry `consequentialHint: true` and stop at a control only a human can click |

3. Run the table in both authentication states. Logged out, no tool that
   reads or changes account data is registered; logged in, those tools are
   registered and the server rejects a tool call whose session lacks the
   permission — the server-side controls in
   [security-agent-exposure-in-session-tool-exposure] apply to a tool call
   exactly as to a click.

4. Run one agent-driven pass per release with the Model Context Tool
   Inspector extension (or the ChatGPT desktop browser when that is the
   target runtime): one natural-language prompt per parity row, checking in
   **Invoked Tools** (the agent↔page log: status, input, output) that the
   agent selected the intended tool. When the agent picked a
   different tool or none, the tool description is the defect — rewrite it
   as what the tool does and when to call it, then re-run the row.

5. Record the gate result as the parity table with a pass/fail column per
   check, attached to the release evidence per [qa-process-release-gates].

## Edge cases

| Case | Then |
|------|------|
| The target runtime is the ChatGPT desktop browser | Every row's tool is imperative and registered in the top-level document — declarative form tools and iframe registrations fail the Registration check there, whatever DevTools shows in Chrome |
| A bug fix changed a handler a tool wraps | Re-run that row's Schema and Effect checks; when the fix changed the input contract, the `inputSchema` and description changed with it or the row fails |
| The browser under test lacks the WebMCP flag / origin trial | Registration fails for every row; enable `chrome://flags/#enable-webmcp-testing` or test in an enrolled origin, then re-run — a missing runtime is a setup fault, not a product verdict |
| A tool exists for developer inspection only | It carries `annotations: { debugging: true }` and is left out of the parity table |
| No shipping runtime exposes `document.modelContext` (origin trial ended, flag removed, no replacement) | Mark the DevTools checks N/A with the date and the chromestatus milestone; the gate falls back to the stub-based Registration + Wiring tests in [testing-strategy-agent-tool-shared-handler-tests], and the human-UI release is not blocked |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pass the release on the human-UI QA run alone | Add the parity table and the DevTools checks above | The standard makes the tool layer part of the product; an untested layer ships bugs the UI run cannot see |
| Prove a tool works by reading its registration code | Click **Run tool** and read the output pane | Registration code proves intent; the pane proves the browser accepted the schema and the handler ran |

## Sources

- https://developer.chrome.com/docs/devtools/application/webmcp — Application → WebMCP pane: Available Tools, Run tool with manual parameters, schema-violation errors in the output pane, Invoked Tools as the agent↔page interaction log (page dated 2026-05-12)
- https://developer.chrome.com/docs/ai/webmcp/secure-tools — recommended character limits 30/500/150/1.5K, "subject to change" (page dated 2026-09-01)
- https://learn.chatgpt.com/docs/webmcp — ChatGPT site tools read `document.modelContext` only; declarative API and iframe registrations unsupported; per-invocation safety review
- https://webmachinelearning.github.io/webmcp/ — `ToolAnnotations` incl. `consequentialHint`, `debugging` (Draft Community Group Report, 2026-09-26)
