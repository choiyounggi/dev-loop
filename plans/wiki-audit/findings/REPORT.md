# wiki-audit — Final report (2026-08-05)

질문: "이 wiki는 LLM이 구현 계획을 세울 때 쓰는 프로덕션급 지식 베이스로서,
시멘틱하게 케이스를 확실히 찾을 수 있고, 내용이 충분·명확하며, harvest→flush
파이프라인이 재료를 잘 걸러 중복 없는 PR을 만드는가?"

## Axis verdicts

| 축 | 판정 | 근거 |
|----|------|------|
| 1. 구조 (기계적 건전성) | **PASS — 결함 0** | 141페이지·13인덱스 전수 스윕: frontmatter/id/related-link/인덱스 양방향/120줄/모호 한정어/소싱/신선도 전부 0건 (findings/structure.md). lint 규칙 2번의 문구-관행 불일치만 이슈화 (#36) |
| 2. 시멘틱 라우팅 | **PASS with 2 findings** | 15 프로브 중 in-charter 11/13 UNIQUE, out-of-charter 2건 clean MISS. AMBIGUOUS 2건(doc-gate 이중 소유, flaky 이중 소유) → #37 |
| 3. 카테고리 충분성 | **PASS, additive gaps** | 60개 카테고리 일관·명확. 16개 개발 관점 체크리스트에서 진짜 갭 G1–G6(아키텍처, CORS, API 버저닝, 피처 플래그, 백필, 실시간) + 하위 G7–G10 → #38. 재구조화 불요 |
| 4. harvest 필터링 | **PASS after fix** | "수집은 관대, 승격은 엄격" 설계 건전. trigger+directive 필수, 30자 하한, 템플릿 에코 차단, 해시 dedup. **processed-store dedup 누락 버그 수정**(red→green 회귀 테스트) |
| 5. flush 게이트/dedup | **PASS after 3 fixes** | INGEST_REPORT 3섹션 하드 게이트(13 테스트로 고정). 수정: 따옴표 경로 파싱, $HOME 확장, SKILL 리터럴 경로 지침, drop 후보 retire 명시(무한 오토플러시 루프 차단). 잔여 강화 → #39 |

## Fixes applied on this branch

- hooks/harvest.js — dedupe set seeded from `.processed.jsonl` (read-only)
- hooks/pre-flush-pr-gate.sh — quoted `--body-file` 인식 + `~`/`$HOME`/`${HOME}` 확장
- skills/knowledge-flush/SKILL.md — 게이트-호환 리터럴 경로 지침(자체 wiki 페이지 인용), step 5 "모든 처리 후보 retire"
- tests/harvest.bats (8), tests/pre-flush-pr-gate.bats (13) — 전부 green; 독립
  test-quality-auditor VERDICT: PASS; 전체 스위트 `bats tests/` exit 0 (315 tests)

## Issues filed

- #36 wiki-lint check 2 vs corpus (규칙 정련)
- #37 라우팅 이중 소유 2건 + 마이너 문구
- #38 카테고리 갭 G1–G10 (시드 페이지 목록 포함)
- #39 파이프라인 잔여 강화 (게이트 우회 창, 기계 검증 가능한 dedup 증빙, 수집 상한)

## Overall

프로덕션급 판정: **가깝다 — 구조·내용 규율은 이미 프로덕션 수준이고, 이번에
수정한 파이프라인 결함 3건이 실사용 신뢰성의 실제 병목이었다.** 남은 것은
전부 가산적(카테고리 확장, 트리거 문구 정련, 게이트 강화)이며 이슈로 추적된다.
