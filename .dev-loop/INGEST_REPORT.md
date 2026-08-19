# Knowledge flush — 8 insight(s)

Cross-Check: independent adversarial `claude -p` review run on this branch before the PR — verdict REVISE (4 major, 8 minor); all applied, each major re-verified independently (see the Cross-Check section below).

8 queued candidates → **7 new pages** (two candidates share one mechanism and were
merged into a single page), 7 existing pages amended with reciprocal `related:`
links, 5 domain indexes updated, `log.md` appended.

## Verified best-practice

### 1. `inspect.getsource` on a class from a path-loaded module → `verified`

**Claim:** a module loaded via `spec_from_file_location`/`module_from_spec`/`exec_module`
without `sys.modules` registration makes **class** introspection fail with
`TypeError: … is a built-in class`, while **function/method** introspection works.

**How verified:** reproduced locally 2026-08-18 on CPython **3.9.6, 3.11.13, 3.13.11,
3.14.6** — the headline behaviour is identical on all four: class → `TypeError:
<class 'aw.Handler'> is a built-in class`; `m.Handler.do_GET` and `m.select` → source returned; after
`sys.modules[spec.name] = m` the class call returns source. Mechanism read directly from
the shipped `inspect.py` (3.14.6) `getfile`: the class branch resolves through
`sys.modules.get(object.__module__)`, the function branch falls through to
`object.__code__.co_filename`. The registration line was confirmed to be part of the
standard library's own documented recipe.

**Sources checked (opened this session):** docs.python.org/3/library/importlib.html
("Importing a source file directly" recipe, `sys.modules[module_name] = module`),
docs.python.org/3/library/inspect.html, docs.python.org/3/reference/import.html,
local `inspect.py` source.

### 2. Unpacked Chromium extension reload → `verified`

**Claim:** after editing a content script, the host-page refresh alone re-injects the
cached copy; the extension itself must be reloaded too.

**How verified:** Chrome's official Hello-World tutorial was opened and states "After
saving the file, to see this change in the browser you also have to refresh the
extension", with its reload table listing content scripts as "Yes (plus the host page)".
`chrome.runtime.getManifest()` (used for the running-build marker directive) was
confirmed on the official runtime API page. The `#dev-reload-button` shadow-root path is
labelled in-page as a **measured internal detail, not a documented API**, with instructions
to re-derive it when it stops matching. Field evidence: okta-autofill, page-refresh-only →
field stayed empty; extension reload → flow completed.

**Sources checked (opened):** developer.chrome.com get-started tutorial,
develop/concepts/content-scripts, reference/api/runtime.

### 3+8. Browser-automation console capture gaps → `verified` (merged page)

**Claim A (candidate 8):** a collector attached after navigation loses load-time records.
**Claim B (candidate 3):** extension content-script logs live in an isolated execution
context that a main-world collector never reports.

