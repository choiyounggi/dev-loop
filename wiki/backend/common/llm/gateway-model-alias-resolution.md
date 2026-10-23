---
id: backend-common-llm-gateway-model-alias-resolution
domain: backend
category: llm
applies_to: [litellm, vllm, general]
confidence: verified
sources:
  - https://docs.litellm.ai/docs/proxy/configs
  - https://docs.litellm.ai/docs/proxy/model_management
  - https://qwen.readthedocs.io/en/latest/deployment/vllm.html
last_verified: 2026-10-23
related: [backend-common-llm-context-window-budget, backend-common-integrations-externally-owned-defaults]
---

# Choosing Between Model Aliases Exposed by an LLM Gateway

## When this applies

An LLM gateway (LiteLLM proxy or another OpenAI-compatible router) lists several
model names and you are picking one for a client, an agent, or an eval — above all
when the names suggest a character (`fast`, `think`, `coder`, `default`) or when the
plan is "the output is poor, switch to a better model".

## Do this

1. **Resolve every alias to its deployment before treating it as a model.** A
   gateway's public name is its own label: in LiteLLM, `model_name` is "the name to
   pass TO litellm from the external client" and `litellm_params.model` is "the
   model string passed to the litellm.completion() function". Read the mapping from
   the gateway's model-info endpoint — for LiteLLM, `GET /model/info`, which "Returns the
   full model list with API keys masked":

   ```sh
   curl -s -H "Authorization: Bearer $KEY" "$GW/model/info" \
     | jq -r '.data[] | [.model_name, .litellm_params.model, (.litellm_params.extra_body|tojson)] | @tsv'
   ```

2. **Group the aliases by backend model string and compare their parameters.**

| Resolution | The choice is | Do |
|------------|---------------|----|
| Aliases map to different backend models | A model choice | Compare the models (window, cost, eval results) |
| Aliases share one backend model and differ only in `extra_body` / sampling params | A parameter choice — the weights are identical | Tune the differing parameter for your task; "switch to the better alias" changes nothing but that parameter |
| One alias lists several deployments | A load-balanced group | Check that every deployment carries the same model and params before attributing output quality to the name |

3. **Name the differing parameter in your decision record** ("`coder-think` =
   same weights with `chat_template_kwargs.enable_thinking: true`"), so the next
   reader does not re-run the model comparison.

## Edge cases

| Case | Then |
|------|------|
| `/model/info` is denied to your key and only `/v1/models` answers | `/v1/models` lists ids only — in the reproduction below each item carried `id`, `object`, `created`, `owned_by` and nothing about the backend. Ask the gateway owner for the config, or send one request per alias and compare the response's `model` field plus any reasoning content |
| The differing parameter is a thinking switch on a hybrid model (Qwen3: `chat_template_kwargs.enable_thinking`) | Thinking and non-thinking are one model, "controlled by either the hard switch … or the soft switch"; the vendor recommends different sampling parameters per mode, so carry the alias's sampling settings over when you replace an alias with your own parameters |
| You set the parameter yourself in the request body | `enable_thinking` "is not OpenAI API compatible" — pass it through the SDK's `extra_body` and confirm on the response that the mode changed (reasoning content present or absent), because the alias's own `extra_body` lives in the gateway config and never appears in your request |
| An alias has no `extra_body` while its siblings set the switch | It runs on the backend's template default, not on a third mode — record which default that is before comparing it with the others |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pick an alias by its name or by the `/v1/models` list | Resolve it through `/model/info` (or the gateway config) first | The list shows labels only; three labels can be one model |
| Swap to "the better model" alias to fix output quality | Group aliases by backend model and identify the parameter that differs | When the backend is shared, the swap is a parameter change and the model-quality hypothesis is untested |

## Sources

- https://docs.litellm.ai/docs/proxy/configs — `model_name` "the name to pass TO litellm from the external client"; `litellm_params.model` "the model string passed to the litellm.completion() function"; the load-balancing example lists several deployments under one `model_name`
- https://docs.litellm.ai/docs/proxy/model_management — `/model/info` "Returns the full model list with API keys masked", with attached `model_info` fields passed through
- https://qwen.readthedocs.io/en/latest/deployment/vllm.html — `extra_body={"chat_template_kwargs": {"enable_thinking": False}}`; "passing `enable_thinking` is not OpenAI API compatible"; one model serves both modes via hard and soft switches; separate sampling recommendations per mode
- Local reproduction 2026-10-23 (LiteLLM 1.106.2 proxy via `uvx --from 'litellm[proxy]'`, macOS, backend `api_base` unreachable — neither endpoint calls it): a config with `coder-fast`, `coder-think`, `chat-default` all on `openai/qwen3-test`, differing only in `extra_body.chat_template_kwargs.enable_thinking` (false / true / unset). `GET /v1/models` returned the three ids with keys `created, id, object, owned_by` only; `GET /model/info` returned each alias's `litellm_params.model` (identical) and `extra_body` (the three variants), with no `api_key` field
- Field observation 2026-08-27 (self-hosted LiteLLM in front of one Qwen3 MoE deployment): three aliases named `coder-fast`, `coder-think`, `chat-default` resolved to the same backend model string, differing only in `enable_thinking` false / true / unset — the planned "switch to a better model" had no other model to switch to
