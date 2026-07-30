# Knowledge flush — 5 insight(s) → 2 pages

Queue drained: 5 pending candidates across 3 sessions. Four of them describe the
same situation at different granularity and were folded into one page (AGENTS.md
"one case per page" cuts by _situation_, not by candidate); the fifth is
unrelated and got its own page.

| #   | Candidate (hash)   | Claim                                                                                                                                                | Outcome                                                                  |
| --- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| 1   | `f997639131d8ec9e` | Validate a grep gate on a conforming sibling file before adopting it                                                                                 | Folded → `testing-docs-as-spec-document-conformance-checks` (Do this §2) |
| 2   | `739b75ed972c6078` | Token-presence gates are blind three ways; split into structure / modality / row-completeness / cross-reference axes with per-axis negative controls | Folded → same page (Do this §3)                                          |
| 3   | `2e3fcd105c8512fa` | Persist `s3.upload()` `Key`, not `Location`                                                                                                          | New page `backend-common-storage-object-key-persistence`                 |
| 4   | `39dfae0d5a813cb4` | Pair a coverage check with a value-validity check, each with its own negative control                                                                | Folded → same page (Do this §4)                                          |
| 5   | `18dc623000d54f07` | Split Markdown rows on unescaped pipes only                                                                                                          | Folded → same page (Edge cases + Instead of)                             |

## Verified best-practice

### Insights 1, 2, 4 — controls on a document-conformance check → `confidence: verified`

**Claim.** A checker is unproven until it has been run against both a conforming
input (must PASS) and a deliberately-broken input (must FAIL), one control per
check; presence checks do not establish correctness.

Sources checked:

- **ESLint `RuleTester`** — https://eslint.org/docs/latest/integrate/nodejs-api#ruletester —
  fetched; requires both a `valid` array (rule must not fire on compliant code)
  and an `invalid` array whose cases must assert the errors the rule produces.
  This is the positive/negative control pair as an enforced API shape.
- **Semgrep rule tests** — https://docs.semgrep.dev/writing-rules/testing-rules —
  fetched; `ruleid:` annotates true positives and `ok:` true negatives, both in
  the same test file. Second independent tool converging on the same requirement.
- **Google Testing Blog, mutation testing** — https://testing.googleblog.com/2021/04/mutation-testing.html —
  already cited elsewhere in this wiki; supports "insert a fault, require the
  check to fail" as the measure of detection.
- **JSON Schema `required`** — https://json-schema.org/understanding-json-schema/reference/object —
  fetched; `required` asserts key presence and constrains no value (a required
  property may even be `null`). This is the canonical statement of the
  coverage-vs-validity split that insight 4 hit empirically.

**How verified.** The two linter sources are official docs for tools whose entire
job is "run a rule against a document/AST", and both mandate the two-sided test.
The candidates' own evidence (an independent auditor's 8 mutations passing a
16-gate suite; a `Bogus` cell surviving a coverage check) is the field half.
Insight 1's specific mechanism — a missing target file makes _every_ pattern
red, so red carries no information about the pattern — is a direct logical
consequence, and the candidate reports the positive control actually run
(7 sections matched on the conforming sibling `rfcs/0005`).

### Insight 5 — unescaped-pipe splitting of GFM table rows → `confidence: verified`

- **GFM spec, tables extension** — https://github.github.com/gfm/#tables-extension- —
  fetched. Cells are "separated by pipes (`|`)", and Example 200 shows you
  "include a pipe in a cell's content by escaping it, **including inside other
  inline spans**" (`f\|oo`, and an escaped pipe inside a code span and inside
  emphasis). So `\|` is legal cell content and `split("|")` overcounts a correct
  row.
- **Reproduced here.** Ran the candidate's `re.split(r"(?<!\\)\|", row)` over both
  new pages: cell counts come out uniform per table (4/4/4/4, then 3×6, 2×8,
  3×7). The two rows in this PR that carry an escaped pipe in their text are
  exactly the rows a naive split would have mis-flagged — the rule's own page is
  its positive control.

### Insight 3 — persist `Key`, not `Location` → `confidence: verified`

