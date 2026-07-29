# Knowledge flush — 1 page from 2 insight(s), 1 candidate deduped

Cross-Check: 독립 claude CLI(headless, --permission-mode plan) 적대검증 1회 — `.strip("|")`가 마지막 셀의 escaped pipe를 먹는 실제 버그(GitHub `/markdown` API로 재현 확인), pitest·ESLint 인용 과대주장 2건을 지적받아 전부 수정 반영. 백슬래시 parity 반례 지적은 GitHub 실렌더로 기각됨.

Queue drained: 3 pending rows. Two became one page (they share a trigger); one was
already flushed and is a duplicate re-emission — see "Existing-layer check".

## Independent adversarial cross-check — 3 defects found and fixed

An independent headless `claude` instance was asked to break this page's claims. It
found one real code defect and two overstated citations; all three are fixed in this
PR, and I re-verified each myself rather than taking the review's word.

| Finding | Verification | Fix |
|---------|--------------|-----|
| **Code defect.** The snippet's `row.strip().strip("|")` strips a *run* of pipes, so a cell ending in an escaped pipe loses it and keeps a dangling backslash — every per-column comparison against that cell then compares the wrong string | Reproduced: `\|a\|b\\\|\|` gave `['a', 'b\\']`. Ground truth from GitHub's own renderer (`POST /markdown`, `mode: gfm`): the row is two cells, `a` and `b\|` | Delimiters now stripped with anchored patterns (`^\|`, `(?<!\\)\|$`); the corrected snippet returns `['a', 'b\|']`. The snippet **as published** was executed against both cases as a check |
| **Overstated citation (pitest).** The page presented "exactly the owning check reddens" as the mutation-testing mechanic; mutation testing kills a mutant when *any* test fails, so fault *isolation* is this page's own convention | Re-read the pitest wording already quoted in Sources | Directive 2 now cites pitest for seed-and-kill only and labels one-mutation-one-owner a convention this page adds |
| **Overstated citation (ESLint).** "every rule is exercised against input that must pass" does not follow — `RuleTester` requires nothing about `valid`, which may be empty | Checked against the cited API doc | Inference cut from both the body and the Sources line; only the `invalid`-declares-`errors` fact remains |

One challenge was **rejected**: the reviewer proposed that `(?<!\\)\|` mishandles an
escaped backslash before a real delimiter (`\\|`). GitHub's renderer emits a single
merged cell there, so the lookbehind matches real GFM behavior; the spec is silent on
backslash parity. No change made.

## Verified best-practice

### Insight A — coverage of a mapping table is not validity of its cells

**Claim.** When a check confirms a spec/mapping table covers every item of a source
list (row-per-rule, key-per-field, case-per-enum), pair it with a separate
value-validity check (each cell's value must exist in the canonical enum/schema/id
set), and give each check its own negative control that mutates only what that check
owns.

**Sources checked.**

- <https://json-schema.org/draft/2020-12/json-schema-validation> — the normative
  split this rests on. `required`: "An object instance is valid against this keyword
  if every item in the array is the name of a property in the instance." `enum`: "An
  instance validates successfully against this keyword if its value is equal to one
  of the elements in this keyword's array value." Presence and value are separate
  keywords in the spec, which is exactly the coverage-vs-validity distinction.
- <https://pitest.org/> — the negative-control mechanic. "Faults (or mutations) are
  automatically seeded into your code, then your tests are run. If your tests fail
  then the mutation is killed, if your tests pass then the mutation lived." And on
  why a green run over covered rows proves less than it appears to: line coverage
  "measures only which code is executed by your tests. It does **not** check that
  your tests are actually able to detect faults in the executed code."
- <https://eslint.org/docs/latest/integrate/nodejs-api> — `RuleTester#run()` takes
  `valid` and `invalid` case arrays, and an invalid case must declare `errors`; the
  must-pass/must-fail pairing is the established form for validating a checker.

**How verified.** The two load-bearing quotes (JSON Schema, pitest) were read from
the primary sources, not from memory. The per-check-negative-control refinement —
one mutation per check, requiring the *owning* check to redden — is the session's
own field evidence (mutating `| EntityDecl | Entity |` to `Bogus` and repointing a
golden node id to `perf.nonexistent` both left the coverage checks PASS until
kind∈schema and id∈document checks were added).

**Confidence: verified** for the coverage/validity split and the seeded-fault
mechanic (official docs). The "exactly one check reddens per mutation" discipline is
field evidence layered on those sources; it is stated as a directive, not attributed
to a source it does not come from.

**Not cited.** The draft this flush inherited cited
`testing.googleblog.com/2021/04/mutation-testing.html`. That page's body could not be
retrieved (the fetch returned only title/comments/sidebar), so it was **removed**
rather than carried as an unread citation; `pitest.org` supplies the same mechanic in
text I could actually read. Two further draft citations (ploeh red-green checklist,
lostechies "red for the right reason") were dropped with the scope change below.

