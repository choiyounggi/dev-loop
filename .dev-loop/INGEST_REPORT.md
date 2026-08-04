# Knowledge flush — 7 insight(s)

Drained the whole pending queue (`~/.dev-loop/queue/`, 7 rows across 5 session
files). Result: **5 new pages, 2 amendments, 1 new category**. Two candidate
claims were **disproved during verification** and the resulting directives were
rewritten before ingest — details under *Verified best-practice* (B1).

| # | Candidate (trigger, abbreviated) | Outcome | Confidence |
|---|----------------------------------|---------|------------|
| T1 | Differential harness reports EQUIVALENT while one side models less state | NEW `testing/quality/differential-run-agreement` | verified |
| T2 | Proving a test file "can fail" after assertions moved into a shared contract | MERGE → `testing/quality/tests-that-cannot-fail` | verified |
| T3 | Monkeypatched deliberate-fault control that never reaches the seam | MERGE → `testing/quality/harness-reverse-controls` | verified |
| T4 | Signature change; enumerating call sites for migration | NEW `backend/common/refactoring/signature-change-call-sites` (new category) | verified |
| D1 | Monitor whose grep completion predicate reports done immediately | NEW `testing/quality/completion-predicates` | verified |
| B1 | Picking a crawl source for Korean public-institution notices | NEW `backend/common/integrations/robots-txt-and-source-selection` (**claim corrected**) | verified |
| B2 | Client throttle in place, still rate-limited on the first call | NEW `backend/common/reliability/client-side-rate-limiting` | field-tested |

---

## Verified best-practice

**T1 — a differential "agree" verdict is scoped to inputs where the asymmetric state is reachable.**
Checked: McKeeman, *Differential Testing for Software*, Digital Technical Journal
10(1) 1998 pp. 100–107 (the method is a pseudo-oracle: agreement is only as
strong as the inputs that could have exposed a difference);
<https://arxiv.org/abs/2410.21904> (RIP — "Finding test cases to kill the alive
mutants in Mutation testing needs to calculate the Reachability, Infection and
Propagation(RIP) conditions": detection requires all three, so an unreached
dimension yields no verdict); <https://pitest.org/quickstart/basic_concepts/>
(**No coverage** is "the same as Survived except there were no tests that
exercised the line of code where the mutation was created" — the tools already
keep "never reached" separate from "reached and not detected");
<https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/>
(score = "detected / valid * 100"). The session's own evidence reproduces it:
`lnpl diff` on a read-then-create module → `EQUIVALENT` 4/4 on the default seed,
`DIVERGENT` `A=failed B=completed` under `--no-row`. → **verified**.

**T2 — mutation granularity is per assertion, and the kill is attributed per test.**
Checked: <https://pitest.org/quickstart/basic_concepts/> — **Killed** = "a test
caught the mutation successfully", **Survived** = "the mutation was not detected
by the covering test", **No coverage** = no test exercised the line. Those are
exactly the three outcomes of a per-assertion mutation, and the per-test
attribution is what makes "which test reddened" the unit of proof rather than
"did the file redden". Session evidence: renaming `workflow Checkout` reddened
`test_source_compiles_to_the_committed_ir` but not
`test_node_ids_and_order_are_stable`, which pins only the first node id and the
trailing capability ids. → **verified**.

**T3 — a patch-based control must target a seam the path reads at call time.**
Checked: <https://docs.python.org/3/library/unittest.mock.html> "Where to patch"
— `patch()` "works by (temporarily) changing the object that a *name* points to
with another one … you must ensure that you patch the name used by the system
under test", and "You patch where an object is *looked up*, which is not
necessarily the same place as where it is defined". The candidate is a genuine
extension of that rule: the name is patched *correctly* and still never read,
because an upstream caller resolved the defaulted value and passed it explicitly,
leaving the callee's `if x is None` branch dead for that path. Session evidence:
patching `backend.seeded_entities` → control green (`AssertionError: True is not
false`); patching `backend.READ_OPS` / `backend._failure_attempts`, both read
unconditionally, → the expected `FAIL 2/4` and `FAIL 3/4`. → **verified**.

