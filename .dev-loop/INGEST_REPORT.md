# Knowledge flush — 3 insight(s)

Drained from `~/.dev-loop/queue` (3 pending candidates, harvested 2026-07-31 from
sessions in `~/.claude/tmp` and `meetingSummary`). Result: **3 new pages** (one of them
opening a new `backend/common/integrations` category) plus one merge-edit into an
existing infrastructure page. No auto-merge.

## Verified best-practice

### 1. A non-interactive flag does not stop a CLI reading stdin
**Claim.** When invoking a prompt-capable CLI from a script/CI/agent harness, pass the
non-interactive flag *and* detach fd 0 (`</dev/null` or `nohup`); if it still hangs,
split client-vs-server by whether the request appears in the server's access log.

Sources checked (all fetched live, 2026-07-31):
- [GNU coreutils `nohup`](https://www.gnu.org/software/coreutils/manual/html_node/nohup-invocation.html)
  — "If standard input is a terminal, redirect it so that terminal sessions do not
  mistakenly consider the terminal to be used by the command. Make the substitute file
  descriptor unreadable, so that commands that mistakenly attempt to read from standard
  input can report an error." Documents this as a GNU extension with the portable form
  `nohup command 0>/dev/null` — which is what makes the page's BSD edge case correct.
- [OpenBSD `ssh(1)`](https://man.openbsd.org/ssh) — `-n` "Redirects stdin from /dev/null
  (actually, prevents reading from stdin). This must be used when ssh is run in the
  background." Primary evidence that mature CLIs ship an explicit stdin-detach flag
  *because* background invocation otherwise blocks.
- [`git` docs, `GIT_TERMINAL_PROMPT`](https://git-scm.com/docs/git) — "If this Boolean
  environment variable is set to false, git will not prompt on the terminal", i.e.
  prompting on the terminal is the default. Second independent instance of the pattern.

Reproduction from the session: `pi 0.79.1 --tools` in the foreground hung twice
(300s, 150s; 0 bytes written), while the LiteLLM gateway log showed **zero requests from
that IP in the window** — so the fault was local, not the model. The identical command
under `nohup` (stdin `/dev/null`) completed a tool call immediately.

**confidence: verified** — mechanism documented by three primary sources, plus a local
reproduction.

### 2. HTTP 200 from `/chat/completions` is not a complete answer
**Claim.** Before using LLM output as an artifact, fail on `finish_reason == "length"`
and on blank `content`; when `content` is blank and a reasoning field is populated,
report that a reasoning model spent the output budget rather than publishing the
reasoning text.

Sources checked (all fetched live, 2026-07-31):
- [OpenAI reasoning guide](https://developers.openai.com/api/docs/guides/reasoning) —
  reasoning tokens "still occupy space in the model's context window and are billed as
  output tokens"; truncation "might occur before any visible output tokens are produced,
  meaning you could incur costs for input and reasoning tokens without receiving a
  visible response"; detect via `status == incomplete` / `max_output_tokens`; reserve
  ≥25,000 tokens while calibrating. This is exactly the failure mode the candidate claimed.
- [OpenAI chat-completion object](https://developers.openai.com/api/docs/api-reference/chat/object)
  — `finish_reason: "length"` = "the maximum number of tokens specified in the request
  was reached"; `tool_calls` and `content_filter` are the other non-`stop` values (the
  `tool_calls` case is why the page carves out legitimately-blank content).
- [vLLM reasoning outputs](https://docs.vllm.ai/en/latest/features/reasoning_outputs.html)
  — reasoning goes in `reasoning` (renamed from `reasoning_content`), final answer in
  `content`.
- [LiteLLM reasoning content](https://docs.litellm.ai/docs/reasoning_content) — LiteLLM
  normalizes to `message.reasoning_content` (+ `thinking_blocks` for Anthropic).

The two gateways disagreeing on the field name is a fact the candidate did not contain;
it became an edge-case row ("check both keys before concluding no reasoning").

Reproduction from the session (2026-07-28, LiteLLM on dgx): alias `chat-default` with a
9,317-token prompt returned **HTTP 200, `finish_reason=length`, `content` 0 chars,
`reasoning_content` 8,173 chars**; the same request to the non-reasoning `coder-fast`
returned `finish=stop` with 2,418 complete chars.

**confidence: verified** — the mechanism and every field name are documented; the
measurement matches.

### 3. Defaults naming repo-external resources need a re-check at merge time
**Claim.** When a default names a resource the repo does not own, re-query the owner's
catalog at review/merge time and resolve the name at startup.

Sources checked (all fetched live, 2026-07-31):
- [OpenAI deprecations](https://developers.openai.com/api/docs/deprecations) — after a
  shutdown date a model "will no longer be accessible"; notice is ≥6 months (GA),
  ≥3 months (specialized variants), and **as little as 2 weeks for preview models**. That
  last number is what makes "verified in the PR body" a perishable claim, and it is now
  the page's rule for tracking shutdown dates.
- [`GET /v1/models`](https://developers.openai.com/api/docs/api-reference/models/list) —
  "Lists the currently available models, and provides basic information about each one
  such as the owner and availability." Confirms the review-time check is a real,
  documented endpoint.
- [LiteLLM proxy model discovery](https://docs.litellm.ai/docs/proxy/model_discovery) —
  the proxy's own `/v1/models` reports what is actually available *behind that gateway*
  (`check_provider_endpoint: true` for wildcards). This corrected the candidate: the
  catalog to query is the gateway's, not the upstream provider's.

Field evidence: PR #15 review (2026-07-28) — default summary alias `dgxb/kanana` had
disappeared from the LiteLLM catalog and returned 400, while the PR's own end-to-end
measurement (7/12, 857 chars in 11s) had been true when written; code, tests, and build
all still passed.

**confidence: verified** — the retirement mechanism and both catalog endpoints are
documented; the incident supplies the review-timing lesson.

## Existing-layer check

Pages read in full before writing anything:

| Read | Outcome |
|------|---------|
| `INDEX.md`, `AGENTS.md`, `templates/page.md`, `skills/wiki-ingest/SKILL.md` | Routing protocol + page format applied (positive guidance, `Instead of` pairing, ≤120 body lines, sourced frontmatter) |
| `wiki/platforms/index.md` + `processes/background-services.md` | **Adjacent, not duplicate.** background-services owns *lifetime after the session ends* (nohup vs launchd vs systemd, KeepAlive, minimal environment). Insight 1 is about *the invocation blocking on fd 0*. Its one genuine overlap — "harness background task killed at session end" — already lives in background-services, so the new page links there instead of restating it. `related:` added **both ways** |
| `wiki/platforms/shells/portable-shell-scripts.md`, `environment/path-resolution.md`, `toolchains/version-management.md`, `tools/bsd-vs-gnu-cli.md` | Grepped all of `wiki/platforms` + `wiki/debugging` for `stdin\|/dev/null\|tty\|interactive`: every hit is about *non-interactive shells not loading rc files* (PATH/shims), never about a blocked stdin read. Confirmed gap. Linked to bsd-vs-gnu-cli for the macOS `timeout` gap, and to path-resolution in an edge case |
| `wiki/debugging/index.md` (+ methodology/signals rows) | Considered as the home for insight 1's client-vs-server split. Kept in platforms because the artifact being changed is the *invocation*; the diagnostic step is one table in that page and links to `debugging-methodology-hypothesis-testing` rather than duplicating it |
| `wiki/backend/index.md` and every `backend/common/**` load-when line | No page covers consuming a third-party API's *response semantics*. `api-design/*` governs the API you publish; `reliability/timeouts-and-retries` governs transport (its "never retry 400" row is why the new page frames a `length` retry as a *new* request — cross-linked). Confirmed gap |
| `backend/node/boundaries/runtime-validation.md`, `backend/python/boundaries/runtime-validation.md` | Stack-level *mechanics* of boundary validation; the new page carries the language-agnostic *decision* (what counts as a complete answer), matching AGENTS.md's common-owns-principle / stack-owns-mechanics split. No duplication |
| `wiki/infrastructure/config/environment-config.md` | **Real overlap with insight 3** — its rule 5 ("Required keys get NO default") is the sibling case. Merged rather than duplicated: added one edge-case row (a required value naming a repo-external resource must be *resolved against the owner's catalog*, not presence-checked) pointing at the new page, plus a `related:` link; `last_verified` bumped to 2026-07-31 |
| `wiki/qa/process/release-gates.md` | Considered as the home for insight 3 (it is a merge-time check). Not merged: release-gates is deliberately a **fixed per-release checklist**, while this is a per-PR check on one kind of diff. Linked from the new page instead, so the gate stays reachable without being diluted |
| `grep -rn 'llm\|openai\|finish_reason\|model alias' wiki/` | Only incidental hits (`security/secrets-in-code` on pasting secrets into an LLM). No prior LLM-integration coverage anywhere |
| `log.md` | No prior `contradiction` or overlapping ingest for these cases. The 2026-07-11 gap entry proposing `common/ingestion/external-source-sync.md` is a different case (idempotent re-ingestion) and is left untouched |

**Conflicts found: none.** Nothing in the wiki contradicts these three directives.

Self-lint before commit: all 3 new pages are 66–71 lines (limit 120); zero banned vague
qualifiers (`usually|generally|consider|might want|as appropriate|typically|probably|ideally`);
all 11 `related:`/inline page ids resolve to exactly one existing page each.

## Routing decision

| Insight | Target | Rationale |
|---------|--------|-----------|
| 1 — non-interactive CLI invocation | `platforms` / `processes` / **new page** `non-interactive-cli-invocation.md` (`platforms-processes-non-interactive-cli-invocation`) | Existing category, no new one needed: `processes` already owns "how a process is started and kept alive outside an interactive session", and this is the sibling case (how it is *invoked*). Domain choice — the artifact changed is a shell/CI invocation, and the OS-level fact (a terminal fd 0 blocks a read) is platforms' subject; debugging is linked, not duplicated |
| 2 — LLM response completeness | `backend` / **NEW category** `common/integrations` / `llm-response-completeness.md` | New category justified: the existing eight common categories cover the API you *publish* (api-design), transport to a dependency (reliability), and internal concerns (caching, jobs, errors, auth, orm, concurrency). None covers *depending on an externally owned service's response contract and its catalog of names*. Placed in `common/` (not `node/`/`python/`) because the decision is language-agnostic; `applies_to: [openai-compatible]` scopes it |
| 3 — externally-owned defaults | `backend` / `common/integrations` / `externally-owned-defaults.md` | Same new category — it is the second face of one concern (insight 2 = the response you get back; insight 3 = the name you asked for). Kept as its own page under AGENTS.md's one-case-per-page rule rather than folded into insight 2, because its trigger (reviewing/merging a diff, plus startup validation) is distinct and it generalizes past LLMs to any repo-external name (bucket, queue, index). Cross-linked to `infrastructure-config-environment-config` and `qa-process-release-gates` |

Plumbing updated: `wiki/backend/index.md` (new `### integrations` section, 2 rows),
`wiki/platforms/index.md` (1 row under `processes`), `INDEX.md` (both domains' "route
here when" lines extended so the new cases are reachable from the root map), `log.md`
(2 `ingest` + 1 `revise` entries), and `background-services` / `environment-config`
`related:` back-links.

Queue rows for these 3 candidates are retired to `~/.dev-loop/queue/.processed.jsonl`
once this PR is opened.
