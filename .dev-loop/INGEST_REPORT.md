# Knowledge flush — 4 insight(s)

Queue drained: 4 pending candidates from 2 sessions (`19484655…`, `dd51281c…`,
harvested 2026-07-30). They land as **2 pages** — three candidates describe one
situation (gates on a spec document) and merge into a single page; the fourth is a
distinct mechanism (Unicode text matching) and gets its own.

| # | Candidate (trigger) | Target |
|---|---------------------|--------|
| 1 | Fixing a grep gate for a document that does not exist yet | `qa/document-verification/spec-document-gates.md` (§Do this 1) |
| 2 | Verifying an RFC/API-spec's requirements with grep gates | same page (§Do this 3, four axes) |
| 4 | Prose-document checklist that keyword checks pass vacuously | same page (§Do this 3–4, modality/polarity + fail-closed) |
| 3 | grep/regex over Korean text, stem-prefix pattern | `platforms/environment/unicode-text-matching.md` (new page) |

## Verified best-practice

### Candidates 1, 2, 4 — gates on a specification document → `confidence: field-tested`

**Claim.** A token-existence grep is not sufficient evidence that a document meets a
requirement; gates need a positive control (a conforming sibling the pattern must
match), a negative control (a mutated copy it must reject), four check axes
(structure / modality+polarity / closed-set completeness / cross-reference), and
fail-closed behaviour when the anchor is missing.

**Sources checked.** Each mechanism is grounded in a tool or spec that implements it:

