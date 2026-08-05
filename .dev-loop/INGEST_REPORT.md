# Knowledge flush — 7 insight(s)

Drained 7 queued candidates from 5 session files in `~/.dev-loop/queue/`.
Result: **6 new pages, 1 merge into an existing page, 1 new category
(`testing/migration`), 0 dropped.** Every directive was re-verified against
primary sources or a local reproduction before ingest; two candidates were
**corrected or narrowed** during verification (see I-4 and I-5).

---

## Verified best-practice

### I-1 — Capturing a tool's warnings when it exits 0 (`confidence: verified`)

**Claim.** A hook that branches on exit status misses warnings, because warnings
are not failures and the tool exits 0; capture stderr instead, with the
redirections written `2>&1 >/dev/null`, and return exit 2.

**Sources checked.**
- https://code.claude.com/docs/en/hooks — exit-code-2 table row for `PostToolUse`:
  Can block? "No", "Shows stderr to Claude; the tool already ran". "Any other exit
  code is a non-blocking error … the transcript shows a `<hook name> hook error`
  notice followed by the first line of stderr". On exit 0, "stdout is written to
  the debug log but not shown in the transcript" except for `UserPromptSubmit`,
  `UserPromptExpansion`, `SessionStart`.
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html —
  "If more than one redirection operator is specified with a command, the order of
  evaluation is from beginning to end"; `[n]>&word` makes fd n "a copy of the file
  descriptor denoted by word".

**How verified.** Both doc facts quoted verbatim, plus a local reproduction
(2026-08-05, bash 3.2, macOS) with a stub writing an artifact line to stdout, a
`warning:` line to stderr, exit 0: `2>&1 >/dev/null` → `warning: unused variable x`
only; `2>/dev/null >&1` → `BUILD-ARTIFACT-ON-STDOUT` only; plain `2>&1` → both;
the exit-code branch saw `rc=0` in every case; a diagnostic-free stub → empty capture.

**Added beyond the candidate.** The candidate said "exit 2". The docs make this
stronger and load-bearing: exit 2 is the *only* non-zero code that delivers stderr
to the model — every other code surfaces one line to the *user* as a hook error.
That precision is now in the page.

### I-2 — Attributing leaked test artifacts (`confidence: verified`)

**Claim.** Count leftovers by name prefix and intersect with creation call sites;
fix by switching to context-managed creators; enforce with an AST rule proven red
against the unfixed tree.

**Sources checked.**
- https://docs.python.org/3/library/tempfile.html — `mkdtemp()`: "The user of
  `mkdtemp()` is responsible for deleting the temporary directory and its contents
  when done with it"; `TemporaryDirectory()` removes the tree "On completion of the
  context or destruction of the temporary directory object".
- https://docs.pytest.org/en/stable/how-to/tmp_path.html — runner-provided per-test
  temp directory and its retention policy.
- https://docs.semgrep.dev/writing-rules/testing-rules — `ruleid:`/`ok:`
  two-direction rule fixtures.

**How verified.** The cleanup-ownership asymmetry (raw creator hands ownership to
the caller; the managed form removes the tree itself) is the documented mechanism
behind the leak and is quoted verbatim. The prove-red-first step is the repo's own
already-verified `checks-that-cannot-pass` directive applied to a new artifact.
Field measurement (998 leftovers → two prefixes at 686/306; 6 `mkdtemp` call sites,
exactly 2 without cleanup; suite artifact delta 0; 72M → 3.3M) is retained as dated
field context, not as the source of the general rule.

### I-3 — Config keys written ahead of their consumer (`confidence: verified`)

**Claim.** "Unknown keys are ignored" is a per-parser setting, not a convention;
read the consumer's parsing code, and record parser + version + `file:line` + date.

**Sources checked.**
- https://pydantic.dev/docs/validation/latest/api/pydantic/config/ — `extra` takes
  `'ignore'` / `'forbid'` / `'allow'`, default `'ignore'`; with `'forbid'`
  "Providing extra data is not permitted, and a `ValidationError` will be raised".
- https://json-schema.org/understanding-json-schema/reference/object — "By default
  any additional properties are allowed"; `additionalProperties: false` means "no
  additional properties will be allowed"; `unevaluatedProperties` "can recognize
  properties declared in subschemas".
- https://serde.rs/container-attrs.html — default: "unknown fields are ignored for
  self-describing formats like JSON"; `deny_unknown_fields` makes it "always error
  during deserialization when encountering unknown fields".

**How verified.** The three sources establish both halves — the permissive default
(why the assumption often holds) and the strict opt-in (why it is not safe to
assume). The field evidence was re-checked live this flush: guardrails 1.0.0
`hooks/bash-guard.sh:71` reads `jq -r --arg r "$id" '.rules[$r].mode // empty'`
(confirmed by reading the installed file) and `grep -rn allowPaths` over the whole
1.0.0 tree returns 0 hits (confirmed).

