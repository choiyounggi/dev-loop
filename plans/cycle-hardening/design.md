# dev-loop 사이클 보강 설계 — 분석 → 설계 → 계획 필수 3단계

Goal: loop-implement/wiki-plan의 "계획 → 구현 → 테스트" 사이클 앞단을
**분석(Analyze) → 설계(Design) → 계획(Decompose)** 3단계로 분리하고, 각 단계에
기계 판정 가능한 종료 게이트를 세워 구현 진입 전에 계획 결함을 차단한다.

작성: 2026-09-02 · 상태: 설계안 (구현 전 영기 승인 대기)

---

## 1. 문제 정의 — 현 사이클의 실증된 결함

현재 흐름: `wiki-plan`(목표 확인 + 위키 결정 매핑 + 태스크 분해가 한 단계에 융합)
→ 태스크별 Red-Green-감사-판정 루프.

실행 단계의 게이트(gates ledger, test-floor, test-quality-auditor)는 촘촘하지만,
**계획 산출물 자체를 검증하는 게이트가 없다.** 실제로 발생한 결함은 전부
계획 시점의 분석 부재였다:

| 실제 사례 | 결함 유형 |
|-----------|----------|
| 위키에 존재하지 않는 페이지를 결정 근거로 인용한 계획 (dl-frontier-gate) | 근거 미검증 |
| 기존 테스트를 깨는 줄 모르고 짜인 계획 (t1-detect, t2-review-blackboard) | 기존 테스트 인벤토리 부재 |
| 핀 갱신(cksum, 지시문 카운트) 예산을 빠뜨린 계획 (session-prompt.md) | 제약조건 조사 부재 |

이 결함들은 구현 단계의 7b(reflect+retry)에서야 드러나 재계획 왕복을 낳거나,
사람이 grep으로 수동 검증해야 잡혔다.

## 2. 방법론 근거 (리서치 결과)

- **Definition of Ready** (Rubin, *Essential Scrum*; Scrum.org): 항목이 "준비"되기 전
  스프린트 진입 금지. MacCormack의 HP 29개 프로젝트 연구에서 기능 명세 완성도가
  최상위 생산성 인자. **경고**: DoR을 경직된 체크박스 계약으로 쓰면 워터폴 재현
  안티패턴 — 그래서 본 설계는 "완벽" 대신 기계 판정 가능한 최소 종료 조건만 게이트로 둔다.
- **Three Amigos / Example Mapping** (Cucumber/BDD): 구현 전 규칙→구체 예시→
  미해결 질문을 분리해 인수 기준을 확정. 대화가 핵심이며 결함을 테스트 단계가 아닌
  발견 단계에서 잡는다. → 분석 단계의 인수 기준 형식으로 채택.
- **설계 리뷰** (Google Research, 141k 문서 분석): 설계 리뷰는 비용이 큰 실수를
  가장 싸게 잡는 지점이며, 구조화된 리뷰가 승인 속도까지 개선. → 설계 단계의
  독립(fresh-context) 리뷰 게이트로 채택. 구현/평가 분리 원칙과 일치.
- **Spike** (XP/SAFe): 견적 불가한 미지수는 타임박스 조사 후 발견/잔여 미지수를
  문서화. 미지수를 플레이스홀더로 계획에 남기는 것 금지. → 분석 단계의 미지수
  처리 규칙으로 채택.

## 3. 목표 사이클

```
[Phase A. 분석]  →  gate-A  →  [Phase B. 설계]  →  gate-B  →  [Phase C. 계획]  →  self-check
                                                                     ↓
                                     기존 실행 루프 (태스크별 0 → 1 → 3~7, 변경 없음)
```

wiki-plan 내부가 A/B/C로 재구조화되고, loop-implement의 "step 2 (Plan)"라는
외부 계약은 유지된다 (호출 지점 변경 없음). 게이트는 기존 gates-ledger 기계를
재사용한다 — 새 판정기를 만들지 않는다.

