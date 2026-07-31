---
id: backend-common-integrations-llm-response-completeness
domain: backend
category: integrations
applies_to: [openai-compatible]
confidence: verified
sources:
  - https://developers.openai.com/api/docs/guides/reasoning
  - https://developers.openai.com/api/docs/api-reference/chat/object
  - https://docs.vllm.ai/en/latest/features/reasoning_outputs.html
  - https://docs.litellm.ai/docs/reasoning_content
last_verified: 2026-07-31
related: [backend-common-reliability-timeouts-and-retries, backend-common-integrations-externally-owned-defaults, backend-common-errors-exception-handling]
---

# Accepting an LLM Chat-Completion Response as a Finished Artifact

## When this applies

Server code posts a prompt to an OpenAI-compatible `/chat/completions` (a provider
directly, or a gateway such as LiteLLM / vLLM) and uses the returned text as an
artifact — persisted, posted to a channel, attached to a ticket, fed downstream.
Which model answers is configurable, so a reasoning model can be routed in without
a code change. Also when empty or mid-sentence output is reaching users while the
call logs as a success.

## Do this

Treat HTTP 200 as "transport succeeded" only, and gate the artifact on the body:

| Case | Do |
|------|----|
| `finish_reason == "stop"` and `content` non-blank | Accept the text |
| `finish_reason == "length"` | Fail the call — the text stopped at your token cap mid-generation. Retry with a higher cap or a smaller input, and keep the partial text out of the artifact |
| `content` blank (empty or whitespace) | Fail the call with a diagnostic carrying `finish_reason`, `usage` (prompt/completion/reasoning tokens), the requested alias, and the returned `model` |
| `content` blank AND a reasoning field non-blank | Report "the reasoning model spent the output budget": raise the token cap (OpenAI advises reserving ≥25,000 tokens for reasoning + output while calibrating) or route to a non-reasoning alias. Source the answer from `content` alone — the reasoning field is scratch work, not the deliverable |
| `finish_reason == "tool_calls"`, or the deprecated `function_call` | Blank `content` is correct here — consume the tool call and skip the blank-content row above |

Then log the `model` value the response carries next to the alias you requested, so
a gateway reroute (alias → different model) is visible in the record afterwards.

## Edge cases

| Case | Then |
|------|------|
| Which reasoning field to read | LiteLLM returns `reasoning_content`; vLLM returns `reasoning` (renamed from `reasoning_content`). Check both keys before concluding no reasoning was produced |
| Streaming responses | Accumulate, then apply the same gate using the final chunk's `finish_reason` — validate before the text leaves your process |
| Caller uses the Responses API, not chat completions | The equivalent signal is `status == "incomplete"` with reason `max_output_tokens`; treat it exactly as `finish_reason == "length"` |
| Retrying a `length` failure | This is a fresh request, not a retry of the same bytes — raise the cap or shrink the input first, otherwise it truncates identically ([backend-common-reliability-timeouts-and-retries] owns retry policy) |
| Reasoning tokens are billed but invisible | Cost is incurred even when `content` is blank — send the blank-content failure to an alert with the token counts attached, and cap automatic retries at one |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read `choices[0].message.content` and write it straight to the artifact | Gate on `finish_reason` and non-blank content first | A 200 with `finish_reason=length` is a truncated artifact wearing a success status; downstream systems cannot tell |
| Treat an empty string as "the model had nothing to add" | Fail with `finish_reason` + token usage in the message | Blank content is budget exhaustion or a reasoning-only response — both are actionable configuration facts, not model opinions |
| Raise the token cap whenever output is blank | Check the reasoning field first, then choose raise-cap vs non-reasoning route | If reasoning filled the budget, a bigger cap buys more scratch work; the alias choice is what actually decides |
| Fall back to the reasoning text when `content` is blank | Fail the call and report the reasoning-token count | Reasoning text is unformatted intermediate state — publishing it leaks scratch work as a deliverable |

## Sources

- https://developers.openai.com/api/docs/guides/reasoning — reasoning tokens occupy the output budget and are billed as output tokens; a response can be cut off "before any visible output tokens are produced"; detect via `status == incomplete` / `max_output_tokens`; reserve ≥25,000 tokens while calibrating
- https://developers.openai.com/api/docs/api-reference/chat/object — five documented `finish_reason` values: `stop`, `length` ("the maximum number of tokens specified in the request was reached"), `tool_calls`, `content_filter`, and the deprecated `function_call` — the two tool-calling values are why blank `content` is carved out
- https://docs.vllm.ai/en/latest/features/reasoning_outputs.html — OpenAI-compatible servers put reasoning in `reasoning` (formerly `reasoning_content`) and the final answer in `content`
- https://docs.litellm.ai/docs/reasoning_content — LiteLLM normalizes provider thinking into `message.reasoning_content` (plus `thinking_blocks` for Anthropic)