### I-4 — Restoring a file you mutated to prove a test can fail (`confidence: verified`) — **candidate corrected**

**Claim as queued.** "`git checkout -- <path>` restores from HEAD; reserve it for
work that is already committed."

**Correction.** It restores from the **index**, not HEAD.
- https://git-scm.com/docs/git-checkout — with no tree-ish: "Replace the specified
  files and/or directories with the version from the index"; "`git checkout
  file.txt` will discard any unstaged changes to `file.txt`".
- https://git-scm.com/docs/git-restore — "By default, if `--staged` is given, the
  contents are restored from `HEAD`, otherwise from the index."

**Why this matters.** The correction yields a remedy the candidate did not have:
`git add` the fix **before** mutating, and `git checkout --` then reverts only the
mutation. Reproduced 2026-08-05 in a scratch repo — unstaged fix + mutation +
`git checkout --` → fix and mutation both gone; the same sequence with the fix
staged → fix preserved, mutation reverted; copy-and-`shasum -a 256` restore →
byte-identical in either state. The page carries a three-row state table instead of
the candidate's blanket prohibition.

### I-5 — Client-side throttle bypassed by credential refresh (`confidence: verified`) — **narrowed**

**Claim.** Count HTTP requests, not public-method calls; put the throttle below
credential refresh; stamp immediately before send; do not let a zero-initialized
timestamp exempt the first call.

**Sources checked.**
- https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy —
  "A single end user request (e.g., Login or Signup) typically initiates multiple
  requests to Authentication API Endpoints"; "Auth0 evaluates requests against the
  global limit for the API, and then evaluates requests against the rate limit for
  specific API endpoints."
- https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/ —
  client-side budgeting of every remote call.

**Provider-specific limit NOT confirmed — page narrowed accordingly.** A search for
the KIS OpenAPI per-second quota (`한국투자증권 유량 제한`) returned secondary sources
only (20/s for live accounts, lower for mock) and no primary doc for the 2/s figure
in the queued evidence. The page therefore states no provider's number as fact — the
quota is a parameter — and the KIS log timeline (token POST `…00.354` → issuance
`…00.495` → balance failure `…00.543`) stays in a dated "Field context" block. The
Auth0 quote carries the general mechanism, which is what the directive rests on.

### I-6 — Enumerating call sites of a changed signature (`confidence: verified`)

**Claim.** Enumerate by callee token, not by parameter name — positional callers
carry no parameter name — and sweep test helper definitions separately.

**Sources checked.**
- https://docs.python.org/3/reference/expressions.html (Calls) — "If there are N
  positional arguments, they are placed in the first N slots"; "for each keyword
  argument, the identifier is used to determine the corresponding slot".
- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/ —
  `textDocument/references` and `callHierarchy/incomingCalls` (both confirmed
  present on the page) resolve callers from the language's semantics, not from text.

**How verified.** The language reference makes the blind spot a property of call
syntax rather than an anecdote: the parameter name exists at the call site only in
the keyword form, so a `param=` grep cannot see positional callers by construction.
The LSP citation supports the "reconcile a textual count with a semantic one" step.
`refactoring.com/catalog/changeFunctionDeclaration.html` was attempted and returned
only the page shell — **not cited**, since the body could not be read. Field
measurement (13 keyword hits → `Ran 472 tests / FAILED (failures=11)`, 8 positional
call sites + a `rows_for()` helper feeding 5 more) retained as dated field context.

### I-7 — `${VAR:-default}` swallows an empty value (`confidence: verified`)

**Claim.** `VAR=` cannot turn off a feature read as `${VAR:-default}`; pass a value
the script's own validation rejects, or change the script to `${VAR-default}`.

**Source checked.**
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html —
  "use of the `<colon>` in the format shall result in a test for a parameter that is
  unset or null; omission of the `<colon>` shall result in a test for a parameter
  that is only unset"; `${parameter:-[word]}`: "If parameter is unset or null, the
  expansion of word … shall be substituted".

**How verified.** POSIX text quoted verbatim, plus a cross-shell reproduction
(2026-08-05, macOS): with `VAR=`, `${VAR:-tmux}` → `tmux` and `${VAR-tmux}` → empty
in **bash 3.2, `/bin/sh`, and zsh alike**. Also confirmed the escape hatch:
`command -v "${WATCH_TMUX:-tmux}"` succeeds for the empty value (feature stays on)
and fails for `/nonexistent-tmux` (feature disabled).

---

## Existing-layer check

