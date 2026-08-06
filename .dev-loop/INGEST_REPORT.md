# Knowledge flush — 3 insight(s)

Drained the 3 pending rows in `~/.dev-loop/queue/` (session files `5d6b4056`,
`cea5f63a`, `ef805210`; the other 10 queue files were already empty). All three
carried `domain: testing`. None was dropped and none is left `unverified`.

Every URL cited below and on the pages was opened in this session — no citation
is carried over on trust. Three new pages, four existing pages merged into, no
new category.

## Verified best-practice

**1. A value-preserving literal→SSOT refactor cannot be guarded by an output assertion → `verified`.**
Claim: when the config value renders byte-identical to the literal you removed,
every assertion on that output passes on the reverted-literal version too, so the
regression test must substitute the constant with a sentinel instead.
Verification — the mechanism is the documented *equivalent-mutant* condition:
[Stryker](https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/)
states there is "no definitive way for Stryker to find and ignore them" and that
"the only solution is by finding these by hand", and
[PIT](https://pitest.org/quickstart/basic_concepts/) defines the class as a mutant
whose result "behaves in exactly the same way as the original". A change that
provably cannot be distinguished by observing output is exactly what a
value-preserving refactor is, which is why the natural assertion is vacuous.
Research changed the candidate's directive in two places rather than transcribing
it: (a) the raw insight said `try/finally` to restore the constant —
[pytest](https://docs.pytest.org/en/stable/how-to/monkeypatch.html) documents that
monkeypatch modifications "will be undone after the requesting test function or
fixture has finished" and that `monkeypatch.context()` applies patches "only in a
specific scope", so the page directs the runner's scoped patcher (it covers exit
paths a `finally` block only covers when every path runs through it); (b) added the
patch-site precondition from
[unittest.mock](https://docs.python.org/3/library/unittest.mock.html) — "you must
ensure that you patch the name used by the system under test" — because a module
that copied the constant into a local at import time never reads the substitution
and the test would report green while measuring nothing.
Session evidence recorded on the page: `"DB ×%s" % E.DB_MULT` under the shipped
config renders `DB ×1.3`, i.e. the exact literal being removed (computed before the
test was written); only the sentinel form reddened on the restored-literal version.

**2. A composite return's unread fields are unguarded, and cross-field invariants need their own assertion → `verified`.**
Claim: diff the returned field list against the fields assertions mention, confirm
each absence with a per-field mutation, then assert the relations binding the
fields (`lo ≤ point ≤ hi`, parts == total) across the input grid.
Verification — the "assert relations between outputs rather than each expected
output" step is metamorphic testing:
[arXiv:2211.12003](https://arxiv.org/abs/2211.12003) (Alzahrani, Spichkova,
Harland, *Application of property-based testing tools for metamorphic testing*)
states "The core concept in MT is metamorphic relations (MRs) which provide formal
specification of the system under test". The grid/generated-input half is
property-based testing as its maintainers define it
([hypothesis.works](https://hypothesis.works/articles/what-is-property-based-testing/)):
tests "such that, when these tests are fuzzed, failures in the test reveal problems
with the system under test that could not have been revealed by direct fuzzing".
Reading a survived per-field mutation as an unguarded field is PIT's own
attribution model (a kill belongs to the covering test; **No coverage** is a state
distinct from **Survived**) plus Stryker's
[RIP model](https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/).
Honest limit: I tried to source a definitional "property/invariant" quote from
Hypothesis's own `readthedocs` quickstart and the page does not contain one, so the
page cites the maintainers' article instead of a fabricated docs quote.
Session evidence on the page: 58 passing assertions over a `lo`/`sp`/`hi` return in
which `lo` and `hi` appeared in none of them; four formula mutations left all 58
green while the no-op control survived (so the harness discriminated); the invariant
over the full discrete grid found 13 combinations with `sp > hi`.

**3. A previously published artifact needs its generation dated and a row-level diff before it is a baseline → `verified`.**
Claim: matching aggregates do not establish matching rows — summation is not
injective, and a row the aggregate already excludes (rollup parent, cancelled
record) can differ freely while the total is unchanged. Date the artifact's
generation from schema fields, and rebuild the before side by reverting only the
change under measurement when the generation differs.
Verification — the generation/stamping directive is
[SLSA v1.0 provenance](https://slsa.dev/spec/v1.0/provenance): provenance is "the
verifiable information about software artifacts describing where, when and how
something was produced", recorded so consumers "can verify that the artifact was
built according to expectations", and a build records "the specific git commit that
the URI resolved to as a dependency" — the field a data artifact needs for the same
reason. The approved-snapshot edge case is
[Jest](https://jestjs.io/docs/snapshot-testing) verbatim: "we would need to fix the
bug before re-generating snapshots to avoid recording snapshots of the buggy
behavior", with snapshots committed and reviewed "as you would any other type of
test or code in your project". The golden-master naming caution comes from a
practitioner blog
([octopusinvitro](http://octopusinvitro.gitlab.io/blog/code-and-tech/approval-testing):
"'Golden Master' is not a great name for the snapshot, as it implies that it will
never change, and this is not always true") — flagged here as a blog, not a primary
spec, and used on the page only for that framing. The arithmetic core (equal sums
do not imply equal multisets) is definitional.
Session evidence on the page: `estimated.json` counted-SP total 211.48 matched HEAD
exactly, while the row diff found NEWRTB-2182 differing (분석조사/0.19 vs
인프라/0.56); the file predated a classifier lookbehind change, its `dead` field
being `None` (current code always populates it) dated the generation, and the issue
was a rollup parent excluded from the counted total — which is why the totals agreed
while a row did not.

## Existing-layer check

Pages read: testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, testing-quality-harness-reverse-controls, testing-quality-differential-run-agreement, testing-quality-behavior-not-implementation, testing-quality-guard-shape-vs-consequence

Read in full: the first five. `guard-shape-vs-consequence` was read as its PR #47
hunks plus its index line (partial — stated rather than implied). Screened by their
`load when` lines in `wiki/testing/index.md` without opening the body, having found
no trigger overlap: completion-predicates, injected-clock-duration-assertions,
write-path-assertions, checks-that-cannot-pass, spec-artifact-checks,
schema-additions-under-a-golden-gate. I also read `wiki/qa/index.md` end to end to
test whether insight 3 belonged in `qa` rather than `testing` (see Routing).

**Overlaps found, and merge-vs-create.** `tests-that-cannot-fail` owns the general
rule all three insights descend from ("a test proves something only if it can
fail"), but its trigger is retrospective — reviewing an always-green suite. All
three candidates trigger at authoring time on a specific shape. The house already
resolves this shape as *dedicated page + pointer row* (`write-path-assertions`,
`injected-clock-duration-assertions`, `schema-additions-under-a-golden-gate` are all
narrower cases of the same page, each linked from its Edge cases), so I followed
that precedent rather than growing a page already at 105 body lines. Merged instead
of duplicated: `tests-that-cannot-fail` +3 Edge rows, `minimum-case-set` +1 Edge row
(its "assert an observable outcome" is underspecified when the outcome is a
composite — the fields *and* their invariants), `differential-run-agreement` +1 Edge
row (its subject is two live runs; a stale artifact as one side is the adjacent
case).

**Conflict found and resolved in place, not overwritten.**
`behavior-not-implementation` step 2 asserts the invariant "a refactor that
preserves behavior keeps every test green", which pulls directly against insight 1's
test — one that goes red when someone re-inlines a literal, a change with identical
output. Rather than let two pages disagree, I added a condition-dependent Edge row
to *both*: configurability is itself behavior, so the assertion runs through the
config seam an operator controls (not a private field), and re-inlining removes an
observable capability — therefore it is not behavior-preserving and step 2's
invariant is intact. That page's `load when` line and `last_verified` were updated
for the new use case; its step 2 text was left exactly as it was.

**Related links added both ways** between the three new pages and
`tests-that-cannot-fail`, `harness-reverse-controls`, `minimum-case-set`,
`differential-run-agreement`, `behavior-not-implementation`, plus one-way references
to `checks-that-cannot-pass`, `write-path-assertions` and
`backend-common-change-impact-call-site-enumeration`. Verified programmatically:
every `related:` id and inline `[page-id]` reference **repo-wide** resolves to an
existing page, all three new pages are listed in `wiki/testing/index.md`, every
touched page's body is under the 120-line limit (max 105), the template's required
sections and frontmatter keys are present, and no banned vague qualifier survives in
the new pages (one "usually" was caught in a directive sentence and rewritten as the
condition that decides it). The checker was itself controlled: injecting a bogus
`related:` id and a banned qualifier made it report both, and it returned to PASS
after restore — so its green is discriminating rather than vacuous.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open` → **#47**
(`knowledge/dch0202-20260806-130040`, label `dev-loop:knowledge`) and #48
(`feat/tmux-coordinator-gaps`, code not wiki). I fetched #47's head and diffed
`origin/main...origin/knowledge/dch0202-20260806-130040 -- wiki/` in full.

| Candidate | Verdict | Basis |
|---|---|---|
| 1. value-preserving refactor assertions | **new** | #47's only `tests-that-cannot-fail` change is a bats/bash-3.2 `[[ ]]` row plus three sources; no overlap of trigger or directive |
| 2. unasserted return fields | **new** | #47 touches no page about return-value coverage or invariants |
| 3. stale artifact baselines | **new** | #47 touches no page about baselines, snapshots, or impact measurement |

Textual adjacency handled rather than ignored: #47 also edits
`wiki/testing/quality/tests-that-cannot-fail.md` and `wiki/testing/index.md`, the two
files this flush edits too. My edits were placed away from its hunks (Edge-cases
table and the `related:` line; three *appended* index rows below the last row it
touches), and where we both bump `last_verified` on `tests-that-cannot-fail` I set
the identical value it sets (`2026-08-06`, today) so the two branches converge
instead of conflicting. Whichever merges second should still be re-read at merge
time — the claim here is that no hunk overlaps, not that git is guaranteed silent.

## Routing decision

`INDEX.md` routes all three to **testing** ("writing or structuring automated
tests: level choice, cases/assertions…"), and within it to the existing
**quality** category. No new category: quality already holds the
"is this assertion capable of failing / may I cite this verdict" family
(`tests-that-cannot-fail`, `harness-reverse-controls`, `differential-run-agreement`,
`spec-artifact-checks`), which is precisely what all three are.

| Insight | Target | Page |
|---|---|---|
| 1 | `testing/quality` (new page) | `value-preserving-refactor-assertions.md` — `testing-quality-value-preserving-refactor-assertions` |
| 2 | `testing/quality` (new page) | `unasserted-return-fields.md` — `testing-quality-unasserted-return-fields` |
| 3 | `testing/quality` (new page) | `stale-artifact-baselines.md` — `testing-quality-stale-artifact-baselines` |

Rejected alternatives, with the reason each was rejected:
- **Insight 2 → merge into `minimum-case-set`**: that page selects cases over the
  *input* space (normal/error/boundary per behavior); insight 2 is coverage of the
  *output* shape and the relations inside it. Distinct axis, so it became a page and
  the two are cross-linked — the same split the house already made for
  `write-path-assertions`.
- **Insight 3 → `qa` domain**: I read `wiki/qa/index.md` in full. `qa` owns
  release-process quality (gates, regression scope, deliverable documents) and
  explicitly sends automated-test-code concerns to `testing/`. Insight 3 is about
  whether a comparison is valid evidence, which is what `testing/quality` already
  hosts for non-test-code artifacts (`differential-run-agreement`,
  `harness-reverse-controls` govern reports and PR bodies, not only suites). Routed
  to `testing/quality` for that precedent, with a `related:` link to
  `qa-deliverables-generated-artifacts-as-deliverable-source`.
- **All three → Edge rows on `tests-that-cannot-fail`**: rejected on the page's own
  constraint. It is at 105 body lines against a 120 limit and #47 adds to it; three
  full cases would push it over and bury three distinct triggers inside a page whose
  routing line is retrospective auditing.
