# Knowledge flush — 3 insight(s)

Queue drained: `~/.dev-loop/queue/0c6a5439-….jsonl` (1 row),
`~/.dev-loop/queue/fb7e7221-….jsonl` (2 rows). All three were harvested
2026-08-04 from the `linkly-t1-spec-notation` and `linkly-t1-repo-policy` repos.

Result: **2 new pages, 1 merge into an existing page, 1 new category.**

| # | Insight (trigger → directive) | Outcome | Confidence |
|---|-------------------------------|---------|------------|
| 1 | Adding a node kind to a format whose only gate mutates a golden example → commit a fixture holding the new kind, one negative per keyword, verify each reddens | **New page** `testing/quality/schema-additions-under-a-golden-gate` | verified |
| 2 | Enumerating call sites before a contract change → enumerate by callee name; a parameter-name search is a partial index | **New page + new category** `backend/common/change-impact/call-site-enumeration` | verified |
| 3 | A fixture helper whose shape depends on a value the test also passes to the SUT → put that value in the helper's signature | **Merged** into `testing/data/test-data-and-isolation` | verified |

---

## Verified best-practice

Every URL below was fetched during this flush; the quotes are from those
fetches, not from memory. Nothing was cited that I did not open.

### Insight 1 — a golden-derived negative corpus cannot reach a newly added schema branch

*Claim under test:* when a format's only gate builds negatives by mutating one
committed golden example, adding a new node kind to the schema produces a green
run that proves nothing about the addition.

| Source checked | What it establishes |
|----------------|---------------------|
| https://json-schema.org/understanding-json-schema/reference/conditionals | The mechanism, verbatim: *"If `if` is invalid, `else` must also be valid (and `then` is ignored)"* — a branch keyed on the new kind is simply **not applied** to an instance that lacks it. So a mutant of a golden without the new kind cannot exercise the new branch. |
| https://json-schema.org/understanding-json-schema/reference/object | Why the new branch also needs constraining before a negative can even exist: *"By default any additional properties are allowed"* and *"By default, the properties defined by the `properties` keyword are not required"*. |
| https://json-schema.org/draft/2020-12/json-schema-core | Sibling applicators *"MUST NOT impact the results of sibling subschemas"*; and *"Unknown keywords SHOULD be treated as annotations"* — a misspelled keyword in a new branch is ignored rather than rejected, a second silent-pass mode. |
| https://pitest.org/quickstart/basic_concepts/ | The same gap has a name in mutation tooling: *"**No coverage**: the same as **Survived** except there were no tests that exercised the line of code where the mutation was created"* — cited so the page tells a reader using PIT/Stryker what the symptom looks like there. |

*Session evidence (kept as a field observation, not as the basis of the
directive):* in `linkly-t1-spec-notation`, `grep -rln "lir.schema\|jsonschema"
impl/tests/` returned 0 of 447 tests, and the only schema gate over `*.lir.json`
was `scripts/validate_ir.py --self-test`, whose three negatives are all
`copy.deepcopy` mutations of `examples/login.lir.json`.

**Confidence: `verified`** — the directive's mechanism is stated in the official
JSON Schema documentation; the incident is corroborating, not load-bearing.

### Insight 2 — enumerate by callee name, not by parameter name

*Claim under test:* a keyword-argument search (`repo_rows=`) is structurally
incapable of finding call sites that pass the same argument positionally.

| Source checked | What it establishes |
|----------------|---------------------|
| https://docs.python.org/3/glossary.html | *positional-or-keyword* — *"specifies an argument that can be passed either positionally or as a keyword argument. **This is the default kind of parameter**"*. The blindness is therefore the default case, not an edge case. |
| https://docs.python.org/3/library/ast.html | `ast.Call`: *"`args` holds a list of the arguments passed by position"*, *"`keywords` holds a list of `keyword` objects representing arguments passed by keyword"* — the two forms live in **separate fields**, so a keyword-name text search reads only one of them. |
| https://peps.python.org/pep-0570/ | The `/` and `*` markers, which is what makes the page's "declare it keyword-only so a stale positional call errors instead of rebinding" edge case actionable. |