**T4 — enumerate call sites by callee; a positional argument carries no name.**
Checked: <https://docs.python.org/3/reference/expressions.html> (a call binds
positional arguments by position; the parameter name is simply absent from a
positional call site's source text, so a name search structurally cannot see
those callers); <https://libcst.readthedocs.io/en/latest/codemods.html> and
<https://github.com/facebookincubator/bowler> ("Safe code refactoring for modern
Python … guaranteeing that the resulting code compiles and runs") for the
sourced replacement action — match `Call` nodes in a CST rather than text.
Session evidence: `grep -rn "repo_rows" impl/tests/` → 13 hits, all keyword form;
full suite → `Ran 472 tests / FAILED (failures=11)`, all from 8 positional
`verify()` call sites plus a `rows_for()` helper feeding 5 more. → **verified**.

**D1 — the bracket-expression false positive, reproduced from scratch.**
Checked: <https://www.gnu.org/software/grep/manual/grep.html> — `-F` "Interpret
patterns as fixed strings, not regular expressions"; `-c` prints "a count of
matching lines"; `-v` "Invert the sense of matching".
<https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap09.html> — a
bracket expression matches a *single* character from the enclosed set.
**Reproduced live on this machine (2026-08-04, macOS/BSD grep)** on a 3-line
status file with one `[completed]` and two in-flight lines:

```
grep -c '[completed]'   → 3      (every line matches the character class)
grep -qv '[completed]'  → selects nothing → "ALL COMPLETED"  ← false positive
grep -cF '[completed]'  → 1      vs total 3 → "still running (1/3)"
```

→ **verified** (reproducible command sequence, not just the original incident).

**B1 — candidate claim DISPROVED; directive rewritten.** The candidate asserted
"기관 자체 사이트는 전면 크롤링 거부(`Disallow: /`)" with `www.i-sh.co.kr` as evidence.
Live fetch 2026-08-04 shows that is **wrong as stated**:

- `www.i-sh.co.kr/robots.txt` gives `User-agent: *` a **path list only**
  (`/admin`, `/cert`, `/upload`, `/gcms/brd`, per-district board paths). The
  `Disallow: /` lines belong to 15 **named** groups — `GPTBot`, `ChatGPT-User`,
  `facebookexternalhit`, `BaiDuSpider`, `MJ12bot`, `OAI-SearchBot`,
  `PerplexityBot`, `Google-Extended`, `ClaudeBot`, `Claude-SearchBot`,
  `meta-externalAgent`, `Applebot-Extended`, `CCBot`, `aiohttp`, `DuckDuckBot`.
  The candidate read the file's last line without its group header.
- `www.gh.or.kr/robots.txt` is **not** `Disallow: /` — it returns **HTTP 410**,
  which RFC 9309 classifies as *unavailable*: "the crawler MAY access any
  resources on the server". That is the opposite of the candidate's reading.
- Confirmed as stated: `housing.seoul.go.kr` → `User-agent: * / Allow: /`;
  `apply.gh.or.kr` → `User-agent: * / Allow: /*`.

Grounded in <https://www.rfc-editor.org/rfc/rfc9309.html>: "Crawlers MUST use
case-insensitive matching to find the group that matches the product token and
then obey the rules of the group"; `*` applies only "If no matching group
exists"; multiple matching groups "MUST be combined into one group"; the product
token "should appear as a substring in the crawler's user-agent header"
(so a client on its library's default UA — aiohttp autogenerates one per
<https://docs.aiohttp.org/en/stable/client_reference.html> — can land in a named
disallowed group); 4xx → "MAY access any resources", 5xx/unreachable → "MUST
assume complete disallow"; five-redirect limit; "SHOULD NOT use the cached
version for more than 24 hours". The page's directive is therefore **"read the
group your product token matches, and branch on the response status"**, with the
republishing-portal fallback as a secondary step — not the candidate's "the
origin blocks crawling". → **verified** (and materially more useful than the
candidate).

