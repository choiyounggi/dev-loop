# loop-orchestrator 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development 또는 superpowers:executing-plans 로 task별 구현. 스텝은 `- [ ]` 체크박스로 추적.

**Goal:** 자연어 목표를 받아 여러 tmux 독립 claude 세션으로 분해·병렬구현·통합·병합하는 범용 Claude Code 플러그인을 만들어 choiyounggi/loop-orchestrator에 배포한다.

**Architecture:** 워크트리멀티세션(오케)+구현루프(검증루프)를 RTB 의존 제거·이식성 패치하여 포팅. 상위 `orchestrate` 스킬 + 하위 `loop-implement` 스킬 + 독립검증 에이전트 1개 + 훅 2개(preflight, loop-gate) + GitHub Release 자동화.

**Tech Stack:** zsh/bash 스크립트, bats(셸 테스트), Markdown(스킬/에이전트/marketplace), JSON(plugin/marketplace/hooks), GitHub Actions.

**기준 문서:** `docs/design.md` (SSOT). 각 task는 design의 해당 섹션을 권위로 한다.

**포팅 원본:** `~/.claude/skills/워크트리멀티세션/{SKILL.md,scripts/*,templates/*}`, `~/.claude/skills/구현루프/SKILL.md`. 구현 시 원본을 읽어 RTB 어휘 제거 + §8 이식성 패치를 적용해 포팅한다.

---

## 파일 구조 (생성 대상)

```
loop-orchestrator/
├── .claude-plugin/{plugin.json, marketplace.json}
├── agents/test-quality-auditor.md
├── skills/orchestrate/{SKILL.md, scripts/{preflight,setup-worktrees,launch-session,watch-status,status-update,safe-cleanup}.sh, templates/{brief.md,session-prompt.md}}
├── skills/loop-implement/SKILL.md
├── hooks/{hooks.json, preflight.sh, loop-gate.sh}
├── tests/*.bats
├── .github/workflows/{test.yml, release.yml}
├── README.md, LICENSE, .gitignore
```

커밋 원칙: 각 task 끝에 1커밋. **author/committer=choiyounggi, Claude 흔적 없음**(§배포). 커밋 메시지는 conventional, Claude 언급 금지.

---

## Task 0: repo 스캐폴드

**Files:** Create `.gitignore`, `LICENSE`(MIT, author=choiyounggi)

- [ ] **Step 1:** `.gitignore` 작성 — `.orchestration/`, `node_modules`, `.DS_Store`, `*.log`, `.claude/`
- [ ] **Step 2:** `LICENSE` — MIT, "Copyright (c) 2026 choiyounggi"
- [ ] **Step 3:** `git init` (이미 docs/ 있으니 init 후 첫 커밋), author 설정은 §배포 절차로
- [ ] **Step 4:** Commit `chore: scaffold repo (license, gitignore)`

## Task 1: 플러그인 매니페스트