*Reproduction run this session* (Python 3.14.6, macOS, no files written — piped
to `python3` on stdin): over four call sites of `verify(...)` of which one passes
`repo_rows=` by keyword, a regex search for `repo_rows\s*=` matches **1** while
an AST pass over `Call` nodes named `verify` finds **4** — 3 sites invisible to
the keyword search. This is the minimal version of the reported incident.

*Session evidence:* recon reported "13 call sites, 7 need editing"; 8 further
seeds passed the value as `verify()`'s 4th positional argument, and the suite the
session had reported green then ran `472 tests / FAILED (failures=11)`.

**Confidence: `verified`** — official language reference plus a reproduction.

### Insight 3 — a fixture factory takes the value the test also passes to the SUT

*Claim under test:* when a fixture helper's shape depends on a value the test
also feeds the system under test, that value belongs in the helper's signature
rather than in a module-level default.

| Source checked | What it establishes |
|----------------|---------------------|
| https://abseil.io/resources/swe-book/html/ch12.html | A test is *complete* when *"its body contains all of the information a reader needs in order to understand how it arrives at its result"*; DAMP over DRY; and, directly on point, that engineers should *"use helper methods with descriptive parameters that make dependencies explicit"* rather than reusing shared constants. |
| https://testing.googleblog.com/2017/01/testing-on-toilet-keep-cause-and-effect.html | Keep the inputs a result depends on visible in the test method rather than in shared setup, so cause and effect is readable without jumping elsewhere. |

*Session evidence:* `rows_for(doc)` seeded from the module constant `PAYLOAD`
while its tests ran payload `{}`; a shape-only migration fixed 1 of 11 failures,
moving the payload into the signature fixed 11 of 11.

**Confidence: `verified`** — both sources are prescriptive on the exact point.

Note: the canonical name for this smell is xUnit Patterns' *Mystery Guest*.
`xunitpatterns.com` is HTTP-only and could not be fetched over HTTPS this
session, so **it is deliberately not cited** — an unfetchable URL is worse than
none, per the ingest rules.

---

## Existing-layer check

Routed via `INDEX.md` → domain `index.md` → every page whose "load when" line
overlapped. Pages read in full before deciding: all six of `testing/quality/`,
`testing/data/test-data-and-isolation`, `testing/index`, `qa/process/regression-scope`,
`qa/index`, `debugging/index`, `backend/index`, `backend/python/index`, plus a
repo-wide search for prior coverage (`grep -rliE "call site|callee|positional
argument|keyword argument"` and a `\bgrep\b` sweep over `wiki/`).

### Insight 1 — nearest neighbours, and why it is not a duplicate

| Page read | Overlap | Decision |
|-----------|---------|----------|
| `testing/quality/spec-artifact-checks` | Closest. Already owns *"one negative control per check, mutating only what that check owns"* and the coverage-vs-validity split. | **Not a merge.** Its trigger is *authoring a check*; this insight's trigger is *evolving the artifact the check validates* — the negatives already exist and are individually sound, yet the corpus as a whole cannot reach the new shape. Per the wiki's one-case-per-page rule this is a new trigger. Linked both ways. |
| `testing/quality/tests-that-cannot-fail` | Owns the break-the-code red-run rule the new page's step 4 depends on. | Referenced inline; `related:` added both ways. |
| `testing/quality/harness-reverse-controls` | Owns the *harness-level* control (can this harness go green). | Complementary, not overlapping: that page asks whether the harness discriminates at all, this one asks whether the fixture corpus reaches a newly added shape. `related:` added both ways. |
| `testing/quality/checks-that-cannot-pass` | Trigger is a check whose **target does not exist yet**. | Distinct — here the target exists and the gate is green. No edit. |
| `qa/document-verification/spec-document-gates` | Release-gate altitude for document deliverables. | Kept as a one-way `related:` from the new page. |

**No conflicts found.** Nothing in the wiki contradicts the new directive.

### Insight 2 — no existing coverage anywhere

