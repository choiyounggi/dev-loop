# Knowledge ingest — WebMCP as the development standard: 2 pages re-verified, 2 new pages, routing widened

Trigger: a Korean WebMCP explainer video (2026-09) pasted for evaluation. Its own content
(declarative vs imperative API, shared page logic, token savings vs browser agents) was already
covered by the two pages ingested 2026-08-18; adoption advocacy and proposal history were again
left out. Verifying the video's claims against primary sources found the wiki a month behind its
sources; the owner then decided (2026-09-28) that the additive WebMCP tool layer is the
development standard for web UI work, QA, and bug fixes, which changes routing.

## Verified best-practice

### 1. `consequentialHint` / `debugging` annotations, ChatGPT site-tools constraints, DevTools pane → **verified**

- https://webmachinelearning.github.io/webmcp/ — Draft Community Group Report dated 2026-09-26;
  IDL `partial interface Document { readonly attribute ModelContext modelContext }` (Document
  only); `dictionary ToolAnnotations { readOnlyHint, untrustedContentHint, consequentialHint,
  debugging }`; no user-confirmation primitive defined. (fetched 2026-09-28)
- https://developer.chrome.com/docs/ai/webmcp/imperative-api — page dated 2026-09-21;
  `document.modelContext.registerTool({ name, description, inputSchema, execute, annotations },
  { signal, exposedTo })`; `consequentialHint` "allows agents and browsers to enforce mandatory
  user confirmation prompts before executing high-stakes tools"; `debugging` Chrome 156+; no
  `requestUserInteraction` mention (the security page's old note on it was removed).
- https://developer.chrome.com/docs/devtools/application/webmcp — page dated 2026-05-12; the
  WebMCP pane is in the Application panel; Available Tools (name, description, invocation count),
  Invoked Tools (status, input, output), Run tool with manual parameters, schema-mismatch errors
  in the output pane.
- https://learn.chatgpt.com/docs/webmcp — "Site tools are ChatGPT's implementation of the
  proposed WebMCP standard"; feature-detects `document.modelContext.registerTool`; declarative
  API and iframe registrations unsupported; "Each tool invocation receives a safety review before
  it runs"; GPT-5.6 Sol / GPT-6 Sol only, Luna disabled; desktop app; not in Enterprise/Edu;
  surfaces: built-in browser, ChatGPT Work, Codex; user toggle under Settings → Browser →
  Permissions. (help.openai.com's site-tools article was dropped as a source: it returns 403 to
  fetchers, so its claims could not be verified.)
- https://developer.chrome.com/docs/ai/webmcp/secure-tools — page dated 2026-09-01; budgets
  30 / 500 / 150 / 1.5K. Contains no auth-state guidance, so the parity gate's both-auth-states
  row is derived from security-agent-exposure-in-session-tool-exposure (PII via read tools,
  server-side authz unchanged), not from this page.
- https://developer.chrome.com/docs/ai/webmcp — page dated 2026-08-07; origin trial from Chrome
  149; Model Context Tool Inspector extension; prompts go to `gemini-3-flash-preview`.

### 2. WebMCP-as-standard routing (owner decision) → **policy, not a sourced claim**

The widened triggers (any new or changed user action in a web UI) and the parity gate's
"every action has a tool unless on the exclusion list" are the owner's development standard,
stated as such in log.md. Every mechanical directive inside those pages is sourced as above.
The standard keeps the existing "human UI primary, tool layer additive" directive unchanged.

## Existing-layer check

Pages read: frontend-agent-interfaces-agent-facing-tool-surfaces, security-agent-exposure-in-session-tool-exposure, qa-process-release-gates, testing-strategy-differential-testing, testing-strategy-cross-layer-effect-tests, testing-strategy-failing-test-first

Whole-wiki grep `webmcp|modelContext|toolname|agent-friendly|answer engine` → 7 files (the two
WebMCP pages, their two domain indexes, INDEX.md, log.md, platforms/tools/plugin-mcp-server-
registration which matches only on a modelcontextprotocol URL). skills/, hooks/, agents/,
templates/, AGENTS.md → 0 mentions. qa/testing/debugging indexes → no WebMCP routing line (the
one qa hit is the model-coupled-guidance-aging-detector page, unrelated). `wiki_search` was
unavailable (dev-loop-wiki MCP server failed to connect this session); the category pages were
read directly per the skill's fallback.

Merge targets: both existing WebMCP pages were **revised in place** (same trigger, same
directive, newer sources) — no new page for that material. The two new pages have new triggers
(a release gate; a test strategy) that no existing qa/testing page covers: release-gates is the
generic checklist page and is linked, not extended; differential-testing / cross-layer-effect-
tests / failing-test-first are referenced from the testing page's edge cases.

Related links added both ways: qa-process-release-gates ↔ qa-process-agent-tool-parity-gate;
testing-strategy-cross-layer-effect-tests ↔ testing-strategy-agent-tool-shared-handler-tests;
frontend agent-facing-tool-surfaces and security in-session-tool-exposure ↔ both new pages.

## Open-PR check

`gh pr list --state open` (2026-09-28): one open PR, #223 (knowledge/choiyounggi-20260927-220735,
15 insights). Its file list contains none of the four WebMCP-related pages; the only overlap is
appended log.md entries (union merge).

