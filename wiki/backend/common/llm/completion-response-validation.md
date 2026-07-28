---
id: backend-common-llm-completion-response-validation
domain: backend
category: llm
applies_to: [general]
confidence: field-tested
sources:
  - https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml
  - https://developers.openai.com/api/docs/guides/reasoning
  - https://docs.litellm.ai/docs/reasoning_content
  - https://docs.vllm.ai/en/latest/features/reasoning_outputs.html
last_verified: 2026-07-28
related: [backend-common-llm-gateway-model-alias-defaults, backend-common-reliability-timeouts-and-retries]
---

# Validating an OpenAI-Compatible Completion Before Using Its Output

## When this applies

Your code consumes `/chat/completions` responses as a final artifact (a
summary, a document, a message) and the routed model can change under you —
a gateway (LiteLLM, vLLM) resolves the model from config, or reasoning-family
models may be served on the same alias.

## Do this

Validate the response before writing the output anywhere downstream; HTTP 200
does not mean the text is usable:

| Check | On failure |
|-------|-----------|
| `finish_reason == "length"` | Treat as failure or explicit truncation handling — per the OpenAI spec, `length` means generation was cut off by the request's token limit, so the text is incomplete even when non-empty |
| `content` empty or blank | Treat as failure — never register/notify with empty output |
| `content` empty AND reasoning field populated | Emit the precise diagnostic "reasoning model consumed the completion budget before producing an answer" — raise max output tokens or route to a non-reasoning model |

Mechanism: reasoning-family models stream chain-of-thought into a separate
field (`message.reasoning_content` on DeepSeek-style APIs and LiteLLM;
renamed to `message.reasoning` on current vLLM) and, on OpenAI o-series and
vLLM-style servers, that reasoning spends the same output-token budget as the
answer. When the budget runs out mid-reasoning you get HTTP 200,
`finish_reason: "length"`, an empty `content`, and a large reasoning field —
a client that reads only `content` passes empty text downstream as success.

## Edge cases

| Case | Then |
|------|------|
| Field is absent on your gateway | Check both spellings: `reasoning_content` (DeepSeek convention, LiteLLM-normalized) and `reasoning` (current vLLM) |
| DeepSeek first-party API | CoT has its own separate budget and does not consume `max_tokens` — the empty-content-from-reasoning failure mode applies to OpenAI o-series/vLLM-style budgeting, not there; keep the finish_reason and empty-content checks anyway |
| Retrying after a `length` failure | Raising max tokens is the fix only when reasoning ate the budget; for genuinely long outputs, chunk the task instead — blind retry with identical parameters reproduces the same truncation ([backend-common-reliability-timeouts-and-retries]: never retry the same failing bytes) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Treat HTTP 200 from `/chat/completions` as success | Gate on `finish_reason` and non-blank `content` before using the text | Measured in the field (LiteLLM gateway, 2026-07-28): a reasoning-routed alias returned 200 with `finish_reason=length`, 0-char `content`, 8,173-char `reasoning_content` — the empty artifact flowed to document registration until the gate was added |
| Read only `message.content` from the response | Also read the reasoning field to distinguish "model produced nothing" from "reasoning consumed the budget" | The two failures need opposite fixes (model/prompt problem vs token-budget/routing problem) |

## Sources

- https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml — `finish_reason` semantics: `length` = "the maximum number of tokens specified in the request was reached"
- https://developers.openai.com/api/docs/guides/reasoning — reasoning can consume the entire output budget before any visible output, incurring cost with no visible response
- https://docs.litellm.ai/docs/reasoning_content — LiteLLM normalizes provider reasoning output to `message.reasoning_content`
- https://docs.vllm.ai/en/latest/features/reasoning_outputs.html — vLLM reasoning outputs; field renamed `reasoning_content` → `reasoning`
- Field context: 2026-07-28 LiteLLM (internal dgx) measurement — same 9,317-token prompt: reasoning alias → 200/`length`/empty content/8,173-char reasoning_content; non-reasoning alias → `stop`/2,418-char complete answer
