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
  environment variable is set to false, git will not prompt on the terminal (e.g., when
  asking for HTTP authentication)." Second independent instance of a CLI shipping an
  explicit opt-out for terminal prompting. (The doc does **not** state the default; an
  earlier draft asserted "default is to prompt" as sourced — removed by cross-check.)
- [OpenBSD `ssh_config`](https://man.openbsd.org/ssh_config) — `BatchMode=yes`: "user
  interaction such as password prompts and host key confirmation requests will be
  disabled"; `StrictHostKeyChecking=accept-new` adds new host keys without permitting
  changed ones. Added by cross-check: `ssh -n` detaches stdin but the same man page notes
  it "does not work if ssh needs to ask for a password or passphrase", so the prompt
  channel needs its own directive.

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
  was reached"; the full set is five values — `stop`, `length`, `tool_calls`,
  `content_filter`, and the deprecated `function_call`. Both tool-calling values return
  blank `content` by design, which is why the page carves them out of the
  blank-content failure path (the `function_call` half was added by cross-check).
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

Self-lint before commit (re-run after the cross-check fixes): all 3 new pages are 66–77
lines (limit 120); zero banned vague
qualifiers (`usually|generally|consider|might want|as appropriate|typically|probably|ideally`);
all 11 `related:`/inline page ids resolve to exactly one existing page each.

## Routing decision

| Insight | Target | Rationale |
|---------|--------|-----------|
| 1 — non-interactive CLI invocation | `platforms` / `processes` / **new page** `non-interactive-cli-invocation.md` (`platforms-processes-non-interactive-cli-invocation`) | Existing category, no new one needed: `processes` already owns "how a process is started and kept alive outside an interactive session", and this is the sibling case (how it is *invoked*). Domain choice — the artifact changed is a shell/CI invocation, and the OS-level fact (a terminal fd 0 blocks a read) is platforms' subject; debugging is linked, not duplicated |
| 2 — LLM response completeness | `backend` / **NEW category** `common/integrations` / `llm-response-completeness.md` | New category justified: the existing eight common categories cover the API you *publish* (api-design), transport to a dependency (reliability), and internal concerns (caching, jobs, errors, auth, orm, concurrency). None covers *depending on an externally owned service's response contract and its catalog of names*. Placed in `common/` (not `node/`/`python/`) because the decision is language-agnostic; `applies_to: [openai-compatible]` scopes it |
| 3 — externally-owned defaults | `backend` / `common/integrations` / `externally-owned-defaults.md` | Same new category — it is the second face of one concern (insight 2 = the response you get back; insight 3 = the name you asked for). Kept as its own page under AGENTS.md's one-case-per-page rule rather than folded into insight 2, because its trigger (reviewing/merging a diff, plus startup validation) is distinct and it generalizes past LLMs to any repo-external name (bucket, queue, index). Cross-linked to `infrastructure-config-environment-config` and `qa-process-release-gates` |

## Cross-check

Cross-Check: independent headless `claude -p --permission-mode plan` adversarial review of
all three pages + this report returned **VERDICT: FAIL with 12 findings**; 8 were confirmed
against the primary sources and applied, 2 were already clean, 2 were declined with reasons.
Applied:

1. **`ssh -n` was miscategorised** as a prompt-channel control. ssh(1) itself says `-n`
   "does not work if ssh needs to ask for a password or passphrase" — it is a stdin detach.
   Moved to directive 1; directive 2 now uses `-o BatchMode=yes` (+
   `StrictHostKeyChecking=accept-new`), verified against ssh_config and cited.
2. **GNU nohup's stdin redirect is conditional** ("If standard input is a terminal…"). In
   this page's own CI/hook triggers fd 0 is often a pipe, so nohup redirects nothing. The
   page now states that `</dev/null` is the unconditional guarantee.
3. **"No request in the server log ⇒ never left the client" was too strong** — DNS, TLS, and
   proxy failures also produce no access-log entry. Row and `Instead of` row widened to
   "pre-log rejection", with `curl -v` as the discriminator.
4. **Deprecated `function_call` also returns blank `content`** by design and would have hit
   the fail path. Added to the carve-out.
5. **The `finish_reason` enumeration was incomplete** (4 of 5) in both the page's Sources
   bullet and this report. Corrected in both.
6. **`GIT_TERMINAL_PROMPT` "default is to prompt" was inference presented as sourced** — the
   doc states only the false case. Removed.
7. **`wiki/backend/index.md`'s concern-first subtree row was not updated** — routing protocol
   step 2 reads that row before the category tables, so an agent would have landed on
   `reliability` instead of the new `integrations` category. Row extended (the real routing
   defect in this batch).
8. **`environment-config`'s `last_verified` bump was unearned** — a one-row edge-case addition
   does not re-verify its three 12factor sources. Reverted to 2026-07-10 so lint's staleness
   clock is not reset.

Also applied for format: four anti-patterns phrased as negations inside `Do this`/`Edge cases`
tables were restated positively (AGENTS.md keeps negations in `Instead of`), and
`externally-owned-defaults`' pure-pointer row and startup directive were given app-side
substance.

Declined, with reasons: (a) **splitting `externally-owned-defaults` by trigger** — the
corpus norm (`environment-config`, `release-gates`) is several related triggers plus a
numbered list *and* a case table on one page, and the three triggers here are one case seen
at review time, boot time, and failure time; (b) **relocating it to `infrastructure/config`**
— its primary trigger is reviewing application-code defaults and its resolution rule lives
in the client wrapper, so `backend` owns it; the config-shape half is delegated by link and
`environment-config` carries the reciprocal row.

Plumbing updated: `wiki/backend/index.md` (new `### integrations` section, 2 rows, plus the
concern-first subtree row),
`wiki/platforms/index.md` (1 row under `processes`), `INDEX.md` (both domains' "route
here when" lines extended so the new cases are reachable from the root map), `log.md`
(2 `ingest` + 2 `revise` entries, the second recording the cross-check), and
`background-services` / `environment-config` `related:` back-links.

Queue rows for these 3 candidates are retired to `~/.dev-loop/queue/.processed.jsonl`
once this PR is opened.

## Decision Log (AI 생성)

### 의도 — 무엇을 / 왜
- 큐에 쌓인 ★ Insight 3건을 **검증 후** 위키로 승격. 원문(GNU nohup·OpenBSD ssh/ssh_config·git·OpenAI reasoning/chat-object/deprecations/models·vLLM·LiteLLM)을 직접 열어 세 directive 모두 `confidence: verified`로 확정했고, 후보에 없던 사실(게이트웨이별 `reasoning` vs `reasoning_content` 필드명 차이, 게이트웨이 자체 카탈로그를 조회해야 함)은 검증 과정에서 발견해 반영.
- 라우팅은 **merge-before-create**: 인사이트 3은 `infrastructure/config/environment-config`의 "필수 키엔 default 없음" 규칙과 형제 케이스라 그 페이지에 edge case 1행 + 양방향 `related`로 연결하고, 본체는 리뷰시점 체크라는 별개 트리거이므로 별 페이지로 분리.
- `backend/common/integrations`를 **새 카테고리로 신설** — 기존 8개 공통 카테고리는 "내가 발행하는 API"(api-design)와 "전송"(reliability)만 다루고, *외부 소유 서비스의 응답 스펙·이름 카탈로그에 의존하는 것*을 담을 자리가 없었다.
- PR 본문 = INGEST_REPORT (게이트가 요구하는 3개 섹션 + 검증 근거를 리뷰어가 한 화면에서 보게).

### 배제한 대안 — 무엇을 안 했나 / 왜
- **인사이트 1을 `debugging`에 두기** — 클라이언트/서버 가르기가 진단이라 후보였지만, 바뀌는 산출물이 *호출 방식*이고 "터미널 fd 0은 읽기를 막는다"는 OS 사실이라 `platforms`. 진단 단계는 `debugging-methodology-hypothesis-testing` 링크로 처리(중복 금지).
- **인사이트 3을 `qa/process/release-gates`에 병합** — release-gates는 의도적으로 *릴리즈마다 동일한 고정 체크리스트*인데 이건 특정 diff 유형에 걸리는 per-PR 체크라 게이트를 희석시킴. 링크만.
- **인사이트 3을 `infrastructure/config`로 이전**(적대검증 제안) — 거절. 1차 트리거가 애플리케이션 코드 default 리뷰이고 해소 지점이 호출을 만드는 client wrapper라 `backend` 소유가 맞음. config 형태는 링크로 위임.
- **인사이트 2·3을 한 페이지로 합치기** — AGENTS.md의 one-case-per-page 위반(트리거가 각각 응답 수신 / 리뷰·부팅 시점).
- **`last_verified` 일괄 bump** — 12factor 출처를 재검증하지 않았으므로 `environment-config`는 2026-07-10 유지(적대검증 지적 반영).

### 리뷰어가 볼 곳 — 신뢰성 판단 포인트
- `wiki/platforms/processes/non-interactive-cli-invocation.md:26-38` — `ssh -n`(stdin 분리)과 `BatchMode=yes`(프롬프트 차단)를 분리한 부분. 1차 초안은 `-n`을 프롬프트 차단으로 잘못 분류했고 적대검증이 man page 인용으로 잡음.
- 같은 파일 `:45`, `:64` — "서버 로그에 요청 없음"의 결론 범위. DNS/TLS/프록시 선차단을 포함하도록 약화했는데, 이 정도가 적정한지 판단 필요.
- `wiki/backend/common/integrations/llm-response-completeness.md:31-38` — 수용/실패 판정 테이블. 특히 `tool_calls`/deprecated `function_call`에서 blank content가 정상인 carve-out.
- `wiki/backend/index.md:8` — concern-first subtree 행. 라우팅 프로토콜 2단계가 카테고리 테이블보다 **먼저** 읽는 줄이라, 여기 누락되면 새 카테고리에 도달하지 못한다(적대검증이 잡은 유일한 실제 라우팅 결함).
- `wiki/backend/common/integrations/externally-owned-defaults.md` 도메인 선택 — 위 "배제한 대안"의 판단이 맞는지가 이 PR에서 가장 논쟁적인 지점.
- `log.md` 마지막 2줄 — 적대검증 결과와 거절 항목을 기록으로 남긴 부분.

> [추정] 표시 항목 없음 — 모든 의도는 이 세션의 검증·적대검증 기록에 근거가 있다.
>
> 컨펌 예외: 이 PR은 auto-flush(headless) 실행으로 생성되어 푸시 전 대면 컨펌을 받지 못했다. 대신 ① 푸시 대상은 본인 fork(`dch0202-rsquare/dev-loop`)이고 ② 머지는 하지 않으며 ③ 리뷰·머지 판단 전체를 레포 오너에게 남긴다.
