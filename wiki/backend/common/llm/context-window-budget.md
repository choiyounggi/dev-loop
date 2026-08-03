---
id: backend-common-llm-context-window-budget
domain: backend
category: llm
applies_to: [general]
confidence: verified
sources:
  - https://platform.claude.com/docs/en/build-with-claude/context-windows
  - https://docs.litellm.ai/docs/exception_mapping
  - https://docs.litellm.ai/docs/anthropic_unified
  - https://code.claude.com/docs/en/env-vars
  - https://docs.vllm.ai/en/stable/serving/integrations/claude_code/
last_verified: 2026-08-01
related: [backend-common-reliability-timeouts-and-retries, backend-common-api-design-error-responses]
---

# Sizing an LLM Client's Output Cap to the Model Actually Serving It

## When this applies

You are repointing an LLM client or agent CLI at a different model or endpoint — a
self-hosted server (vLLM/Ollama), a gateway (LiteLLM), or a smaller/cheaper model —
or setting `max_tokens` for a client whose default was picked for a larger model.
Also when the first request after such a switch returns 400 with a context-window
error while the same client worked against the original endpoint.

## Do this

1. **Budget input and reserved output against one number.** The context window
   holds the request *and* the generation: system prompt, every message (tool
   results, images, documents), tool definitions, plus the output including
   thinking tokens. `max_tokens` is a reservation inside that window, not a
   separate allowance, so a cap sized for a 1M-token model overflows a 128k one
   at identical input.
2. **Derive the cap from the serving model:**
   `max_output ≤ context_window − worst_case_input`, where worst-case input is the
   system prompt + tool definitions + history at the point the client compacts.
   Set it explicitly rather than inheriting the client's default — the default
   encodes the vendor's flagship window, and nothing revalidates it when the
   endpoint changes.
3. **Set the cap at the client's own knob**, since the client sends `max_tokens`
   on every request:

| Client | Knob |
|--------|------|
| Direct SDK/HTTP call | `max_tokens` in the request body |
| Claude Code | `CLAUDE_CODE_MAX_OUTPUT_TOKENS` (output reservation) and `CLAUDE_CODE_MAX_CONTEXT_TOKENS` (input budget) — both present in the shipped v2.1.220 binary; the CLI's own message names the first as the fix for "exceeded the … output token maximum" |
| Gateway in front of many clients | The gateway's own per-model output-cap setting (key name varies by gateway — read its model-config reference), so a client that omits the cap still gets a valid one |

4. **Point the base URL at the endpoint root, not `/v1`.** Claude Code's
   `ANTHROPIC_BASE_URL` "override[s] the API endpoint to route requests through a
   proxy or gateway", and vLLM's own integration sets it to `http://localhost:8000` —
   the root, no `/v1`. The client appends `/v1/messages` itself, so a base URL already
   ending in `/v1` yields `/v1/v1/messages` and 404s while looking like an auth or
   routing fault (observed in the reproduction below; the doc gives the root form as
   the example, not the append rule).
5. **Read a 400 on the first request as a budget error before touching the
   network.** LiteLLM raises `ContextWindowExceededError` (400) as a "special error
   type for context window exceeded error messages". In the reproduction below the
   message carried the arithmetic itself (input + requested output vs the window);
   when it does, recompute step 2 from those three numbers rather than measuring
   anything.

## Edge cases

| Case | Then |
|------|------|
| The provider accepts input + `max_tokens` > window (Claude 4.5 and newer) | The request succeeds and generation stops with `stop_reason: "model_context_window_exceeded"` — branch on the stop reason, because a truncated answer is not an error and arrives as a normal 200 |
| Extended thinking is on | Thinking tokens are a subset of `max_tokens` and billed as output — raise the reservation for thinking instead of assuming it is free, then re-derive step 2 |
| The gateway advertises a window that differs from the server's | Trust the serving engine's configured length (the value that rejects the request), and correct the gateway's model config so its fallbacks compute against the same number |
| Prompt caching is enabled | Cached prefixes still occupy the window — caching changes billing, not occupancy, so the input side of step 2 is unchanged |
| The client is Claude Code and the base URL is not `api.anthropic.com` | MCP tool search is disabled by default (`ENABLE_TOOL_SEARCH=true` when the proxy forwards `tool_reference` blocks) and Remote Control is off as of v2.1.196 — budget the tool definitions as always-present input |
| The window is large enough but responses truncate mid-structure | The cap, not the window, is the limit — raise `max_output` toward the step-2 ceiling ([backend-common-api-design-error-responses] for surfacing the truncation to callers) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Retry or raise the timeout after a context-window 400 | Recompute the cap from the error's own three numbers and resend once | The rejection is arithmetic, not transient; every retry fails identically ([backend-common-reliability-timeouts-and-retries] owns what is retryable) |
| Keep the client's default output cap when swapping in a smaller model | Set the cap from the new model's window before the first request | The default is sized for the vendor's largest window, so the smaller model fails on the first full-context turn rather than degrading later |
| Set the base URL to `http://host:4000/v1` | Set it to `http://host:4000` | The client appends `/v1/messages` itself, so the duplicated prefix 404s while looking like an auth or routing fault |
| Lower the cap until requests stop failing | Compute `window − worst_case_input` once and set that | Trial-and-error lands on a number that holds for today's history length and breaks as the conversation grows |

## Sources

- https://platform.claude.com/docs/en/build-with-claude/context-windows — the window "holds the conversation history plus the new output"; "Everything in the request counts toward the context window: the system prompt, every message in `messages` (including tool results, images, and documents), and your tool definitions"; overflow behavior: input alone over the window → 400 `invalid_request_error`, while on Claude 4.5+ input + `max_tokens` over the window is accepted and stops with `stop_reason: "model_context_window_exceeded"` (earlier models return a validation error); thinking tokens "are a subset of your `max_tokens` parameter"; "Cached prompt prefixes still occupy the context window"
- https://docs.litellm.ai/docs/exception_mapping — "400 | ContextWindowExceededError | litellm.BadRequestError | Special error type for context window exceeded error messages - enables context window fallbacks"
- https://docs.litellm.ai/docs/anthropic_unified — LiteLLM serves the Anthropic-format `/v1/messages` endpoint for "All LiteLLM supported providers" (openai, bedrock, vertex_ai, gemini, azure …), which is what lets an Anthropic-protocol client sit in front of an OpenAI-compatible model
- https://code.claude.com/docs/en/env-vars — `ANTHROPIC_BASE_URL`: "Override the API endpoint to route requests through a proxy or gateway. When set to a non-first-party host, MCP tool search is disabled by default. Set `ENABLE_TOOL_SEARCH=true` if your proxy forwards `tool_reference` blocks"; Remote Control disabled for non-`api.anthropic.com` hosts as of v2.1.196
- https://docs.vllm.ai/en/stable/serving/integrations/claude_code/ — `ANTHROPIC_BASE_URL=http://localhost:8000` "Points to your vLLM server (default port is 8000)" — the root, with no `/v1` suffix
- Field reproduction 2026-07-31 (Claude Code 2.1.220 → LiteLLM → 128k-window OpenAI-compatible model): default output cap + 99,073 input tokens exceeded the 131,072-token window and returned 400 on the first request; an 8,192-token cap ran the same session through tool calls. `CLAUDE_CODE_MAX_OUTPUT_TOKENS` and `CLAUDE_CODE_MAX_CONTEXT_TOKENS` confirmed present in the shipped binary, and absent from the published env-vars reference
