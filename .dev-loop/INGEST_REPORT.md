# Knowledge flush — 4 insight(s)

Drained 4 pending candidates from `~/.dev-loop/queue`. All four survived
research and are ingested: **4 new pages, 5 amendments.** Three are
`confidence: verified`; one is `field-tested` and says so (see below).

| # | Insight | Target page | Confidence |
|---|---------|-------------|-----------|
| 1 | Duration assertions against an injected float clock | `testing/quality/injected-clock-duration-assertions.md` (new) | verified |
| 2 | A path-valued config key must be absolute | `infrastructure/config/path-valued-config.md` (new) | verified |
| 3 | Enumerate call sites by callee, not parameter name | `backend/common/refactoring/call-site-enumeration.md` (new) | verified |
| 4 | Sharpen an artifact guard from shape to consequence | `testing/quality/guard-shape-vs-consequence.md` (new) | field-tested |

---

## Verified best-practice

### 1 — Duration assertions against an injected float clock

**Claim as queued:** with a fake monotonic clock started at a large value (e.g.
`1000.0`), `assert gap >= interval` fails on correct code; add a small tolerance
or start the clock at `0.0`.

**Verified — and the claim was too narrow.** Reproduced locally (CPython 3.14.6,
macOS) across start values for a `1.05` step:

| start | `start + 1.05 - start` | `>= 1.05`? |
|-------|------------------------|-----------|
| `0.0` | `1.05` | yes |
| `1.0` | `1.0499999999999998` | no |
| `100.0` | `1.0499999999999972` | no |
| `1000.0` | `1.0499999999999545` | no |
| `1e6` | `1.0500000000465661` | yes (rounded **up**) |
| `1e9` | `1.0499999523162842` | no |

Two corrections folded into the page: a start of `1.0` already breaks the exact
comparison (not just "large" values), and the error is **not always negative** —
at `1e6` the gap came out larger than the interval, so equality and upper-bound
assertions need tolerance on both sides. Every listed start satisfies
`gap >= 1.05 - 1e-6`.