**Pages read in full before routing:** `AGENTS.md`, `INDEX.md`, and the domain
indexes for testing, platforms, backend, infrastructure, debugging, qa; then
`testing/quality/tests-that-cannot-fail`, `testing/quality/checks-that-cannot-pass`,
`testing/quality/harness-reverse-controls`, `testing/quality/behavior-not-implementation`,
`testing/data/test-data-and-isolation`, `platforms/shells/portable-shell-scripts`,
`platforms/shells/command-text-inspected-before-execution`,
`backend/common/reliability/timeouts-and-retries`,
`backend/common/integrations/externally-owned-defaults`,
`infrastructure/config/environment-config`, `debugging/concurrency/intermittent-failures`.

### Merged rather than created

| Insight | Overlap found | Resolution |
|---------|---------------|------------|
| I-4 | `tests-that-cannot-fail` step 1 already ends "…re-verify red **before restoring the code**" — the restore mechanism was the page's missing half, not a new situation | **Merged.** Added step 2 (restore-mechanism state table) and step 3 (confirm by test count), renumbered the following steps, added 2 edge-case rows and 1 `Instead of` row, added both git sources and a Field context block, bumped `last_verified` to 2026-08-05. Body 58 → 91 lines, under the 120 limit |

### Created new, with the overlap ruled out

