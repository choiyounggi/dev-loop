# loop-orchestrator — 설계 문서

> ⚠️ **dev-loop 계보 문서 (inherited).** 이 문서는 상위 프로젝트 loop-orchestrator의
> 설계 문서로, dev-loop가 갈라져 나오기 **전** 상태를 기술한다. dev-loop에서 바뀐 핵심
> 한 가지 — **plan 단계(step 2)는 더 이상 옵셔널/pluggable `plan` role이 아니라 번들된
> `wiki-plan` 방법론으로 고정**되었고, 아래에서 "큰 작업만"·"inline 계획"이라 적힌 부분은
> dev-loop에는 해당하지 않는다. 정본은 루트 `README.md` + `skills/loop-implement/SKILL.md`.

> 자연어 목표/이슈/작업 하나를 받아, 오케스트레이터가 작업을 여러 tmux 독립 claude 세션으로 쪼개 병렬 구현·통합·병합까지 (게이트가 있는) 자율 루프로 끌고 가는 범용 Claude Code 플러그인.
>
> 상태: **설계 확정 대기** (brainstorming → 이 문서 → writing-plans 순). 2026-06-29.

---

## 1. 개요

### 무엇인가
- 사내 RTB 전용이던 `워크트리멀티세션`(오케스트레이터) + `구현루프`(단일작업 검증 루프)를 **RTB/Jira/wiki-rag 의존을 걷어내고 범용화**한 것.
- 입력: 자연어 ("이 목표/이슈/작업을 오케스트레이터로 구현해줘"). 출력: 깃레포면 피처브랜치에 병합된 구현, 레포 없으면 git init된 기본브랜치에 통합된 구현.

### 목표
- 한 세션에 다 떠넘기지 않고 **작업을 분해해 여러 독립 세션으로 병렬 구현**.
- 각 세션은 방법론 근거가 있는 **검증 루프**로 단일 작업을 완수까지.
- 오케스트레이터가 분해·분배·검토·통합·병합을 **자율**로 관리하되, **사고가 남는 지점엔 게이트**를 둔다.

### 비범위 (YAGNI)
- 원격 push / GitHub PR 생성·머지 — 사용자 몫 (자동화 안 함).
- Windows 지원 — macOS/Linux만 (tmux 의존).
- 단일 작업 1개만 할 땐 이 플러그인 대상 아님 (그건 `loop-implement` 단독 사용).
- 전용 탐색/계획/통합검증 에이전트 — 세션 본인 + 코어 Task로 충분 (§9.2).

---

## 2. 사용자 경험

```
사용자: "X를 구현해줘 (오케스트레이터로)"
  → [구체화 인터뷰]    오케가 목표/범위/제약/완료기준을 충분해질 때까지 질문
  → [환경 감지]        깃레포? → 분기
  → [작업 분해]        N개 작업 + 충돌/의존/Wave 분석
  → 🚦 게이트1: 분해 승인   "이렇게 N개로 쪼갰어. 진행?"  ← 사용자 확인
  → [세션 기동·계획]   워크트리별 claude 세션 → 각자 loop-implement로 계획·구현
  → [검토·재작업]      오케가 각 세션 diff 검토 (재작업 상한)
  → [통합 테스트 루프] 통합 지점에서 전체 동작 검증
  → 🚦 게이트2: 병합 전 검수  통합 diff 전체 제시   ← 사용자 별도 컨펌
  → [정리·병합]        서브브랜치→피처브랜치 병합 → 워크트리 제거 → tmux 종료
```

**사용자 접점은 4개**: ①구체화 질문 ②되물음(모호 시) ③분해 승인(게이트1) ④병합 전 검수 컨펌(게이트2). 그 외는 자율.

---

## 3. 아키텍처

