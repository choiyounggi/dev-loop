---
id: backend-common-llm-gateway-model-alias-defaults
domain: backend
category: llm
applies_to: [general]
confidence: field-tested
sources:
  - https://developers.openai.com/api/reference/resources/models/methods/list
  - https://docs.litellm.ai/docs/proxy/model_discovery
  - https://docs.vllm.ai/en/latest/getting_started/quickstart/
  - https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue
last_verified: 2026-07-28
related: [backend-common-llm-completion-response-validation, infrastructure-config-environment-config, qa-process-release-gates]
---

# Code Defaults That Name Gateway-Resolved Model Aliases

## When this applies

A default value in code (a default model name, gateway route alias, or
similar externally-resolved identifier) is resolved by a serving catalog that
changes outside this repository — an LLM gateway (LiteLLM, vLLM), an API
gateway route table, a model registry. Especially when a PR touching such a
default claims "end-to-end verified".

## Do this

| Case | Do |
|------|----|
| Reviewing or merging a PR whose default names a catalog-resolved alias | Re-query the live catalog at review/merge time — `GET /v1/models` on any OpenAI-compatible gateway lists the currently served model IDs — and confirm the default still resolves. Treat the PR body's verification evidence as a statement about a past state of the catalog, not the present |
| The default is load-bearing in production | Also validate it at process startup (resolve the alias once, crash loud on failure) so a catalog change becomes a failed deploy instead of silent runtime 400s — startup-validation mechanics: [infrastructure-config-environment-config] |
| Review and merge are days apart | Re-check at merge time too — the same staleness that merge queues exist to catch (a PR validated earlier can be invalid against the current state) applies to external catalogs |
| The gateway lists models from config, not live upstream state | Confirm with one real completion call, not just the list — e.g. LiteLLM `/v1/models` reflects its configured `model_list`; a listed alias can still fail upstream |

The mechanism to internalize: the catalog is an external dependency that
drifts independently of the repo. Code, unit tests, and builds exercise none
of it, so every green signal stays green while the default is already dead.

## Edge cases

| Case | Then |
|------|------|
| No network access to the catalog from the review environment | Say so in the review instead of approving the claim — an unverifiable default gets flagged, not assumed alive |
| The default has a fallback chain (try alias A, then B) | Verify every member of the chain; a dead primary that silently falls back hides the drift until the fallback dies too |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Approve a PR because its body shows a successful end-to-end run | Re-run the catalog check (`GET /v1/models` + one real call) at review time | The run proves the alias resolved then; the catalog may have changed since — observed in the field as a default model returning 400 days after a verified PR |
| Hardcode a "known good" model alias as a constant | Keep it as validated config that is resolved at startup | A constant is invisible to config inventories and startup validation; drift surfaces as runtime errors |

## Sources

- https://developers.openai.com/api/reference/resources/models/methods/list — `GET /v1/models` lists currently available model IDs (OpenAI API semantics)
- https://docs.litellm.ai/docs/proxy/model_discovery — LiteLLM serves `/v1/models` from its configured model list; live provider checking is opt-in
- https://docs.vllm.ai/en/latest/getting_started/quickstart/ — vLLM OpenAI-compatible server exposes `/v1/models` for listing served models
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue — validation done earlier on a PR must be redone against the latest state (staleness rationale)
- Field context: 2026-07-28 review of an internal meeting-summary service — default summarization model alias removed from the LiteLLM catalog between PR verification and review; code/tests/build all green while `/chat/completions` returned 400