### Insight B — Markdown table rows split on unescaped pipes only

**Claim.** When validating or parsing Markdown table rows programmatically, split on
unescaped pipes — `re.split(r"(?<!\\)\|", row)` — then unescape `\|` in each cell,
before asserting cell counts.

**Sources checked.**

- <https://github.github.com/gfm/> (tables extension) — "Include a pipe in a cell's
  content by escaping it, including inside other inline spans"; "The header row must
  match the delimiter row in the number of cells. If not, a table will not be
  recognized"; and for body rows, "If there are a number of cells fewer than the
  number of cells in the header row, empty cells are inserted. If there are greater,
  the excess is ignored". The last quote corrected an edge-case claim: a fixed
  body-row cell count is a repo convention, not a GFM requirement, and the page now
  says so.

**How verified.** Reproduced locally (Python 3.9.6, macOS) on a 5-column row whose
third cell holds `create\|update\|delete`: `split("|")` → **7** cells,
`re.split(r"(?<!\\)\|", …)` → **5**, matching the 5-cell header. Note the inherited
draft asserted "6 cells naive vs 4 correct" — those figures did not reproduce (they
came from a differently-shaped row), so the page carries **my measured 7-vs-5** with
the interpreter version stated.

**Confidence: verified** (GFM spec quote + local reproduction).

## Existing-layer check

Routed via `INDEX.md` → `testing` → read `wiki/testing/index.md` and every
`quality/` page whose "load when" overlaps.

| Page read | Overlap | Resolution |
|-----------|---------|------------|
| `quality/tests-that-cannot-fail.md` | Same family: its step 1 proves a test can fail by mutating the code under test once. Different trigger (a test of code vs. a multi-check harness over a spec artifact) and a distinct directive (one mutation *per check*, scoped so the owning check is the one that reddens) | New page; `related:` added **both ways** |
| `quality/minimum-case-set.md` | Case selection for a function/endpoint — not artifact conformance | No change |
| `quality/behavior-not-implementation.md` | What a test should assert — no overlap | No change |
| `qa/index.md` + `qa/process/*` | Insight B was harvested with `domain: qa` | Rerouted to `testing`; rationale below |

**Duplicate found — candidate retired, not ingested.** The third pending row
(hash `f997639131d8ec9e`, "validating a grep/regex gate whose target does not exist
yet") is already recorded in `~/.dev-loop/queue/.processed.jsonl` with
`status: flushed`, and it is the subject of **open PR #7**
(`wiki/testing/quality/checks-that-cannot-pass.md`). The pending row is a second
emission of the identical hash from a later session. It is retired without a second
page.

**Conflict flagged — PR #7 and this PR touch the same lines.** Both append an id to
the same `related:` line in `tests-that-cannot-fail.md` and add a row to the same
`quality` table in `wiki/testing/index.md`. A textual merge conflict is expected on
whichever merges second; the resolution is to **keep both** ids and **both** rows.

**Scope narrowed against PR #7.** An earlier aborted run of this flush left an
untracked draft that folded all three candidates into one page, so its item 1 and one
"Instead of" row re-taught PR #7's subject (validate a gate against a known-good
sibling before adopting it), and it duplicated PR #7's grep-exit-status edge case.
Both were **removed** — that subject belongs to PR #7. No `related:` link to
`testing-quality-checks-that-cannot-pass` was added, because AGENTS.md invariant 4
requires every `related:` id to resolve and that page does not exist on `main` while
PR #7 is open. If PR #7 merges, adding the link both ways is a one-line follow-up.

## Routing decision

| Insight | Target | Rationale |
|---------|--------|-----------|
| A (coverage vs. value validity, per-check negative controls) | `testing` / `quality` / **`spec-artifact-checks.md`** (new page, existing category) | Writing the checking code is `testing`'s remit per `INDEX.md`; `quality` already holds the "can this check actually detect a defect" family (`tests-that-cannot-fail`) |
| B (unescaped-pipe table parsing) | Same page, as directive 5 + an edge-case row | Same trigger — a check over a Markdown spec artifact must parse the table before it can assert anything about it. Keeping them together respects "one case per page"; the case is "checking that a spec/mapping artifact conforms" |

**Harvested `domain: qa` overridden for insight B.** `INDEX.md` scopes `qa` to
release-quality *process* (gates, regression scoping, bug reports, triage) and
`testing` to writing automated tests and checks. Parsing a table inside a checker is
check-authoring code, so it routes to `testing`. `wiki/qa/` was read to confirm no
page there owns doc parsing.

**No new category.** `testing/quality` fits; nothing was created at the domain or
category level, so `INDEX.md` is unchanged.