- **S3 `CompleteMultipartUpload` API reference** — https://docs.aws.amazon.com/AmazonS3/latest/API/API_CompleteMultipartUpload.html —
  fetched. `Key` is documented as "The object key of the newly created object";
  `Location` is documented only as "The URI that identifies the newly created
  object", with **no encoding guarantee**. That asymmetry is the load-bearing
  fact: only one of the two fields has a contract.
- **`AWS.S3.ManagedUpload` docs** — https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3/ManagedUpload.html —
  fetched. Callback data carries `Location`, `ETag`, `Bucket`, `Key`;
  `minPartSize = 1024 * 1024 * 5` and default `partSize` is 5 MB. Confirms the
  candidate's 5,242,880-byte boundary and that `Key` is present on both paths.
- **`lib/s3/managed_upload.js` source** — https://github.com/aws/aws-sdk-js/blob/master/lib/s3/managed_upload.js —
  fetched from `raw.githubusercontent.com`. `finishSinglePart` builds
  `data.Location` from `endpoint.protocol + '//' + endpoint.host + httpReq.path`
  and sets `data.Key` from `params.Key`; `finishMultiPart` takes the service's
  `Location` and applies only `.replace(/%2F/g, '/')`. Exactly the two producers
  the candidate described, verified line-for-line against current master.
- **aws-sdk-js issue #1158** — https://github.com/aws/aws-sdk-js/issues/1158 —
  fetched. Reported side by side: multipart returns
  `…/stream-uploads%2Fkokoko.gif`, single-part returns `…/stream-uploads/kokoko.gif`,
  and `Key` is identical in both. Independent confirmation that `Location` is
  path-dependent and `Key` is stable.
- **aws-sdk-js-v3 issue #5656** — https://github.com/aws/aws-sdk-js-v3/issues/5656 —
  fetched. Same structural split in v3 `lib-storage`: `__uploadUsingPut`
  constructs `Location` client-side, `CompleteMultipartUploadCommand` does not.
  Widened `applies_to` to `[aws-s3, aws-sdk-js-v2, aws-sdk-js-v3]`. (Closed for
  staleness — no maintainer fix, so the directive is the workaround, not a bug
  that has since been patched.)

