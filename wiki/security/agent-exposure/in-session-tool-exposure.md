---
id: security-agent-exposure-in-session-tool-exposure
domain: security
category: agent-exposure
applies_to: [general]
confidence: verified
sources:
  - https://developer.chrome.com/docs/ai/webmcp/secure-tools
  - https://webmachinelearning.github.io/webmcp/
last_verified: 2026-08-18
related: [frontend-agent-interfaces-agent-facing-tool-surfaces, security-input-validation-at-trust-boundaries, security-agent-exposure-authorization-scope-persistence, testing-quality-gate-parsing-vs-command-execution]
---

# Exposing Executable Tools to an Agent in a User's Session

## When this applies

Exposing executable actions to an LLM agent that operates inside a user's
authenticated context — WebMCP tools, an in-page assistant, or a
browser-agent integration — where a tool call runs with the user's cookies,
session, and permissions. Also when reviewing such a design.

## Do this

1. Treat every string the agent can read on the page — reviews, user bios,
   search results, third-party embeds, tool outputs — as attacker input to
   the agent. Indirect prompt injection ("ignore your instructions and…"
   planted in page content) is an unsolved problem: Chrome's guidance states
   models are probabilistic and repeatable injection attacks succeed against
   state-of-the-art LLMs. Design the tool surface so that a fully hijacked
   agent still cannot cause unacceptable damage; model-level refusal is not a
   control you get to count on.

2. Gate each tool by its consequence class:

| The tool… | Do |
|-----------|----|
| Only reads state (search, list, get) | Mark it `readOnlyHint`; it may run without per-call confirmation |
| Mutates user state (cart, profile, settings) | Keep the human in the submit path: declarative forms omit `toolautosubmit`; imperative `execute` shows an in-page confirmation UI before applying the change |
| Spends money or is irreversible (order, payment, delete) | Require an explicit human confirmation the agent cannot perform — a click on a control the tool result only points to, never triggers |

   The WebMCP CG draft does not yet standardize a confirmation primitive
   (Chrome's docs discuss a proposed `requestUserInteraction()` that is not
   in the draft) — the page's own UI is the confirmation mechanism you can
   rely on today.

3. Mark tools whose output contains user-generated or externally sourced
   content with `untrustedContentHint`, so the consuming agent runtime can
   treat that output as data rather than instructions.

4. Keep tool visibility at its same-origin default. Registration's
   `exposedTo` option widens which origins can observe and call the tool —
   list only origins you would trust to click the same buttons as the user.
   That bar applies to read-only tools too: a read-only tool that returns
   user information leaks PII to every origin it is exposed to.

5. Keep server-side controls unchanged. A tool call is client-side JavaScript
   running in the session — the server must apply the same authn, per-resource
   authorization, input validation, and rate limiting as for a human-driven
   request ([security-input-validation-at-trust-boundaries],
   [security-authz-resource-level-checks]). The tool's `inputSchema` is a hint to the agent,
   not validation.

## Edge cases

| Case | Then |
|------|------|
| Agent output is rendered into the DOM (assistant panel, filled fields) | It is untrusted input to the page — render per frontend/security/xss-safe-rendering |
| Tools fire at machine speed against endpoints tuned for human pacing | Rate-limit per session server-side; an injected agent loops faster than any human |
| A "harmless" combination: read-only tool + state-changing tool on one page | Evaluate injection blast radius across the whole tool set — a read tool can exfiltrate the data an injected instruction needs to drive the write tool |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on the model to refuse injected instructions | Enforce mechanical gates: consequence-class table above, `readOnlyHint`/`untrustedContentHint`, same-origin `exposedTo` | Refusal is probabilistic; gates hold at 0% and 100% injection success alike |
| Loosen server validation because "the schema already constrains the agent" | Validate server-side exactly as for human requests | Any client can call the endpoint without the schema; the schema is advisory |
| Add `toolautosubmit` to a checkout/payment form to smooth the demo | Let the agent fill and the human submit | Autosubmit hands an injected agent the full consequence of the form |

## Sources

- https://developer.chrome.com/docs/ai/webmcp/secure-tools — prompt-injection stance, `exposedTo` trust guidance, `readOnlyHint`/`untrustedContentHint`, do/don't list
- https://webmachinelearning.github.io/webmcp/ — CG draft; no standardized user-confirmation primitive as of 2026-08-18