```
loop-orchestrator/                     (GitHub repo)
├── .claude-plugin/
│   ├── plugin.json                    메타(name/version/description)
│   └── marketplace.json               /plugin marketplace add 진입점
├── agents/                            ⚠️ 플러그인 루트 (.claude-plugin/ 안 아님 — 로드 보장)
│   └── test-quality-auditor.md        독립 테스트품질 검증자 (§9.3, 읽기전용)
├── skills/
│   ├── orchestrate/                   ① 상위: 분해·분배·검토·통합·병합 관리
│   │   ├── SKILL.md
│   │   ├── scripts/                   워크트리멀티세션에서 포팅 + 이식성 패치
│   │   │   ├── setup-worktrees.sh
│   │   │   ├── launch-session.sh
│   │   │   ├── watch-status.sh
│   │   │   ├── status-update.sh
│   │   │   └── safe-cleanup.sh        미커밋 선검사 + 정확매칭 tmux kill + worktree remove
│   │   └── templates/
│   │       ├── brief.md               XML 구조 작업 지시서 (§9.1)
│   │       └── session-prompt.md      단계별 트리거 + 에이전트 사용 규약 (§9.1, §9.4)
│   └── loop-implement/                ② 하위: 단일작업 검증 루프 (각 세션이 호출)
│       └── SKILL.md
├── hooks/
│   ├── hooks.json                     SessionStart preflight + 검증루프 게이트
│   ├── preflight.sh                   의존성 체크/안내 (설치는 자동 안 함)
│   └── loop-gate.sh                   검증루프 무결성 게이트 (§8.4)
├── .github/workflows/
│   ├── release.yml                    태그 push → GitHub Release + 릴리즈노트 (npm 없음)
│   └── test.yml                       셸 스크립트 + 에이전트 픽스처 테스트 (§12)
├── README.md
└── LICENSE
```

**스킬 2분할 이유**: 상위(조율)와 하위(단일작업 완수)는 책임이 다름. 분리하면 `loop-implement`는 단독으로도 쓸 수 있음.

---

## 4. 오케스트레이터 워크플로우 (Phase)

| Phase | 하는 일 | 게이트 |
|-------|---------|--------|
| **0. 구체화** | 자연어 목표 → 목표/범위/제약/완료기준이 충분해질 때까지 질문 | (질문) |
| **1. 환경 분기** | 깃레포 감지 → §6 분기. 의존성 preflight(§8.1) | — |
| **2. 분해** | 목표 → 독립 작업 N개 + 충돌/의존/Wave 분석 + 동시세션 상한 적용(§8.6) | — |
| **2.5 분해 승인** | 분해 결과(작업 목록·Wave·예상 세션 수·비용)를 사용자에게 보고 | 🚦 **게이트1** |
| **3. 세션 기동·계획** | Wave별 워크트리에 claude 세션 → brief + `loop-implement` 주입 → 각자 계획·구현 | — |
| **4. 검토·재작업** | 오케가 각 세션 diff 검토(+필요 시 `test-quality-auditor` cross-call §9.3), 미달 시 재작업(상한 3) | — |
| **5. 통합 테스트 루프** | 통합 지점에서 전체 동작 검증, 실패 시 재작업(상한 3) | — |
| **6. 병합 전 검수** | 통합 diff 전체(`git diff`)를 사용자에게 제시 | 🚦 **게이트2** |
| **7. 정리·병합** | §7 안전 순서대로 병합 → 워크트리 제거 → tmux 종료 | — |

자율성은 **구현 루프 내부(Phase 3~5)** 에 있고, *무엇을 몇 개로 쪼갤지*(게이트1)와 *무엇을 병합할지*(게이트2)는 사람이 본다.

---

## 5. 검증 루프 `loop-implement` (방법론 근거 기반)

각 세션이 자기 작업 하나에 대해 도는 루프. 출처는 §13.

```
0. 종료조건 정의       ← Scrum DoD + XP 인수기준 (게이트 기준을 먼저 고정)
1. 분석/이해           ← TDD 테스트 시나리오 목록 + PDCA Plan
2. 계획/설계           ← PDCA Plan + Eng review (큰 작업만; 작으면 1과 병합)
3. 테스트 작성 (Red)   ← TDD test-first (테스트 = 명세이자 검증 오라클)
4. 구현 (Green)        ← TDD Green(최소 코드) + PDCA Do
5. 테스트 실행 (Check) ← PDCA Check + Fowler self-testing code
6. 셀프리뷰 + 리팩터   ← TDD Refactor + Google self-review + Self-Refine
6.5 독립 검증          ← test-quality-auditor 호출 (§9.3) — self-grading 차단, 필수
7. 종료조건 판정       ← DoD/인수기준 게이트 + auditor VERDICT
   ├─ 통과 → done
   └─ 실패 → 7b. 반성(Reflexion: 실패원인 언어화) + 재시도 (상한 3, 초과 시 에스컬레이션)
```

