# Knowledge flush — 7 insight(s)

Drained `~/.dev-loop/queue` (7 pending rows across 5 session files). Result:
**5 new pages, 3 revised pages, 1 new category, 2 log entries** — including one
**correction**, where live re-verification refuted the candidate's stated evidence
and the page was rewritten around the mechanism that actually holds.

| # | Candidate (trigger) | Outcome | Confidence |
|---|---------------------|---------|------------|
| 1 | Choosing a scrape source for Korean public-agency notices | **New** `backend/common/integrations/crawl-permission-by-user-agent` — *rewritten*, candidate's evidence refuted | verified |
| 2 | Completion predicate in a background-job monitor | **New** `testing/quality/polling-completion-predicates` | verified |
| 3 | Testing code that writes to `~/Library/LaunchAgents` | **Merged** into `testing/data/test-data-and-isolation` | verified |
| 4 | Mutation/revert loop over Python source, equal byte size | **New** `backend/python/language/bytecode-cache-staleness` | verified |
| 5 | Throttled API client still rate-limited on first call | **New** `backend/common/reliability/client-side-rate-limiting` | field-tested |
| 6 | Migrating call sites after a signature change | **New** `backend/common/refactoring/call-site-enumeration` (new category) | field-tested |
| 7 | `VAR=` to disable a feature read as `${VAR:-default}` | **Merged** into `platforms/shells/portable-shell-scripts` | verified |

---

## Verified best-practice

### 1. robots.txt and scrape-source selection — **candidate evidence refuted, page rewritten**

**Candidate claimed:** agency sites blanket-deny crawling (`www.i-sh.co.kr` robots.txt
"last line `Disallow: /`"; `www.gh.or.kr` likewise `Disallow: /`), so route to the
permissive upstream portal instead.

**Checked** (live fetch, 2026-08-04) — two of the four claims are wrong:

| Claim | Result |
|-------|--------|
| `www.i-sh.co.kr` = blanket `Disallow: /` | **REFUTED.** HTTP 200, 64 lines. The `User-agent: *` group disallows only specific path prefixes (`/admin`, `/upload`, `/gcms/brd`, …) and has **no** blanket rule. The thirteen `Disallow: /` lines each open a *named* group: GPTBot, ChatGPT-User, facebookexternalhit, BaiDuSpider, MJ12bot, OAI-SearchBot, PerplexityBot, Google-Extended, ClaudeBot, Claude-SearchBot, meta-externalAgent, Applebot-Extended, CCBot, **aiohttp**, DuckDuckBot |
| `www.gh.or.kr` = blanket `Disallow: /` | **REFUTED.** HTTP **410** with an HTML body — no robots.txt exists. Under RFC 9309 §2.3.1.3 a 4xx means the file is *unavailable* and "the crawler MAY access any resources on the server" — the opposite of a disallow |
| `housing.seoul.go.kr` = `Allow: /` | **CONFIRMED.** HTTP 200 `text/plain`: `User-agent: *` / `Allow: /` |
| `apply.gh.or.kr` = `Allow: /*` | **CONFIRMED.** HTTP 200 `text/plain`: `User-agent: *` / `Allow: /*` |

