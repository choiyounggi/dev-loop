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
  100%". This is the primary support: the docs prescribe _rewriting the code_,
  not adding a test.
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
the "rewrite the code" remedy directly. The comment-correction step is the
session's field observation, recorded as a dated field-measurement line in the
page's Sources rather than attributed to a doc.

**Confidence: verified** (classification + remedy doc-backed; the
comment-correction step carries its field measurement inline).

### 2. Anchor source-text wiring assertions per site instead of counting (`testing`)

**Claim.** A guard that asserts by regex that a call is present, using
`toHaveLength(n)` or `>= n` over match count, stays green when one of the N call
sites is deleted. Bind each occurrence to its own context — a bounded lazy order
anchor `A[\s\S]{0,N}?B`, or a function-body slice — and prove each by deleting
only its own site.

**Sources checked (all opened this session).**

- <https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/>
  — the Block Statement mutator "removes the content of every block statement",
  so deleting one call site is a standard mutation operator, not an ad-hoc edit.
- <https://pitest.org/quickstart/basic_concepts/> — "'Survived' means the
  mutation was not detected by the covering test": the per-site deletion that
  leaves the suite green is exactly this verdict.
- <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Quantifier>
  — `{min,max}` "repeats an atom a minimum of `min` times and a maximum of `max`
  times"; adding `?` makes it non-greedy so "the quantifier will try to match as
  few times as possible". This is what makes the bounded lazy form limit an
  anchor's reach to one site.
- <https://jestjs.io/docs/expect> — `toHaveLength` compares a `.length` value; on
  a match array it is a total and carries no per-site information.
- <https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html>
  — the refactor cost a source-text guard accepts, which is why the page scopes
  it to wiring and routes behavior coverage elsewhere.

**How verified.** The "a lower bound survives deleting one of N" property is
arithmetic and is stated as such. The mutation-operator and regex-semantics
claims are doc-quoted. The concrete red/green pair (count assertion green vs
anchored assertion red on the same mutant, comment-only control green) is the
session's field measurement, dated in the page's Sources.

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
and assert zero warning lines naming the file under test.

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