| Insight | Nearest existing page | Why it is a distinct case |
|---------|----------------------|---------------------------|
| I-1 | `platforms/shells/command-text-inspected-before-execution` | That page is the **PreToolUse** direction (a gate reading a command before it runs). I-1 is the **PostToolUse** direction (getting a tool's output back to the model). Complementary, not overlapping — cross-linked in `related` |
| I-2 | `testing/data/test-data-and-isolation` (row: "Filesystem / temp files → fresh per-test temp dir, remove it in teardown") | That row states the convention; I-2 is what to do when artifacts have **already** accumulated and the producer is unknown — attribution, then enforcement. Merging would make one page answer two situations, against the one-case-per-page rule. **That row now cross-links to the new page**, and `related` was extended |
| I-3 | `backend/common/integrations/externally-owned-defaults` | That page is about a config **value** naming an external resource that may vanish. I-3 is about a config **key** an external parser may reject. Different failure (400 at request time vs process refuses to start) and different check (query the owner's catalog vs read the consumer's parser) |
| I-3 | `infrastructure/config/environment-config` | Owns config shape and startup validation for services **you** run. Silent-drop-vs-hard-reject in a foreign parser appears nowhere in it |
| I-5 | `backend/common/reliability/timeouts-and-retries` | Has a 429 row — how to *react* to being limited. I-5 is how to *stay under* a quota, and specifically which layer the limiter belongs at. No page covered client-side rate limiting |
| I-6 | `testing/quality/behavior-not-implementation` | Its load-when line mentions "a behavior-preserving refactor broke tests"; I-6 is a **signature-changing** migration, where tests are *supposed* to change. Opposite invariant — merging would have contradicted that page's step 2 |
| I-7 | `platforms/shells/portable-shell-scripts` | Its `set -u` edge row recommends `"${OPT:-}"` but never distinguishes colon from no-colon. Rather than reopen that row's meaning inside a page already at 66 lines, the colon rule got its own page and both are `related`-linked |

### Conflicts flagged

- **None contradicting existing directives.** The one adjacency worth naming:
  `portable-shell-scripts` recommends `"${OPT:-}"` for `set -u` safety, which is
  correct for its case (avoid an unbound-variable abort where empty and unset mean
  the same thing). I-7's page states the condition that separates the two forms and
  reproduces that guidance in its step 5 rather than overriding it.
- **I-4 corrects a claim in the queued candidate, not in the wiki** (HEAD vs index).
  No shipped page carried the wrong version.

### Related-links added

- `testing-data-test-data-and-isolation` → +`testing-data-leaked-test-artifacts`
  (frontmatter `related` and the temp-files row).
- New pages link outward to: `platforms-shells-command-text-inspected-before-execution`,
  `platforms-shells-portable-shell-scripts`, `platforms-environment-path-resolution`,
  `testing-quality-checks-that-cannot-pass`, `testing-data-test-data-and-isolation`,
  `debugging-methodology-hypothesis-testing`, `testing-quality-behavior-not-implementation`,
  `qa-process-regression-scope`, `infrastructure-config-environment-config`,
  `backend-common-integrations-externally-owned-defaults`,
  `backend-node-boundaries-runtime-validation`, `backend-python-boundaries-runtime-validation`,
  `backend-common-reliability-timeouts-and-retries`, `backend-common-auth-jwt-server-side`,
  `debugging-concurrency-intermittent-failures`.
- All `related:` ids and inline `[page-id]` references were checked to resolve
  against the id set in `wiki/**` — 0 broken.

---

## Routing decision

| # | Insight (one line) | Target | New? |
|---|--------------------|--------|------|
| I-1 | Tool warns on stderr and exits 0 → capture stderr, `2>&1 >/dev/null`, exit 2 | `platforms/shells/zero-exit-diagnostics-into-a-hook.md` | new page |
| I-2 | Attribute leaked temp artifacts by prefix count, then enforce with an AST rule proven red | `testing/data/leaked-test-artifacts.md` | new page |
| I-3 | Read the consumer's parser before pre-declaring an unreleased config key | `infrastructure/config/keys-ahead-of-their-consumer.md` | new page |
| I-4 | Restoring a hand-mutated file when the work under test is uncommitted | `testing/quality/tests-that-cannot-fail.md` | **merge** |
| I-5 | Credential refresh bypasses a wrapper-level throttle; the first call is unmetered | `backend/common/reliability/client-side-rate-limiting.md` | new page |
| I-6 | Enumerate call sites by callee, not parameter name; sweep test helpers | `testing/migration/call-site-enumeration.md` | new page + **new category** |
| I-7 | `${VAR:-d}` substitutes for empty as well as unset, so `VAR=` cannot disable | `platforms/shells/unset-versus-empty-parameters.md` | new page |

### Domain choices worth stating

- **I-1 → platforms, not testing** (the queued hint said `testing`). The mechanism is
  shell stream/exit-status semantics plus a hook protocol, and `platforms/shells`
  already owns the mirror-image page for the PreToolUse direction. Nothing about it
  concerns writing tests.
- **I-2 → testing/data, not debugging.** The routing protocol sends you to the domain
  owning the artifact you will change; the artifacts here are test fixtures and the
  fix lands in test setup. The attribution technique cross-links to
  `debugging-methodology-hypothesis-testing` rather than living there.
- **I-3 → infrastructure/config, not backend/integrations.** The artifact changed is a
  config file, and `infrastructure/config` owns config shape and validation.
  Cross-linked to `externally-owned-defaults` for the value-side twin.
- **I-5 → backend/common/reliability**, language-agnostic outbound-call concern, in
  the same category as `timeouts-and-retries`, which it cross-links.
- **I-7 → platforms/shells** as a sibling of `portable-shell-scripts`.

### New category: `testing/migration`

`wiki/testing/migration/` is the only new category. Justification: the existing
testing categories are `strategy` (which level to test at), `quality` (whether a test
can detect a defect), `data` (fixtures and isolation), `mocking`, `flaky`, `async`,
and `e2e` — every one is about the **content of a test**. I-6 is about keeping a
suite **correct across a change to the code it calls**, which none of them covers;
filing it under `quality` would put a call-site-search directive beside
assertion-strength directives and blur both load-when lines.
`qa/process/regression-scope` is the nearest neighbour and is cross-linked, but it
scopes *what to re-test*, not *how to find every caller*.

**Logged as a gap, deliberately.** `testing` is the best available home, not an
obviously right one — the directive generalizes past tests to any signature
migration, and no domain owns cross-cutting refactoring mechanics. A `gap` entry in
`log.md` records this and proposes revisiting it as a domain-level decision (owner's
call) if a second refactoring-shaped insight arrives, rather than growing `testing/`
sideways one page at a time.

### Index and log updates

- `INDEX.md`: route lines extended for testing (leaked artifacts, signature
  migration), backend (client-side rate limiting), infrastructure (keys parsed by
  components you do not own), platforms (stderr diagnostics into a hook,
  unset-vs-empty knobs).
- `wiki/testing/index.md`: domain blurb extended; new `## migration` section;
  `leaked-test-artifacts` listed; `tests-that-cannot-fail` load-when line extended to
  name the merged use cases (restore mechanism, dropped suite total).
- `wiki/platforms/index.md`, `wiki/infrastructure/index.md`, `wiki/backend/index.md`:
  one row each for the new page, load-when lines enumerating distinct use cases.
- `log.md`: one `ingest` entry and one `gap` entry, both dated 2026-08-05.

### Maintenance invariants (checked mechanically)

| Invariant | Result |
|-----------|--------|
| Every new page listed in its domain index | 6/6 |
| Every domain in `INDEX.md` | unchanged, 10/10 |
| `log.md` entry appended | 2 entries (ingest + gap) |
| Every `related:` id and inline `[page-id]` resolves | 0 broken |
| Page id matches file path | 7/7 |
| Body ≤ 120 lines | max 91 (`tests-that-cannot-fail` after the merge) |
| Banned vague qualifiers | 0 (one "usually" was caught in the check and rewritten) |
| Every "don't" paired with an "instead" | all prohibitions live in `Instead of` tables; 6/6 new pages have one |

---

## Queue

7 candidates in, 7 processed, 0 dropped, 0 left pending. The processed rows are
moved to `~/.dev-loop/queue/.processed.jsonl` and removed from their session files
after this PR is opened.
