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
last_verified: 2026-08-29
related: [security-agent-exposure-in-session-tool-exposure, frontend-accessibility-interactive-elements, backend-common-api-design-agent-tool-granularity]
---

# Exposing Site Actions as Tools for AI Agents (WebMCP)

## When this applies

Asked to make a web app usable by AI agents ("agent-ready", "add WebMCP
tools", "let an assistant order/search/book on the site"); building a form or
action flow where agent consumption is anticipated; reviewing code that
registers browser-native agent tools.

## Do this

1. Know the platform status before designing around it: WebMCP is a W3C **Web
   Machine Learning Community Group Draft Report** (not on the standards
   track), shipped by Chrome as an **origin trial from Chrome 149** behind
   `chrome://flags/#enable-webmcp-testing` for local development. Build the
   agent surface as an additive layer over a fully working human UI, and gate
   every call site with feature detection:

   ```js
   if (document.modelContext?.registerTool) { /* register tools */ }
   ```

   The current API surface is `document.modelContext`; an earlier draft
   exposed this as `navigator.modelContext` — register on `document.modelContext`,
   not the older name.

2. Pick the API by what the action already is:

| The action is… | Use |
|----------------|-----|
| An existing HTML form (search, signup, checkout) | Declarative: `toolname` + `tooldescription` attributes on the `<form>`; the browser derives the JSON schema from the form's fields |
| SPA state changes, multi-step logic, anything driven by JS handlers | Imperative: `document.modelContext.registerTool({ name, description, inputSchema, execute })` |

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

5. Keep tool text inside Chrome's documented budgets: 30 characters for
   names, 500 for tool descriptions, 150 for parameter descriptions, 1.5K per
   tool output. Write descriptions as what the tool does and when to call it —
   the agent selects tools by reading them.

6. Leave `toolautosubmit` off any form whose submission spends money, mutates
   user data, or is otherwise consequential: the agent fills the form, the
   human clicks submit. Confirmation gating and injection defense are decided
   in [security-agent-exposure-in-session-tool-exposure] — load it whenever
   you register a state-changing tool.

7. Make agent activity visible: style the `:tool-form-active` (on the form
   while an agent invokes its tool) and `:tool-submit-active` (on the submit
   button) pseudo-classes so the user sees the agent acting on the page.

## Edge cases

| Case | Then |
|------|------|
| Tools must be callable from another origin (partner iframe) | Pass `exposedTo` in the registration options — the default is same-origin only; expand it only per [security-agent-exposure-in-session-tool-exposure] |
| A registered tool must be removed on route change / component unmount | Pass an `AbortSignal` in the registration options and abort it on teardown |
| Origin trial ends (scheduled through Chrome 156) or spec churn renames APIs | The feature-detection guard from step 1 makes the agent layer degrade to the human UI with no code change |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build a parallel "agent API" duplicating UI logic | Register the existing handler as the tool's `execute` | Two code paths drift; the tool ships bugs the UI already fixed |
| Point screenshot/DOM-scraping automation at your own site | Register the action as a tool | Scraping breaks on CSS/markup changes and costs tokens per pixel; a tool is a stable, named contract |
| Make WebMCP the only way to trigger an action | Keep the human UI primary and the tool additive | Single-browser origin-trial API: Firefox/Safari have not committed to implementation |

## Sources

- https://developer.chrome.com/docs/ai/webmcp — origin trial from Chrome 149, testing flag
- https://developer.chrome.com/docs/ai/webmcp/imperative-api — `document.modelContext.registerTool` shape (current API surface is `document.modelContext` only — no `navigator.modelContext` mention), `exposedTo`/`signal` options
- https://developer.chrome.com/docs/ai/webmcp/declarative-api — `toolname`/`tooldescription`/`toolautosubmit`/`toolparamdescription`, label→schema derivation, `:tool-form-active`/`:tool-submit-active`
- https://developer.chrome.com/docs/ai/webmcp/secure-tools — character budgets: 500/tool description, 150/parameter description, 30/tool name and parameter name, 1.5K/tool output
- https://webmachinelearning.github.io/webmcp/ — Draft Community Group Report status (Web Machine Learning CG)
- https://chromestatus.com/feature/5117755740913664 — official milestone tracker: origin trial desktop first 149, last 156
