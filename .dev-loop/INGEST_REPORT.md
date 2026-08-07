# Knowledge flush — 4 insights

Queue drained: 4 pending candidates across 3 session files
(`9dab7c31…` ×2, `a26ea793…` ×1, `df9561a2…` ×1). All 4 ingested; 0 dropped.

## Verified best-practice

### 1. Classify a surviving mutant before writing a test for it (`testing`)

**Claim.** When a mutant survives, decide whether it is a missing test, an
_equivalent_ mutant, or an uncovered line before changing anything. When it is
equivalent, the branch it mutates is redundant — delete it and correct the
comment that justified it, rather than adding a test.

**Sources checked (all opened this session).**

- <https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/>
  — "There is no definitive way for Stryker to find and ignore them"; the
  documented remedy is "by finding these by hand, which is time consuming and
  try to rewrite the code so it won't occur, or accept that you won't make
  100%". This is the primary support, and both halves are load-bearing: the
  docs name rewriting the code and accepting a classified survivor as the two
  outcomes — neither of them is "add a test for it".
- <https://pitest.org/quickstart/basic_concepts/> — "Not all mutations will
  behave differently than the unmutated class. These mutants are referred to as
  **equivalent mutations**"; "The resulting mutant behaves in exactly the same
  way as the original"; and the two distinct verdicts "Survived: The mutation
  was not detected by the covering test" vs "No coverage: The same as Survived
  except there were no tests that exercised the line of code where the mutation
  was created" — which is the three-way split the page's step-1 table encodes.
- <https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/>
  — the mutant state set and `detected / valid` scoring.
- <https://testing.googleblog.com/2021/04/mutation-testing.html> — inserting
  faults and requiring failure is the measurement.

**How verified.** The mutation-testing docs substantiate the classification and
both remedies directly. The comment-correction step is the session's field
observation, recorded as a dated field-measurement line in the page's Sources
rather than attributed to a doc. After the adversarial pass, the page no longer
lets one hand-run input establish equivalence: the same Stryker sentence that
supports the remedy ("no definitive way … to find and ignore them") is what
makes a domain argument the required evidence for deleting a branch.

**Confidence: verified** (classification + both remedies doc-backed; the
comment-correction step carries its field measurement inline).

### 2. Anchor source-text wiring assertions per site instead of counting (`testing`)

**Claim.** A guard that asserts by regex that a call is present, using
`toHaveLength(n)` or `>= n` over match count, stays green when one of the N call
sites is deleted. Bind each occurrence to its own context — a bounded order
anchor `A[\s\S]{0,N}B` whose anchor occurs **exactly once** in the file, or a
function-body slice — and prove each by deleting only its own site.

**Sources checked (all opened this session).**

- <https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/>
  — the Block Statement mutator "removes the content of every block statement".
  Corrected after the adversarial pass: this empties a whole block rather than
  removing one call, so the per-site deletion is a **hand-seeded** mutation and
  the page now says so instead of claiming tool support it does not have.
- <https://pitest.org/quickstart/basic_concepts/> — "'Survived' means the
  mutation was not detected by the covering test": the per-site deletion that
  leaves the suite green is exactly this verdict.
- <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Quantifier>
  — documents `{min,max}` as bounded repetition and `?` as the non-greedy form
  that "will try to match as few times as possible". Corrected after the
  adversarial pass: an earlier draft presented MDN's `{min,max}` **table** as a
  prose quotation, and claimed the lazy form limits the anchor's reach. Neither
  holds — see the Node measurement below.
- <https://jestjs.io/docs/expect> — `toHaveLength` compares a `.length` value; on
  a match array it is a total and carries no per-site information.
- <https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html>
  — cited for the change-detector category (the refactor cost a source-text
  guard accepts), **without a quotation**: the sentence an earlier draft
  attributed to this article is a reader comment, and the body was not
  retrievable in full. See the cross-check table, row 1.

**How verified.** The "a lower bound survives deleting one of N" property is
arithmetic and is stated as such. The regex mechanism was **measured**, not
assumed: in Node, `/ANCHOR\([\s\S]{0,20}CALL\(/` and its lazy variant return
identical verdicts on four inputs (in range, call-before-anchor only, beyond the
bound, and call on both sides of the anchor), so the bound plus a once-occurring
anchor is what constrains the match. The concrete red/green pair (count
assertion green vs anchored assertion red on the same mutant, comment-only
control green) is the session's field measurement, dated in the page's Sources.