**Files:** Create `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] **Step 1:** `plugin.json` — name=`loop-orchestrator`, version=`0.1.0`, description, author=choiyounggi, homepage/repository=github repo. (공식 plugin manifest 스키마 — 구현 직전 docs 실측: §14 `bin/`·필드 확인)
- [ ] **Step 2:** `marketplace.json` — 이 repo를 marketplace로 노출하는 최소 구조(plugins 배열에 loop-orchestrator 1개). **구현 직전 공식 marketplace 스키마 실측**(plugins-reference.md).
- [ ] **Step 3:** 검증 — `cat`으로 JSON 유효성(`jq . < plugin.json`)
- [ ] **Step 4:** Commit `feat: add plugin manifest and marketplace`

## Task 2: 의존성 preflight (훅)

**Files:** Create `hooks/preflight.sh`, `hooks/hooks.json`, `tests/preflight.bats`

- [ ] **Step 1 (Red):** `tests/preflight.bats` — ① git/tmux/jq가 모두 있으면 exit 0, ② tmux 없으면 안내문에 "tmux" + 설치 명령 포함하고 **exit 0(non-blocking)**, ③ 경로 탐지: `command -v`로 resolve된 경로를 출력. (PATH를 조작해 누락 시뮬레이션)
- [ ] **Step 2:** bats 실행 → FAIL 확인
- [ ] **Step 3 (Green):** `preflight.sh` 작성 — `command -v git/tmux/jq`로 탐지, 누락 시 OS별 설치 안내(`$OSTYPE` darwin→brew, linux→apt/yum) stderr 출력, **자동설치 안 함**(§8.3), non-blocking exit 0. resolve된 경로를 stdout. design §8.1/8.3 근거.
- [ ] **Step 4:** bats PASS 확인
- [ ] **Step 5:** `hooks.json` — SessionStart matcher `startup`에 preflight.sh 등록 + (Task 3 후 loop-gate 추가)
- [ ] **Step 6:** Commit `feat: dependency preflight hook with path detection`

## Task 3: 검증루프 게이트 (훅)

**Files:** Create `hooks/loop-gate.sh`, `tests/loop-gate.bats`; Modify `hooks/hooks.json`

- [ ] **Step 1 (Red):** `tests/loop-gate.bats` — ① 검증루프 미완 상태(status≠done, DoD 미충족 마커)에서 세션 Stop 시 **차단(exit 2 + stderr 사유)**, ② 정상 완료 상태에서 통과(exit 0), ③ 차단 메시지가 stdout 아닌 stderr인지. (self-habits: 훅 입력 `tool_input` 중첩 파싱, end-to-end 차단 테스트)
- [ ] **Step 2:** bats FAIL 확인
- [ ] **Step 3 (Green):** `loop-gate.sh` — Stop 훅. 세션 상태 파일/마커를 읽어 검증루프 무결성(테스트 약화·미완·종료조건 미충족) 감지 시 차단. 입력은 stdin JSON `{tool_input:...}` 구조 실측 파싱(self-habits). design §8.4 근거.
- [ ] **Step 4:** bats PASS 확인
- [ ] **Step 5:** `hooks.json`에 Stop 훅으로 loop-gate.sh 추가
- [ ] **Step 6:** Commit `feat: verification-loop integrity gate hook`

## Task 4: 오케 스크립트 포팅 + 이식성 패치

**Files:** Create `skills/orchestrate/scripts/{setup-worktrees,launch-session,watch-status,status-update}.sh`, `tests/scripts.bats`

원본(`~/.claude/skills/워크트리멀티세션/scripts/`)을 읽어 포팅하며 **패치 적용**:
- 하드코딩 경로 `/usr/bin/git`·`/opt/homebrew/bin/tmux`·`/usr/bin/jq` → `command -v` 탐지 변수(§8.1)
- RTB 어휘(Jira/wiki-rag/lease·sale/NEWRTB) 제거 → `{TASK}` 범용 토큰
- jq 의존: preflight에서 보장(§8.2), 스크립트는 resolve된 `$JQ` 사용

- [ ] **Step 1 (Red):** `tests/scripts.bats` — ① 경로 탐지: PATH에 git/tmux/jq 있으면 스크립트가 절대경로 하드코딩 없이 동작, ② status-update가 유효 JSON 생성(jq로 파싱 가능), ③ watch-status가 목표 phase 도달 시 종료. (tmux 실제 기동은 통합 smoke로 분리)
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3 (Green):** 4개 스크립트 포팅+패치 작성
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** Commit `feat: port orchestration scripts with portable path detection`

## Task 5: safe-cleanup (파괴작업 가드) + git init 선검사

**Files:** Create `skills/orchestrate/scripts/safe-cleanup.sh`, `tests/safe-cleanup.bats`

design §7(정리·병합 순서), §6(git init 3종 선검사), §8.7/8.9 근거.

- [ ] **Step 1 (Red):** `tests/safe-cleanup.bats` — ① 미커밋 변경 있는 워크트리는 remove **차단**(`git status --porcelain` 비어있지 않으면 중단, `--force` 미사용), ② tmux kill 대상이 **정확 세션명 리스트만**(prefix/grep 매칭이면 실패해야 — 양방향: 정확명 통과, 유사명 비대상), ③ git init 선검사: 상위 레포 존재(`rev-parse --show-toplevel`) 시 중단, .gitignore 부재 시 경고, 시크릿 패턴(`.env*`/`*.pem`/`*credential*`) 발견 시 차단.
- [ ] **Step 2:** FAIL 확인 (임시 git repo 픽스처로)
- [ ] **Step 3 (Green):** `safe-cleanup.sh` 작성 — 미커밋 선검사→순차병합(충돌 시 중간상태 기록 후 중단)→병합성공 실측 후 worktree remove→정확명 tmux kill. git init 선검사 함수 포함.
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** Commit `feat: safe cleanup with uncommitted/secret/exact-match guards`

## Task 6: 독립검증 에이전트

**Files:** Create `agents/test-quality-auditor.md`

design §9.3 초안 사용. **플러그인 루트 `agents/`**(§14 — 스킬 하위 미보장).

- [ ] **Step 1:** `test-quality-auditor.md` 작성 — frontmatter `name/description/tools: Read,Grep,Glob,Bash/model: inherit`(Edit/Write 제외). 본문: 읽기전용 판정 절차 + 정량 게이트(assertion≥1/케이스≥3/에러≥1/경계≥1) + tautology·skip 탐지 + `VERDICT:/REASONS:` 고정 출력.
- [ ] **Step 2:** 검증 — frontmatter YAML 유효성. **구현 직전 §14: `claude --debug`로 agent registration 실측** (스킬하위 아닌 루트 확인).
- [ ] **Step 3:** Commit `feat: add test-quality-auditor agent (read-only verifier)`

## Task 7: loop-implement 스킬

**Files:** Create `skills/loop-implement/SKILL.md`

design §5(검증루프 0~7b) 권위.

- [ ] **Step 1:** SKILL.md 작성 — frontmatter(name/description). 본문: 검증루프 단계(종료조건→분석→계획→테스트(Red)→구현(Green)→테스트실행→셀프리뷰→6.5 독립검증 호출→판정→반성+재시도 상한3). 가드레일(테스트 약화 금지), 규모 비례, test-first 정신. RTB 어휘 없음.
- [ ] **Step 2:** 검증 — frontmatter 유효성, design §5와 단계 일치 확인
- [ ] **Step 3:** Commit `feat: add loop-implement verification-loop skill`

## Task 8: orchestrate 스킬 + 템플릿

**Files:** Create `skills/orchestrate/SKILL.md`, `skills/orchestrate/templates/{brief.md, session-prompt.md}`

design §4(워크플로우), §9.1(XML brief 4요소), §9.2/9.4(트리거+에이전트 규약) 권위.

- [ ] **Step 1:** `templates/brief.md` — design §9.1 XML 구조(`<context><dependencies><objective><scope_boundaries><tools_guidance><constraints><definition_of_done><effort_level><output_contract>`). RTB 특화 제거, 범용 토큰.
- [ ] **Step 2:** `templates/session-prompt.md` — 단계별 트리거(①계획②구현③재작업④병합준비) 한 줄, brief 태그 권위 호출 + §9.4 에이전트 사용 규약 필수 블록.
- [ ] **Step 3:** `SKILL.md` — Phase 0~7(§4), 게이트1(분해승인)·게이트2(병합검수), 환경분기(§6), 동시세션 상한(§8.6), 재진입(§8.10), 정리는 safe-cleanup 호출. "나는 오케스트레이터 — 직접 구현 안 함" 가드레일.
- [ ] **Step 4:** 검증 — 모든 frontmatter 유효성, 스크립트 경로 참조 정확성
- [ ] **Step 5:** Commit `feat: add orchestrate skill with XML brief and agent guidance`

## Task 9: GitHub Actions

**Files:** Create `.github/workflows/{test.yml, release.yml}`

cliclaw `publish.yml`/`test.yml` 참고하되 **npm 단계 제외**(§11).

- [ ] **Step 1:** `test.yml` — push/PR 시 bats 설치 후 `tests/*.bats` 실행. macOS + ubuntu 매트릭스(이식성 §12).
- [ ] **Step 2:** `release.yml` — 태그 `v*` push 시 `softprops/action-gh-release`로 GitHub Release + `generate_release_notes: true`. **npm publish 없음.** tag=package 버전 검증은 plugin.json version과 대조.
- [ ] **Step 3:** 검증 — YAML 유효성(`yq`/`jq` 또는 actionlint 가능 시)
- [ ] **Step 4:** Commit `ci: add test and release workflows`

## Task 10: README

**Files:** Create `README.md`

cliclaw README 구조 참고(구현 직전 실측). 한국어 + 설치/사용/동작원리/한계.

- [ ] **Step 1:** cliclaw README를 gh로 읽어 섹션 구조 파악
- [ ] **Step 2:** `README.md` 작성 — 제목/한줄소개, 설치(`/plugin marketplace add choiyounggi/loop-orchestrator`), 빠른시작, 동작원리(워크플로우 다이어그램), 검증루프 근거, 안전장치, 요구사항(macOS/Linux·tmux·git), 한계, 라이선스. **npm 설치 언급 없음.**
- [ ] **Step 3:** Commit `docs: add README`

## Task 11: 배포 (choiyounggi, 흔적 없이)

**Files:** none (git 작업)

> 🛑 토큰은 env로만, 명령라인·파일·커밋 미기록. 작업 후 영기 revoke.

- [ ] **Step 1:** repo 로컬 author 설정: `git -C ~/loop-orchestrator config user.name choiyounggi` + `user.email`(choiyounggi의 GitHub noreply 또는 영기 지정). **전역 설정 안 건드림.**
- [ ] **Step 2:** 모든 커밋이 choiyounggi author인지 `git log --format='%an %ae'` 실측. Claude 흔적(Co-Authored-By) grep으로 0건 확인.
- [ ] **Step 3:** remote 추가 + push — PAT를 `GIT_ASKPASS` 또는 `https://choiyounggi:$PAT@...`를 **env 경유**(히스토리/명령라인 노출 최소화). push to main.
- [ ] **Step 4:** push 성공 실측(`git ls-remote`). GitHub Actions test.yml 통과 확인.
- [ ] **Step 5:** 태그 `v0.1.0` 생성+push → release.yml이 GitHub Release 생성하는지 확인.
- [ ] **Step 6:** 영기에게 결과 보고 + **토큰 2개 revoke 재공지**.

---

## Self-Review (spec 대조)

- **§3 구조 커버**: plugin/marketplace(T1), agents(T6), orchestrate+templates(T8), loop-implement(T7), hooks(T2,T3), scripts(T4,T5), workflows(T9), README/LICENSE(T0,T10) — ✅ 전 구성요소 task 존재.
- **§5 검증루프**: T7. **§8 안전장치**: 8.1/8.3(T2), 8.4(T3), 8.5(T6+T8 규약), 8.7/8.9(T5), 8.6/8.10(T8), 8.12(T5 git init). ✅
- **§9 프롬프트**: 9.1 brief XML(T8.1), 9.2 트리거(T8.2), 9.3 에이전트(T6), 9.4 규약(T8.2). ✅
- **§6 환경분기·§7 정리병합**: T5(safe-cleanup)+T8(orchestrate). ✅ **§11 배포**: T9(Actions)+T11(push). ✅
- **§14 미해결**(구현 직전 실측): plugin/marketplace 스키마(T1), agents 루트 로드(T6), `once:`/`bin/`(T1) — 각 task에 "구현 직전 실측" 명시. ✅
- **테스트**: 로직 있는 셸(preflight/loop-gate/scripts/safe-cleanup)은 bats TDD, 마크다운/설정은 유효성+로드검증. test-quality-auditor 픽스처 검증은 T9 CI에 포함 권장.
- **placeholder 스캔**: 포팅 task(T4)는 "원본+패치 리스트"로 명세화(placeholder 아님). 공식 스키마 의존 부분은 "구현 직전 실측"으로 명시(추정 금지).