### Phase A — 분석 (산출물: `plans/<feature>/analysis.md`)

현 wiki-plan step 1(목표 확인)을 흡수·확장. 세 섹션:

**A1. 요구사항 + 인수 예시** (Example Mapping 형식)
```markdown
## Requirements
| Rule | Concrete example (Given/When/Then 1줄) | Open question |
```
- Open question 열이 비거나, 각 항목에 해결(요청자 답 또는 명시적 디폴트)이
  기록되어야 게이트 통과. 미해결 질문을 남긴 채 설계 진입 금지 (DoR).

**A2. 그라운드 트루스 조사** — 증거 첨부 의무 (기존 "Attach evidence, not claims"
원칙을 계획 시점으로 승격)
```markdown
## Ground truth
- Baseline: HEAD <sha>, git status clean 여부
- Affected files: <경로> — 근거: <실행한 검색 명령 + hit 수>
- Existing tests: <영향권 테스트 목록> + baseline 실행 결과 (명령 + rc + 요약)
- Constraints: 핀 파일(cksum/카운트), 보호 스팬, CI 요구사항 — 각각 근거 명령
```

**A3. 미지수 → 스파이크** (XP)
- 견적·설계를 막는 미지수는 타임박스 조사 후 `## Spikes`에 발견/잔여 미지수 기록.
- 잔여 미지수가 load-bearing이면 STOP + 요청자 에스컬레이션. 플레이스홀더로
  다음 단계 진입 금지.

**A4. 외부 리서치** (필수 — `research` 롤, 아래 "리서치 롤" 참조)
- 이 피처의 도메인에 대한 베스트 프랙티스/알려진 함정을 외부 검색으로 확보:
  최소 검색 1회 이상, 채택한 소스는 `## Research` 섹션에 "쿼리 → 소스 URL →
  이 계획에 반영된 내용 1줄"로 기록. 검색했으나 유의미한 결과가 없으면
  "0건 — 쿼리 명시"로 기록 (증거 원칙: 안 찾은 것과 못 찾은 것을 구분).
- 위키가 이미 커버하는 결정은 위키가 우선 (위키 = 검증된 내부 지식). 리서치는
  위키에 없는 영역(`[no-wiki]` 후보)과 스파이크 조사에 집중한다.

**gate-A** (`.dev-loop/gates/plan-A-<feature>.md`, gate-check.sh --run으로 판정):
| Gate | CHECK (기계 실행) | EXPECT |
|------|------------------|--------|
| baseline-tests-ran | analysis.md에 기록된 baseline 테스트 명령 재실행 | rc=0 또는 "사전 실패 목록 명시됨" 토큰 |
| affected-files-evidenced | analysis.md 파서: Affected files 각 행에 `근거:` 존재 | ok |
| open-questions-resolved | analysis.md 파서: Open question 미해결 행 0개 | ok |
| constraints-surveyed | 핀 대상 파일 목록 대조 (스크립트가 기지 핀 목록 보유) | ok |
| research-evidenced | analysis.md 파서: `## Research`에 쿼리+소스 행 ≥1 (또는 0건 기록) | ok |

완전 오프라인 환경(검색 도구 전무)에서는 research-evidenced를 `ABANDON: <사유>`로
공개 포기 — 기존 gates ledger의 abandonment 규칙 그대로, 조용한 생략은 불가.

### Phase B — 설계 (산출물: `plans/<feature>/design.md`)

현 `## Decisions` 표를 확장 — 행마다 두 열 추가:

```markdown
| # | Decision | Choice | Wiki basis | Rejected alternative + why | Testability |
```
- `Wiki basis`는 기존 규칙 유지 (페이지 id 또는 `[no-wiki]` + ingest 후보).
- **grounding 검증이 여기서 기계화**된다: 인용된 모든 페이지 id를
  `${CLAUDE_PLUGIN_ROOT}/wiki/`에 grep — 존재하지 않으면 게이트 FAIL.
  (verify-wiki-plan-groundings-by-grep 교훈의 자동화.)