- **핵심 정신**: 순수 TDD 강제가 아니라 **"테스트(또는 검증 가능한 인수기준/명령)를 구현 전에 고정"**. 탐색적 UI 등 test-first가 어려우면 인수기준/검증명령을 구현 전에 박는 걸로 갈음.
- **규모 비례**: 단순 작업(오타·설정·rename)은 0·2 생략, 테스트 면제 가능. 비단순은 전체 루프 + 상한 3.
- 가드레일: **테스트를 약화/삭제/skip해서 통과시키지 않는다.** 통과 못 하면 코드를 고치지 테스트를 무르지 않는다. (6.5 독립 검증자가 이를 강제.)

---

## 6. 환경 분기

### 깃레포 있음
- 피처브랜치 생성 → 작업별 워크트리 분기. base는 `gh repo view --json defaultBranchRef`(없으면 현재 브랜치) 실측.
- 완료 후 서브브랜치 → 피처브랜치 **로컬 병합**. 원격 push/PR은 사용자 몫.

### 깃레포 없음 → git init 자동 (3종 선검사 통과 시에만)
git init **전** 반드시 검사하고, 하나라도 걸리면 **중단·보고**(자동 init 금지):
1. **상위 레포 감지**: `git rev-parse --show-toplevel 2>/dev/null` 결과가 있으면 → 작업폴더가 이미 다른 레포 하위. 중단.
2. **.gitignore 부재**: 없으면 기본 무시 패턴(`node_modules`, `.env*`, 빌드산출물, `.orchestration/`) 제안 후 동의받아 생성.
3. **시크릿 선검사**: 첫 커밋 전 `git status`로 추적될 파일에서 `.env*`·`*.pem`·`*credential*` 발견 시 차단·경고.
- 통과하면 init → 이후는 깃레포 있음과 **동일 흐름**(기본브랜치로 병합, 원격 없음).

---

## 7. 정리·병합 (게이트2 통과 후에만)

순서가 안전의 핵심 (적대검증 반영):

1. 병합 순서를 의존성/머지 순서로 고정(단일 시퀀스).
2. 각 워크트리 **미커밋 선검사**: `git status --porcelain` → 미커밋/미푸시 있으면 중단·보고. (`worktree remove --force` 금지)
3. 서브브랜치 → 피처브랜치 **순차 병합**. **충돌 시 멈추고** status에 `이미 병합됨/남음/재개법` 기록 후 보고.
4. 병합 **성공 실측 확인 후**에만 → 해당 워크트리 `git worktree remove`.
5. tmux 세션 종료: 오케가 **생성 시 기록한 정확한 세션명 리스트만** 대상. `grep`/prefix 매칭 절대 금지. 세션명에 실행 고유 토큰 포함해 충돌 회피.

---

## 8. 안전장치 (적대검증 반영 일람)