**B2 — mechanism verified, vendor numbers NOT verified → field-tested.**
Sourced the general claims: <https://www.rfc-editor.org/rfc/rfc6749.html> (the
token endpoint is reached by an ordinary HTTP request from the client, so
credential acquisition consumes the same request budget as data calls) and
<https://www.rfc-editor.org/rfc/rfc6585.html> (429 "indicates that the user has
sent too many requests in a given amount of time", `Retry-After`). I could
**not** confirm the candidate's specific "한도 2건/초" or a token-issuance quota
from Korea Investment & Securities' official developer portal — public sources I
found cite a different per-second figure, so the page carries **no vendor
numbers** and states the mechanism only (auth refresh inside `_headers()` sits
outside a throttle wrapped around the call layer; a zero-initialized
`_last_request_at` makes the first wait evaluate to zero). The timestamped log
evidence (POST `:00.354` → token `:00.495` → rejected `:00.543`, on two separate
token-issuance days, clean on cached-token days) is real production observation.
→ **field-tested**, labelled as such in frontmatter and stated plainly in the
page's Sources.

No candidate was dropped, and nothing was upgraded to `verified` without a cited
source or a reproduction. Every cited link was fetched (HTTP 200) or is a
bibliographic citation with no URL (McKeeman 1998).

---

## Existing-layer check

Routed via `INDEX.md` → domain indexes → every page whose "load when" overlapped.

**Pages read in full before writing** (dedup + conflict + link decisions):
`wiki/testing/quality/harness-reverse-controls.md`,
`wiki/testing/quality/tests-that-cannot-fail.md`,
`wiki/testing/quality/checks-that-cannot-pass.md`,
`wiki/backend/common/reliability/timeouts-and-retries.md`, plus the `testing`,
`backend`, `debugging`, and `platforms` domain indexes, `INDEX.md`, `AGENTS.md`
and `templates/page.md`.

**Merged rather than created (merge-before-create):**

- **T2 → `tests-that-cannot-fail`.** Its step 1 already prescribes manual
  mutation testing; the candidate refines the *granularity* of that same case, so
  a new page would have split one case in two. Added: a new step 2 (one mutation
  per assertion, with a three-outcome table mapping to PIT's
  Killed/Survived/No-coverage), a never-fails-pattern row for assertions
  inherited into a shared base class/mixin/parameterised harness, two edge-case
  rows, two `Instead of` rows, the PIT source, and the field reproduction.
  Renumbered the following steps; `last_verified` → 2026-08-04.
- **T3 → `harness-reverse-controls`.** The candidate explicitly lands in that
  page's "every case green" failure mode, but the page documented only Stryker's
  two *sandbox-mechanics* causes. Added a third cause as a table row, a new Do
  item 7 (patch a seam the path consults at call time; require the control red),
  an edge-case row for the refactor that creates the dead default, an
  `Instead of` row, the `unittest.mock` "Where to patch" source, and the field
  reproduction. Page stayed at 97 body lines (limit 120).

**Overlaps found but judged distinct (kept separate, cross-linked):**

- `checks-that-cannot-pass` vs **D1** — exact mirror cases: that page is "a gate
  only ever observed *failing*"; D1 is a predicate only ever observed
  *succeeding*. Its grep material is about exit-status semantics (0/1/>1) and
  `-q` masking; D1's is about a literal degrading into a bracket expression
  through quoting layers, and its subject is a polling monitor rather than a
  gate. Cross-linked both ways via `related`.
