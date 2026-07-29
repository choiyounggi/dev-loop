# Knowledge flush — 1 insight(s)

Cross-Check: 주장별 1차 소스 직접 대조(POSIX grep 규격, James Shore AoAD2, Semgrep 룰테스트 문서, pytest exit codes) + 로컬 재현(BSD grep 2.6.0-FreeBSD, ugrep 7.5.0)으로 검증. 이 실행 컨텍스트는 서브에이전트/워크플로우 사용이 금지되어 독립 에이전트 패널 대신 1차 소스 인용 + 실행 재현으로 교차검증했고, 그 과정에서 초안 스니펫의 자체 결함 1건을 잡아 교정했다(아래 참조).

## Decision Log

- **의도**: 큐(`~/.dev-loop/queue`)의 ★ Insight 후보를 knowledge-flush 파이프라인(리서치 검증 → 기존 레이어 중복확인 → 라우팅 → wiki-ingest)으로 정제해 반영. 큐 3행 중 실제 신규는 1건.
- **배제한 대안**: ① 기존 `testing/quality/tests-that-cannot-fail.md`에 병합 — 그 페이지의 트리거는 "항상 통과하는 스위트 감사"로 이번 케이스(타깃이 아직 없는 체크의 작성 시점)와 로딩 조건이 어긋나 index "load when"과 모순되고 페이지가 두 상황을 겸하게 됨(AGENTS.md "One case per page") → 대칭 신규 페이지 + 양방향 related. ② `qa/process/acceptance-criteria`에 편입 — qa 인덱스가 자동 체크 작성은 `wiki/testing/`으로 라우팅하라고 명시 → testing. ③ 수확 원문 그대로 반영 — 리서치에서 메커니즘 교정 1건 + 실측 false-green 함정 2건이 나와 교정본으로 반영.
- **리뷰어가 볼 곳**: 신규 페이지(82 body lines)의 `confidence: verified` 근거가 인용과 맞는지, `tests-that-cannot-fail`·`minimum-case-set`의 `related:` 한 줄 추가가 과하지 않은지, 그리고 **`log.md` 말미 append가 열려 있는 PR #6과 같은 위치라 머지 순서에 따라 텍스트 컨플릭트가 날 수 있음**(양쪽 append를 모두 살리면 해소).
- **큐 회수 이슈 [확인됨]**: 큐 3행 중 2행(`cc42fbc0…`, `75b447fc…`)은 `.processed.jsonl`에 이미 `flushed`로 기록되어 있고 **열린 PR #6에 이미 반영된 항목**인데 세션 파일에서 제거되지 않아 pending으로 재등장했다. 이번 flush에서 재-ingest하지 않고 회수만 한다(중복 방지). 이전 flush의 retire 단계가 `.processed.jsonl` append는 했으나 세션 파일 rewrite를 못 한 것으로 보인다 — 재발하면 `knowledge-flush` 5단계(회수)를 손볼 필요가 있다.

## Verified best-practice

**1. 타깃이 아직 없는 체크(grep/정규식 게이트·lint 룰·스키마 단정)를 채택하기 전에 known-good 입력으로 먼저 돌린다**

주장: 부재한 타깃에 대한 실패 실행은 어떤 패턴이든(옳은 것도, 오타 난 것도) 동일하게 내므로 "패턴이 옳다"의 증거가 아니다. 같은 규격을 이미 만족하는 형제 산출물에 돌려 기대 카운트가 나오는지 확인한 뒤 게이트로 채택한다.