| # | 항목 | 처리 |
|---|------|------|
| 8.1 | **바이너리 경로 이식성** | `/usr/bin/git`·`/opt/homebrew/bin/tmux`·`/usr/bin/jq` 하드코딩 제거 → `command -v` 탐지+fallback. preflight에서 1회 resolve해 export. Intel맥/Linux 지원. |
| 8.2 | **jq 의존** | preflight에서 **필수 의존으로 체크, 없으면 차단**(침묵 실패 방지). 또는 status 포맷을 jq 없이 파싱 가능하게(`phase=plan_ready`) 단순화 — 구현 시 택일. |
| 8.3 | **tmux 설치** | SessionStart preflight는 **존재 체크 + 안내만**(자동설치 금지). 설치는 orchestrate 스킬 *실제 호출 시* 1회, 사용자 컨펌 후 brew(macOS, sudo 불필요) 자동/그 외 안내. |
| 8.4 | **훅 범위** | 오케스트레이션 루프 직결 훅만: ① **SessionStart preflight**(의존성 체크/안내) ② **검증루프 게이트 `loop-gate.sh`**(세션 Stop 훅 — 검증루프 미완·테스트 약화·종료조건 미충족 시 종료 차단). **범용 파괴명령 가드는 번들 안 함**(영기 결정). |
| 8.5 | **검증루프 게이밍** | self-grading 차단 → 6.5 단계에서 **독립 검증자 `test-quality-auditor`**(§9.3)가 테스트 품질 정량 기준 판정. 세션 self-call + 오케 cross-call **이중**. |
| 8.6 | **멀티세션 비용** | **동시 세션 상한**(기본 4, 사용자 조정). 초과 분해는 Wave 직렬화 또는 확인. 비용 경고를 게이트1에 포함. effort scaling(§9.1) 적용. |
| 8.7 | **미커밋 유실** | §7.2 — remove 전 `git status --porcelain` 실측, `--force` 금지. |
| 8.8 | **부분 병합** | §7.3 — 충돌 시 중간상태(병합됨/남음/재개법) 기록. |
| 8.9 | **tmux kill 오매칭** | §7.5 — 정확 세션명 리스트만, prefix/grep 금지. |
| 8.10 | **재진입/고아세션** | 원본 재진입 절차 포팅(`worktree list`·status phase 실측 → 미완 단계부터 재개). 오케 부재 시 세션 idle 타임아웃. |
| 8.11 | **trust 화면 취약** | 가능하면 비대화 플래그/settings로 trust 화면 회피. 못 하면 문구 패턴을 한 곳에 모으고 버전 의존 문서화. |
| 8.12 | **.orchestration 추적** | git init 케이스에서 `.orchestration/`을 `.gitignore`(또는 `.git/info/exclude`)에 항상 추가. |

---

## 9. 세션 프롬프트 설계 & 서브에이전트

오케스트레이터가 각 세션에 전달하는 프롬프트는 Anthropic 프롬프트 엔지니어링 + 멀티에이전트 위임 베스트프랙티스를 따른다(§13). 핵심: **무거운 맥락/계약은 XML `brief` 파일로**(long-context: 맥락 상단·지시 하단), **단계별 트리거는 한 줄**(tmux send-keys 제약)이되 brief의 특정 태그를 권위로 호출.

### 9.1 brief.md — XML 작업 지시서 (세션이 먼저 읽음)

위임 **4요소 계약**(Objective / Output format / Tools guidance / Task boundaries)을 XML 태그로 구조화. 빠지면 세션이 "done이 뭔지 몰라" 드리프트(멀티에이전트 연구의 중복조사 실패 처방).

```xml
<task_brief task="{TASK}" wave="{W}">
  <context>          <!-- long-context: 큰 맥락 상단 -->
    <main_goal/> <architecture/> <this_task_role/> <surrounding_code/>
  </context>
  <dependencies>     <!-- compounding error 방지: 선행 산출물은 소비만 -->
    <upstream/> <i_produce/>
  </dependencies>
  <objective/>       <!-- 4요소 ① -->
  <scope_boundaries> <!-- 4요소 ④ + 명시적 금지 (중복작업 방지 핵심) -->
    <in_scope/> <out_of_scope/>  <!-- "X는 다른 세션 담당, 하지 마라" -->
  </scope_boundaries>
  <tools_guidance/>  <!-- 4요소 ③ + 에이전트 사용 규약(§9.4) -->
  <constraints/>
  <definition_of_done/>  <!-- "what done looks like" — 검증 가능하게 -->
  <effort_level/>    <!-- 복잡도·반복 한도·정지 조건을 숫자로 (effort scaling) -->
  <output_contract/> <!-- 4요소 ②: 산출물 경로·형식·완료 신호(status-update) -->
</task_brief>
```