**One scope correction against the candidate.** The candidate asserted the
multipart form is specifically `space → +`. What is _documented/reproduced_ in
public sources is the slash case (`/` → `%2F`, visible in #1158 and implied by
the SDK's `%2F`-only repair). The `+`-for-space observation is field evidence
from the originating production incident, consistent with form-urlencoding but
not shown in a cited source. The page therefore labels the encoding column
"Observed form" and does not claim a documented `+` contract; the **directive**
(store `Key`) is fully verified and does not depend on which character it is.

## Existing-layer check

Pages read before routing:

| Read                                                                                                    | Why                                              | Result                                                                                                                                                                                                                                                                                                                    |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INDEX.md`                                                                                              | Domain routing                                   | testing vs qa vs backend decided below                                                                                                                                                                                                                                                                                    |
| `wiki/testing/index.md` (all 8 "load when" lines)                                                       | Overlap scan                                     | No page covers document/spec checking                                                                                                                                                                                                                                                                                     |
| `wiki/testing/quality/tests-that-cannot-fail.md` (full)                                                 | Nearest neighbour — owns "prove a test can fail" | **Overlap, not duplication.** It owns mutation-and-require-red for _test code_ (its never-fails table is Jest/mock/async-shaped). It has no positive-control half and nothing about documents. Kept separate; the new page `related:`-links it and routes to it from an edge-case row ("subject is code, not a document") |
| `wiki/testing/quality/minimum-case-set.md`, `behavior-not-implementation.md`                            | Overlap scan                                     | Case selection / assertion targets for code; no conflict. `minimum-case-set` added to `related:`                                                                                                                                                                                                                          |
| `wiki/qa/index.md` + `process/release-gates.md`, `acceptance-criteria.md`                               | Insights 2 and 5 were tagged `domain: qa`        | `release-gates` is about _which_ gates a release must clear, not whether a gate can fail — no overlap. `acceptance-criteria` owns "make the requirement testable", which is upstream of "check the document encodes it"; linked in `related:` and in an edge-case row so the two compose                                  |
| `grep -ril` over `wiki/` for mutation / markdown / negative control / linter / lint rule / docs-as-spec | Whole-wiki dedup                                 | Only `tests-that-cannot-fail` hit meaningfully; the rest are incidental word matches in frontend/security/backend pages                                                                                                                                                                                                   |
| `wiki/backend/index.md` + all 8 `common/` categories                                                    | Insight 3 routing                                | No storage/object-storage page exists                                                                                                                                                                                                                                                                                     |
| `grep -ril` over `wiki/` for s3 / multipart / object storage / presigned / url-encod                    | Whole-wiki dedup for insight 3                   | Zero real hits (`column-data-types.md` and `severity-and-priority.md` match on unrelated substrings)                                                                                                                                                                                                                      |

**Conflicts flagged:** none. No existing directive is contradicted or overwritten;
both pages are additive.

**Merge-before-create decision.** Insights 1/2/4/5 merged into a single _new_
page rather than appended to `tests-that-cannot-fail`: appending would have
pushed that page past its one-case scope (test code → documents) and mixed two
trigger sets in one "When this applies". They merged with _each other_ because
they share one situation — writing a checker whose subject is a document — which
is why 5 candidates produced 2 pages, not 5.

**Related-links added:**
`testing-docs-as-spec-document-conformance-checks` → `testing-quality-tests-that-cannot-fail`,
`testing-quality-minimum-case-set`, `qa-process-acceptance-criteria`.
`backend-common-storage-object-key-persistence` → `backend-common-api-design-idempotency`
(backfill retry behaviour), `backend-node-boundaries-runtime-validation`.
All five ids verified to resolve to existing files; no duplicate ids in `wiki/`.

## Routing decision

### 1. `wiki/testing/docs-as-spec/document-conformance-checks.md` — NEW category

- **Domain `testing`** over `qa` (two candidates were tagged `qa`): the artifact
  being authored is an automated check, which `INDEX.md` routes to testing; `qa`
  is scoped to release _process_. Routing by "which artifact do you change"
  (AGENTS.md step 1) puts it in testing.
- **New category `docs-as-spec`** rather than `quality`. Every existing testing
  category — strategy, quality, data, mocking, flaky, async, e2e — is organized
  around testing _executable code_, and their mechanics (assertions, fixtures,
  fake timers, selectors) do not apply when the subject is a Markdown document.
  Filing under `quality` would have made the "load when" line collide with
  `tests-that-cannot-fail`'s, which is the drift condition AGENTS.md invariant 1
  warns about. Single-page categories are already the norm here (`async`, `e2e`,
  `data`, `mocking`, `flaky` each hold one page).
- Index updates: new section in `wiki/testing/index.md` with a "load when" line
  enumerating all four distinct uses (authoring the check pre-document; choosing
  the mutation; a gate that passed on a degraded document; Markdown table
  parsing); testing's "Route here for" preamble and the root `INDEX.md` testing
  row both extended with "checks whose subject is a document rather than code".

### 2. `wiki/backend/common/storage/object-key-persistence.md` — NEW category

- **Domain `backend`, subtree `common`** rather than `node`. The directive
  ("persist the identifier the service documents as canonical; derive URLs at
  read time") is language-agnostic and reproduces in v2 and v3 — AGENTS.md says
  common owns the principle and the stack page owns the mechanics, and there are
  no Node-runtime mechanics here beyond the SDK field names.
- **New category `storage`.** The eight existing `common/` categories are
  api-design, reliability, caching, jobs, errors, auth, orm, concurrency —
  none covers object storage. `api-design` is about this service's own contract,
  not a dependency's response shape; `orm` is DB persistence.
- Index updates: new `### storage` section in `wiki/backend/index.md` (placed
  before `reliability`), plus "object-storage references" added to the `common`
  subtree route line and to the backend row of the root `INDEX.md`.

## Cross-Check