### Files in this PR

- **new** `wiki/testing/quality/spec-artifact-checks.md` — 92 body lines (≤120), no
  banned vague qualifiers, every anti-pattern paired with a replacement in
  `Instead of`, `id` matches path, unique across the wiki
- `wiki/testing/index.md` — `quality` table row with a "load when" line enumerating
  all four distinct uses (mapping coverage, cross-document ids, verdict wording,
  Markdown row parsing)
- `wiki/testing/quality/tests-that-cannot-fail.md` — reverse `related:` id only;
  `last_verified` deliberately left at 2026-07-10 since no claim on that page was
  re-verified
- `log.md` — appended `## [2026-07-29] ingest | testing +1 (quality)` entry

Invariants checked mechanically: `related:` ids resolve, reverse link present, page
listed in its domain index, no unresolved inline links, body ≤120 lines, id unique.

## Decision Log (AI 생성)

### 의도 — 무엇을 / 왜
- 큐에 쌓인 3건 중 2건(coverage-vs-validity 음성대조, GFM escaped pipe 파싱)을 한 페이지로 묶어 `testing/quality/spec-artifact-checks.md`로 신설. 두 건이 트리거("spec/mapping 산출물을 검사하는 체크를 짠다")를 공유하므로 AGENTS.md의 "one case per page"를 지키면서 한 페이지가 맞다고 판단.
- 나머지 1건은 이미 `flushed` 상태(열린 PR #7)인 동일 hash의 재방출이라 페이지를 만들지 않고 회수만 했다 — 같은 주제로 두 페이지가 생기는 것을 막기 위함.
- 인용은 전부 직접 열어 확인했고, 본문을 못 읽은 출처(Google testing blog)는 인용에서 제거하고 읽을 수 있는 pitest.org로 교체했다. 물려받은 초안의 수치(6 vs 4)가 재현되지 않아 내가 측정한 7 vs 5로 교체.
- load-bearing 산출물(PR)이므로 독립 headless claude로 적대검증 1회를 돌렸고, 지적된 코드 버그 1건·과대인용 2건을 반영했다.

### 배제한 대안 — 무엇을 안 했나 / 왜
- **물려받은 untracked 초안을 그대로 커밋하지 않음**: 중단된 이전 실행의 산출물이라 검증되지 않았고, 실제로 인용 1건이 미확인·수치 1건이 재현 불가·PR #7과 주제 중복이었다.
- **PR #7의 주제(미존재 타깃 게이트를 형제 파일로 검증)를 이 페이지에 포함하지 않음**: PR #7이 이미 소유. 초안에 있던 해당 항목과 grep exit-status 엣지케이스를 삭제했다.
- **`related:`에 `testing-quality-checks-that-cannot-pass`를 넣지 않음**: AGENTS.md 불변식 4(모든 related id는 실재해야 함)를 위반하게 된다 — PR #7이 머지되기 전엔 `main`에 그 페이지가 없다. PR #7 머지 후 양방향 링크 추가가 1줄 후속작업.
- **insight B를 수집 당시 힌트대로 `qa`로 라우팅하지 않음**: `INDEX.md`가 qa를 릴리즈 프로세스로, testing을 테스트/체크 코드 작성으로 규정하므로 체커 코드는 testing.
- **`tests-that-cannot-fail.md`의 `last_verified`를 올리지 않음**: 역방향 링크만 추가했고 그 페이지의 주장을 재검증한 게 아니라서.

### 리뷰어가 볼 곳 — 신뢰성 판단 포인트
- `wiki/testing/quality/spec-artifact-checks.md:62-77` — 파싱 스니펫. 적대검증에서 잡힌 `.strip("|")` 버그를 고친 자리이고, **게시된 스니펫 그대로** 실행해 `|a|b\||` → `['a','b|']`를 확인했다. GitHub `/markdown` API 렌더 결과가 정본.
- `wiki/testing/quality/spec-artifact-checks.md:46-50` — pitest 인용 경계. "어느 체크가 붉어지는가"는 pitest의 메커니즘이 아니라 이 페이지의 convention이라고 명시한 부분.
- `wiki/testing/index.md` + `wiki/testing/quality/tests-that-cannot-fail.md:14` — **열린 PR #7과 같은 줄/같은 표를 건드린다.** 나중에 머지되는 쪽에서 텍스트 충돌이 예상되며, 해소는 "양쪽 id·양쪽 행 모두 유지".
- 큐 회수 처리 — `f997639131d8ec9e`를 페이지 없이 회수한 판단이 맞는지(PR #7이 실제로 그 주제를 담고 있는지) 확인.

> [추정] 표시 항목은 세션에 명시 근거가 없어 사후 재구성한 의도임 — 검증 필요
