---
id: frontend-agent-interfaces-agent-facing-tool-surfaces
domain: frontend
category: agent-interfaces
applies_to: [general]
confidence: verified
sources:
  - https://developer.chrome.com/docs/ai/webmcp
  - https://developer.chrome.com/docs/ai/webmcp/imperative-api
  - https://developer.chrome.com/docs/ai/webmcp/declarative-api
  - https://developer.chrome.com/docs/ai/webmcp/secure-tools
  - https://webmachinelearning.github.io/webmcp/
  - https://chromestatus.com/feature/5117755740913664
  - https://developer.chrome.com/docs/devtools/application/webmcp
  - https://learn.chatgpt.com/docs/webmcp
last_verified: 2026-09-28
related: [security-agent-exposure-in-session-tool-exposure, frontend-accessibility-interactive-elements, backend-common-api-design-agent-tool-granularity, qa-process-agent-tool-parity-gate, testing-strategy-agent-tool-shared-handler-tests]
---

# Exposing Site Actions as Tools for AI Agents (WebMCP)

## When this applies

Adding or changing any user action in a web UI (form, button flow,
search/filter, state change) in a project under this wiki's development
standard — an additive WebMCP tool per action (owner decision, log.md
2026-09-28, a policy rather than a sourced fact); asked to make a web app
usable by AI agents ("agent-ready", "add WebMCP tools"); fixing a bug in a
handler a tool wraps; reviewing code that registers browser-native agent tools.

## Do this

1. Know the platform status before designing around it: WebMCP is a W3C **Web
   Machine Learning Community Group Draft Report** (not on the standards
   track), shipped by Chrome as an **origin trial from Chrome 149** (and,
   separately, behind `chrome://flags/#enable-webmcp-testing` for local
   development), and consumed by the ChatGPT desktop app's built-in browser as "site tools"
   (ChatGPT Work and Codex chats; desktop app only, off in Enterprise/Edu
   workspaces and on some models). Build the
   agent surface as an additive layer over a fully working human UI, and gate
   every call site with feature detection:

   ```js
   if (document.modelContext?.registerTool) { /* register tools */ }
   ```

   The API surface in Chrome's docs and the CG draft is `document.modelContext`
   and nothing else — register there.

2. Pick the API by what the action already is:

| The action is… | Use |
|----------------|-----|
| An existing HTML form (search, signup, checkout) | Declarative: `toolname` + `tooldescription` attributes on the `<form>`; the browser derives the JSON schema from the form's fields |
| SPA state changes, multi-step logic, anything driven by JS handlers | Imperative: `document.modelContext.registerTool({ name, description, inputSchema, execute })` |
| A tool the ChatGPT desktop browser must discover | Imperative, registered in the top-level document: ChatGPT's site-tools runtime reads `document.modelContext` registrations only — declarative form attributes and tools registered inside iframes are invisible to it |

3. Reuse the handler the human UI already calls. The `execute` function wraps
   the same `addToCart()`-style function the button's click handler invokes —
   one code path, two entry points. When the action logic currently lives
   inline in the click handler, extract it to a named function first, then
   register that.

4. Schema quality comes from form semantics. The declarative API describes
   each field from, in priority order: its `toolparamdescription` attribute,
   its associated `<label>` content, its `aria-description`. Give every field
   a real `<label>`, correct input `type`, and `required` where applicable —
   the same work [frontend-accessibility-interactive-elements, backend-common-api-design-agent-tool-granularity] already
   requires — and add `toolparamdescription` only where the label alone
   under-specifies the value format.

5. Keep tool text inside Chrome's recommended budgets, which this standard
   applies as limits: 30 characters for tool and parameter names, 500 for
   tool descriptions, 150 for parameter descriptions, 1.5K per tool output. Write descriptions as what the tool does and when to call it —
   the agent selects tools by reading them.

6. Leave `toolautosubmit` off any form whose submission spends money, mutates
   user data, or is otherwise consequential: the agent fills the form, the
   human clicks submit. When the tool is imperative and spends money or is
   irreversible, set `annotations: { consequentialHint: true }`; the
   per-class rules, confirmation gating and injection defense are decided in
   [security-agent-exposure-in-session-tool-exposure] — load it whenever
   you register a state-changing tool.

7. Make agent activity visible: style the `:tool-form-active` (on the form
   while an agent invokes its tool) and `:tool-submit-active` (on the submit
   button) pseudo-classes so the user sees the agent acting on the page.