**How verified:** Claim A **independently reproduced this session** (Aside CLI
1.26.810.1915 / daemon 1.26.818.1059) against a local `python3 -m http.server` page whose
inline script logs one `log` and one `error`: `openTab` → `[]`; after `sleep(800)` → `[]`;
after `console.clear()` + `reload()` + `sleep(300)` → both records. Claim B's mechanism is
documented — Chrome content-scripts page ("An isolated world is a private execution
environment that isn't accessible to the page…") and CDP `Runtime.consoleAPICalled`
carrying `executionContextId`, "Identifier of the context where the call was made"; the
default/isolated/worker distinction is carried in `executionContextCreated`'s `auxData`
("Embedder-specific auxiliary data"), and the page now says so rather than presenting it
as a documented field of its own. The tool-specific miss stays labelled as a field
measurement.

**Correction made:** a drafted `playwright.dev/docs/api/class-page` citation was **dropped**
— the fetch did not surface the `console` event section, so the claim could not be
confirmed from it.

**Sources checked (opened):** chromedevtools.github.io Runtime domain,
developer.chrome.com content-scripts. (playwright.dev opened, not confirmable → removed.)

### 4. Correlated SubLink duplicated by derived-table pull-up → `verified`

**Claim:** a derived table carrying no aggregate/LIMIT/DISTINCT/set-op is flattened, its
select-list SubLink is substituted into every referencing aggregate, and PostgreSQL does
not CSE SubPlans — so N outer references cost N evaluations per row; `OFFSET 0`,
`MATERIALIZED`, or `LATERAL` fix it.

**How verified:** the harvested evidence was second-hand (a worker's measurement the
harvesting session could not re-run). **Reproduced from scratch this session** on a
throwaway local cluster, PostgreSQL **16.11** (Homebrew), 5 driving rows:

| Shape | Plan |
|---|---|
| Unfenced derived table, read by `bool_or` + `sum` | `SubPlan 1` + `SubPlan 2`, each `loops=5` (10 evaluations) |
| `OFFSET 0` inside the derived table | one `SubPlan`, `loops=5` |
| `WITH … AS MATERIALIZED` | one `SubPlan` under a `CTE` node |
| Plain `WITH` (not materialized) | **two** `SubPlan` nodes — a plain CTE is not a fence |
| `LEFT JOIN LATERAL` | no `SubPlan` — Nested Loop Left Join |
| Derived table with `GROUP BY` | one `SubPlan` |
| 1 / 2 / 3 outer references | 1 / 2 / 3 `SubPlan` nodes |

The plain-CTE and reference-count rows are additions the candidate did not contain.
Doc quotes obtained verbatim: `OFFSET 0` "is the same as omitting the `OFFSET` clause"
(queries-limit), and the folding/`MATERIALIZED`/push-down-restriction sentences
(queries-with). The pull-up predicate is cited **by location** (`is_simple_subquery()` in
`prepjointree.c`) and explicitly marked as measured-not-quoted, because the only doxygen
rendering available returned a paraphrase rather than the source comment.

**Sources checked (opened):** postgresql.org queries-limit.html, queries-with.html;
local EXPLAIN / EXPLAIN ANALYZE runs.

### 5. Expectation sets with one distinct value → `verified`

**Claim:** when every case expects the same literal, a hardcoded constant at the assembly
point is observationally identical to the wired computation, so adding assertions cannot
kill it; a delete probe only proves key presence.

**How verified:** **reproduced with a minimal control** (CPython 3.9.6, `unittest`):
3 cases all expecting `"HAS_VACANCY"` → constant mutant **survived** (0 failures);
adding one case expecting `"UNSURVEYED"` → same constant **killed** (1 failure); wired
baseline green in both sets; a delete probe reddened via `KeyError`, i.e. on key presence
alone. Field measurement (rtb-unified NEWRTB-2786, 2046-test api suite) retained as the
production instance.

**Correction made:** the Stryker and PIT quotes were **re-fetched rather than inherited** —
the real sentences are "When all tests passed while this mutant was active, the mutant
survived. You're missing a test for it." and "Survived means the mutation was not detected
by the covering test." A third drafted citation (testing.googleblog.com) was dropped as
unopened.

**Sources checked (opened):** stryker-mutator.io mutant-states-and-metrics, pitest.org
basic_concepts; local reproduction.

### 6. ORM-generated test schema hides model-vs-DB drift → `field-tested`

**Claim:** with `ddl-auto: create-drop`/`create`/`update` the test schema is generated
from the entity model, so an entity-vs-database drift cannot exist there and "add a
reproducing test" is unachievable; verification must move to a migration-built DB with
`validate` or an `information_schema` gate.

**How verified — and why not `verified`:** the knobs are documented (Spring Boot: JPA
databases "are automatically created **only** if you use an embedded database"; the
`ddl-auto` ↔ `hibernate.hbm2ddl.auto` mapping; "If you are using a higher-level database
migration tool, like Flyway or Liquibase, you should use them alone to create and
initialize the schema"; Jakarta `@Column.nullable` = "(Optional) Whether the database
column is nullable"). The **consequence** — that the drifted state is unconstructible in a
generated schema — follows from those but was **not executed** here (no JVM reproduction
run), so the page stays `field-tested` on the manage-repo observation rather than claiming
a measurement it does not have. A Hibernate User Guide fetch for the `hbm2ddl.auto` value
table returned a truncated section, so the value enumeration was first folded into the
Spring Boot bullet — which does **not** enumerate the values. The cross-check caught that;
the enumeration now cites Hibernate's `org.hibernate.tool.schema.Action` javadoc directly
(`NONE`/`CREATE_DROP`/`UPDATE`/`VALIDATE` with their legacy `hbm2ddl.auto` names), which
also supplies the "Drop the schema and then recreate it on `SessionFactory` startup"
semantics the page's mechanism rests on.

**Sources checked (opened):** docs.spring.io reference/data/sql.html,
how-to/data-initialization.html, jakarta.ee `@Column` javadoc.

### 7. Deleted-file recovery on macOS/APFS → `field-tested`

**Claim:** check TRIM and APFS snapshots before recommending any recovery tool, work copy
sources in fidelity order, and read the exact path from an app's bookmark blob when the
remembered name is wrong.

**How verified:** the probe commands were **run locally** 2026-08-18 (macOS 15, Darwin
25.5.0, APPLE SSD AP0512Z): `system_profiler SPNVMeDataType` → "TRIM Support: Yes";
`tmutil listlocalsnapshots /System/Volumes/Data` runs and prints its header with no
snapshots. Man pages quoted: `tmutil(8)` listlocalsnapshots/localsnapshot, `trimforce(8)`
("By default, TRIM commands are not sent to third-party drives" — the basis for the
third-party edge case). The strongest claim — that carving is not a viable path with TRIM
active — has **no Apple statement behind it**, so the page keeps `field-tested` and phrases
the directive as routing to copy sources rather than asserting impossibility.

**Correction made:** two drafted Apple URLs (a Disk Utility support page and the NSURL
`bookmarkData` developer page) were **dropped** — the developer page is JS-rendered and
returned no body, and neither was confirmable; the page now cites the local man pages and
measurements instead.

## Existing-layer check

Routing started at `INDEX.md`, then each domain `index.md`; every category directory that
could plausibly own a candidate was listed and the overlapping pages were opened in full.

Pages read: testing-quality-checks-that-cannot-pass, testing-quality-generated-sql-property-assertions, testing-quality-source-text-wiring-assertions, testing-quality-tests-that-cannot-fail, testing-quality-unasserted-return-fields, testing-quality-default-values-under-test, qa-environments-test-environment-parity, backend-java-jpa-entity-mapping, platforms-tools-version-keyed-artifact-cache, backend-python-language-bytecode-cache-staleness

**Overlaps found and how they were resolved**

| Candidate | Nearest existing page | Verdict |
|---|---|---|
| 1 (inspect/class) | `backend-python-language-bytecode-cache-staleness` (same "edited/loaded source vs what runs" family), `testing-quality-checks-that-cannot-pass` (an always-red check) | **New page** — neither carries the resolution-route mechanism; cross-linked both ways to the first and inline to the second |
| 2 (extension reload) | `platforms-tools-version-keyed-artifact-cache` (cache serves the old artifact) | **New page** — that page is version-string cache invalidation for a distribution system; this one is a per-file-type reload matrix. Reciprocal link added |
| 3+8 (console capture) | `qa-environments-headless-browser-bot-blocking` (only other browser-environment page); `platforms-processes-tool-diagnostics-without-a-failing-exit-code` (empty result ≠ clean) | **One new page for both candidates** — same trigger ("a console reading is about to become a verdict"), two disjoint blind spots. Reciprocal link added to the bot-blocking page |
| 4 (SubLink duplication) | `testing-quality-generated-sql-property-assertions` — its step 4 said an aggregate-occurrence count "doubles as the single-evaluation regression guard for a correlated subquery" | **New page + a content amendment to the old one.** As written the two pages *did* conflict for a reader who loaded only the old one: a string assertion cannot see planner-level duplication. That step is now scoped to a *textual* second evaluation and routes planner-level duplication to the new page. (This row previously read "no conflict — the two agree"; the cross-check below refuted that, and the amendment is the fix) |
| 5 (degenerate expectations) | `testing-quality-default-values-under-test` step 1 covers the same degeneracy **scoped to a constructor/factory default**; `unasserted-return-fields` covers fields no assertion reads | **New page** for the general expectation-set form, with explicit edge-case rows routing the default-parameter form and the unread-field form to those two pages. Reciprocal links added to both |
| 6 (ORM test schema) | `qa-environments-test-environment-parity` (parity inventory), `backend-java-jpa-entity-mapping` | **New page** — parity page owns the release-decision inventory, this owns the "what can this test level reproduce" decision. Reciprocal link added to the parity page |
| 7 (APFS recovery) | none in `platforms/filesystems` | **New page** |

**Conflicts flagged:** none. No candidate contradicted an existing directive.

**New categories:** none — all seven pages landed in existing categories.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --limit 50` returned **zero rows**
(also with `--search "head:knowledge/"`). There are no `knowledge/*` heads in flight, so
no candidate could overlap a pending PR.

| Candidate | Overlapping open head | Verdict |
|---|---|---|
| 1 inspect/class | none | new |
| 2 extension reload | none | new |
| 3 isolated-world console | none | **folded into candidate 8's page** (same-flush merge, not an open-PR fold) |
| 4 SubLink duplication | none | new |
| 5 degenerate expectations | none | new |
| 6 ORM test schema | none | new |
| 7 APFS recovery | none | new |
| 8 console buffer timing | none | new |

## Routing decision

| # | Target | Confidence |
|---|---|---|
| 1 | `backend/python/language/source-introspection-of-a-dynamically-loaded-module.md` | verified |
| 4 | `databases/query-optimization/repeated-sublinks-in-a-pulled-up-derived-table.md` | verified |
| 3+8 | `qa/environments/browser-console-capture-gaps.md` | verified |
| 2 | `platforms/tools/unpacked-extension-source-reload.md` | verified |
| 5 | `testing/quality/expectation-sets-with-one-distinct-value.md` | verified |
| 6 | `testing/strategy/orm-generated-test-schema.md` | field-tested |
| 7 | `platforms/filesystems/deleted-file-recovery-on-apfs.md` | field-tested |

Routing notes:
- **2 → platforms/tools rather than frontend**: the lesson is a developer-loop/tooling
  fact (which artifact the runtime is serving), not web-UI code; `frontend/` has no
  extensions category and creating one for a tooling lesson would split the
  cache-staleness family across domains.
- **3+8 → qa/environments rather than testing**: the subject is judging a running
  system's output as a release/QA verdict, not writing automated test code.
- **6 → testing/strategy rather than qa/environments**: the decision it drives is "which
  level can hold this defect", which is `test-level-choice`'s neighbourhood; the parity
  page keeps the release-decision framing and now links here.

## Verification of this change

- `node scripts/wiki-structure-checks.js wiki` → **pages: 249, indexes: 13, findings: 0**
- `node scripts/wiki-lint-prohibitions.js wiki` → **directives: 71, compliant: 71,
  violations: 0** (1 pre-existing info row in `infrastructure/config`, untouched here)
- **Gate-reads-my-files control:** a bare prohibition inserted into the new console page
  moved the linter to `violations: 1`; restoring from a `cp` backup returned it to
  `violations: 0` with the mutation marker absent and the file byte-identical (`cmp`).
  Without this the green run would not have been evidence the new pages were scanned.
- Body lengths 63–72 lines, all within the ≤120 rule.
- **Not run locally:** the `bats tests/` suite (bats is not installed on this machine) —
  CI runs it on this PR.

## Cross-Check

An independent adversarial reviewer (separate `claude -p` process, `--permission-mode plan`,
no shared context) was run against this branch before the PR, tasked only with source
fidelity, overclaim, cross-page contradiction, report accuracy and AGENTS.md compliance.
Verdict: **REVISE** — 4 major, 8 minor. All were addressed, and each major was re-checked
by me independently rather than taken on the reviewer's word:

| # | Finding | Independently re-checked | Fix applied |
|---|---|---|---|
| 1 | The PostgreSQL source path was wrong — `optimizer/plan/prepjointree.c` does not exist | `gh api repos/postgres/postgres/contents/…`: the file is under `optimizer/prep/`, not `plan/` | Path corrected. The reviewer also noted the predicate rejects `sortClause`; I measured it (derived table with `ORDER BY` → one `SubPlan`) and added both the decision row and the measurement arm |
| 2 | The `__main__` edge case is version-dependent, while the page claimed four versions behaved "identical" | Re-measured with `python -c` (so `__main__` has no `__file__`): 3.9.6 → `TypeError`, 3.11.13 / 3.13.11 / 3.14.6 → `OSError: source code not available` | Row scoped by version with the measurement; the "identical on all four" claim narrowed to the headline behaviour |
| 3 | The `ddl-auto` value enumeration was attributed to a Spring Boot page that does not enumerate it | Re-read my own fetch: the enumeration came from the fetch tool's summary, not from the page itself | Split out and cited to Hibernate's `Action` javadoc, opened this session |
| 4 | Cross-page contradiction with `generated-sql-property-assertions`, which this report had declared conflict-free | Read both side by side — the old step 4 does overreach for a reader loading it alone | Old step 4 scoped to textual duplication and cross-linked; the Existing-layer row above corrected |

Minor findings applied: version-scoped the planner claim to the measured 16.11; labelled
the push-down rationale as inferred rather than cited; "three assertions" → "three cases"
in the expectation page (the very axis that page teaches); rewrote three source bullets
that had dropped their source's hedge or scope (`getfile` vs `getsource` argument list,
`getManifest()` wording, `executionContextCreated` `auxData`); dropped two weakly-adjacent
`related:` ids from the APFS page and replaced its one hedged cell with the stated
condition; corrected the lint numbers and the body-line range in this report.

Not changed, with reasons: the "Also when" trigger shape flagged on the console page is
house convention (71 of 252 pages use it) and both halves share one decision point;
`.dev-loop/CROSSCHECK_FINDINGS.md` and `.dev-loop/fold-note-73.md` are pre-existing
untracked scratch from an earlier flush — this commit stages explicit paths only, so
neither ships, and neither is mine to delete.

The reviewer stated it could not verify the off-checkout evidence (the Aside runs, the
okta-autofill observation, NEWRTB-2786, the `manage` repo, the PG 16.11 EXPLAIN runs, and
the lint mutation control) and neither confirmed nor refuted it — those rest on the
measurements recorded in the pages.
