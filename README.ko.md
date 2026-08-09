# dev-loop

[English](README.md) | **한국어**

두 가지를 하나의 자기완결적 도구로 합친 Claude Code 플러그인:

- **[loop-orchestrator]** — 하나의 태스크, 또는 여러 병렬 태스크를 "done"까지
  끌고 가는 방법론 기반 검증 루프 (TDD / PDCA / Reflexion).
- **[dev-llm-wiki]** — 케이스 라우팅되는 시맨틱 레이어 소프트웨어
  베스트프랙티스·엣지케이스 지식 베이스, 그리고 모든 설계 결정을 거기에
  근거시키는 계획 방법론.

그리고 세션 하나를 넘어 확장됩니다: `orchestrate` 스킬은 같은 루프 위의
**멀티 세션 오케스트레이터**입니다 — 목표를 의존 그래프로 분해하고, ready-set
스케줄러로 병렬 워커들을 스케줄하며, Orca CLI가 설치돼 있으면 **Orca
네이티브**로 감독합니다(없으면 raw tmux).
[Orca 연동](#orca-연동--스폰이-아니라-감독) 참고.

**업스트림 loop-orchestrator에서 바뀐 단 한 가지:** 계획 단계가 더 이상
선택적·플러거블 role이 아닙니다. **번들된 `wiki-plan` 방법론에 고정**되어 —
비단순 태스크는 코드를 쓰기 전에 모든 설계 결정을 번들 `wiki/`의 페이지로
라우팅해 계획합니다. 루프의 나머지는 그대로입니다.

그 위에 dev-loop은 **지식 수집 루프**를 더합니다: 세션이 검증된 인사이트를
방출하면, `knowledge-flush`가 조사·중복제거·라우팅을 거쳐 위키를 키워가는
리뷰형 PR을 엽니다.

---

## 설치 (글로벌)

Claude Code 플러그인 마켓플레이스로 설치되므로, 스킬과 훅이 작업하는
**모든 프로젝트에 전역으로** 적용됩니다:

```
/plugin marketplace add choiyounggi/dev-loop
/plugin install dev-loop@dev-loop
```

레포 스코프인 것은 없습니다: 위키 기반 루프, `★ Insight` 수집 지시,
하베스트 훅이 어떤 레포를 열어도 활성입니다.

---

## 구현 루프

두 가지 방식으로 돌립니다:

- **태스크 하나 또는 기능 하나** → `loop-implement` 스킬 — **단일 구현자**.
  스텝 2가 `wiki-plan`을 1회 실행해 각 태스크가 자기를 근거 짓는 위키
  페이지들을 명시한 순서 있는 태스크 목록을 만들고, 루프는 그 태스크들을
  **계획의 순서대로** 실행합니다. 태스크마다:
  `0 완료 정의 → 1 분석 + 태스크가 명시한 위키 페이지 로드 → 3 테스트(Red)
  → 4 구현(페이지 지시 그대로 적용, 즉흥 금지) → 5 실행 → 6 셀프리뷰 →
  6.5 독립 테스트 품질 감사 → 7 판정(적용한 WIKI 참조 보고) → 7b 반성 +
  재시도(횟수 제한)`. 별도 실행자는 없습니다 — wiki-executor의 규율
  (명시된 페이지만 로드, 결정 우선, 공백은 BLOCKED)이 이 루프에 흡수돼
  있습니다.
- **하나의 목표를 병렬 워커 세션들로 분할** → `orchestrate` 스킬:
  인테이크 → 분해(승인 게이트) → 디스패치 루프: 계획(wiki-plan) → 구현 + 리뷰
  (각 세션이 `loop-implement` 실행) → 통합 테스트 → 머지 전 게이트 → 머지.
  웨이브 배리어는 없다: 의존 그래프 + 슬롯 회계가 각 task를 그 task의 의존이
  승인되고 슬롯이 비는 순간 시작시키므로, 끝난 워커는 배치에서 가장 느린 task를
  기다리지 않고 바로 다음 일을 받는다. 워커는 자기 task가 브리프의 가정보다
  훨씬 크다고 판단되면 실행 중에 분할을 제안할 수 있다.
  **substrate: Orca가 감지되면 — 태스크 분할 게이트에서 제안됨 — 스폰 *과
  감독*을 Orca가 담당, 아니면 raw tmux.** Orca 위에서는 각 페이즈가 추적되는
  Task + Dispatch가 되고, 코디네이터는
  상태 파일을 타이머로 폴링하는 대신 푸시되는 `worker_done` / `escalation` /
  `question` 메일에 블로킹합니다 — 워커의 질문이 수 초 안에 도달합니다. tmux에서는
  기존 상태 파일 폴링이 그대로입니다. 어느 쪽이든 워커 세션은 guardrails `ask`에서
  멈추는 대신 에스컬레이션하고, 죽은 워커는 런을 멈추지 않고 빠르게 감지됩니다.

### 스텝 2는 `wiki-plan`에 고정

`wiki-plan`은 플래너에게 **위키 라우팅 스윕**을 시킵니다: `INDEX.md`를 읽고,
건드리는 각 도메인의 `index.md`를 읽고, 모든 설계 결정에 대해 그것을 소유한
페이지를 찾아 — `결정 → 위키 페이지` 맵을 기록합니다. 결정은 구체적인
값/코드로 적습니다("적절히" 금지). 그래서 구현 패스는 추측하는 대신
실행합니다. 어떤 페이지도 다루지 않는 결정은 `[no-wiki]`로 표시되어 인제스트
후보가 됩니다. 이것은 설정 가능한 role이 아니며 끌 수 없습니다.

위키는 플러그인 루트에 있습니다(`wiki/`, `INDEX.md`, `AGENTS.md`,
`templates/`). 위키 스킬들은 `${CLAUDE_PLUGIN_ROOT}` 기준으로 경로를
해석합니다.

### 도구 설정 (선택)

loop-orchestrator처럼 dev-loop은 설정 **없이도** 완전히 범용으로 돌지만,
**capability role**을 실제 도구에 매핑해 루프가 그것들을 쓰게 할 수 있습니다:

| Role | 매핑 대상 |
|------|--------|
| `verify` | 프로젝트의 **테스트 / 빌드 / QA** 명령 (루프의 실행 스텝) |
| `knowledge` | 도메인/팀 **위키** 또는 knowledge MCP (외부 사실) |
| `explore` | 코드/심볼 검색 (LSP, ripgrep, 소스 검색 CLI) |
| `tacit` | 과거 인시던트 / danger-zone 사례 |
| `design` | Figma / 비주얼 스펙 MCP (UI 작업) |
| `intake` | 이슈 트래커 (orchestrate의 작업 목록) |

(`plan`은 role이 **아닙니다** — 계획 단계는 `wiki-plan`에 고정입니다. 그리고
번들 베스트프랙티스 `wiki/`는 설정이 필요 없습니다. `knowledge`는 *별개의*
외부 위키입니다.)

**`/dev-loop:configure`**로 설정하세요 — `~/.claude/dev-loop/tools.json`
(글로벌) 또는 `<repo>/.dev-loop/tools.json`(레포별, 팀 공유)을 씁니다.
우선순위는 git-config 스타일: `기본값 < ~/.claude/dev-loop/tools.json <
<repo>/.dev-loop/tools.json`. 아무것도 설정하지 않았다면 SessionStart 훅이
넛지합니다(최대 주 1회, 이후 없음) — `DEV_LOOP_CONFIG_NUDGE=0`으로 끌 수
있습니다. 레거시 `loop-orchestrator` 설정 경로도 fallback으로 읽습니다.
`references/tool-profile.md`와 `examples/tools.example.json`을 보세요.

---

## Orca 연동 — 스폰이 아니라 감독

`orchestrate`는 Orca를 터미널 스포너가 아니라 **1급 기판**으로 다룹니다.
`orca` CLI가 PATH에 있으면 코디네이터가 태스크 분할 게이트에서 Orca를 제안하고,
그때부터 런 전체가 Orca 오케스트레이션 위로 흐릅니다:

- **계보(Provenance)** — 오케스트레이션 런당 하나의 Run; 모든 태스크 *페이즈*
  (plan / implement / rework / merge-prep)가 추적되는 Task + Dispatch가 되어,
  "누가 무엇을 하고 있고, 정산됐는가"가 추측이 아니라 조회 가능한 상태입니다.
- **이벤트 기반 대기** — 코디네이터는 상태 파일을 타이머로 폴링하는 대신
  푸시되는 `worker_done` / `escalation` / `question` 메일(`orca-wait.sh`)에
  블로킹합니다. 워커의 블로킹 `ask`는 몇 초 안에 코디네이터에 도달하고
  `orchestration reply`로 응답됩니다. 죽은 Orca 런타임은 조용한 타임아웃이
  아니라 구분되는 exit로 드러납니다.
- **환경변수를 실어 나르는 워커 기동** — `orca-worker-start.sh`가 워크트리,
  guardrails 에스컬레이션 규약(`GROUNDWORK_ESCALATION_DIR` /
  `GROUNDWORK_TASK_ID`)을 실은 에이전트 터미널, Dispatch 바인딩을 한 번에
  구성합니다. 재진입 시에는 살아 있는 에이전트를 먼저 탐침하므로 하나의
  워크트리에 에이전트가 둘 생기지 않습니다.
- **생존 감지는 두 가지 질문** — `orca-worktree-alive.sh`(터미널이 있는가?)
  **그리고** `orca-worker-stalled.sh`(pane이 실제로 움직이는가?) — 멈춘 워커는
  첫 번째 검사를 몇 시간이고 통과하기 때문입니다.

Orca가 없어도 같은 런이 **raw tmux** 위에서 같은 보호를 파일 기반으로 받습니다:
워커는 `ask-coordinator.sh`로 블로킹 질문을 기록하고 감시가 이를 표면화하며
(exit 6), 조용해진 pane은 스톨로 표면화되고(exit 7, 분류 후 대응 플레이북:
선택 UI / 사용량 한도 / 완료했지만 무보고), 화면에 뜬 선택 UI는 허용목록 키
이벤트(`send-prompt.sh keys`)로 응답하고, 모든 런치가 status 레코드를 선기록해
플래닝 중에 죽은 워커도 기다리지 않고 잡습니다. guardrails 에스컬레이션 규약은
두 기판에서 동일합니다.

**auto 모드 코디네이터를 위한 셋업 노트 (tmux):** 런처는 각 워커를
`claude --permission-mode bypassPermissions`로 띄우는데, auto 모드 권한
분류기는 이를 권한 상승으로 플래그합니다 — 이를 안전하게 만드는 guardrails
deny-net을 분류기는 볼 수 없기 때문입니다. 코디네이터 세션이 auto 모드로
돌아간다면 워커 관리 스크립트 3개(`launch-session.sh`, `send-prompt.sh`,
`watch-status.sh`)를 프로젝트의 `.claude/settings.local.json`에 사전
승인하세요 — 정확한 `permissions.allow` + `autoMode.allow` 스니펫은
orchestrate SKILL.md의 Preflight 섹션에 있습니다. `safe-cleanup.sh`는 파괴적
verb가 일반 검토를 계속 받도록 의도적으로 제외했고, 차단당한 코디네이터는
분류기를 우회하는 대신 스니펫을 보여주고 멈춥니다.

---

## 지식 수집 루프

위키는 실제로 배운 것으로부터 자라도록 설계됐습니다. 세 개의 부품:

1. **수집 (글로벌, 자동).** SessionStart 훅이 상시 지시를 주입합니다: 어떤
   레포에서든 검증된 베스트프랙티스나 남길 가치가 있는 실제 엣지케이스를
   발견하면, 간결한 `★ Insight` 블록(trigger / directive / why / evidence /
   domain / tags)을 방출하라.

2. **하베스트 (자동, 오프라인).** Stop 훅이 세션 트랜스크립트에서 그 블록들을
   긁어 로컬 큐(`~/.dev-loop/queue/`)에 넣습니다. 세션 큐 파일과 이미 플러시된
   저장소(`.processed.jsonl`) 양쪽에 대해 dedup하고, 세션당 10행 상한(폭주
   백스톱)을 두며, 비워진 큐 파일은 정리합니다. 위키를 편집하지도 PR을
   열지도 않습니다 — 하베스트는 저렴하고 논블로킹입니다.

3. **플러시 → 검증된 PR (자동 또는 온디맨드).** 큐는 `knowledge-flush`
   파이프라인이 비웁니다. **각** 후보에 대해, PR 전에 반드시:
   - 실제 출처(공식 문서, 1차 레퍼런스)에 대고 베스트프랙티스를 **조사·검증**
     하고 신뢰도를 부여합니다 (verified / field-tested / unverified — 지어낸
     인용은 절대 금지),
   - 병합할 중복과 링크할 페이지를 찾아 **기존 레이어를 확인**하고
     (실제로 읽은 페이지 id를 명시),
   - **열린 `knowledge/*` PR들을 확인**해 형제 플러시와 중복 PR이 쌓이지
     않게 합니다 — 각 후보를 진행 중인 PR에 폴드하거나, 대기-중복으로
     드롭하거나, 신규로 인제스트합니다,
   - **타깃 레이어/카테고리를 결정**(또는 새 카테고리를 정당화)한 뒤,
   - `wiki-ingest`를 실행하고 `INGEST_REPORT.md`를 씁니다.

   플러시당 **PR 하나**를 열고 **절대 자동 머지하지 않습니다**. 각 기여자의
   PR은 **본인의 git/gh 신원으로** 커밋·오픈됩니다(하드코딩된 계정도,
   어시스턴트도 아님). 레포 소유자가 열린 `dev-loop:knowledge` PR들을
   리뷰해 각각 머지하거나 반려합니다.

   실행되는 두 가지 경로:
   - **자동** — `hooks/auto-flush.sh` Stop 훅이 큐가 임계치를 넘고 rate-limit
     윈도우가 지났을 때 분리된 headless `claude` 실행으로 파이프라인을
     발화합니다. 아무것도 하지 않아도 PR이 나타납니다. 가드:
     킬 스위치 `DEV_LOOP_AUTOFLUSH=0`, `DEV_LOOP_AUTOFLUSH_INTERVAL`(기본
     3600초)당 1회, 대기 항목 `DEV_LOOP_AUTOFLUSH_MIN`(기본 3)개 이상일 때만,
     single-flight 잠금, 재귀 안전. `claude` + `gh`가 PATH에 있고 gh 인증이
     필요합니다. 하나라도 없으면 조용히 no-op — 수동으로 fallback.
   - **수동** — 언제든 `/dev-loop:knowledge-flush`로 큐를 지금 비웁니다.

### 이 순서는 훅으로 강제됩니다

`hooks/pre-flush-pr-gate.sh`(PreToolUse)는 knowledge 브랜치에서
`INGEST_REPORT.md`가 존재하고 네 섹션(`## Verified best-practice`,
`## Existing-layer check`, `## Open-PR check`, `## Routing decision`)이 실제
내용으로 채워져 있지 않으면 `gh pr create`를 **차단**합니다. Existing-layer
check에는 `Pages read: <id>, …` 라인이 필수이며, 각 id는 체크아웃의
`wiki/`에 실물 대조됩니다 — 존재하지 않는 페이지를 인용한 리포트는
fail-closed로 거부됩니다. 게이트는 knowledge-flush PR로 좁게 스코프되어,
다른 레포의 일반 `gh pr create`에는 절대 간섭하지 않습니다.

---

## 스킬

| 스킬 | 역할 |
|-------|------|
| `loop-implement` | **단일 구현자** — wiki-plan을 소비해 태스크를 순서대로 (각 태스크가 명시한 위키 페이지를 로드하며) 검증 루프로 실행. 계획 단계 = wiki-plan. |
| `orchestrate` | **멀티 세션 오케스트레이터** — 하나의 목표를 병렬 워커 세션들로 분할, 각 세션은 loop-implement 실행 — 감지되면 **Orca 위에서**(Task/Dispatch 추적, `worker_done`/`ask`/`escalation` 이벤트 대기, 네이티브 liveness), 아니면 강화된 감시의 tmux(워커 질문 채널, 스톨 표면화, 허용목록 선택 UI 키). 스케줄링은 웨이브 배리어가 아니라 의존 그래프 + 슬롯 회계: `ready-set.sh`가 지금 시작해도 되는 task를 판정하고, 슬롯 수는 Gate 1에서 제안·승인되며 `LO_MAX_SESSIONS`가 상한이고, 실패한 의존은 조용한 대기가 아니라 보고되는 교착으로 드러난다. 역할별 모델 선택: 워커는 저렴한 모델, 플래너/감사자는 강한 모델. 워커는 guardrails `ask`에서 멈추지 않고 에스컬레이션하며, 실행 중 task 분할을 제안할 수 있고, 죽은 워커는 감지된다. |
| `wiki-plan` | **고정된 계획 방법론** — 각 결정을 위키 페이지로 라우팅, 순서 있는 페이지-내비게이션 태스크로 분해. |
| `wiki-ingest` | 검증된 지식을 올바른 시맨틱 레이어에 추가 (knowledge-flush가 사용). |
| `wiki-query` | 위키에서 인용과 함께 질문에 답변. |
| `wiki-lint` | 위키 건강 점검. |
| `knowledge-flush` | 큐의 인사이트를 조사 + 검증 + 라우팅 → 리뷰형 위키 PR 하나. |
| `configure` | capability-role 도구 프로파일 설정 (위키·테스트 명령 등 매핑). |

## 구조

```
dev-loop/
├── .claude-plugin/{plugin,marketplace}.json
├── AGENTS.md INDEX.md templates/     # 위키 스키마 + 라우팅 진입점 + 페이지/브리프/세션프롬프트 템플릿
├── wiki/                             # 10개 도메인 시맨틱 레이어 지식 베이스
├── skills/                           # 위의 스킬 8종 (사용자 호출 가능; / 메뉴에 스킬 이름으로 표시)
├── agents/test-quality-auditor.md    # 번들된 독립 테스트 감사자 (루프 스텝 6.5)
├── hooks/
│   ├── hooks.json
│   ├── preflight.sh                  # SessionStart: git/tmux/jq 어드바이저리
│   ├── insight-instruction.sh        # SessionStart: ★ Insight 수집 지시 주입 (글로벌)
│   ├── config-nudge.sh               # SessionStart: 미설정 시 /dev-loop:configure 넛지 (주간)
│   ├── loop-gate.sh                  # Stop: 검증 루프 무결성 게이트
│   ├── harvest-insights.sh + harvest.js  # Stop: 인사이트 하베스트 → 큐
│   ├── auto-flush.sh                 # Stop: knowledge-flush 자동 실행 (가드됨) → PR
│   └── pre-flush-pr-gate.sh          # PreToolUse: 플러시 사전 PR 파이프라인 강제
├── scripts/resolve-tools.sh          # capability-role 프로파일 리졸버 (`plan` role 없음)
├── tests/                            # bats 스위트 — 훅(하베스트, 플러시 게이트, 루프 게이트) + 오케스트레이션 스크립트; CI가 ubuntu + macos에서 실행
├── references/tool-profile.md
└── docs/                             # 물려받은 설계 노트 (loop-orchestrator 계보)
```

---

## 기여 표시 (Attribution)

Knowledge PR(수동이든 자동이든)은 **각 기여자 본인의 git/gh 신원으로**
커밋됩니다 — 하드코딩된 계정도 어시스턴트도 아니며, `Co-Authored-By`
트레일러도 없습니다. 모든 기여자는 자기 계정으로 PR을 열고, 레포 소유자가
리뷰해 머지/반려합니다.

## 계보 & 라이선스

**loop-orchestrator**와 **dev-llm-wiki**(둘 다 choiyounggi 작)에서
포크했습니다. 물려받은 루프 설계는 `docs/`를 보세요 (주의: 그 문서들은 위에
설명한 계획-단계-고정 변경 이전에 쓰였습니다). MIT — `LICENSE` 참고.

[loop-orchestrator]: https://github.com/choiyounggi/loop-orchestrator
[dev-llm-wiki]: https://github.com/choiyounggi/dev-llm-wiki