### 9.2 단계별 트리거 (한 줄 send-keys) — 기존 4단계 유지 + 강화

①계획 ②구현 ③재작업 ④병합준비 트리거는 산문 한 줄이되, **brief의 `<scope_boundaries>`·`<definition_of_done>`·`<effort_level>`을 권위로 명시 호출**하고 정지 조건을 못박는다. (RTB 특화 어휘 wiki-rag/rtb-lore/지라/lease·sale 등은 전부 범용 표현으로 치환.)

### 9.3 서브에이전트 — 자체 번들 1개

| 에이전트 | 종류 | 역할 |
|---------|------|------|
| **`test-quality-auditor`** | **자체 번들** (`agents/`, 플러그인 루트) | diff+테스트만 받아 테스트 품질을 **읽기 전용**으로 독립 판정. tools=`Read,Grep,Glob,Bash`(Edit/Write 제외 — 검증자가 코드 고치면 self-grading 방지 무효). 출력 `VERDICT: PASS|FAIL` + `REASONS:` 고정 → phase 전이에 파싱. |

- **왜 별도·번들**: 자기 코드 짠 세션이 자기 테스트를 자가판정하면 게이밍됨(evaluator-optimizer 패턴 = 생성자/평가자 분리). 받는 환경에 이런 에이전트 존재 보장 없고 게이트 기준이 플러그인 고유 → 번들 필수.
- **나머지 역할(탐색·계획·구현·통합검증·코드리뷰)은 세션 본인 + 코어 Task 도구**로. 전용 번들 안 함(YAGNI).
- **특정 빌트인 에이전트 이름(general-purpose/Explore/Plan) 의존 금지** — 공식 문서에 코어 목록 SSOT 없어 버전 의존. "Agent 도구로 위임" 수준으로만 가이드.

### 9.4 세션 프롬프트의 "에이전트 사용 규약" (필수 블록)

`session-prompt.md`에 필수로 박는다(없으면 세션이 자가판정하거나 없는 에이전트를 부르다 실패):

```
[1] 테스트 품질 독립 검증 — 루프 단계 6 직후, 7 전에 반드시 test-quality-auditor 호출.
    전달: brief 경로·diff·테스트 경로. VERDICT:PASS→impl_done / FAIL→REASONS 반영
    테스트 보강(약화·삭제 금지)·reworkCount++·단계3부터 재루프. (이 에이전트는 번들 — 항상 존재)
[2] 탐색/추가 시각(선택) — 토큰 절감 필요 시 코어 Agent 도구로 범용 위임. 에이전트 이름 의존 금지.
[3] 금지 — 번들된 test-quality-auditor 외 특정 에이전트 이름 호출 금지(받는 환경에 없을 수 있음).
```
- 오케 측 대칭 규약: Phase 4에서 의심스러우면 오케가 `test-quality-auditor`를 **cross-call**(세션 self-call + 오케 cross-call 이중 §8.5).

---

## 10. 세션 통신 / 디렉토리

```
.orchestration/                (네임스페이스 — 충돌 회피)
├── status/<task>.json         세션→오케 (phase, reworkCount, error, updatedAt …)
├── briefs/<task>.md           오케→세션 작업 지시서 (XML, §9.1)
├── plans/<task>.md            세션이 작성한 계획
├── reviews/<task>-rN.md       오케 검토 결과
└── conflict-matrix.md         분해/충돌/의존/Wave 산출물
```
- 세션→오케: status 파일. 오케→세션: `tmux send-keys` 한 줄.
- phase: `pending→planning→plan_ready→implementing→impl_done→approved→merged→done`(+`failed`)

---

## 11. 배포

- **설치**: `/plugin marketplace add choiyounggi/loop-orchestrator` → `/plugin install loop-orchestrator@loop-orchestrator` (git repo 기반).
- **자동화**: 태그(`vX.Y.Z`) push → GitHub Actions(`release.yml`)가 **GitHub Release + 릴리즈노트** 자동 생성. **npm publish 없음**(CC 플러그인은 marketplace로 설치되므로 npm 효용 없음 — 영기 결정). cliclaw `publish.yml`의 릴리즈 부분을 참고하되 npm 단계는 제외.
- **repo**: https://github.com/choiyounggi/loop-orchestrator (PUBLIC).
- **커밋/푸시**: author/committer = choiyounggi, Claude 흔적(Co-Authored-By 등) 없이. PAT는 env로 일회성 사용(명령라인·파일·커밋에 미기록), 작업 후 영기가 revoke.

