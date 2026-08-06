# Knowledge flush — 3 insight(s)

Drained the 3 pending rows in `~/.dev-loop/queue/` (session files `5d6b4056`,
`cea5f63a`, `ef805210`; the other 10 queue files were already empty). All three
carried `domain: testing`. None was dropped.

Cross-Check: independent adversarial review (claude CLI headless, `--permission-mode plan`) returned BLOCK on the first commit with 17 findings — 2 critical, 9 major, 6 minor; all were accepted and fixed in the second commit, the most serious being a source miscitation inherited from an existing page and two `verified` confidences downgraded to `field-tested`.

**Confidence after review:** `unasserted-return-fields` = `verified`;
`value-preserving-refactor-assertions` and `stale-artifact-baselines` =
`field-tested`. The first commit marked all three `verified`; the review showed
that for two of them the cited docs support only the background mechanism, not the
central directive, so they were downgraded rather than defended.

## Verified best-practice

**1. A value-preserving literal→SSOT refactor cannot be guarded by an assertion that holds the config fixed → `field-tested`.**
Claim: when the config value renders byte-identical to the literal you removed,
every assertion that holds the config fixed passes on the reverted-literal version
too; the separating input is the config value itself, so the test must vary it
through a seam a caller or operator reaches.
Sources opened: [pytest monkeypatch](https://docs.pytest.org/en/stable/how-to/monkeypatch.html)
("All modifications will be undone after the requesting test function or fixture
has finished"; `monkeypatch.context()` applies patches "only in a specific scope"),
[unittest.mock](https://docs.python.org/3/library/unittest.mock.html) ("you must
ensure that you patch the name used by the system under test"),
[Stryker equivalent-mutants](https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/),
[PIT basic concepts](https://pitest.org/quickstart/basic_concepts/).
What the review changed here, and why it matters: the first commit called this "the
equivalent-mutant condition" and cited Stryker/PIT as its mechanism. That was
self-refuting — an equivalent mutant is one *no input* separates, while this page
then tells you to separate the versions by varying the config. The two are now
cited as a near analogy with the difference stated explicitly. Three further
corrections: the `try/finally` rationale was factually wrong (a `finally` block does
run on assertion failure, so the honest reasons are "no restore code to review" and
"covers a patch applied in a fixture whose test body never runs"); the
wrong-patch-site failure mode is a *misleading red*, not a silent green (the
sentinel assertion fails on correct code); and the presence/absence halves were
described backwards — presence is the discriminator, absence is a supplement.
Confidence is `field-tested` because no cited document supports the central
directive; the only evidence for it is one in-house reproduction (manday renderer,
2026-08-05: `"DB ×%s" % E.DB_MULT` rendered exactly the removed literal `DB ×1.3`,
computed before the test was written; only the sentinel form reddened on the
reverted version).

**2. A composite return's unread fields are unguarded, and cross-field invariants need their own assertion → `verified`.**
Claim: diff the returned field list against the fields assertions mention, confirm
each absence with a per-field mutation plus the harness no-op control, then assert
the relations binding the fields across the input grid.
Sources opened: [arXiv:2211.12003](https://arxiv.org/abs/2211.12003) (Alzahrani,
Spichkova, Harland, *Application of property-based testing tools for metamorphic
testing*) — "The core concept in MT is metamorphic relations (MRs) which provide
formal specification of the system under test";
[hypothesis.works](https://hypothesis.works/articles/what-is-property-based-testing/)
— property-based testing as "the construction of tests such that, when these tests
are fuzzed, failures in the test reveal problems with the system under test that
could not have been revealed by direct fuzzing of that system";
[PIT](https://pitest.org/quickstart/basic_concepts/) for the Survived-vs-No-coverage
distinction step 2 depends on;
[abseil ch12](https://abseil.io/resources/swe-book/html/ch12.html).
This page keeps `verified`: the two sources above back its central directive, and
its field reproduction carries measured numbers (58 passing assertions over a
`lo`/`sp`/`hi` return in which `lo` and `hi` appeared in none of them; four formula
mutations left all 58 green while the no-op control survived, so the harness
discriminated; the invariant over the full discrete grid found 13 combinations with
`sp > hi`).
Honest limit: Hypothesis's own `readthedocs` quickstart does not contain a
definitional "property/invariant" statement — I fetched it, found none, and cited
the maintainers' article rather than inventing a docs quote.

**3. A previously published artifact needs its generation dated and a row-level diff before it is a baseline → `field-tested`.**
Claim: matching aggregates do not establish matching rows; date the artifact's
generation from its schema fields, and rebuild the before side by reverting only the
change under measurement when the generation differs.
Sources opened: [SLSA v1.0 provenance](https://slsa.dev/spec/v1.0/provenance)
(provenance is "the verifiable information about software artifacts describing
where, when and how something was produced"; a build records "the specific git
commit that the URI resolved to as a dependency") — backs the stamping directive;
[Jest snapshot-testing](https://jestjs.io/docs/snapshot-testing) ("we would need to
fix the bug before re-generating snapshots to avoid recording snapshots of the buggy
behavior") — backs one edge row;
[octopusinvitro](http://octopusinvitro.gitlab.io/blog/code-and-tech/approval-testing)
— a practitioner blog, not a primary spec, used only for the golden-master naming
caution.
What the review changed here: the first commit explained the failure with
non-injectivity of summation, which describes *cancelling* summands — but the field
evidence is a rollup parent **excluded from the total**, which was never a summand,
so no cancellation occurred. An engineer following the stated reason would hunt for
offsetting deltas, find none, and wrongly trust the total. The page now enumerates
three mechanisms and leads with exclusion (the one requiring no coincidence). The
generation-dating heuristic was also split: an *absent* field dates the file before
the field existed, a *present-but-empty* field dates it before the writer populated
it — two different conclusions the first commit conflated.
Confidence is `field-tested`: the three central directives (dating by schema field,
row-level full match, in-memory single-revert rebuild) cite nothing and rest on one
in-house reproduction (manday engine, 2026-08-05: counted-SP total 211.48 matched
HEAD exactly while the row diff found NEWRTB-2182 differing — 분석조사/0.19 vs
인프라/0.56 — with `dead: None` dating the file before the classifier's lookbehind
change, and the issue being a rollup parent excluded from the counted total).

**Retraction.** The first commit's report asserted "Every URL cited below and on the
pages was opened in this session — no citation is carried over on trust." That was
false. Two of my new pages attributed the reachability–infection–propagation (RIP)
fault-detection model to
`https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/`.
I had not opened that URL; I copied the attribution from an existing wiki page. The
cross-check flagged it and I then fetched the page: it contains the mutant-state set
and the metric formulas and says nothing about reachability, infection, propagation,
or RIP. Both citations are removed from my pages (the Stryker URL is retained on
`unasserted-return-fields` for the mutant states it does document, and dropped
entirely from `stale-artifact-baselines`).

**Pre-existing defect flagged, not silently edited.** The same miscitation exists in
`wiki/testing/quality/differential-run-agreement.md:92` ("reachability, infection,
and propagation (RIP) model for fault detection") and its directives at `:60` and
`:83` rest on it. That page is not mine to rewrite in this flush — the RIP model is
real but belongs to Ammann & Offutt, *Introduction to Software Testing*, not to
Stryker's docs. Flagged here and in `log.md` for the owner.

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

**Conflict found, and the resolution tightened after review.**
`behavior-not-implementation` step 2 asserts "a refactor that preserves behavior
keeps every test green", which pulls against insight 1's test — one that goes red
when someone re-inlines a literal, a change with identical output. I resolved it
with a condition-dependent Edge row on *both* pages rather than overwriting either.
The cross-check then attacked my first wording as a rationalization, correctly: it
justified the test by "configurability is behavior … through the seam an operator
controls", while another edge row extended the same test to a *module-local*
constant no operator can set — where re-inlining removes no observable capability
and the assertion becomes exactly what `behavior-not-implementation:41` orders
deleted. Generalized, that would let any implementation detail be relabelled a
capability and would quietly remove step 2's diagnostic force. Both rows now carry
the boundary: the value must be settable through an interface a caller or operator
reaches **without editing source** (config file, env var, DI parameter, CLI flag);
when it is not, step 2 stands unchanged and the guard moves to a static check. The
module-local edge row was rewritten to route there instead of asserting the
substitution test "still applies". That page's step 2 text is untouched, and its
`last_verified` was returned to `2026-07-10` — I added an edge row without
re-opening its three sources, so bumping the date would have claimed a verification
I did not do.

**Related links** are now genuinely bidirectional for all five adjacent pages (the
first commit left two one-way: `minimum-case-set` → value-preserving and
`harness-reverse-controls` → stale-artifact-baselines; both back-links added).
One-way references remain, by design, to `checks-that-cannot-pass`,
`write-path-assertions` and `backend-common-change-impact-call-site-enumeration`.

Verified programmatically: every `related:` id and inline `[page-id]` reference
**repo-wide** resolves; all three new pages are listed in `wiki/testing/index.md`;
every touched page's body is under the 120-line limit (max 105); template sections
and frontmatter keys present; no banned vague qualifier in a directive sentence (one
"usually" was caught and rewritten as the condition that decides it). The checker
was itself controlled — injecting a bogus `related:` id and a banned qualifier made
it report both, and it returned to PASS after restore. Note the limit that mattered:
that checker validates link *resolution*, never whether a source says what a page
claims, which is why the RIP miscitation above needed the independent review to
surface.

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

## Reviewing this PR

The two `field-tested` pages are the ones to read hardest: their central directives
rest on single in-house reproductions, described on each page, and are the parts no
external source backs. If you would rather not carry a page at that confidence,
`stale-artifact-baselines` is the most self-contained one to drop — the other two are
cross-linked from four existing pages. The `differential-run-agreement:92` RIP
miscitation is pre-existing and left for you to decide on.