The repo-wide search found **zero** pages discussing call-site enumeration,
callee-name search, or positional-vs-keyword arguments as a recon concern. The
single adjacent line is `qa/process/regression-scope`'s edge-case row *"The
change is in code with no test coverage and unclear callers | Trace callers
before scoping"* — which names the need and does not say how. That row now
points at the new page, and `regression-scope` gained the new page in
`related:` (both directions).

Checked and rejected as homes: `debugging/*` (diagnosis of a failure, not
pre-change recon), `backend/python/language/mutable-state-traps` (mutable
defaults and shared state — a different mechanism), `platforms/tools/bsd-vs-gnu-cli`
(grep *flag* portability, not search strategy).

### Insight 3 — merged, not created

`testing/data/test-data-and-isolation` already owns fixture construction and
carries the adjacent rule *"pass explicitly only the fields the test's behavior
depends on"* plus a row for shared **mutable** fixture objects. This insight is
the same trigger with a directive that extends it (a *defaulted* constant, which
is not mutated and so is not covered by the existing row). Merge-before-create
applied — no new page. Added: 1 `Do` row, 1 edge-case row (the symptom is a
lookup miss far from the helper), 1 `Instead of` row, 2 sources, and
`last_verified` bumped to 2026-08-04.

---

## Routing decision

| Insight | Target | Rationale |
|---------|--------|-----------|
| 1 | `testing` / `quality` / **new page** `schema-additions-under-a-golden-gate` | `INDEX.md` routes "writing or structuring automated tests … verifying tests can actually fail" to `testing`; within it, `quality` already holds the five pages about whether a check proves anything. Existing category, no structural change. |
| 3 | `testing` / `data` / **merge** into `test-data-and-isolation` | Same trigger as the page's own ("tests need fixture data and you are choosing how to create it"); directive extends step 1. |
| 2 | `backend` / `common` / **NEW category `change-impact`** / `call-site-enumeration` | See below. |

### New category: `backend/common/change-impact/`

**Why `backend`:** `AGENTS.md`'s routing protocol resolves a multi-domain match
by "the domain that owns **the artifact you will change**" — here, application
code. **Why `common`:** the directive is language-agnostic (any language with
optional or positional arguments; in a language with no keyword arguments at all
the parameter-name search returns nothing whatsoever). The Python mechanics are
cited as the mechanism, not as the scope.

**Why not an existing category** — all eleven `backend/common` categories were
re-checked by name before creating a new one:

- `api-design` is the only near miss, and all three of its pages are HTTP-shaped
  (status codes, endpoint idempotency, list-endpoint pagination). Its "load when"
  lines are written about endpoints; filing an in-process function-signature
  concern there would make the category's routing lines contradict its contents,
  which invariant 1 forbids.
- `reliability`, `caching`, `jobs`, `errors`, `auth`, `orm`, `concurrency`,
  `llm`, `integrations`, `storage` — all runtime-behaviour categories; none
  covers a design-time change-impact question under any other name.

`change-impact` is the noun for the concern, leaves room for sibling pages
(schema/event-contract consumers, deprecation windows), and is registered in
`wiki/backend/index.md` plus the root `INDEX.md` backend row.

### Plumbing

- `wiki/testing/index.md` — new `quality` row with a use-case-enumerating "load when" line.
- `wiki/backend/index.md` — new `change-impact` section + subtree summary row updated.
- `INDEX.md` — backend row's `common/` concern list updated.
- `log.md` — `## [2026-08-04] ingest | …` entry appended.
- `related:` added both ways for all four adjacent pages.

### Invariants verified mechanically (not by eye)

Ran over all **141** pages after the edits:

- every page is listed in an ancestor `index.md` → **0 unlisted**
- every `related:` id and inline `[page-id]` reference resolves → **0 broken**
- no page exceeds 120 body lines → **0 over**
- banned vague qualifiers (`usually`, `consider`, `might want to`, `generally`,
  `as appropriate`) in the three touched pages → **0 hits**
- every "don't"-shaped statement in the new pages is descriptive prose, not a
  bare prohibition; anti-patterns appear only in `Instead of` tables, each paired
  with its replacement.
