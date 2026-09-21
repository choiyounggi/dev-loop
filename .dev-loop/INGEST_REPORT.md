# Knowledge flush — 6 insight(s)

Claimed queue ids: `bf675f09e7973bbc`, `6a0cdc6a27637c93`, `ad50053952f28169`,
`354053be0de8d411`, `aca4c8fce4cabd8a`, `66894645015082e9`.
All six were handled: 2 new pages, 1 amended page, 1 folded onto open PR #183, 2 dropped.
Branch `knowledge/choiyounggi-20260917-160110`, flush run `20260917-160035-87121`.

## Verified best-practice

**1. `bf675f09e7973bbc` — a freshness manifest must record skipped inputs too** (→ new page, `confidence: verified`)

Claim: when a derived index judges freshness by comparing a stored input-hash manifest
with the current input set, and the builder may skip an unprocessable input, the skipped
input's hash still belongs in the manifest (it is excluded from the output table only).
A manifest filled from successes can never equal the current inputs, so status reads
stale straight after a successful build and every trigger rebuilds — with no error
logged, because each rebuild succeeds.

- https://github.com/tirth8205/code-review-graph/issues/944 — fetched this session via
  `gh api`. An independent project hit the same loop in its version-marker form: the
  builder refuses to record its identity version when any file failed to parse, so
  "**every** incremental update becomes a full rebuild, indefinitely … it is silent apart
  from an INFO log". Its proposed direction matches the directive: "Record the version
  and track the specific failed files, so only those are retried".