**Confidence: verified.**

### 3. `data === undefined` is not "loading" in TanStack Query (`frontend`)

**Claim.** A component contract of `data | undefined` collapses two orthogonal
axes. A disabled (`enabled: false`) or offline-paused query is `status: 'pending'`
with `isLoading === false` and `isError === false` and `data === undefined`, so
"undefined means loading" renders a spinner no fetch will resolve.

**Sources checked (all opened this session).**

- <https://tanstack.com/query/latest/docs/framework/react/guides/queries> —
  "The `status` gives information about the `data`: Do we have any or not? The
  `fetchStatus` gives information about the `queryFn`: Is it running or not?";
  "Background refetches and stale-while-revalidate logic make all combinations
  for `status` and `fetchStatus` possible"; the value definitions including
  `paused`: "The query wanted to fetch, but it is paused".
- <https://tanstack.com/query/latest/docs/framework/react/reference/useQuery> —
  `isLoading` "Is `true` whenever the first fetch for a query is in-flight. Is
  the same as `isFetching && isPending`"; `data` "Defaults to `undefined`".
- <https://tanstack.com/query/latest/docs/framework/react/guides/disabling-queries>
  — a disabled query with no cached data is "status === 'pending' and
  fetchStatus === 'idle'"; "Lazy queries will be in `status: 'pending'` right
  from the start because `pending` means that there is no data yet … you likely
  cannot use this flag to show a loading spinner"; the `skipToken`/`refetch`
  incompatibility quoted in the page's edge table.
- <https://tanstack.com/query/latest/docs/framework/react/guides/network-mode> —
  "Queries can be in `state: 'pending'`, but `fetchStatus: 'paused'` if they are
  mounting for the first time, and you have no network connection"; "it might
  not be enough to check for `pending` state to show a loading spinner".

**How verified.** Docs above, plus a local source check of the shipped build:
`@tanstack/query-core@5.100.14`, `build/modern/queryObserver.js` line 308
`const isPending = status === "pending"`, line 310
`const isLoading = isPending && isFetching`, line 332
`isPaused: newState.fetchStatus === "paused"`. The derivation in the shipped
code matches the reference, so `pending` + non-`fetching` yields
`isLoading === false` with `data === undefined`.

**Confidence: verified.**

### 4. Prove a Python `encoding=` fix with `EncodingWarning`, not byte round-trip (`backend/python`)

**Claim.** On a UTF-8 locale, removing `encoding="utf-8"` from `open()` produces
byte-identical output, so a round-trip regression test is green on the defect.
Run the real entry point under `-X warn_default_encoding -W always::EncodingWarning`
and assert zero warning lines naming the file under test. Scope correction from
the adversarial pass: this replaces the round-trip only for an *omitted*
argument — `EncodingWarning` never fires on an explicitly wrong value, so the
page keeps a value assertion (run under a non-UTF-8 locale) for the encodings
you set on purpose.

**Sources checked (all opened this session).**

- <https://peps.python.org/pep-0597/> — `EncodingWarning` "is emitted when the
  `encoding` argument to `open()` is omitted and the default locale-specific
  encoding is used"; "The `-X warn_default_encoding` option and the
  `PYTHONWARNDEFAULTENCODING` environment variable are added. They are used to
  enable `EncodingWarning`"; "Developers using macOS or Linux may forget that
  the default encoding is not always UTF-8".
- <https://peps.python.org/pep-0686/> — UTF-8 mode by default targets Python
  3.15; "many Python developers using Unix forget that the default encoding is
  platform dependent … Inconsistent default encoding causes many bugs"; "this
  change mostly affects Windows users". This is the mechanism for "invisible on
  your machine".
- <https://docs.python.org/3/library/functions.html> — `open()`: "The default
  encoding is platform dependent (whatever `locale.getencoding()` returns)";
  "For reading and writing raw bytes use binary mode and leave _encoding_
  unspecified".