---

## 12. 테스트 / 검증 전략

- **셸 스크립트**(setup/launch/watch/status/safe-cleanup/preflight/loop-gate): bats 또는 셸 단위 테스트. 특히 ① 경로 탐지 fallback ② tmux kill 정확매칭(언급은 통과/실행은 차단 양방향) ③ git init 3종 선검사 ④ 미커밋 선검사 ⑤ loop-gate 차단 — 회귀 테스트 필수.
- **이식성**: macOS(Apple/Intel)·Linux 최소 1종에서 preflight·worktree 생성 smoke test.
- **에이전트**: `test-quality-auditor`가 약한 테스트(assertion 없음/tautology/skip)를 FAIL 처리하는지 픽스처로 검증.
- **드라이런**: 정리·병합은 파괴적이므로 dry-run 모드로 "무엇을 지우고/병합할지" 먼저 출력하는 경로 제공.

---

## 13. 근거 출처

**검증 루프 방법론**:
- TDD Red-Green-Refactor, test-first: Kent Beck *Canon TDD* / *TDD by Example*; Martin Fowler (Self-Testing Code).
- 반복 완수 사이클: PDCA/PDSA (Shewhart/Deming).
- 코드 리뷰: Google eng-practices (작은 CL, self-review→peer-review, 테스트 동반).
- 종료조건: Scrum Guide 2020 (Definition of Done) + XP 인수기준.
- AI self-verification: Self-Refine (Madaan 2023), Reflexion (Shinn 2023), Anthropic *Building Effective Agents* (evaluator-optimizer).
- bounded retry: resilience 패턴(상한+백오프+서킷브레이커; 무한재시도 안티패턴).

**프롬프트 / 멀티에이전트 위임**:
- Anthropic *Building Effective Agents* — orchestrator-workers 패턴("여러 파일 코드 변경"을 동적 분배 = 우리 케이스), ACI 도구 문서화, compounding error.
- Anthropic *How we built our multi-agent research system* — 위임 4요소 계약(objective/output/tools/boundaries), 명시적 금지(중복조사 실패 처방), effort scaling(노력을 숫자로).
- Claude Docs *Prompt engineering* — clear&direct, multishot, CoT, XML tags, role, prefill, long-context tips(맥락 상단·지시 하단).

**플러그인/에이전트**:
- CC 플러그인엔 설치시점 훅 없음 → SessionStart 훅 preflight가 표준.
- 에이전트 정의: sub-agents.md 스키마(name/description/tools/model)가 정본. `agents/`는 **플러그인 루트**(plugins-reference.md 경고).

---

## 14. 미해결 / 추정 항목 (구현 직전 실측)

- [추정] CC 플러그인 `bin/` PATH·스킬 `once:` 필드 — 공식 문서 실측.
- [추정] **스킬 하위 `agents/` 로드 여부 미보장** → `test-quality-auditor`는 **플러그인 루트 `agents/`** 에 둔다(`claude --debug`로 agent registration 실측 권장).
- [추정] **코어 빌트인 에이전트 이름(general-purpose/Explore/Plan)은 버전 의존** — 공식 SSOT 없음. 이름에 의존하지 말 것. 자체 번들은 `test-quality-auditor` 1개로 한정.
- jq 의존 제거 vs 필수체크 — §8.2, 구현 시 택일.
- bypassPermissions → acceptEdits 강등 가능 여부 — 자율 구현이 막히지 않는 선에서 실측. (파괴명령 가드는 번들 안 하므로 권한 모드가 유일한 방어선 — 실측 시 유의.)
- trust 화면 회피 비대화 플래그 — claude CLI 현재 버전에서 가능한지 실측.