8. Verify registration before handing the page to an agent: open Chrome
   DevTools → Application → WebMCP. **Available Tools** lists each registered
   tool with its description and invocation count — a tool missing there is
   not registered, whatever the console says. Select a tool, enter parameters
   and click **Run tool** to exercise `execute` without an agent; the output
   pane shows the return value, or an error when parameters or return values
   violate the declared schema. For an agent-driven check, the Model Context
   Tool Inspector extension sends natural-language prompts to a Gemini model
   against the live page; **Invoked Tools**, the pane's log of agent↔page
   interactions, shows each call's status, input and output.

## Edge cases

| Case | Then |
|------|------|
| Tools must be callable from another origin (partner iframe) | Three pieces: the host page grants the iframe `allow="tools"` (Permissions Policy — registration is off by default in cross-origin iframes), the registering page lists the origin in `exposedTo` (default same-origin only), and the consuming page names it in `getTools({ fromOrigins })`; widen `exposedTo` only per [security-agent-exposure-in-session-tool-exposure] |
| A registered tool must be removed on route change, component unmount, or logout | Pass an `AbortSignal` in the registration options and abort it on teardown; a tool that reads or changes account data is registered only once the session is known to be authenticated and aborted on logout |
| Origin trial ends (scheduled through Chrome 156) or spec churn renames APIs | The feature-detection guard from step 1 makes the agent layer degrade to the human UI with no code change |
| A tool exists only for inspection or developer tooling | Register it with `annotations: { debugging: true }` (Chrome 156+) so agent runtimes can leave it out of task selection |
| A bug fix changes the handler a tool wraps | Fix the shared function once; when its input contract changed, update `inputSchema` and the description in the same commit and re-run the tool per [testing-strategy-agent-tool-shared-handler-tests] and [qa-process-agent-tool-parity-gate] |
| A user action is exempt from the tool standard (no agent use case) | Record it on the project's exclusion list with the reason; the parity gate reads that list |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build a parallel "agent API" duplicating UI logic | Register the existing handler as the tool's `execute` | Two code paths drift; the tool ships bugs the UI already fixed |
| Point screenshot/DOM-scraping automation at your own site | Register the action as a tool | Scraping breaks on CSS/markup changes and costs tokens per pixel; a tool is a stable, named contract |
| Make WebMCP the only way to trigger an action | Keep the human UI primary and the tool additive | Two runtimes consume it today (Chrome's origin trial, the ChatGPT desktop browser), the spec is a CG draft, and Firefox/Safari have not committed to implementation |

## Sources

- https://developer.chrome.com/docs/ai/webmcp — origin trial from Chrome 149, testing flag
- https://developer.chrome.com/docs/ai/webmcp/imperative-api — `document.modelContext.registerTool` shape (current API surface is `document.modelContext` only — no `navigator.modelContext` mention), `exposedTo`/`signal` options, `annotations` fields `readOnlyHint`/`untrustedContentHint`/`consequentialHint`/`debugging` (page dated 2026-09-21)
- https://developer.chrome.com/docs/ai/webmcp/declarative-api — `toolname`/`tooldescription`/`toolautosubmit`/`toolparamdescription`, label→schema derivation, `:tool-form-active`/`:tool-submit-active`, `SubmitEvent.agentInvoked` + `respondWith()` for the page's own response
- https://developer.chrome.com/docs/ai/webmcp/secure-tools — recommended character limits ("subject to change"): 500/tool description, 150/parameter description, 30/tool name and parameter name, 1.5K/tool output
- https://webmachinelearning.github.io/webmcp/ — Draft Community Group Report status (Web Machine Learning CG)
- https://chromestatus.com/feature/5117755740913664 — official milestone tracker: origin-trial stage desktop and Android 149–156, Firefox/Safari "No signal" (the HTML page is a JS shell; read `https://chromestatus.com/api/v0/features/5117755740913664`, stripping the `)]}'` prefix)
- https://developer.chrome.com/docs/devtools/application/webmcp — DevTools Application → WebMCP pane: Available Tools; Invoked Tools as the log of agent↔page interactions; Run tool with manual parameters; schema-violation errors in the output pane (page dated 2026-05-12)
- https://learn.chatgpt.com/docs/webmcp — "Site tools are ChatGPT's implementation of the proposed WebMCP standard"; `document.modelContext` only, declarative API and iframe registrations unsupported, per-invocation safety review, `readOnlyHint: true` in its read-only example ("A tool's name or claim that it only reads data isn't proof of what it does"), user toggle under Settings → Browser → Permissions