확인한 소스:
- **James Shore, *The Art of Agile Development* 2nd ed., TDD 챕터** — https://www.jamesshore.com/v2/books/aoad2/test-driven_development (fetch) — verbatim: *"Don't just predict that it will fail, though; predict how it will fail."* / *"If the test doesn't fail, or if it fails in a different way than you expected, you're no longer in control of your code."* → "red를 봤다"가 아니라 "예측한 방식으로 red였다"가 증거라는 일반 원칙 확인.
- **POSIX / Open Group `grep` 규격** — https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html (fetch) — verbatim: EXIT STATUS `0` = one or more lines selected, `1` = no lines were selected, `>1` = an error occurred. 그리고 *"If the -q option is specified, the exit status shall be zero if an input line is selected, even if an error was detected."* → 페이지의 exit-status 구분 표와 `-q` 마스킹 엣지케이스의 규격 근거.
- **Semgrep rule-testing 문서** — https://docs.semgrep.dev/writing-rules/testing-rules (fetch) — `ruleid:` 주석은 *"for protecting against false negatives"*, `ok:` 주석은 *"for protecting against false positives"*. 매처를 **매칭돼야 하는 입력 + 매칭돼선 안 되는 입력** 양방향으로 검증하는 것이 문서화된 규범임을 확인 → "known-good 입력으로 먼저 돌린다"의 1차 근거.
- **pytest exit codes** — https://docs.pytest.org/en/stable/reference/exit-codes.html (fetch) — `5` = *"No tests were collected"*, `1` = 테스트가 실행되고 실패. 셀렉터 오타가 "실패한 테스트"로 위장되지 않게 구분하는 근거(엣지케이스 행).
- (참고: ESLint `RuleTester` 문서 https://eslint.org/docs/latest/integrate/nodejs-api 도 확인했으나 `valid`/`invalid` 양방향을 **요구**한다고는 쓰여 있지 않고 빈 `valid: []` 예시가 있어, 이 근거는 채택하지 않고 Semgrep으로 대체했다.)

로컬 재현(macOS, BSD grep 2.6.0-FreeBSD + ugrep 7.5.0, 2026-07-29):

| 실행 | 결과 |
|------|------|
| 존재하는 파일 + 매칭 없는 패턴 | exit 1 |
| 없는 파일 | exit 2 (stdout 비어 있음) |
| 문법적으로 잘못된 정규식 | exit 2 |
| **의미상 틀렸지만 유효한 앵커**(`^### x$` vs `^## x$`)를 존재하는 파일에 | **exit 1 — "아직 안 쓰였다"와 구별 불가** |
| `grep -q pat 없는파일 매칭되는형제파일` | **exit 0 (false green)** — 형제의 매칭이 타깃 부재를 가림 |
| `grep -c pat 없는파일 \| tail -1` (pipefail 없음) | **exit 0 (false green)** — 파이프가 grep의 error 2를 덮음 |
| `[ "$n" -eq 7 ]`에서 `$n`이 빈 값 | 셸 에러 `integer expression expected` → 원인을 가린 게이트 실패 |

수확 원문 대비 **교정 1건**: 원문은 "대상 파일이 없을 때의 exit≠0"을 근거 부족의 이유로 들었으나, 규격·실측상 **없는 파일은 exit 2로 no-match(1)와 구별 가능**하다. 진짜 함정은 ⓐ 의미상 틀렸지만 유효한 패턴이 no-match(1)와 동일해 red가 패턴 정확성을 증명하지 못한다는 점, ⓑ `exit != 0` 같은 boolean 게이트가 세 결과를 뭉갠다는 점이다. 페이지는 교정된 메커니즘으로 기술했다. **리서치 보너스 2건**(`-q` 마스킹, 파이프 마스킹)은 부재-타깃 게이트가 red가 아니라 **거짓 green**이 될 수도 있음을 보여주는 별개 실패 모드로 추가했다.

**자기적용에서 잡은 결함 1건**: 페이지 초안의 예시 스니펫 `n=$(grep -cE "$pat" "$f") || n=0`을 네 입력(known-good / 오타 앵커 / 없는 파일 / 잘못된 정규식)으로 실제 돌려보니 **잘못된 정규식(exit 2)을 카운트 불일치(rc=1)로 보고**해, 페이지가 금지하는 바로 그 뭉갬을 저질렀다. grep 상태를 먼저 보존하는 버전으로 교체하고 네 갈래(rc 0/1/3/4)가 각각 구분됨을 재확인했다.

**Confidence: verified** — 메커니즘 주장은 규격 인용 + 두 grep 구현에서 재현 가능, 일반 원칙은 1차 문헌 인용. 발원 맥락(형제 RFC로 7섹션·상호 시그니처 게이트를 먼저 검증한 계획 세션)은 현장 경험이므로 페이지 본문·`log.md`에 그 성격대로 기술했다.

## Existing-layer check

읽은 것: 루트 `INDEX.md`; `wiki/testing/index.md` 전체; 트리거가 겹칠 수 있는 페이지 전문 — `testing/quality/tests-that-cannot-fail.md`, `testing/quality/minimum-case-set.md`; `wiki/qa/index.md` + `qa/process/acceptance-criteria.md`(도입부·라우팅 라인), `qa/process/release-gates.md`(관련 행). 레포 전역 grep(`wrong reason|vacuous|grep -c|verify command|not yet exist|sibling|false negative|falsifiab|TDD|red-green`)으로 이 트리거를 소유한 페이지가 없음을 확인.

- **발견된 겹침**: 소유권 겹침 없음. `tests-that-cannot-fail`은 **항상 green인 테스트 감사**(거울상)를 소유하고, red가 잘못된 이유로 날 수 있는 문제는 다루지 않는다. `minimum-case-set` 5항은 "버그 수정 시 먼저 실패하는 회귀 테스트를 보라(red → green)"까지만 말하고 그 red가 **예상한 red인지**는 다루지 않는다(인접하되 별개). `qa/process/acceptance-criteria`는 기준 문장의 테스트가능성을 소유하며 자동 체크 작성은 명시적으로 `wiki/testing/`으로 라우팅한다. `qa/process/release-gates`는 릴리즈 체크리스트 프로세스를 소유한다.
- **병합 vs 신규**: 0 병합, 1 신규. 트리거("타깃이 아직 없는 체크를 채택하려는 시점")가 신규이고, 기존 페이지에 넣으면 그 페이지의 "load when"과 어긋난다.
- **충돌 플래그**: 없음. 기존 지시와 모순되는 내용 없음 — `minimum-case-set`의 red-then-green 규칙을 약화시키지 않고 "예측한 red인지 확인"으로 보강한다.
- **추가한 related(양방향)**: `checks-that-cannot-pass` ↔ `tests-that-cannot-fail`, ↔ `minimum-case-set`. (`qa-process-acceptance-criteria`는 초안에 넣었다가 제거 — 도메인이 다르고 트리거가 기준 문장 작성이라 링크 그래프를 부풀리지 않기로 했다.)

## Routing decision

| Insight | Target | Page |
|---------|--------|------|
| 1 (타깃 부재 체크의 검증) | `testing/quality` (**기존 카테고리**) | `wiki/testing/quality/checks-that-cannot-pass.md` — 신규 페이지, 신규 트리거 |

**신규 카테고리 없음.** `testing/quality`가 이미 "이 테스트가 실제로 결함을 잡을 수 있나"류의 판정을 소유하며(`tests-that-cannot-fail`, `minimum-case-set`), 이번 페이지는 그 대칭축(체크가 **통과**할 수 있음을 증명)이라 같은 카테고리에 나란히 두는 것이 최소 변경이다. 도메인은 `testing` — 루트 `INDEX.md`의 testing 라우팅("자동 테스트 작성/구조화: 케이스·단정")에 부합하고, qa 인덱스도 자동 체크 작성을 testing으로 넘긴다.

배관 갱신: `wiki/testing/index.md`(quality 표에 "load when" 행 추가 + 도메인 라우팅 문장에 사용처 1개 추가), `wiki/testing/quality/tests-that-cannot-fail.md`·`minimum-case-set.md`(`related:` 각 1개), `log.md`(ingest 엔트리 1건). 루트 `INDEX.md`는 도메인/상태 변화가 없어 수정하지 않았다.

## Queue disposition

| hash | 처리 |
|------|------|
| `f997639131d8ec9e` (testing — doc-verification/grep-gates) | ingest → 이 PR |
| `cc42fbc033c8cf4f` (backend — LLM completion validation) | 재-ingest 안 함 — 열린 PR #6에 이미 반영, 회수만 |
| `75b447fc2d2e4f78` (backend — gateway alias defaults) | 재-ingest 안 함 — 열린 PR #6에 이미 반영, 회수만 |