**Sources checked:** [RFC 9309](https://www.rfc-editor.org/rfc/rfc9309.html) §2.2.1
(case-insensitive product-token match; multiple matching groups MUST be combined; `*`
only as fallback when no group matches), §2.3.1.1–2.3.1.4 (2xx follow; ≤5 redirects;
4xx MAY access; 5xx "MUST assume complete disallow"), §2.5 (24-hour cache ceiling) —
plus the four live `robots.txt` fetches above.

**What the page says instead:** the candidate's *conclusion* (check other publishers)
survives as directive 4, but the *mechanism* it gave was a misreading. The page is
built on the rule that actually governs: **attribute every `Disallow` to its
`User-agent` group before concluding anything**, and **decide from the HTTP status
code, not the rendered body**. The `aiohttp` finding is the sharp, checkable payoff —
a Python scraper sending its client library's default UA lands in a blanket-denied
group that the very same scraper with an explicit UA never matches. → `verified`.

### 2. Polling completion predicates

**Claim:** a text-match "everything finished" predicate must be validated against the
not-yet-finished state; bracketed status tokens need `grep -F`.

**Verified by reproduction** (2026-08-04). Status board with 1 of 4 done:

```
t1 [completed] / t2 [implementing] / t3 [dispatch] / t4 [reviewing]

grep -v '[completed]'   -> 0 leftover lines  => predicate reports "ALL COMPLETE"  (FALSE POSITIVE)
grep -cF '[completed]'  -> 1 of 4 total      => predicate reports "still running" (CORRECT)
```

Every status word contains a character from `{c,o,m,p,l,e,t,d}`, so as a BRE the
bracket expression matches all four lines and the "nothing unfinished" test is
vacuously true on the first poll.

**Sources checked:** [POSIX grep](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html)
("-F Match using fixed strings. Treat each pattern specified as a string instead of a
regular expression"; BRE by default), [POSIX RE §9.3.5 bracket
expressions](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html),
[POSIX shell quote removal](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html).
→ `verified`.

### 3. `$HOME` redirection for filesystem test isolation

**Claim:** override `process.env.HOME` in the test rather than widening the production
signature with a test-only directory parameter; `os.homedir()` re-reads `$HOME` per call.

**Verified by reproduction** (Node v25.8.1, 2026-08-04) — mutating `process.env.HOME`
*between two calls in the same process* changed the second return value, and restoring
it restored the original. That rules out caching, which is the load-bearing part of the
claim:

```
in-process before: /Users/choeyeong-gi
in-process after : <scratch>/home
restored         : /Users/choeyeong-gi
```

**Source checked:** [Node os.homedir()](https://nodejs.org/api/os.html) — "On POSIX, it
uses the `$HOME` environment variable if defined. Otherwise it uses the effective UID…";
Windows reads `USERPROFILE`. No caching is documented. → `verified`.

### 4. CPython bytecode-cache staleness

**Claim:** an equal-byte-size revert inside the same second reuses stale `.pyc`, so a
mutation harness reports results detached from disk.

**Verified by reproduction** (Python 3.14.6, macOS, 2026-08-04). With mtime pinned via
`touch -t` and every revision exactly 18 bytes:

```
1) compile VERSION = "3.1.1"          -> import sees 3.1.1
2) revert file to VERSION = "3.1.0"   -> import sees 3.1.1   <-- reverted source, MUTANT bytecode
3) delete __pycache__                 -> import sees 3.1.0
   (control) bare `touch mod.py`      -> import sees 3.1.0   <-- mtime bump alone also fixes it
```

Decoded `.pyc` header: `flags=0` (timestamp invalidation), `mtime=1785812400`, `size=18`
— exactly matching `os.stat('mod.py')`. The forward direction reproduces too (a same-size
mutation having *no* effect), which is why both uniform harness verdicts are reachable.

**Sources checked:** [CPython import
reference](https://docs.python.org/3/reference/import.html) — "By default, Python does
this by storing the source's last-modified timestamp and size in the cache file"; "the
import system then validates the cache file by checking the stored metadata … against
the source's metadata"; hash-based `.pyc` "store a hash of the source file's contents
rather than its metadata". [PEP 552](https://peps.python.org/pep-0552/),
[py_compile](https://docs.python.org/3/library/py_compile.html) (`PycInvalidationMode`).
→ `verified`.

### 5. Client-side rate limiting and the hidden token request

**Claim:** the auth/token fetch bypasses a method-level throttle, so two requests leave
in the window the throttle believes holds one; reproduces only on token-issuance days.

**Sources checked:** [Okta OAuth token rate
limits](https://developer.okta.com/docs/reference/rl2-token-oauth/), [eBay OAuth rate
limits](https://developer.ebay.com/api-docs/static/oauth-rate-limits.html), [GitHub REST
rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api),
[AWS Builders' Library on timeouts/retries](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/).

**Where the research narrowed the claim:** providers *do* meter token endpoints (all
three publish limits attached to them), but they do **not** universally share one bucket
with the data API — Okta, eBay and GitHub each meter the token endpoint separately. So
the candidate's implied "the token POST eats your API quota" is not a general truth. The
page therefore rests on the part that is provider-independent — the throttle's own
accounting is wrong because a request left without being counted, and the clock was
stamped before it — and the shared-bucket question is handled as an edge-case row rather
than a premise.

**Evidence** is the contributor's own production timeline (brokerage client, documented
2 req/s): token POST `00.354` → issuance `00.495` → balance rejected `00.543`, on the two
token-issuance days (2026-07-23, 2026-08-04) only. No external source establishes this
for that specific provider. → `field-tested`, not upgraded.

### 6. Call-site enumeration

**Claim:** enumerate callers by call target, not by parameter name; positional callers
carry no keyword text; test helpers reproduce the old shape behind a single hit.

**Sources checked:** [Refactoring catalog — Change Function
Declaration](https://refactoring.com/catalog/changeFunctionDeclaration.html) (URL
verified 200; the public page shows the example but not the full mechanics text, so it
is cited for the named refactoring and its migration-style approach, **not** quoted for
a claim it does not visibly make), [POSIX
grep](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html) for the
"matching is textual, not call-graph-aware" point.

**Evidence** is the contributor's own reproduction: `grep -rn "repo_rows" impl/tests/`
→ 13 hits, all keyword-form, migration scoped as "7 of 13"; full suite then reported
`Ran 472 tests / FAILED (failures=11)`, all in `test_backend.py` where the seed was
`verify()`'s 4th **positional** argument; a follow-up `grep -n "verify(" …` surfaced 8
positional sites plus a `rows_for()` helper feeding the old shape to 5 more.
No external source states the keyword-grep failure mode. → `field-tested`, not upgraded.

### 7. `${VAR:-default}` vs `${VAR-default}`

**Claim:** the colon form substitutes the default for empty as well as unset, so passing
`VAR=` to disable a feature is silently ignored.

**Verified by reproduction** (zsh, macOS, 2026-08-04):

```
V=""    ${V:-default} -> default      ${V-default} -> (empty)
unset V ${V:-default} -> default      ${V-default} -> default
```

**Source checked:** [POSIX Shell §2.6.2 Parameter
Expansion](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html) —
"use of the \<colon\> in the format shall result in a test for a parameter that is unset
or null; omission of the \<colon\> shall result in a test for a parameter that is only
unset." → `verified`.

---

## Existing-layer check

Routed via `INDEX.md`, then read the `backend`, `testing`, `platforms` and `debugging`
domain indexes and every page whose "load when" overlapped.

**Pages read in full before deciding merge-vs-create:**
`testing/quality/tests-that-cannot-fail`, `testing/quality/harness-reverse-controls`,
`testing/quality/checks-that-cannot-pass` (index line),
`testing/data/test-data-and-isolation`, `platforms/shells/portable-shell-scripts`,
`backend/common/reliability/timeouts-and-retries`,
`backend/common/integrations/externally-owned-defaults`, plus the
`backend/python` and `backend/node` subtree indexes.

**Merged rather than created (2):**

- **#3 → `testing/data/test-data-and-isolation`.** The page already carried
  "Filesystem / temp files" and "Global config / environment variables / singletons"
  rows. The uncovered case is narrower and worth a row of its own: production code that
  *derives* a write path from the environment, where the fix is redirecting the variable
  rather than adding a parameter. Added one row to the isolate-by-resource-type table,
  one `Instead of` row (test-only directory parameter → redirect the env var), the Node
  `os.homedir()` source, and `last_verified` → 2026-08-04. No new page.
- **#7 → `platforms/shells/portable-shell-scripts`.** The page's edge-case table already
  had "`set -u` breaks on optional variables → `"${OPT:-}"`", which *uses* `:-` without
  distinguishing it from `-`. Added one edge-case row and two `Instead of` rows covering
  the empty-value feature-flag case, quoted POSIX §2.6.2 into the existing source line,
  `last_verified` → 2026-08-04. No new page.

**Overlaps found but deliberately kept separate:**

- **#2 vs `testing/quality/harness-reverse-controls`** — same *discipline* (negative
  control), different trigger: that page is about citing a harness's **score**, this one
  about a poll loop's **done signal** gating an action. Cross-linked both ways
  (edge-case row added there, `related:` on both) instead of stretching either "load
  when".
- **#2 vs `testing/quality/tests-that-cannot-fail`** — that page is scoped to *tests*
  and their assertions; a tmux/status-file monitor is not a test. Linked, not merged.
- **#4 vs `harness-reverse-controls`** — that page's "every case caught / every case
  survives" rows describe the *symptom*; the pyc mechanism is the Python-specific
  *cause*. Followed the wiki's own common-owns-principle / stack-owns-mechanics split:
  page lives in `backend/python/language`, with a routing edge-case row added to
  `harness-reverse-controls`.
- **#5 vs `backend/common/reliability/timeouts-and-retries`** — that page covers
  timeouts, retry policy, and *concurrency* caps against a slow dependency; it does not
  cover throttling to a published request-rate quota or which layer the throttle wraps.
  Adjacent, cross-linked via `related:`, not merged.
- **#1 vs `backend/common/integrations/externally-owned-defaults`** — both concern
  resources the repo does not own; that page is about a *name* silently ceasing to
  resolve, this one about *permission* to fetch at all. Cross-linked; an edge-case row in
  the new page routes to it for the inherited-source-constant case.

**Conflicts flagged:** none. No existing directive contradicts anything ingested. The
only contradiction found was between candidate #1 and reality, resolved by rewriting the
candidate (logged as a `correction` entry in `log.md`, alongside the `ingest` entry).

**Related-links added (both directions):** `harness-reverse-controls` ↔
`polling-completion-predicates`; `harness-reverse-controls` ↔ `bytecode-cache-staleness`;
`portable-shell-scripts` → `polling-completion-predicates`;
`client-side-rate-limiting` → `timeouts-and-retries`, `jwt-server-side`,
`intermittent-failures`; `crawl-permission-by-user-agent` → `externally-owned-defaults`,
`timeouts-and-retries`; `call-site-enumeration` → `tests-that-cannot-fail`,
`test-data-and-isolation`; `test-data-and-isolation` → `behavior-not-implementation`.

---

## Routing decision

| # | Target | Rationale |
|---|--------|-----------|
| 1 | `backend/common/integrations/crawl-permission-by-user-agent.md` **(new page)** | Existing category. `integrations` already owns "consuming external-API responses / externally-owned defaults"; deciding whether an external publisher permits your fetch is the same concern one step earlier |
| 2 | `testing/quality/polling-completion-predicates.md` **(new page)** | Existing category. `testing/quality` already holds the can-this-check-fail family (`tests-that-cannot-fail`, `checks-that-cannot-pass`, `harness-reverse-controls`); a done-predicate that cannot say "not yet" is the same defect class |
| 3 | `testing/data/test-data-and-isolation.md` **(merge)** | Existing page, exact trigger match — "tests need isolation from state they do not own" |
| 4 | `backend/python/language/bytecode-cache-staleness.md` **(new page)** | Existing category. `backend/python` routes "language traps"; the mechanism is CPython's import cache, so the stack subtree owns the mechanics while `testing/quality` keeps the harness principle |
| 5 | `backend/common/reliability/client-side-rate-limiting.md` **(new page)** | Existing category. `reliability` already owns outbound-call behaviour (timeouts, retries, backoff); staying under a provider's quota is the same axis |
| 6 | `backend/common/refactoring/call-site-enumeration.md` **(NEW category `refactoring`)** | See justification below |
| 7 | `platforms/shells/portable-shell-scripts.md` **(merge)** | Existing page; its edge-case table already used `:-` without distinguishing it from `-` |

### New category: `backend/common/refactoring` — why nothing existing fit

Re-checked every seeded category before creating it. The case is "changing a function's
declaration and migrating its callers":

- `debugging/*` owns **diagnosing a failure**; here nothing is broken yet — the work is a
  planned change, and the failure is what happens if enumeration is incomplete.
- `testing/*` owns **authoring tests**. Broken tests were the *symptom*; the directive is
  a search strategy for production call sites, and the test helpers matter as sources of
  the old shape, not as tests.
- `backend/common/{api-design, orm, errors, concurrency, …}` are each scoped to a runtime
  concern, none of which is code-change methodology.
- No `refactoring` category exists in any of the ten domains (checked all ten indexes).

Placed under `backend/common/` because that subtree is explicitly the **language-agnostic
application-code** home and the wiki has no cross-cutting "code craft" domain.

**Known routing limitation for the owner to weigh:** the directive applies equally to a
frontend signature migration, and a frontend task would not route into `backend`. Two
alternatives if you prefer: (a) promote `refactoring` to a top-level domain in `INDEX.md`,
or (b) add a cross-pointer line from `wiki/frontend/index.md`. I did neither — both change
the domain map, which `AGENTS.md` puts under owner approval. Happy to follow up with
whichever you pick.

---

## Verification run

- **Body length** — all 8 touched pages within the 120-line limit (max 84; new pages 60–65).
- **Page ids** — unique across the wiki; all new ids follow the existing
  `backend-common-*` subtree convention.
- **Link integrity** — every `related:` id and every inline `[page-id]` reference in the
  touched pages resolves to an existing page; every relative link in the four touched
  index files resolves to an existing file.
- **Index invariants** — each new page listed in its domain `index.md` with a "load when"
  line enumerating its distinct use cases; `INDEX.md` backend row updated for the new
  concerns; `log.md` has the `ingest` entry plus the `correction` entry.
- **Style** — no banned vague qualifiers ("usually", "consider", "generally", …) in any
  touched page; every prohibition sits in an `Instead of` row paired with its replacement.
- **Citations** — all 7 cited URLs re-fetched 2026-08-04 and returning HTTP 200. No URL
  was written from memory.
