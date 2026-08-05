# Findings — Task 02: Semantic routing probe (15 scenarios)

Method (plan D2): each probe is a realistic implementation intent, traced
INDEX.md "route here when" → domain index "load when" → page. Verdicts:
UNIQUE (one page wins), AMBIGUOUS (≥2 equally-matching rows), MISS (no row).
For the 2 out-of-charter probes, MISS is the *correct* outcome — recorded is
whether the router can tell cleanly.

### Probe 1 — "리스트 API에 커서 기반 페이지네이션 추가" (backend+databases)
INDEX: backend "API contracts" (artifact = endpoint contract). Domain:
`pagination-contract` — "Designing a list endpoint's request/response contract —
cursor vs page-number … (the backing SQL/index → databases/query-optimization/
keyset-pagination)". Cross-link to databases is inline in the load-when line.
**Verdict: UNIQUE** (exemplary cross-domain composition).

### Probe 2 — "웹훅 중복 전달로 결제가 두 번 발생"
INDEX: backend. Candidates: `api-design/idempotency` ("An endpoint with side
effects (create, charge, send) can receive the same request twice") vs
`jobs/idempotent-handlers` ("queue consumer, background job"). Webhook = endpoint
→ idempotency matches; jobs line does not claim endpoints. **Verdict: UNIQUE.**

### Probe 3 — "검색 자동완성에서 이전 검색어 결과가 늦게 도착해 최신 결과를 덮어씀"
INDEX: frontend. `data-fetching/race-conditions` — "search-as-you-type … UI
intermittently shows results for a previous input". **Verdict: UNIQUE.**

### Probe 4 — "URL의 주문 ID를 바꾸면 남의 주문이 보임"
INDEX: security ("per-resource authorization (IDOR)"). `authz/resource-level-checks`
— "resource identified by a request-supplied id (IDOR risk)". **Verdict: UNIQUE.**

### Probe 5 — "버그 수정에 회귀 테스트 추가 — 어떤 케이스를 커버해야 하나"
INDEX: testing. `quality/minimum-case-set` — "adding a regression test for a bug
fix". **Verdict: UNIQUE.**

### Probe 6 — "스펙 문서가 요구사항을 충족하는지 검사하는 grep 게이트 작성" (qa+testing)
INDEX: qa "automated verification of document deliverables (spec/RFC gates)" AND
testing has `quality/spec-artifact-checks` ("automated check that a mapping table
covers every rule/field/enum case"), `quality/checks-that-cannot-pass` (gate on an
unwritten doc). qa's `spec-document-gates` load-when: "Writing or reviewing
automated checks (grep/script) that decide whether a spec/RFC/schema document
meets its requirements". Two domains claim near-identical scope; INDEX gives qa
the "document deliverables" phrase but testing's page triggers match the same
sentence. **Verdict: AMBIGUOUS — testing/quality doc-gate cluster (4 pages) vs
qa/document-verification (2 pages) split one concern across two domains.**
Mitigation exists (INDEX qa line says "automated verification of document
deliverables"; testing line says "writing automated test code") but the page-level
triggers overlap materially.

### Probe 7 — "재시도하면 통과하는 간헐적 CI 테스트 실패" (testing+debugging)
testing `flaky/diagnosing-flaky-tests`: "A test fails intermittently with no code
change: on retry, in CI only". debugging `concurrency/intermittent-failures`:
"passes on retry, fails under load, fails only in CI, **flaky test**". Both
domain INDEX lines ("flaky tests" / "intermittent failures") and both page
triggers claim the same situation verbatim. **Verdict: AMBIGUOUS — dual ownership
of flaky-test diagnosis.** (INDEX debugging line does scope to "diagnosing", and
testing to policy/quarantine, but the page triggers don't respect that split.)

### Probe 8 — "쿠버네티스 파드가 OOMKilled로 재시작"
INDEX: infrastructure. `containers/resource-limits-and-probes` — "pods OOMKilled,
evicted, or CPU-throttled". **Verdict: UNIQUE.**

### Probe 9 — "macOS에선 되는데 리눅스 CI에서 sed -i가 실패"
INDEX: platforms ("BSD-vs-GNU CLI"). `tools/bsd-vs-gnu-cli` — names `sed -i`
explicitly. **Verdict: UNIQUE.**

### Probe 10 — "앱 전환 후 돌아오면 작성 중이던 폼이 사라짐"
INDEX: mobile ("process death/state survival"). `lifecycle/process-death-and-state`
— "'app lost my data when I switched apps'". **Verdict: UNIQUE.**

### Probe 11 — "로그인 유지 방식 설계: 세션 vs 토큰, 서버 발급, 클라 저장" (security+backend+frontend)
INDEX: security ("session-vs-token auth choice"). `authn/session-vs-token` owns
the choice and its load-when routes onward: "(implementation → wiki/backend/
common/auth/, wiki/frontend/auth/)". Three-domain chain fully signposted.
**Verdict: UNIQUE** (chained).

### Probe 12 — "외부 결제 API 호출에 타임아웃/재시도 설계"
INDEX: backend. `common/reliability/timeouts-and-retries` — exact match.
**Verdict: UNIQUE.**

### Probe 13 — "S3 업로드 후 DB에 어떤 값을 저장해야 하나"
INDEX: backend ("object-storage references"). `common/storage/object-key-persistence`
— "choosing which response field goes in the DB column". **Verdict: UNIQUE.**

### Probe 14 — [out-of-charter] "유니티 게임 셰이더 최적화"
INDEX: no "route here when" line mentions games/graphics/GPU. Router can tell
immediately; protocol step 5 applies (answer not-wiki-backed + gap log).
**Verdict: MISS — clean.**

### Probe 15 — [out-of-charter] "ML 모델 학습 파이프라인의 하이퍼파라미터 튜닝"
INDEX: backend line contains "LLM completion validation & context budgeting" — a
weak attractor for ML-ish queries. Backend `llm` category pages are strictly about
*consuming* completions; their triggers reject the match (protocol step 3 drift
check catches it). **Verdict: MISS — clean, one hop wasted.** Minor: INDEX line
could say "consuming LLM APIs" to repel training/ML queries at the root.

## Summary

- Routing precision: **11/13 UNIQUE** on in-charter probes; both out-of-charter
  probes MISS cleanly (correct behavior).
- **AMBIGUOUS #1 (probe 6):** doc-verification gates split across
  testing/quality (spec-artifact-checks, checks-that-cannot-pass,
  schema-additions-under-a-golden-gate, harness-reverse-controls) and
  qa/document-verification (spec-document-gates, editing-a-gated-document).
  → issue: unify ownership or sharpen the two clusters' load-when lines with
  explicit mutual cross-pointers ("authoring the check code → testing;
  release-gate policy → qa").
- **AMBIGUOUS #2 (probe 7):** flaky-test diagnosis claimed verbatim by both
  testing/flaky/diagnosing-flaky-tests and debugging/concurrency/
  intermittent-failures. → issue: give each trigger a disjoint scope
  (test-suite-local diagnosis+policy → testing; general intermittent failures
  incl. prod → debugging) and cross-link.
- Minor (probe 15): backend INDEX "LLM" phrasing → "consuming LLM APIs".
- Strengths worth keeping: inline cross-domain pointers in load-when lines
  (probes 1, 11) make multi-domain work chain without bulk-loading.