Cross-Check: source-level, not adversarial-reviewer. Every claim in this PR was
re-derived in-session from the primary source rather than from the harvested
candidate text — five docs/issues fetched for the S3 page (including reading
`managed_upload.js` on `raw.githubusercontent.com` instead of trusting the
candidate's line numbers) and four for the doc-gate page, with two independent
tools (ESLint `RuleTester`, Semgrep rule tests) converging on the
positive+negative control requirement. The pipe-splitting rule was reproduced
against this PR's own two pages. One candidate claim was downgraded on review
(the `space → +` multipart form is field evidence, not a documented contract —
see the scope correction above). No separate adversarial reviewer ran; the
owner's PR review is the remaining gate.

## Decision Log (AI 생성)

### 의도 — 무엇을 / 왜

- 큐에 쌓인 5개 후보를 각각 원본 1차 소스로 재검증한 뒤 wiki 2페이지로 적재했다. 후보 텍스트를 그대로 믿지 않고 ESLint/Semgrep/GFM/JSON Schema/AWS 문서와 `managed_upload.js` 소스를 직접 열어 대조했다 — 수확된 블록은 후보이지 검증된 지식이 아니기 때문.
- 5후보 → 2페이지로 접었다. AGENTS.md "one case per page"는 후보 수가 아니라 **상황** 단위로 자르므로, 1·2·4·5는 모두 "문서를 대상으로 하는 체커를 작성하는 상황" 하나라 한 페이지로 병합했다.
- 새 카테고리 2개(`testing/docs-as-spec`, `backend/common/storage`)를 만들었다. 기존 카테고리는 각각 "코드 테스트"와 "8개 common 관심사"로 짜여 있어 문서 검증·오브젝트 스토리지를 담을 자리가 없었다.

### 배제한 대안 — 무엇을 안 했나 / 왜

- `testing/quality/tests-that-cannot-fail.md`에 append하지 않았다. 그 페이지는 *테스트 코드*의 mutation 규칙을 소유하고 "load when" 라인이 충돌해 AGENTS.md invariant 1의 drift 조건에 걸린다. 대신 양방향 링크로 연결.
- 후보 2·5가 `domain: qa` 태그였지만 qa로 라우팅하지 않았다. qa는 릴리즈 *프로세스* 스코프이고, 여기서 만드는 산출물은 자동 체커라 testing이 소유한다.
- 후보 3을 `backend/node`가 아닌 `backend/common`에 뒀다. v2·v3 양쪽에서 재현되고 원리가 언어 무관이라, "common이 원리·stack이 메커닉"이라는 AGENTS.md 규칙에 따랐다.
- 후보 3의 "space → `+`"를 문서화된 계약으로 단정하지 않았다. 공개 소스로 확인되는 건 `/` → `%2F`뿐이라 컬럼명을 "Observed form"으로 두고 스코프를 좁혔다.
- 포매터(PostToolUse prettier)가 index 3개 파일의 표 전체를 패딩해 무관한 행까지 diff에 올렸다 — 되돌리고 스크립트로 대상 라인만 재적용했다(INDEX.md 2줄, backend +8/-1, testing +12/-3).

### 리뷰어가 볼 곳 — 신뢰성 판단 포인트

- `.dev-loop/INGEST_REPORT.md` "Verified best-practice" — 인용 URL이 실제로 그 주장을 지지하는지. 특히 "One scope correction" 문단(후보보다 약하게 적은 부분).
- `wiki/testing/docs-as-spec/document-conformance-checks.md:39-42` — positive/negative control 표. ESLint valid/invalid + Semgrep ok/ruleid 두 출처가 실제로 이 형태를 강제하는지.
- `wiki/backend/common/storage/object-key-persistence.md:40-43` — 단일/멀티파트 인코딩 표. "Observed form" 열이 문서화된 계약처럼 읽히지 않는지.
- `wiki/testing/index.md`, `wiki/backend/index.md` — 새 "load when" 라인이 인접 페이지 트리거와 겹치지 않는지(AGENTS.md invariant 1).
- 새 카테고리 2개 신설이 과한지 — 기존 카테고리로 접는 게 낫다고 보면 이 PR에서 되돌리기 쉬운 부분.

> [추정] 표시 항목은 세션에 명시 근거가 없어 사후 재구성한 의도임 — 검증 필요

## Invariants checked

- Body length: 73 and 60 lines (limit 120).
- Every `related:` id resolves; no duplicate ids across `wiki/`.
- Both pages listed in their domain `index.md`; both domains in `INDEX.md`.
- Two `## [2026-07-30] ingest` entries appended to `log.md`.
- Positive guidance only: every "don't" lives in an `Instead of` row paired with
  its replacement and a why.
- Table cell counts re-verified with the unescaped-pipe splitter this PR
  documents.