**How verified.** Reproduced locally this session (CPython 3.14.6, macOS,
`locale.getpreferredencoding(False) == 'UTF-8'`): a script containing one
`open(p, "w")` and one `open(p, "w", encoding="utf-8")` produced byte-identical
output — the round-trip assertion cannot distinguish them. Running
`python3 -X warn_default_encoding -W always::EncodingWarning script.py out.txt`
emitted exactly one line, naming the unencoded call by file and line number; the
same run without the flag emitted nothing (which is why the page requires proving
the harness reddens on a deliberately unencoded `open()`).

**Confidence: verified.**

## Adversarial cross-check (run before this PR was opened)

Cross-Check: independent `claude` CLI (headless, `--permission-mode plan`) reviewed the wiki diff for fabricated citations, overreach, internal contradiction, bare prohibitions, and vague qualifiers — it returned 18 findings (4 critical, 9 warning, 5 info); every critical was re-verified by me against the primary source or by measurement, and all 18 were fixed before this PR was created.

The four criticals were real, and two of them were citation defects:

| # | Finding | Verified how | Fix |
|---|---|---|---|
| 1 | `source-text-wiring-assertions` quoted "you cannot safely refactor code if you know you need to adapt the tests afterwards…" as the Google Testing Blog article's own sentence | Re-fetched the page: the sentence is from a **reader comment dated 2015-02-04**, and its wording differs ("refactor **stuff**", "know **for sure**"). The article body was not retrievable in full, so no sentence from it is quotable | Quotation removed; the URL is now cited for the change-detector *category* only, with a note that nothing is quoted from it. **The same fabricated quote exists in the already-merged `testing-quality-guard-shape-vs-consequence`** — I inherited it from there rather than opening the source. That bullet is corrected in this PR with the correction stated inline |
| 2 | Step 4 claimed deleting one call site is Stryker's Block Statement mutator | The doc says it "removes the content of every block statement" — it empties a whole block, not one call | Reworded: the per-site deletion is a hand-seeded mutation, and the doc is cited for why tools do not generate it |
| 3 | The order-anchor rationale claimed a lazy quantifier limits the anchor's reach and that the call could "not [appear] anywhere else in the file" | Measured in Node: `{0,20}` and `{0,20}?` return identical verdicts on all four inputs, and a call appearing both before and after the anchor still matches | Rewritten around what actually constrains the match: the bound `N` **and an anchor that occurs exactly once**. Added an occurrence-count step, a "no unique anchor" row, and the measurement as a source. A separate MDN pseudo-quote (a table rendered as prose) was also removed |
| 4 | `surviving-mutant-equivalence-triage` authorised **deleting production code** on the basis of one hand-run input, while its own cited source says "There is no definitive way for Stryker to find and ignore them" | Read against the cited Stryker page | Step 1 now starts from the tool's `No coverage` verdict; step 2 requires a stated argument over the branch's whole input domain and routes to the missing-test row when that argument cannot be written; step 5 splits a moved pass count into behavior-test vs implementation-test causes |