**Sources checked:**
- [PEP 564](https://peps.python.org/pep-0564/) — the strongest confirmation of
  the "start at 0.0" branch, in CPython's own words: *"Internally, Python starts
  `monotonic()` and `perf_counter()` clocks at zero on some platforms which
  indirectly reduce the precision loss."* Also *"the `float` type starts to lose
  nanoseconds after 104 days."*
- [Python floating-point tutorial](https://docs.python.org/3/tutorial/floatingpoint.html)
  — *"most decimal fractions cannot be represented exactly as binary fractions."*
- [`math.isclose`](https://docs.python.org/3/library/math.html#math.isclose) —
  signature `(a, b, *, rel_tol=1e-09, abs_tol=0.0)`; **symmetric**, which is why
  the page routes it to the equality row only: on a lower bound `isclose` also
  accepts a gap that is too *short*, the exact defect a rate-limit test guards.
- [`pytest.approx`](https://docs.pytest.org/en/stable/reference/reference.html#pytest-approx)
  — default rel tol `1e-6`, abs tol `1e-12`; justifies the page's `1e-6` default.

### 2 — A path-valued config key must be absolute

**Claim as queued:** when a launcher owns the CWD, reject a relative path env var
with `ValueError` rather than resolving it against CWD; a missing dir globs to
`[]` and looks like "no work today".

**Verified by controlled experiment.** Installed a LaunchAgent with
`ProgramArguments` + `RunAtLoad` and **no** `WorkingDirectory` key; it recorded
`cwd=/`, `PWD=/`, and a relative `./data/signals` lookup reported "No such file
or directory". Plist booted out and removed afterwards. Independently,
launchd-spawned `loginwindow` also reports cwd `/` under `lsof`.

The silent-failure half also reproduced: `glob.glob("/nonexistent-xyz/*.json")`
returns `[]` and `Path(...).glob(...)` yields nothing — neither raises — while
`os.listdir` on the same path raises `FileNotFoundError`. And
`Path("~/data").expanduser().is_absolute()` is `True` while
`Path("./data").expanduser().is_absolute()` is `False`, which is what makes the
queued implementation's `expanduser()`-then-`is_absolute()` order correct.

**Sources checked:**
- [systemd.exec(5)](https://man7.org/linux/man-pages/man5/systemd.exec.5.html) —
  `WorkingDirectory=`: *"If not set, defaults to the root directory when systemd
  is running as a system instance and the respective user's home directory if run
  as user."* This adds a nuance the candidate did not have: **systemd user units
  default to `$HOME`, not `/`** — so the same relative path resolves to three
  different places across launchd / systemd-system / systemd-user. That nuance is
  now in the page and in the `background-services` edge row.
- `launchd.plist(5)` (local man page) — `WorkingDirectory` is *"This optional key
  is used to specify a directory to chdir(2) to before running the job"*: optional,
  nothing inherited from the installer.
- [Apple, Creating launchd jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html),
  [12factor config](https://12factor.net/config).

### 3 — Enumerate call sites by callee, not parameter name

**Claim as queued:** grep the callee (`verify(`), not the parameter name
(`repo_rows=`), because positional calls carry no parameter name; sweep test
helpers separately.

**Verified, mechanism reproduced.** For a file holding both a keyword call and a
positional call, `grep -n "repo_rows"` returns 2 hits (definition + keyword call)
while `grep -n "verify("` returns 3 (definition + both calls) — the positional
call is invisible to the parameter-name search.

**Two additions the candidate did not have**, both verified:
- **Find-references beats both greps.** [LSP 3.17](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/)
  `textDocument/references` resolves the symbol, so it returns positional and
  keyword calls alike and does not over-match a same-named function on another
  type. Callee grep is now the documented *fallback*.
- **Make stale calls loud.** Marking the parameter keyword-only
  ([PEP 3102](https://peps.python.org/pep-3102/)) turns an unmigrated positional
  call into `TypeError: verify() takes 3 positional arguments but 4 were given`
  instead of silently binding into a neighbouring parameter. Verified locally.

Also cited: [Python calls reference](https://docs.python.org/3/reference/expressions.html#calls)
for the positional/keyword binding rules. The original field evidence (linkly:
13 keyword hits → `Ran 472 tests / FAILED (failures=11)`, plus a `rows_for()`
helper feeding 5 more sites) is preserved in the page's Sources.

### 4 — Sharpen an artifact guard from shape to consequence

**Claim as queued:** when a repo-wide guard asserting "no artifact has shape S"
fires on a legitimate artifact, rewrite it as "no artifact has S *and* the
consequence C", computing C via the production derivation.

**Kept `confidence: field-tested`, deliberately.** The *failure mode* is
sourced — Google Testing Blog,
[Change-Detector Tests Considered Harmful](https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html)
(Alex Eagle, 2015-01-27): *"Change-detector tests do not add clarity, and you
cannot safely refactor code if you know you need to adapt the tests afterwards to
get them passing again."* A shape-only guard needing an exemption per legitimate
artifact is that failure at repo scope. Step 4's required-red fixture rests on
[pitest.org](https://pitest.org/)'s mutation mechanic (already cited elsewhere in
this wiki).

But the specific technique — compute C from the *production* derivation, assert
the exemption's reason — rests on **one** real case (linkly #35: the guard fired
on `examples/checkout.lnpl`; sharpening to "guarded call that could actually
fail" via `_lnpl_ops`' `seeded_entities`/`repository_calls` returned the suite to
`Ran 518 tests / OK` while a guarded-and-can-fail fixture still drove it red).
One case is field evidence, not verification, so the page says `field-tested` and
describes that context.

**Honest caveat on this source:** the change-detector article's body would not
render through fetch (only header/comments returned). The quoted sentence is the
one confirmed via search snippet; the URL itself is already cited by
`testing-quality-behavior-not-implementation` in this wiki. No other sentence
from that article is quoted.

---

## Existing-layer check

**Pages read in full for overlap:** `testing/index.md`, `infrastructure/index.md`,
`platforms/index.md`, `qa/index.md`, `debugging/index.md`, `backend/index.md`,
`testing/quality/tests-that-cannot-fail.md`,
`testing/quality/spec-artifact-checks.md`,
`testing/quality/behavior-not-implementation.md`,
`testing/async/async-testing.md`, `infrastructure/config/environment-config.md`,
`platforms/processes/background-services.md`, plus a repo-wide grep for
`floating.point|tolerance|isclose|approx|monotonic|fake clock` and
`absolute path|is_absolute|working directory|launchd|relative path|fail-fast`.

| Insight | Overlap found | Resolution |
|---------|---------------|-----------|
| 1 | `test-data-and-isolation` already says "refactor the code to accept an injected clock; that seam is the fix". `async-testing` covers fake timers vs condition waits. | **Complementary, not duplicate** — those pages get you *to* an injected clock; this page is what to do once you have one and must compare its readings. Created new; linked both ways. |
| 2 | `environment-config` already mandates full-schema startup validation + "required keys get NO default". `background-services` covers minimal environment and absolute paths **for binaries** — but nowhere states the CWD default. | **Merged the fact where it belongs, created the directive page.** The CWD-is-`/` fact went to `background-services` (platforms owns it). The validation directive is a new sibling page under `infrastructure/config/`. |
| 3 | `behavior-not-implementation` covers "a refactor broke tests"; `qa/process/regression-scope` covers what to re-test. | Both are adjacent, neither owns *enumerating call sites*. Created new; linked to both. |
| 4 | `tests-that-cannot-fail` (a test that can't detect) and `spec-artifact-checks` (per-check negative controls) are close cousins. | **Distinct trigger**: those pages are about a guard that never fires; this is a guard that fires on a *legitimate* artifact. It is the mirror case. Created new; linked to both. |

**Conflicts flagged:** none. No new directive contradicts an existing one.
Insight 2's directive *sharpens* `environment-config` rule 3 ("crash on any
missing or invalid key") for the path case rather than opposing it.

**Amendments to existing pages (5):**
- `infrastructure/config/environment-config.md` — new edge row (path-valued keys)
  + `related:` link.
- `platforms/processes/background-services.md` — new edge row (working directory
  defaults per manager), `systemd.exec(5)` added to `sources:` with the verbatim
  default quote, `last_verified` → 2026-08-04, `related:` link.
- `testing/quality/tests-that-cannot-fail.md` — reciprocal `related:` links.
- `testing/quality/behavior-not-implementation.md` — reciprocal `related:` links.
- `testing/async/async-testing.md` — reciprocal `related:` link.

---

## Routing decision

| Insight | Domain / category / page | Rationale |
|---------|--------------------------|-----------|
| 1 | `testing` / `quality` / `injected-clock-duration-assertions` | Existing category. It is assertion-design: a test that **fails on correct code**, the mirror of `tests-that-cannot-fail`. Considered `async` (fake timers) and `data` (time-dependent fixtures); both own adjacent concerns and are linked instead. |
| 2 | `infrastructure` / `config` / `path-valued-config` | Existing category, **new page rather than a row in `environment-config`**. Distinct trigger ("a config value is a path and the CWD is not mine" vs "config differs per environment"), and AGENTS.md rule 1 is one case per page. The platform *fact* (CWD default) was merged into `platforms/processes/background-services` instead of duplicated. |
| 3 | `backend` / **new category `refactoring`** / `call-site-enumeration` | Routing protocol says route to the domain owning the artifact you change — this changes application code → `backend`, and it is language-agnostic → `common/`. **New category justified:** the 11 existing `backend/common` categories are all runtime concerns (api-design, reliability, caching, jobs, errors, auth, orm, concurrency, llm, integrations, storage); none covers changing existing code. Filed under `common/` because positional/keyword argument binding is not Python-specific. |
| 4 | `testing` / `quality` / `guard-shape-vs-consequence` | Existing category, alongside the other four guard/check-design pages. |

**New categories created: 1** (`backend/common/refactoring/`).
`INDEX.md` and `wiki/backend/index.md` updated for it; `INDEX.md` and
`wiki/infrastructure/index.md` updated for insight 2.

---

## Verification of the change itself

A structural lint over all **143** pages passes: no duplicate ids, no id/path
mismatch, no page over 120 body lines, every page carries `sources:` and the
required sections, every `related:` id and inline `[page-id]` reference resolves,
and every page is listed in its domain index. One vague-qualifier hit in a new
page was fixed; the two remaining hits are pre-existing and untouched.
