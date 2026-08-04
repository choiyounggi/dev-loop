# Knowledge flush — 1 insight

Queue drained: 1 candidate from `~/.dev-loop/queue/c2113b9a-…jsonl`. The other 10 session files were empty.

## Verified best-practice

**Claim (as queued):** when the repo already generates an artifact (ERD, schema doc, API spec) and someone asks for the same content as a hand-off deliverable, find and re-run the generator and use its output as the body, hand-writing only what the generator cannot express.

**Sources checked**

| Source                                                                                                    | What it supports                                                                                                                                                                                                         |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [Write the Docs — Documentation principles](https://www.writethedocs.org/guide/writing/docs-principles/)  | "Eliminate content overlap between separate sources"; scopes must be "clearly defined and disjoint" to prevent "parallel maintenance (or worse — _lack_ of maintenance) of the same information across multiple sources" |
| [OpenAPI — Best Practices](https://learn.openapis.org/best-practices.html)                                | A single description acting as the single source of truth for both the product and its docs                                                                                                                              |
| [Google — Documentation Best Practices](https://google.github.io/styleguide/docguide/best_practices.html) | Keep documentation sources next to the code they document so both change together                                                                                                                                        |

**How it was verified.** Fetched the Write the Docs principles page directly rather than relying on the search summary, because the two disagreed in a way that matters. The page **hedges against** a naive reading of this insight: _"In an ideal world, an automated system would generate documentation from the software's source code … Unfortunately, today, the best documentation is hand-written"_, and it notes generators "still require input from humans to function."

That hedge is load-bearing, so the page does **not** claim generation beats writing. It splits the deliverable instead:

- mechanically checkable facts (column sets, key names, endpoint lists, counts) → the generator's output verbatim
- judgement (why a table exists, what is out of scope, caveats) → hand-written, marked as such

Framed that way the directive is supported by all three sources, and "prose quality is the deliverable (tutorial, onboarding guide)" is carved out as an explicit edge-case row pointing back to hand-writing.

**Confidence: `verified`.** The single-source-of-truth / no-content-overlap principle is cited from primary sources. The operational specifics (re-run even when the committed output is stale; land the refresh as its own commit) rest on the field evidence below and are labelled as field evidence in the page's Sources section.

**Field evidence** (2026-08, monorepo hand-off, carried from the queue row): a hand-written schema deliverable matched the live database on **3 of 19** cross-checked tables, listed **2 tables that do not exist**, and rendered **all 14 primary keys as `id`** against an actual `<entity>_id` convention. The repository's committed generated ERD matched the live database on the same tables; one generator re-run refreshed **97 → 105** tables.

## Existing-layer check

**Pages read**

- `INDEX.md` (domain routing), `wiki/qa/index.md`, `wiki/databases/index.md` (the queue row proposed `domain: databases`)
- `wiki/qa/document-verification/spec-document-gates.md`, `wiki/qa/document-verification/editing-a-gated-document.md` — the only existing document-focused pages
- `wiki/frontend/state/derived-state.md` — surfaced by a repo-wide grep for the same underlying principle

**Overlap search.** `grep -rniE "regenerat|re-run the generator|auto-generated|generated (doc|artifact|file)|docs?-as-code"` across all 152 wiki pages returned 3 incidental hits (`security/dependencies/supply-chain`, `testing/quality/harness-reverse-controls`, `testing/e2e/e2e-stability`) — all about regenerating _lockfiles / auth state / mutation inputs_, none about sourcing a document deliverable. **No duplicate; nothing to merge into, so a new page was created.**

**Conflicts flagged:** none. The nearest tension is the Write the Docs "hand-written is best" statement, resolved inside the page rather than left implicit.

**Related links added (both directions)**

| Existing page                                  | Relationship to the new page                                                      |
| ---------------------------------------------- | --------------------------------------------------------------------------------- |
| `qa/document-verification/spec-document-gates` | Gating a document vs. sourcing its content — adjacent, distinct                   |
| `frontend/state/derived-state`                 | Same underlying principle (never store what you can derive) in a different domain |

## Routing decision

**Target: `qa` / new category `deliverables` / `generated-artifacts-as-deliverable-source.md`**

- **Not `databases`** (the queue row's guess). The evidence is an ERD, but the directive is generator-agnostic — it applies equally to API specs and dependency inventories. Filing it under `databases/schema-design` would hide it from every non-schema hand-off.
- **`qa`** owns deliverable quality, and its route-here line already covers document deliverables.
- **New category justified.** Existing qa categories are `process` (acceptance criteria, release gates, regression scope, severity, post-release), `document-verification` (checks that gate a document), `environments`, `bug-reports`, `exploratory`. `document-verification` is about _checking_ a document; this case is about _where a document's content comes from_. No existing category covers that under this or another name.

**Plumbing updated:** `wiki/qa/index.md` (new `## deliverables` section + the domain header's route-here line), `INDEX.md` (qa row), `log.md` (ingest entry recording the new category and its justification).

## Nothing left unverified

No candidate was dropped and none was carried at `unverified`.

Cross-Check: 면제(이 세션은 서브에이전트 사용이 제한됨) — 대신 검색 요약을 신뢰하지 않고 1차 출처(Write the Docs `docs-principles`)를 직접 fetch해 인용문을 원문 대조했고, 그 과정에서 이 지침과 **반대 방향으로 hedge**하는 문장("the best documentation is hand-written", 생성기는 "still require input from humans")을 발견해 페이지의 주장 범위를 "기계적 사실은 생성기, 산문은 손"으로 좁혔다. 중복 여부는 wiki 152개 페이지 전수 grep으로 확인(무관한 3건만 매칭), 라우팅은 databases·qa 두 도메인 index를 모두 읽고 결정했다.

## Decision Log

### D1 — 페이지 주장을 "생성이 우월하다"가 아니라 "기계적 사실만 생성기에서" 로 좁혔다 (의도)

**배제한 대안**: 큐 원문 그대로 "손으로 다시 쓰지 말고 생성기 출력을 써라"로 단정.
**배제 이유**: 1차 출처(Write the Docs)가 정반대 방향으로 hedge한다 — *"the best documentation is hand-written"*, 생성기는 *"still require input from humans to function"*. 검색 요약만 봤으면 이 문장을 놓치고 출처가 뒷받침하지 않는 주장을 인용으로 달 뻔했다. 그래서 산출물을 **기계적 사실(생성기) / 판단·산문(손)** 으로 쪼갰고, "산문 품질 자체가 산출물인 경우(튜토리얼·온보딩)"는 edge case로 손 작성에 돌려보냈다.

### D2 — 도메인을 `databases` 가 아니라 `qa` 로 (의도)

**배제한 대안**: 큐 행이 제안한 `databases`(증거가 ERD라서).
**배제 이유**: 지침 자체는 생성기 종류를 가리지 않는다(API 스펙·의존성 인벤토리에 동일 적용). `databases/schema-design` 아래 두면 스키마가 아닌 모든 hand-off에서 라우팅되지 않는다.

### D3 — `deliverables` 카테고리 신설 (의도)

**배제한 대안**: 기존 `qa/document-verification` 에 세 번째 페이지로 추가.
**배제 이유**: 그 카테고리는 문서를 *검사(gate)* 하는 케이스를 담는다. 이 케이스는 문서의 *내용이 어디서 오는가* 이므로 "load when" 라인이 겹치지 않는다. 기존 5개 카테고리(process·document-verification·environments·bug-reports·exploratory) 어디에도 이름만 다른 동일 개념이 없음을 확인했다.

### 리뷰어가 볼 곳

1. **인용 정확성** — 출처가 hedge한 문장을 페이지 Sources에 그대로 옮겼는지(요약이 붙여준 hedge를 떼면 위조 인용이 된다). 페이지 Sources 첫 항목.
2. **신규 카테고리 타당성** — D3의 근거가 충분한지. 과하면 `document-verification` 으로 접어도 된다.
3. **confidence: verified 판정** — SSOT/중복금지 원리는 1차 출처로 검증됐고, 운영 세부(stale이어도 재실행·리프레시는 별도 커밋)는 field evidence 기반이라 페이지 안에서 라벨을 갈라 적었다. 이 조합을 `verified` 로 볼지 `field-tested` 로 내릴지는 소유자 판단.