## Routing decision

- frontend/agent-interfaces/agent-facing-tool-surfaces — revised (owning artifact: the UI code).
- security/agent-exposure/in-session-tool-exposure — revised (confirmation gating).
- **qa/process/agent-tool-parity-gate** — new page in the existing `process` category beside
  release-gates: it is a release-decision checklist for one surface, so it belongs where
  release-gates and regression-scope live; no new category.
- **testing/strategy/agent-tool-shared-handler-tests** — new page in the existing `strategy`
  category beside test-level-choice / cross-layer-effect-tests: it decides what to test and at
  which level for a two-entry-point action; no new category.
- AGENTS.md routing step 7 — one row added (web UI user action → frontend agent-interfaces,
  then the qa parity gate); tests/review-routing.bats pin 6 → 7 rows in the same commit.
- INDEX.md frontend / qa / testing route lines and the three domain indexes updated; log.md
  gained two ingest entries and two revise entries.

## Verification

- `node scripts/wiki-lint-prohibitions.js wiki` → directives 79, violations 0 (pin unchanged).
- `node scripts/wiki-structure-checks.js wiki --layer bundled` → pages 353, findings 0.
- bats: tests/wiki-*.bats + tests/review-routing.bats + tests/orchestrate-review-pass.bats →
  273/273 ok (one earlier `Recall@5` flake re-ran green; baseline on an untouched HEAD worktree
  measured the same 0.87).
- Body lines: frontend 110, security 76, qa 70, testing 66 (limit 120).

## Independent review (before commit)

- General reviewer (feature-dev:code-reviewer, fresh context): FAIL → 2 major + 4 minor, all
  applied: `consequentialHint` scope aligned with the security page's class table; gate edge row
  for a vanished runtime (human-UI release not blocked); logout added to the AbortSignal edge
  row and the Registration test; step 2/3 of the testing page conditioned on imperative vs
  declarative; AGENTS.md step-7 row admits the exclusion list; qa index clause matched to the
  page trigger.
- Adversarial fact-checker (fresh context, every source re-fetched): 8/8 targeted claims
  confirmed; FAIL on 2 unsupported sentences + 8 imprecisions, all applied: dropped the
  `navigator.modelContext` history (no cited source has it); Run tool no longer claimed to write
  Invoked Tools (that log is agent↔page); `consequentialHint` quote re-attributed (draft: "client
  or agent"; Chrome: "agents and browsers"); secure-tools' stale `requestUserInteraction()`
  mention recorded; `readOnlyHint` "requested" → "in its read-only example"; budgets labelled
  as Chrome's recommendations applied as limits, parameter names included; cross-origin edge
  row now names `allow="tools"` + `exposedTo` + `getTools({ fromOrigins })`; origin trial and
  local flag separated; `SubmitEvent.agentInvoked` / `respondWith()` added to the declarative
  test directive.

## CI agent gate (run 36329841491) — blocker refuted, advisories applied

- Blocker claimed the CG draft has no "client or agent … selectively enforce" language. Ground
  truth (`curl -sL https://webmachinelearning.github.io/webmcp/`, 504,537 bytes, tags stripped,
  2026-09-28): the phrase occurs once, in §6 Security considerations under the mitigation for
  "Misrepresentation of Intent": "A boolean consequentialHint annotation acts as a signal to the
  client or agent that the tool performs a consequential action … This way they can selectively
  enforce mandatory user confirmation prompts before executing high-stakes tools". The gate's
  fetch read a truncated page. The page now names the section beside the quote.
- Advisory (chromestatus unverifiable from CI): confirmed via the JSON API — stage 150
  desktop/Android 149–156; Firefox and Safari "No signal". The source line now records the API
  path.
- Advisory (Run tool vs Invoked Tools): Do 8 no longer implies manual runs are excluded from the
  log; it states only what the DevTools page states.
- Advisory (cross-link gap): qa parity gate ↔ backend-common-api-design-agent-tool-granularity
  linked both ways, with one sentence placing the parity table as the release-time reading of
  that page's design-time capability map.