- `Testability`: 이 결정이 틀렸을 때 어느 테스트/게이트가 잡는지 1줄.

**독립 설계 리뷰** — 새 번들 서브에이전트 `plan-reviewer` (test-quality-auditor,
integration-reviewer와 동급 패턴):
- 입력: analysis.md(Research 섹션 포함) + design.md + (요청자 원문 목표).
- 읽기 전용 (Read, Grep, Glob, Bash), fresh context — 계획을 만든 세션이 자기
  설계를 통과시키지 못하게 하는 자기채점 가드.
- 리뷰 관점 고정 (프롬프트에 명시): ① 요구사항-설계 정합 (모든 Rule이 어떤
  결정으로 커버되는가) ② 결정 근거 실존 ③ 더 단순한 대안 존재 여부
  ④ analysis.md의 Constraints를 위반하는 결정 유무.
- 출력 고정: `VERDICT: PASS | FAIL` + `FINDINGS:` (integration-reviewer와 동일 규격).

**gate-B**:
| Gate | CHECK | EXPECT |
|------|-------|--------|
| groundings-exist | 스크립트: design.md의 위키 페이지 id 전수 grep | ok (0 miss) |
| decision-rows-complete | 파서: 모든 행에 basis/alternative/testability 채워짐 | ok |
| reviewer-verdict | plan-reviewer 결과 기록 파일 확인 | VERDICT: PASS |

### Phase C — 계획 (분해) — 현 step 3~6 유지 + 2개 보강

기존 의존 순서화, small-model 태스크 컷 기준표, Size verdict, self-check 그대로.
추가:
1. **ATDD 연결**: 각 태스크의 `## Verify`는 A1 인수 예시 중 최소 1개를 참조
   (`covers: R2-example` 형식). 어느 예시도 커버하지 않는 태스크 = 스코프 밖 신호,
   어느 태스크도 커버하지 않는 예시 = 계획 누락 신호. self-check에 양방향 대조 추가.
2. **핀 예산**: A2 Constraints의 핀 파일을 건드리는 태스크는 해당 핀 갱신을
   Deliverables에 명시해야 함 (escalate-plan-breaking-test-conflicts 교훈의 규칙화).

### 리서치 롤 (`research`) — 도구 해석 순서 강제

loop-implement의 기존 capability role 패턴(`knowledge`/`tacit`/`verify`/`explore`/
`design`)에 `research` 롤을 추가한다. 다른 롤과 달리 **해석 순서가 스킬에
고정**된다 (환경마다 최선의 검색 도구를 자동 선택):

1. 사용자가 tool-profile에 명시 설정한 도구 (기존 우선순위 규칙 그대로)
2. `mcp__brave-search__brave_web_search` 가 환경에 존재하면 그것
   (count/freshness 제어 가능 — 쿼리당 결과 수를 명시적으로 제한해 토큰 절약)
3. 내장 WebSearch
4. 전부 없으면: gate-A의 research-evidenced를 ABANDON (공개 포기)

사용 지점: Phase A4(베스트 프랙티스/함정 확보), Phase A3 스파이크 조사,
Phase B에서 `[no-wiki]` 결정의 근거 보강. 호출 실패 시 다음 순번으로 폴백하고
어느 도구를 썼는지 `## Research`에 기록한다.

### 스킵 룰 (안티패턴 방지 — 비례 원칙)

| 조건 | 적용 |
|------|------|
| loop-implement 자체를 스킵하는 사소 작업 (오타/설정값/rename) | 기존대로 전체 스킵 |
| Size verdict `small` 예상 + `[no-wiki]` 결정 0 + 핀/보안/마이그레이션 무관 | **lite 모드**: analysis.md 한 파일에 A1/A2 축약 (baseline 핀 + grounding grep은 유지), plan-reviewer 생략, gate-A/B는 축약 항목만 |
| 그 외 전부 | full 3단계 |