Warnings fixed: selective half-quote of the Stryker remedy; the universal claim that any change in pass count means misclassification; the missing `success` + `paused` cell (with a `status: 'error'` row that had collapsed the fetch axis into `any`, contradicting the page's own premise) in a table that step 5 makes a coverage contract; `applies_to: general` on a page whose every field name is TanStack-specific (now `[react, tanstack-query]`, with an edge row for single-axis caches); the "keep the flag on the test invocation only" step contradicting the next step's "enable it repo-wide"; and the claim that a round-trip test "can only fail on a machine you are not testing on" — plus the gap it hid, that `EncodingWarning` fires only on an *omitted* argument and says nothing about an explicitly wrong one (new step 6 keeps a value assertion for those).

Info fixed: banned qualifiers "usually", "commonly", "generally" removed from directive sentences; a "sixth combination" ordinal that did not match its own table.

Re-checked after the fixes: 183 pages / 0 duplicate ids, 0 unresolved `[page-id]` refs in the new pages, 0 broken index links, all four sections present in each page, bodies 83–94 lines (limit 120).

## Existing-layer check

Routed each candidate via `INDEX.md` → domain `index.md`, then read every page
whose "load when" line overlapped.

Pages read: testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, testing-quality-behavior-not-implementation, testing-quality-guard-shape-vs-consequence, frontend-data-fetching-async-ui-states, frontend-state-client-vs-server-state, frontend-data-fetching-race-conditions, platforms-environment-timezone-and-locale, backend-python-language-mutable-state-traps, backend-python-language-bytecode-cache-staleness

**Overlaps found and what was done.**

| Existing page                                                                     | Overlap                                                                                                                                                                                                                                               | Action                                                                                                                                                    |
| --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `testing-quality-tests-that-cannot-fail`                                          | Its whole-suite edge row read _every_ surviving mutant in changed code as "missing or defective tests" — the exact naive reading insight 1 corrects. Page is already ~100 body lines, so appending a triage procedure would break the ≤120 rule       | **Refined, not overwritten.** The row now routes surviving mutants through classification first. New page created for the procedure; `related:` both ways |
| `testing-quality-harness-reverse-controls`                                        | Already covers equivalent mutants — but as a _deliberately constructed_ no-op control whose correct verdict is "survived". Different trigger (building/citing a harness vs triaging one live mutant)                                                  | Kept separate; `related:` both ways, and the new page routes uniform-verdict cases to it                                                                  |
| `testing-quality-behavior-not-implementation`                                     | Source-text assertions are implementation-coupled, which this page governs                                                                                                                                                                            | Kept as the upstream decision ("should you assert on source at all"); insight 2's page opens by routing there, and links back                             |
| `testing-quality-guard-shape-vs-consequence`                                      | Also about scanning-guard design, but its trigger is a repo-wide guard over _shipped artifacts_ going red on a legitimate one — the opposite failure (false positive) from insight 2 (false negative)                                                 | Kept separate; `related:` both ways                                                                                                                       |
| `frontend-data-fetching-async-ui-states`                                          | Owns the loading/error/empty/data design and mentions `isLoading` vs `isFetching` in one line. It has no coverage of the status × fetchStatus product, and its four-state model has no cell for disabled/paused                                       | **Merged where it fit** (+1 edge row routing the disabled/paused case) + new page for the mechanism; `related:` both ways                                 |
| `frontend-state-client-vs-server-state`, `frontend-data-fetching-race-conditions` | Grepped for `isPending`/`fetchStatus`/`isLoading`/`isFetching`: zero hits. No overlap                                                                                                                                                                 | No change                                                                                                                                                 |
| `platforms-environment-timezone-and-locale`                                       | Owns locale as a hidden input generally, and pins `TZ` for tests. Says nothing about text-encoding defaults or `EncodingWarning` (repo-wide grep for `EncodingWarning`/`warn_default_encoding`/`getpreferredencoding`/`cp949`: 0 hits before this PR) | New page in `backend/python/language`; `related:` both ways, new page routes upward for the general case                                                  |
| `backend-python-language-mutable-state-traps`                                     | Same category, unrelated trigger (state leaking across calls)                                                                                                                                                                                         | No change                                                                                                                                                 |
| `backend-python-language-bytecode-cache-staleness`                                | Adjacent: it governs mutation harnesses that rewrite `.py` files, which insight 4's harness does                                                                                                                                                      | `related:` both ways; new page carries an edge row routing to it                                                                                          |

**Conflicts flagged:** none. The one directive that needed adjusting
(`tests-that-cannot-fail`'s whole-suite row) was incomplete rather than
contradictory, so it was refined in place and routed onward, per
`wiki-ingest` step 4.

**Health checks run on the checkout after the edits:** 183 pages, 0 duplicate
ids; 0 unresolved `[page-id]` references introduced (the 3 the scan reports are
pre-existing false positives — a regex character class in two testing pages and
the literal `[openai-compatible]` in an LLM page); 0 broken relative links from
any index; all 4 new pages 75–80 body lines (limit 120).

## Open-PR check

Listed with
`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`.
Four open heads:

| PR  | Head                                                                                                     | Wiki paths touched                                                                                                                                                                                                 | Overlap with this batch                                                                                                                                                                                                                                                                                                                                                                                          |
| --- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| #51 | `knowledge/dch0202-20260806-183029`                                                                      | backend/{api-design,change-impact}, backend/index, debugging/hypothesis-testing, infrastructure/agent-orchestration ×2, qa/deliverables + qa/index, security/data/commit-identity-in-public-repos + security/index | None — no testing/quality, frontend, or python/language page in common                                                                                                                                                                                                                                                                                                                                           |
| #50 | `knowledge/dch0202-20260806-172420`                                                                      | testing/index, testing/quality/policy-at-several-return-sites (new), backend/change-impact/call-site-enumeration                                                                                                   | **Nearest neighbour — examined in full.** Same underlying defect shape ("one of N sites silently stops being covered"), different subject: #50 covers _behavioral_ tests, one per success-return site of a handler, proven by reverting one site. Insight 2 covers _source-text_ regex guards where no behavioral seam is reachable, and the count-vs-anchor pattern choice. Neither carries the other's content |
| #49 | `knowledge/dch0202-rsquare-20260806-142309` (head ref deleted on remote; diffed via `refs/pull/49/head`) | testing/index + testing/quality ×8 (new: stale-artifact-baselines, unasserted-return-fields, value-preserving-refactor-assertions)                                                                                 | Same category, no shared trigger: baselines/return-field assertions/refactor-value assertions vs mutant triage and source-text wiring                                                                                                                                                                                                                                                                            |
| #47 | `knowledge/dch0202-20260806-130040`                                                                      | infrastructure/agent-orchestration, platforms/filesystems, testing/index, testing/quality/{guard-shape-vs-consequence, tests-that-cannot-fail} amendments                                                          | Touches two of the pages I amend. My edits are additive and in different regions (a `related:` id and one edge-row rewording); noted as a possible textual conflict for the owner to resolve at merge, not a content duplicate                                                                                                                                                                                   |

**Per-candidate verdict:** 1 = **new**, 2 = **new**, 3 = **new**, 4 = **new**.
No candidate was folded or dropped — no open PR carries any of these four
insights.

Note for the owner: #50, #49 and this PR all add pages under
`wiki/testing/quality` and all append a row to `wiki/testing/index.md`, so
whichever merges second will need the index rows rebased. The page files
themselves do not collide.

## Routing decision

| #   | Insight                          | Target                                                                                                                                                                     | New category?                                                                      |
| --- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| 1   | Surviving-mutant triage          | `testing / quality` → `testing-quality-surviving-mutant-equivalence-triage` (new page)                                                                                     | No — `quality` already owns assertion strength and mutation verification           |
| 2   | Source-text wiring assertions    | `testing / quality` → `testing-quality-source-text-wiring-assertions` (new page)                                                                                           | No                                                                                 |
| 3   | Query state vs fetch state       | `frontend / data-fetching` → `frontend-data-fetching-query-state-vs-fetch-state` (new page) + 1 edge row and a `related:` link on `frontend-data-fetching-async-ui-states` | No — `data-fetching` already owns in-UI fetching states                            |
| 4   | Locale-default text I/O encoding | `backend / python / language` → `backend-python-language-default-encoding-in-text-io` (new page)                                                                           | No — `python/language` is described in `INDEX.md` as the home for "language traps" |

**Why insight 4 went to `backend` and not `testing` or `platforms`.** The
directive changes Python source (`encoding=` at every text-mode call site) and
its test is a property of that language's tooling, so the routing protocol's
"own the artifact you will change" rule puts it in `backend/python`. It routes
upward to `platforms-environment-timezone-and-locale` for the general
hidden-environment-input case and to `testing-quality-tests-that-cannot-fail`
for proving the harness reddens.

**Plumbing updated:** `wiki/testing/index.md` (+2 rows),
`wiki/frontend/index.md` (+1 row), `wiki/backend/python/index.md` (+1 row),
`log.md` (+1 ingest entry). `INDEX.md` unchanged — no new domain, and every
target domain's "route here when" line already covers these cases.

## Decision Log (AI 생성)

### 의도 — 무엇을 / 왜

- `~/.dev-loop/queue` 에 쌓인 pending 후보 4건을 검증 통과시켜 wiki 에 편입하는 것이 목적. 각 후보를 1차 출처(공식 문서)로 확인하고, 2건은 로컬에서 재현(CPython 3.14.6 EncodingWarning, `@tanstack/query-core@5.100.14` queryObserver.js)해 `confidence: verified` 근거를 만들었다.
- 4건 모두 **신규 페이지**로 라우팅했다. merge-before-create 를 먼저 적용했으나, 가장 가까운 기존 페이지(`tests-that-cannot-fail`)가 이미 ~100 body line 이라 절차를 덧붙이면 ≤120 규칙을 깬다. 대신 그 페이지의 "surviving mutant = missing test" edge 행을 **분류 우선**으로 정정하고 새 페이지로 라우팅하도록 고쳤다.
- PR 직전 독립 적대검증을 1회 돌렸고, 18건 전건을 반영했다. 특히 위조 인용 1건은 **기존 wiki 페이지에서 물려받은 것**이라 그 원본(`guard-shape-vs-consequence`)까지 같은 PR 에서 정정했다 — 알면서 거짓 귀속을 남길 수 없다고 판단.

### 배제한 대안 — 무엇을 안 했나 / 왜

- **열려 있는 PR #50 에 fold 하지 않음.** #50 은 한 핸들러의 여러 success-return 지점을 *행위 테스트*로 덮는 내용이고, 이번 insight 2 는 행위 seam 이 없을 때 쓰는 *소스 텍스트* 가드의 count↔anchor 선택이다. 겹치는 것은 결함 형태("N개 중 하나가 조용히 빠짐")이지 기법이 아니라 별도 페이지로 두고 보고서에 근거를 남겼다.
- **insight 4 를 `testing/` 이 아니라 `backend/python/language/` 로.** 지시가 바꾸는 산출물이 Python 소스이고 판별자가 그 언어 도구의 성질이라, 라우팅 프로토콜의 "바꿀 artifact 를 소유한 도메인" 규칙을 따랐다.
- **round-trip 단정을 전면 금지하지 않음.** 적대검증이 짚은 대로 `EncodingWarning` 은 *인자 누락*만 잡는다 — 명시했지만 틀린 값(`encoding="latin-1"`)은 값 단정이 아니면 아무도 못 잡으므로 둘을 병행하게 했다.
- **merge 하지 않음.** knowledge-flush 는 PR-only 이고 승인은 레포 오너 몫이다.
- **[추정] 커밋 아이덴티티**: skill 지시(ambient git identity 상속)와 직전 flush(PR #49)의 선례에 맞춰 `최영기 <dch0202@rsquare.co.kr>` 로 커밋했다. 이 레포는 public 이고, 마침 열려 있는 PR #51 이 "public 레포에는 forge no-reply 주소를 쓰라"는 페이지를 추가하는 중이라 상충 소지가 있다 — 바꿀지는 작성자 판단.

### 리뷰어가 볼 곳 — 신뢰성 판단 포인트

- `wiki/testing/quality/surviving-mutant-equivalence-triage.md:49` (step 2) — 이 단계가 **운영 코드 분기 삭제**를 승인하는 게이트다. 도메인 논증 요구가 충분한 강도인지 봐 달라.
- `wiki/testing/quality/source-text-wiring-assertions.md:39` (step 2~3) — anchor 유일성 + bound N. 적대검증 전 버전은 lazy quantifier 가 reach 를 제한한다고 **틀리게** 적었다가 실측으로 뒤집힌 자리다.
- `wiki/testing/quality/guard-shape-vs-consequence.md` (Sources 마지막 bullet) — 이번 PR 범위 밖이지만 위조 인용을 정정한 out-of-band 수정. 되돌릴지 판단 필요.
- `wiki/frontend/data-fetching/query-state-vs-fetch-state.md` (step 2 표) — step 5 가 이 표를 테스트 커버리지 계약으로 못박으므로 빠진 셀이 곧 커버리지 구멍이다. 8행이 status × fetchStatus 를 다 덮는지 확인해 달라.
- `wiki/testing/index.md` — #50, #49 도 같은 파일에 행을 추가한다. 두 번째로 머지되는 쪽이 이 행을 rebase 해야 한다(페이지 파일 자체는 충돌 없음).

> [추정] 표시 항목은 세션에 명시 근거가 없어 사후 재구성한 의도임 — 검증 필요