- `harness-reverse-controls` vs **T1** — same theme ("a uniform verdict is a
  property of the harness"), different case and different remedy: the control
  there is a semantics-preserving *mutation* that must survive; here it is an
  *input* that forces an unmodelled dimension to decide. Made a separate page and
  cross-linked; also added a T1 pointer to `tests-that-cannot-fail`'s edge cases.
- `timeouts-and-retries` vs **B2** — that page owns the *reactive* path (its only
  rate-limit content is one row: "429 | Wait the `Retry-After` value…"). B2 is
  *proactive* quota pacing and which requests count. Kept separate; B2's step 7
  defers to it for the reactive half and `related`-links it.
- `externally-owned-defaults` vs **B1** — B1's source host/path/id scheme is an
  externally-owned default; referenced from B1's edge cases rather than
  duplicated.

**Conflicts flagged:** none. No existing directive is contradicted or
overwritten; the two amendments only extend their pages.

**Links added:** `differential-run-agreement` ↔ `harness-reverse-controls`,
`tests-that-cannot-fail`, `minimum-case-set`; `completion-predicates` ↔
`checks-that-cannot-pass`, `tests-that-cannot-fail`, `portable-shell-scripts`,
`background-services`; `robots-txt-and-source-selection` → `timeouts-and-retries`,
`externally-owned-defaults`; `client-side-rate-limiting` → `timeouts-and-retries`,
`jwt-server-side`, `intermittent-failures`; `signature-change-call-sites` →
`tests-that-cannot-fail`, `behavior-not-implementation`.

**Invariants checked after the change:** all 7 touched pages ≤120 body lines
(74/73/79/75/73/77/97); every `related:` id across the whole wiki resolves to an
existing page id; every inline `[page-id]` reference in the touched pages
resolves; every markdown link in `INDEX.md`, `wiki/testing/index.md` and
`wiki/backend/index.md` resolves to a file; no banned vague qualifier remains in
the touched pages; `log.md` carries the appended `ingest` and `revise` entries.

---

## Routing decision

| Insight | Domain / category | Page | Note |
|---------|-------------------|------|------|
| T1 | `testing` / `quality` | **NEW** `quality/differential-run-agreement.md` | Domain owns "verifying tests can actually fail"; this is the differential-harness instance of that case |
| T2 | `testing` / `quality` | **MERGE** into `quality/tests-that-cannot-fail.md` | Same case at finer granularity — a new page would have split one case |
| T3 | `testing` / `quality` | **MERGE** into `quality/harness-reverse-controls.md` | The candidate names that page's own failure mode; adds a third documented cause |
| D1 | `testing` / `quality` | **NEW** `quality/completion-predicates.md` | Non-test checks already live in this category (`checks-that-cannot-pass` covers grep gates and "a plan's verification command"), so a polling monitor's predicate belongs here rather than in `debugging` (nothing is being diagnosed) or `platforms/shells` (the bracket-expression behaviour is not OS-specific) |
| B1 | `backend` / `integrations` | **NEW** `common/integrations/robots-txt-and-source-selection.md` | Existing category, language-agnostic, sits beside `externally-owned-defaults` (both are "a resource the repo does not own") |
| B2 | `backend` / `reliability` | **NEW** `common/reliability/client-side-rate-limiting.md` | Existing category; complements `timeouts-and-retries` (proactive pacing vs reactive retry) |
| T4 | `backend` / **`refactoring` (NEW category)** | **NEW** `common/refactoring/signature-change-call-sites.md` | Rationale below |

**New category: `backend/common/refactoring`.** The candidate arrived tagged
`domain: testing` because a test suite is what caught the miss, but the practice
governs *changing application code*, not writing tests — routing protocol step 1
sends it to the domain that owns the artifact being changed. No existing category
covers it: `testing/quality` is about what tests assert;
`testing/quality/behavior-not-implementation` covers "a behavior-preserving
refactor broke tests" (test coupling), which is the opposite direction — here the
tests were right and the migration was short; `debugging` is for diagnosing a
failure, and nothing is being diagnosed. Placed under `backend/common` because
`INDEX.md` assigns language-agnostic application-code concerns there, matching
the existing `common/api-design`, `common/orm`, `common/errors` pattern. Category
name follows the lowercase-kebab-noun rule; the page id is
`backend-common-refactoring-signature-change-call-sites`, matching its path.

`INDEX.md` was updated (the backend and testing "route here when" lines) — no new
domain, so the domain table itself is unchanged. `wiki/backend/index.md` gained
the `refactoring` section plus two rows; `wiki/testing/index.md` gained two rows
and an extended "Route here for" line.

---

**Review note.** Opened for review only; nothing is auto-merged. The one item
worth a maintainer's eye is B2's `field-tested` confidence — the mechanism and
the timestamped production evidence are solid, but the vendor's published quota
could not be confirmed, so the page deliberately carries no numbers. Reject that
page alone if the bar for a `reliability` entry is a cited provider limit.