lite 판정 조건은 전부 기계 확인 가능하므로 재량 우회가 안 된다.

## 4. 변경 파일 목록 (구현 스코프)

| # | 파일 | 변경 |
|---|------|------|
| 1 | `skills/wiki-plan/SKILL.md` | 단계 재구조화 (A/B/C), 산출물 3분할, 게이트 절차 추가 |
| 2 | `agents/plan-reviewer.md` | 신규 — 읽기 전용 설계 리뷰어, VERDICT 고정 규격 |
| 3 | `skills/wiki-plan/scripts/plan-gate.sh` | 신규 — analysis/design 파서 + grounding grep + gates ledger 항목 생성 (판정 자체는 기존 gate-check.sh --run 재사용) |
| 4 | `skills/wiki-plan/templates/` | analysis.md / design.md / plan-gates.md 템플릿 신규 |
| 5 | `skills/loop-implement/SKILL.md` + `references/tool-profile.md` | step 2 서술 갱신 (A/B/C 참조), 7b 라우팅 세분화 (요구사항 결함→A, 결정 결함→B, 태스크 컷 결함→C), `research` 롤 추가 + 해석 순서 (brave-search → WebSearch) 문서화, resolve-tools.sh에 research 롤 해석 추가 |
| 6 | `skills/orchestrate/` | 코디네이터가 워커에 플랜을 넘길 때 gate-A/B 통과 증거 확인 1줄 추가 (session-prompt.md 보호 스팬은 건드리지 않는 선에서 — 불가피하면 cksum 핀 갱신 예산 포함) |
| 7 | `tests/` | plan-gate.sh bats 신규 (정상/에러/경계: 페이지 miss, 미해결 질문 잔존, lite 판정 경계), 지시문 카운트 핀 갱신, agents 파일 검증 테스트 갱신 |

예상 규모: wiki-plan 재작성이 중심. Size verdict 예상 `medium` (6~8 태스크).
구현은 당연히 이 보강된 사이클로 직접 드시푸딩(dogfooding)한다 — analysis.md부터.

## 5. 비용과 리스크

- **추가 비용**: full 모드 기준 서브에이전트 1회(plan-reviewer) + 게이트 스크립트
  실행. 태스크당이 아니라 **피처당 1회**라 실행 루프 비용은 불변.
- **리스크 1 — 게이트 형식주의**: DoR 안티패턴 그대로. 방어: 게이트 수를 위
  표의 최소 항목으로 동결하고, 추가는 실증된 실패 사례가 생겼을 때만 (1결함 1게이트 원칙).
- **리스크 2 — lite 판정 오분류**: small로 잘못 판정해 리뷰를 건너뜀. 방어:
  lite에서도 baseline 핀 + grounding grep은 무조건 유지 — 실증 사례 3건은 전부
  이 두 개만으로 잡혔다.
- **리스크 3 — Stop hook(loop-gate) 상호작용**: plan 게이트 ledger가 UNMET인 채
  세션 종료 시 loop-gate가 막을 수 있음. 계획 단계 ledger는 파일명 prefix
  (`plan-`)로 구분해 loop-gate 파서가 기존 동작을 유지하는지 확인 필요 (테스트 항목에 포함).

## 6. Sources

Definition of Ready (Rubin, *Essential Scrum*; scrum.org/resources/blog/walking-through-definition-ready;
DoR 안티패턴 경고: agileambition.com/Essays/Definition-Of-Ready) ·
Example Mapping / Three Amigos (cucumber.io Example Mapping; automationpanda.com/2017/02/20/the-behavior-driven-three-amigos) ·
설계 리뷰 효과 (research.google/pubs/improving-design-reviews-at-google — 141,652건 분석) ·
Spike (framework.scaledagile.com/spikes; XP spike solutions) ·
기존 loop-implement Sources (TDD/PDCA/DoD/Reflexion) 유지.