| Directive | Source | What it says (checked, not assumed) |
|-----------|--------|--------------------------------------|
| Positive **and** negative control per gate | [eslint.org custom-rule-tutorial](https://eslint.org/docs/latest/extend/custom-rule-tutorial) (fetched) | Verbatim: "RuleTester requires that at least one valid and one invalid test scenario be present." |
| Structure of a checker's test cases | [eslint.org nodejs-api](https://eslint.org/docs/latest/integrate/nodejs-api) (fetched) | `RuleTester#run()` takes `valid` + `invalid` arrays; invalid cases assert the expected error count |
| Mutants prove detection, coverage does not | [testing.googleblog.com mutation testing](https://testing.googleblog.com/2021/04/mutation-testing.html) | Inserting faults and requiring failure measures whether checks detect bugs (already cited by `testing-quality-tests-that-cannot-fail`) |
| MUST→SHOULD demotion changes the requirement while keeping every keyword | [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) (fetched) | MUST = "an absolute requirement of the specification"; SHOULD = there "may exist valid reasons … to ignore a particular item" |
| Cross-reference axis is a real check class | [docs.vale.sh/checks/conditional](https://docs.vale.sh/checks/conditional) (fetched) | Verbatim: "Ensures that the existence of 'first' implies the existence of 'second'." |
| Count + scope, not bare existence | [docs.vale.sh/checks/occurrence](https://docs.vale.sh/checks/occurrence) (fetched) | Enforces "the maximum or minimum number of times a particular token can appear in a given scope" (`scope: sentence`) |
| Table structure gets parsed, not grepped | [markdownlint MD056](https://github.com/DavidAnson/markdownlint/blob/main/doc/md056.md) | Flags tables whose rows disagree with the header column count |
| A delimiter count is not a parse | [markdownlint issue #1206](https://github.com/DavidAnson/markdownlint/issues/1206) | MD056 counts pipes inside backticks as separators and misreports — the failure mode of approximating a parse |

**How verified.** Every ESLint/Vale/RFC quote above was fetched from the primary
source in this session, not recalled. The *composite* methodology (the four-axis
framing and its ordering) comes from the two harvested sessions, where an
independent auditor built tampered copies that a 16-gate existence checklist
accepted (5 of 8 passed all 16, including one with a row deleted from a 5-row
`type` enum) and, after the axes were added, 32/32 mutants failed their designated
check while the intact document passed 62/62.

**Resulting confidence: `field-tested`, deliberately not `verified`.** Each
individual directive is doc-backed, but the composite rule's evidence is in-house
session experience a reader cannot re-run, so the page carries a `Field context`
section stating that provenance instead of claiming external verification.

### Candidate 3 — Unicode text matching → `confidence: verified`

**Claim.** A stem-prefix pattern silently returns 0 hits on precomposed text
(`아니` is not inside `아닌`), and `grep` applies no canonical equivalence, so an
NFC pattern misses NFD data entirely.

**How verified — reproduced locally** (macOS 15 / APFS, `grep` 2.6.0-FreeBSD, Python 3.13, 2026-07-30):

```
NFC 아닌 = U+C544 U+B2CC     NFC 아니 = U+C544 U+B2C8     substring? False
NFD 아닌 = U+110B U+1161 U+1102 U+1175 U+11AB              substring? True   ← form-dependent
grep -c '아니' <NFC file> → 0      grep -c '아닌' <NFC file> → 1   (same line)
grep -c -f <NFC pattern> <NFD file> → 0      -f <NFD pattern> → 1
```

The NFC/NFD asymmetry was **not** in the harvested candidate; the reproduction
surfaced it, and the page states it because it decides whether the naive pattern
fails at all. A second reproduction (creating an NFC-named file, listing it, and
opening it by both forms) confirmed APFS returns the name as written and resolves
either form — matching Apple's documented behaviour rather than the folklore that
macOS always decomposes.

**Sources checked.**
- [UAX #15](https://unicode.org/reports/tr15/) (fetched) — Hangul syllables have special full-decomposition rules and are maintained under all normalization forms; canonically equivalent strings have different binary representations unless normalized.
- [Unicode 16.0 core spec, chapter 3](https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-3/) — §3.12 Conjoining Jamo Behavior: 11,172 precomposed Hangul syllables from `SBase = U+AC00`, algorithmic L/V/T decomposition.
- [Apple File System Guide FAQ](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html) — APFS preserves the file name's normalization and is normalization-insensitive via hashes of the normalized form; HFS+ stores the normalized form.
- [POSIX grep](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html) — matching is specified by regular-expression rules over input lines; no canonical-equivalence folding.

The candidate's own note that its first diagnosis ("BSD grep ERE multibyte bug")
was wrong is preserved as behaviour, not blame: the page's edge-case row says to
dump code points before concluding the text is absent.

**Nothing left `unverified`.** No candidate was dropped.

## Existing-layer check

**Pages read in full:** `INDEX.md`, `AGENTS.md`, `templates/page.md`,
`skills/wiki-ingest/SKILL.md`, `wiki/qa/index.md`, `wiki/testing/index.md`,
`wiki/platforms/index.md`, `wiki/debugging/index.md`,
`wiki/testing/quality/tests-that-cannot-fail.md`, `wiki/qa/process/release-gates.md`,
`wiki/qa/process/acceptance-criteria.md` (frontmatter + structure),
`wiki/platforms/environment/timezone-and-locale.md`,
`wiki/platforms/filesystems/paths-case-and-line-endings.md`.
**Repo-wide greps** for `grep`, `unicode|normali[sz]|codepoint|multibyte|NFC|NFD`,
and `specification|RFC|design doc|acceptance criteri` to find any page already
holding this material.

| Overlap candidate | Verdict |
|---|---|
| `testing-quality-tests-that-cannot-fail` | **Closest neighbour, not a duplicate.** It owns "prove a *test* can fail by mutating the code"; the new page owns "prove a *document gate* can pass and can fail". Same principle, different artifact and different failure table. Linked **both ways**, and the new page's edge-case table routes code deliverables back to it. |
| `qa-process-release-gates` | Human release checklist (suite green / smoke / regression / rollback). No overlap with automated checks on a document's text. Left untouched. |
| `qa-process-acceptance-criteria` | Adjacent: it defines testable criteria for a ticket; the new page verifies a document against them. Back-link added; the new page's "document deliberately relaxes a requirement" row points at it. |
| `platforms-environment-timezone-and-locale` | Covers locale-dependent **casing and collation** (Turkish `İ`/`ı`, `LC_COLLATE`) — the environment as hidden input. Normalization form is a property of the **data**, not the environment, and the page is already 81 lines with a different "load when". Kept separate, back-linked. |
| `platforms-filesystems-paths-case-and-line-endings` | Covers case-collisions and CRLF; mentions path normalization only as "use the platform's path API". Does not cover Unicode form. Back-link added. |
| `platforms-tools-bsd-vs-gnu-cli` | Owns userland flag differences. The new page cites it inline for the multi-byte character-class caveat rather than restating it. |

**Conflicts flagged: none.** No existing directive contradicts either new page.

**Reciprocal `related:` links added** to `testing-quality-tests-that-cannot-fail`,
`qa-process-acceptance-criteria`, `platforms-environment-timezone-and-locale`, and
`platforms-filesystems-paths-case-and-line-endings`.

## Routing decision

### 1. `qa` / **new category `document-verification`** / `spec-document-gates.md`

- **Domain — `qa` over `testing`.** `INDEX.md` scopes `testing` to *automated test
  code for software behaviour*; the artifact here is a written deliverable and the
  question is "does it meet its acceptance criteria, and is the gate that decides
  that trustworthy" — which is `qa`'s remit (acceptance criteria, gates). Two of the
  four candidates self-declared `qa`; the third declared `testing` and is routed
  with them because it is a directive about the same gates.
- **New category justified.** Existing `qa` categories are `process` (human release
  workflow), `environments` (staging parity), `bug-reports`, `exploratory` — none
  covers automated verification of an artifact. Folding it into `process` would put
  a script-authoring page among human-workflow pages and blur that index's routing
  lines. `document-verification` is where doc linting and link checking will also land.
- **Merged 3 candidates into 1 page** per "one case per page": all three answer the
  same situation (authoring/reviewing gates over a spec document) — candidate 1 is
  the *control* step, candidate 2 the *what to check* step, candidate 4 the
  *polarity + fail-closed* step. Splitting them would produce three pages sharing one
  "load when" line, which is what the merge-before-create rule exists to prevent.

### 2. `platforms` / existing category `environment` / `unicode-text-matching.md`

- **Domain — `platforms` over `qa`** (the candidate's own hint): the mechanism is
  text representation and its OS/producer-dependent form, not release quality. The
  `platforms` index already owns "hidden environment inputs" and cross-OS filesystem
  behaviour, and `environment/` is the sibling of `timezone-and-locale`, the existing
  page for text operations that behave differently than assumed.
- **No new category** — `environment` fits, so none was created.
- Cross-linked to the `qa` page so a doc-gate author writing a Korean pattern is
  routed here, and back so a 0-hit debugger reaches the gate-design rules.

### Plumbing updated

`wiki/qa/index.md` (new category block + route-line scope), `wiki/platforms/index.md`
(page row + intro scope), `INDEX.md` (both domain route lines), `log.md` (2 ingest
entries). Checked before commit: both pages under the 120-line body limit (77 / 54),
every `related:` and inline `[page-id]` resolves, both pages listed in their domain
index, no banned vague qualifiers, no prohibition without a paired replacement.

## Decision Log

- **의도** — 큐 4건을 드롭 없이 위키에 넣되 중복 페이지를 만들지 않도록 3건을 한
  페이지로 병합하고, 각 지시문을 1차 출처로 검증했다. 하베스트된 주장을 그대로 옮기지
  않고 ESLint·Vale·RFC 2119·markdownlint 원문을 실제로 열어 인용했다.
- **배제** — ⓐ 4건을 4페이지로 쪼개는 안(“one case per page” 위반, load-when 라인이
  겹침) ⓑ Unicode 건을 `timezone-and-locale`에 병합하는 안(그 페이지는 *환경*이 입력인
  경우를 다루고 정규화형은 *데이터*의 속성 — 트리거가 다름) ⓒ 문서 게이트 페이지를
  `qa/process`에 넣는 안(사람 프로세스 페이지 사이에 스크립트 작성 지침이 섞임)
  ⓓ 복합 방법론에 `verified`를 부여하는 안 — 개별 지시문은 출처가 있으나 4축 조합의
  근거는 사내 세션이라 `field-tested`로 낮추고 그 사실을 페이지에 명시.
- **리뷰포인트** — ① 새 카테고리 `qa/document-verification` 신설이 과한지(대안: `process`
  편입) ② 후보 3건 병합 경계가 맞는지 ③ `field-tested` 등급 판단 ④ Unicode 페이지의
  NFC/NFD 비대칭은 원 후보에 없던 내용으로 이번 재현으로 추가된 것 — 원 후보 취지를
  넘어서는지.

Cross-Check: 각 지시문을 1차 출처 원문 fetch로 대조(ESLint RuleTester 문장·RFC 2119
MUST/SHOULD 정의·Vale conditional/occurrence 설명·UAX #15·APFS FAQ), Unicode 주장은
로컬 재현 2종(코드포인트 덤프 + grep 4회, APFS 파일명 생성/조회)으로 실측. 이번 세션은
서브에이전트 사용이 배제되어 독립 에이전트 적대검증은 돌리지 않았음 — 검증은 출처
대조와 재현에 근거한다.