- https://aws.amazon.com/builders-library/caching-challenges-and-strategies/ — fetched
  this session. Negative caching ("cache the error response … using a different TTL than
  positive cache entries"; "Don't cause or amplify an outage by repeatedly asking for the
  same downstream resource and discarding the error responses") is the remote-call form
  of recording a failed input. Used for the principle only, not for the manifest shape.
- Own reproduction this session (Python 3, two-file fixture, three simulated sessions
  that rebuild when stale): success-only manifest → `builds over 3 sessions: 3 | final
  status: stale`; all-inputs manifest → `builds: 1 | final status: fresh`; identical
  output table in both runs.
- Session evidence corroborated read-only in the originating worktree: the index builder
  carries the fix (docstring "A page that cannot be parsed still gets its sha recorded")
  and `tests/wiki-index.bats` has the case "an unparseable page still lets the index
  settle to fresh" with a repair-the-page negative control. That work is uncommitted in
  its own worktree, so I read it and did not run it there.

**2. `6a0cdc6a27637c93` — uv under a relocated HOME needs both `UV_CACHE_DIR` and `UV_PYTHON_INSTALL_DIR`** (→ new page, `confidence: verified`)

Claim: uv resolves its package cache and its managed interpreters from two separate
HOME/XDG-derived locations. Carrying only the cache across a HOME swap makes uv fall back
to a different Python, so `--offline` fails on packages that are cached; a suite that
turns that failure into `skip` then passes without executing the cases.

- https://docs.astral.sh/uv/reference/storage/ — fetched this session. Cache:
  `$XDG_CACHE_HOME/uv` or `$HOME/.cache/uv`. "By default, Python versions managed by uv
  are stored in a `python/` subdirectory of the persistent data directory, e.g.,
  `~/.local/share/uv/python`" — overridden by `UV_PYTHON_INSTALL_DIR`. Tools: `tools/`
  under the same data dir, overridden by `UV_TOOL_DIR`.
- https://docs.astral.sh/uv/concepts/cache/ — fetched this session. Precedence:
  `--no-cache` temp dir, then "`--cache-dir`, `UV_CACHE_DIR`, or `tool.uv.cache-dir`",
  then the system default. The page has no sentence on `--offline`, so the page body
  makes no documentation claim about `--offline` beyond the field measurement.
- Own reproduction this session (uv 0.11.5, macOS arm64): `HOME=<scratch>` moved both
  `uv cache dir` and `uv python dir` under the scratch dir and removed the managed
  `cpython-3.14.4` / `cpython-3.12.13` from `uv python list --only-installed` (only
  Homebrew and python.org interpreters remained); exporting both variables with the
  pre-swap values restored both locations. `XDG_CACHE_HOME` / `XDG_DATA_HOME` alone moved
  the cache and the python/tools dirs respectively.
- Not reproduced here: the exact "not found in the cache" failure (it needs the
  originating project's cache contents). It is recorded on the page as a field
  measurement, not as a documented behavior. A Windows inference I first drafted
  (which variable relocates `%LOCALAPPDATA%\uv\cache`) was removed as unverifiable on
  this machine; the row now states only the documented default.

**3. `ad50053952f28169` — a backtick span inside a double-quoted `grep -F` pattern is executed, not matched** (→ merged into an existing `verified` page)

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — fetched
  this session. 2.2.3: "The backquote shall retain its special meaning introducing the
  other form of command substitution"; 2.2.2: "A single-quote cannot occur within
  single-quotes."
- Own reproduction this session under sh, bash, zsh and dash: the double-quoted
  raw-backtick pattern printed `wiki-local/: No such file or directory` and `grep -qF`
  returned 1 with the text present; `printf '[%s]'` showed grep received `[own  layer]`.
  Single-quoted, `` \` ``-escaped inside double quotes, and `grep -F -f file` each
  returned 0.
- Correction to the candidate's evidence line: as harvested it shows the pattern with
  `` \` `` escapes, which the reproduction proves would have matched. The originating
  gate file (read this session) now holds the single-quoted form, with the pattern
  shortened to avoid the apostrophe in "project's" — that apostrophe case is why the
  merge adds a second row (`-f file` / shorten the span) rather than only "single-quote it".

**4. `354053be0de8d411` — per-site mutation of a source-text wiring test** (→ dropped, already covered; claim itself is sound)

The directive (enumerate the protected sites, delete each one, require red) is already
the verified content of `testing-quality-source-text-wiring-assertions` steps 1 and 5,
sourced to Stryker and PIT. No new verification was needed.

**5. `aca4c8fce4cabd8a` — coordinator, not the design author, invokes the plan reviewer** (→ folded onto #183, `field-tested` at most)

- https://code.claude.com/docs/en/sub-agents — fetched this session; all three quoted
  platform facts in the candidate are present verbatim ("Claude uses the `SendMessage`
  tool with the agent's ID or name as the `to` field to resume it"; "up to three layers
  below the main conversation"; "omit `Agent` from its `tools` list or add it to
  `disallowedTools`").
- The handshake itself is a plan decision with no measured outcome, so it is not
  evidence for a `verified` claim; stated as such in the fold comment.

**6. `66894645015082e9` — README wording for the task-planner agent** (→ dropped, unverifiable as a best practice)

A repository-specific wording decision (which README line gains which sentence). It has
no trigger outside this repo and no directive a future task elsewhere could apply.

## Existing-layer check

Pages read: backend-common-caching-invalidation-and-stampede, platforms-tools-version-keyed-artifact-cache, testing-quality-source-text-wiring-assertions, platforms-shells-escapes-in-shell-string-literals, platforms-shells-command-text-inspected-before-execution, platforms-shells-portable-shell-scripts, testing-data-test-data-and-isolation

Also consulted: `INDEX.md`, `wiki/backend/index.md`, `wiki/platforms/index.md`; whole-wiki
greps for `manifest`, `UV_CACHE_DIR|UV_PYTHON_INSTALL_DIR`, `uv run|uv sync`,
`backtick|backquote|command substitution`, `mutat`, `source-text|wiring test`,
`self-grad|fresh-context` (all hits listed, none truncated); grep-only look at
`mutation-harness-file-custody` and `tests-that-cannot-fail` for restore-verification and
`skip` coverage.

- **#1 manifest:** `invalidation-and-stampede` covers read caches (TTL, delete-on-write,
  stampede, negative caching) and `version-keyed-artifact-cache` covers a version-string
  key that never changes. Neither covers a per-input manifest with skipped inputs — new
  trigger → **new page**. Linked both ways with `invalidation-and-stampede` (rule 6,
  negative caching, is the remote-call analogue); one-way to `version-keyed-artifact-cache`.
- **#2 uv:** no page mentions `UV_CACHE_DIR` or `UV_PYTHON_INSTALL_DIR` (0 hits).
  `test-data-and-isolation` has the row that tells you to point `HOME` at a scratch dir —
  this page is the consequence for a tool that locates its state through HOME. New
  trigger → **new page** in `platforms/toolchains`. No conflict: the new page keeps `HOME`
  relocated and overrides uv's stores, consistent with that row.
- **#3 backticks:** `portable-shell-scripts` step 7 already states the rule for message
  text, and `escapes-in-shell-string-literals` owns pattern literals. Same trigger family,
  same directive (single-quote) → **merged** into `escapes-in-shell-string-literals`: one
  "When this applies" sentence, two edge-case rows, one `Instead of` row, two source
  bullets, `last_verified` bumped. No conflicting directive.
- **#4 per-site mutation:** duplicate of `source-text-wiring-assertions` steps 1 and 5 and
  its `Instead of` row "Ship the anchored guard because the suite is green". The only
  nuance (the sites were documentation sentences) is covered by that page's doc-gate edge
  row. The page is also at its body-line budget. → **no edit**.
- **Related-links deliberately one-way:** `test-data-and-isolation`, `version-management`
  and `environment-resync-removes-undeclared-packages` are each modified by open PRs
  (#179, #181, #188, #191), and their `related:` lines are the usual conflict point, so
  the uv page links to them without a back-link in this PR. `escapes-in-shell-string-literals`
  is touched by #189 on its `related:` line only; this PR leaves that line unchanged.
- Checks run in the checkout: `node scripts/wiki-structure-checks.js wiki` →
  `pages: 280, indexes: 13, findings: 0`; `node scripts/wiki-lint-prohibitions.js wiki` →
  `directives: 75, violations: 0` (75 before and after, so the bats pin is unchanged);
  `bats tests/wiki-lint-prohibitions.bats tests/wiki-structure-checks.bats
  tests/wiki-lint-model-era.bats tests/wiki-lint-score.bats` → `1..38`, 38 `ok`, 0 `not ok`.
  New page bodies are 68 and 71 lines; the amended page is 67.

**Independent review before commit (8 files changed).** A fresh-context reviewer with an
adversarial brief re-fetched every cited URL, re-ran the uv and backtick reproductions
under sh/bash/zsh/dash, re-ran the linters and the 38 bats cases, and checked this
report's PR-number claims against the fetched heads. Verdict PASS-WITH-FIXES, three
findings, all applied: (1) the manifest page's "retry only when the hash changes" was
overstated — a builder upgrade that can now parse a skipped file leaves its hash
unchanged, so an edge row now keys retry on (input hash, builder version); (2) and (3)
the two field-measurement bullets read as if executed in this flush — both are now
labelled "Reported field measurement … not re-executed / not independently reproduced",
and uv step 2 separates the reproduced fallback from the reported `--offline` failure.
The reviewer left the working tree byte-identical (diff compared against a pre-review
snapshot).

## Open-PR check

Listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`:
#179, #180, #181, #182, #183, #185, #186, #187, #188, #189, #190, #191, #205, #207, #208
(15 heads). Each head was fetched and its `origin/main...head -- wiki/` diff grepped per
candidate; every hit file was listed.

| Candidate | Overlapping open head | Verdict |
|-----------|----------------------|---------|
| `bf675f09e7973bbc` manifest | none — `manifest`/`fresh` hits in #183, #185, #186 are unrelated (artifact cache version bump, graph mtime gate, key regeneration) | **new** |
| `6a0cdc6a27637c93` uv | none — sole `uv run` hit is a verify-command table cell in #179 | **new** |
| `ad50053952f28169` backticks | none — 0 added lines match `backtick|backquote` in any head; #189 edits only the target page's `related:` line | **new** (merge into the existing page) |
| `354053be0de8d411` per-site mutation | none in flight; duplicate of the merged layer | **drop** |
| `aca4c8fce4cabd8a` reviewer ownership | #183 adds `qa/process/fresh-context-code-review`, whose trigger is "designing which session or subagent an automated review stage dispatches to" | **fold** — unique addition (nested-spawn edge row, coordinator-owned handshake) noted on #183: https://github.com/choiyounggi/dev-loop/pull/183#issuecomment-5710463729 |
| `66894645015082e9` README wording | none | **drop** (project-specific) |

No sibling duplicate PR is opened by this flush.

## Routing decision

| Candidate | Target | Decision |
|-----------|--------|----------|
| `bf675f09e7973bbc` | `backend/common/caching/input-manifest-freshness-with-skipped-inputs` | New page in the existing `caching` category; `wiki/backend/index.md` row added |
| `6a0cdc6a27637c93` | `platforms/toolchains/uv-state-directories-under-a-relocated-home` | New page in the existing `toolchains` category. The candidate's hint was `testing`, but the knowledge is where a tool keeps per-user state, which is the platforms domain; the testing-side rule (relocate HOME) already lives in `test-data-and-isolation` and is linked. `wiki/platforms/index.md` row added |
| `ad50053952f28169` | `platforms/shells/escapes-in-shell-string-literals` | Merged; that page's index "load when" line extended with the backtick symptom |
| `354053be0de8d411` | — | Dropped as covered by `testing/quality/source-text-wiring-assertions` |
| `aca4c8fce4cabd8a` | `qa/process/fresh-context-code-review` (on #183) | Folded by PR comment; not ingested here |
| `66894645015082e9` | — | Dropped as project-specific |

No new category was created.
