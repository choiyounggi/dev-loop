---
id: backend-common-api-design-agent-tool-granularity
domain: backend
category: api-design
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/EveryInc/compound-engineering-plugin
  - https://www.anthropic.com/engineering/building-effective-agents
last_verified: 2026-08-22
related: [frontend-agent-interfaces-agent-facing-tool-surfaces, backend-common-llm-binding-instructions-for-agents]
---

# Choosing the Tool Surface an In-App LLM Agent Calls

## When this applies

Adding agent capabilities to an application — an MCP server, a
function-calling tool list, plugin tools; deciding between exposing a
workflow function and exposing primitives; an agent cannot perform an action
the UI offers; reviewing a tool list for an agent feature.

## Do this

1. Build a capability map — every UI action paired with its agent-tool
   equivalent — and close the gaps: an action reachable in the UI but not by
   the agent caps the agent at chatbot, answering questions about work it
   cannot do.
2. Expose atomic primitives (create/read/update/delete/list, send, search)
   and implement features as prompts that compose them in an agent loop.
   Business workflow baked into one tool (`process_feedback` doing
   categorize + prioritize + store + notify in code) fixes every decision at
   build time — expose `store_item` and `send_message`, and let the prompt
   own the workflow.
3. Complete each resource's CRUD: a tool set that can create but not list,
   update, or delete strands the agent mid-task, in a state only a human can
   clean up.
4. End agent tasks with an explicit completion tool (`complete_task`) rather
   than heuristic detection (silence, phrase matching) — heuristics
   misclassify pauses as completions and completions as pauses.
5. Run the agent in the user's own data space, and reflect agent-caused
   changes in the UI as they happen — a sandboxed copy or a silent mutation
   both read as "the agent is broken" to the user watching the screen.
6. Before shipping, run the composition test: ask the agent for an in-domain
   outcome you never explicitly built. With primitives and parity in place it
   composes a path or fails visibly; with workflow-shaped tools it can only
   do what was anticipated.

## Edge cases

| Case | Then |
|------|------|
| The upstream API is large or changes often | Generate the tool list from the API's schema instead of hand-maintaining a static mapping that drifts |
| A composed flow is frequent and latency-sensitive | Add a domain-level tool for that observed pattern, and keep the primitives it composes — the shortcut is an optimization, not a replacement |
| An action is dangerous to run autonomously | Gate it behind an approval step that states its reason in the tool result — an unexplained refusal reads as a bug and invites workarounds |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Bolt a chat agent onto a finished UI as a router to hardcoded flows | Build the capability map and primitive tools alongside the feature | A router caps capability at exactly the flows someone anticipated |
| Add one convenience tool per product feature | Expose primitives; ship features as prompts | With workflow-shaped tools every new feature needs new code; with primitives it needs a new prompt |

## Sources

- https://github.com/EveryInc/compound-engineering-plugin — agent-native-architecture skill: parity capability map, tools-as-primitives with the `process_feedback` counter-example, CRUD completeness, explicit completion signal, named anti-patterns (agent-as-router, sandbox isolation, silent actions); field-tested in the plugin authors' shipped products
- https://www.anthropic.com/engineering/building-effective-agents — agent-computer interface guidance: invest in tool definitions and keep tools simple and composable
