---
id: backend-common-integrations-externally-owned-defaults
domain: backend
category: integrations
applies_to: [general]
confidence: verified
sources:
  - https://developers.openai.com/api/docs/deprecations
  - https://developers.openai.com/api/docs/api-reference/models/list
  - https://docs.litellm.ai/docs/proxy/model_discovery
last_verified: 2026-07-31
related: [backend-common-llm-completion-response-validation, infrastructure-config-environment-config, qa-process-release-gates, backend-common-integrations-consumer-required-fields]
---

# Defaults That Name a Resource Owned Outside the Repository

## When this applies

A code or config default names something whose existence is controlled outside your
repository — a gateway model alias, a serving endpoint name, a bucket, a queue, a
search index. Also when reviewing or merging a PR that claims end-to-end
verification of such a default, and when a feature that "was tested" fails on its
default path in an environment nobody changed.

## Do this

1. **Re-query the owner's catalog at review/merge time** and confirm the default
   still resolves: `GET /v1/models` for an OpenAI-compatible provider or gateway,
   the equivalent list/describe call otherwise. A measurement inside the PR body
   dates from when it was written; nothing in code review re-checks a name the repo
   does not own.
2. **Paste the dated check into the PR** (endpoint queried, result, date), so the
   next reviewer reads the age of the evidence instead of trusting its existence.
3. **Resolve the configured name at startup, in the client wrapper that owns the
   call, and crash when it is absent** — the process that will use the name is the
   one that must prove it exists, so a retired alias fails the deploy instead of the
   user's request. Put the resolution in the same module that builds the request, so
   a new call site cannot bypass it. Config-shape and startup-validation mechanics:
   [infrastructure-config-environment-config].
4. **Make the runtime failure name the resource**: log the requested name and the
   provider's error verbatim, so "400 from the gateway" reads as "alias X no longer
   exists" without a debugging session.

| Case | Do |
|------|----|
| The named resource is required for the feature | Validate at startup, crash on failure, and gate the deploy on that check |
| Several names are tried in order (primary + fallbacks) | Resolve all of them at startup, log which ones exist, and alert when the primary is unresolvable while a fallback is serving |
| The provider has announced a shutdown date | Record the date next to the default (comment + tracking issue) — preview-tier names can retire on as little as two weeks' notice |
| The name exists in one environment's catalog but not another's | Make it a required per-environment value with no default, and run the resolution check in every environment at boot — one shared default silently points staging at a name only production owns ([infrastructure-config-environment-config] owns the config shape) |

## Edge cases

| Case | Then |
|------|------|
| CI has no credentials for the catalog | Run the check by hand at review and paste the output with its date; add the startup resolution check so runtime still catches drift |
| The gateway lists the alias from static config, not live upstream state | A listed name can still fail upstream — confirm with one real call, not just the list (LiteLLM serves `/v1/models` from its configured `model_list`) |
| Catalog lists the name but calls still fail | The name exists and your route/key lacks access — repeat the check with the exact credentials the service uses |
| Gateway resolves wildcards or aliases to upstream models | Query the gateway's own list endpoint (LiteLLM `/v1/models`, `check_provider_endpoint` for wildcards), not the upstream provider's — the gateway's mapping is the one your code hits |
| Default is only reached on a rarely used path | The startup check still runs — that is the point; a path exercised once a month otherwise reveals the dead name to a user first |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust a PR's "verified end-to-end" for an externally owned name | Re-query the catalog at merge time and record the dated result | The measurement was true when written; the catalog changes outside the repo while code, tests, and build all keep passing |
| Hardcode a convenient default so local dev "just works" | Require the value and validate it at startup ([infrastructure-config-environment-config]) | A default that suits the author's machine becomes the silent production value once the real name is retired |
| Let the first user request discover that the name is gone | Resolve the name at startup / in the health check | The same failure costs a failed deploy instead of a broken feature plus an incident |

## Sources

- https://developers.openai.com/api/docs/deprecations — deprecation announces a shutdown date, after which the model "will no longer be accessible"; notice periods 6 months (GA), 3 months (specialized), as little as 2 weeks (preview)
- https://developers.openai.com/api/docs/api-reference/models/list — `GET /v1/models` "Lists the currently available models, and provides basic information about each one such as the owner and availability"
- https://docs.litellm.ai/docs/proxy/model_discovery — the proxy's `/v1/models` returns the models actually available behind that gateway; `check_provider_endpoint: true` resolves wildcard entries
- Field context: 2026-07-28 review of an internal meeting-summary service — the default model alias was removed from the LiteLLM catalog between PR verification and review; code, tests, and build were all green while `/chat/completions` returned 400
