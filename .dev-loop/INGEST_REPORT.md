# Knowledge flush — 3 insight(s)

Queue drained: 3 pending candidates (2 × `platforms`/`backend`, 1 × `testing`).
Result: **2 pages ingested, 1 candidate retired as already in flight.**

> **Read this first.** My initial existing-layer check was contaminated and I reversed
> two of its three conclusions. The checkout carried **untracked leftovers from an
> earlier flush that died before committing** — `git reset --hard origin/main` does not
> remove untracked files. Two pages were sitting in the working tree looking exactly
> like merged wiki content while belonging to no branch, no PR, and not to `main`.
> I only caught it when `git status` staged them as **new** rather than modified.
> Everything below is re-derived against clean `origin/main` **plus the 7 open PRs**,
> which the skill's dedup step does not currently mention and which turned out to
> matter. See "What I got wrong" at the end.

## Verified best-practice

### 1. Non-interactive CLI blocking on stdin → **already in flight, not ingested**

The knowledge is real and I verified it independently, but it is **already an open
PR**: `wiki/platforms/processes/non-interactive-cli-invocation.md` is added by both
**PR #11** and **PR #12**, same page id, same directive. Opening a third copy would
have been the third duplicate of one insight. Retired against PR #12.

What I verified before finding the overlap (offered as review material for whichever
PR survives, since **neither** currently cites any of it):

| Source | What it establishes |
|--------|---------------------|
| <https://pubs.opengroup.org/onlinepubs/9699919799/functions/read.html> | Why bare `&` is not a fix: SIGTTIN on "a member of a background process group attempting to read from its controlling terminal" |
| <https://man.freebsd.org/cgi/man.cgi?nohup(1)> + local `man nohup` (macOS 15) | BSD `nohup` DESCRIPTION covers SIGHUP, stdout and stderr only — stdin is never mentioned. PR #12 asserts the stdin redirect "is a GNU extension" without citing the BSD page |
| <https://man7.org/linux/man-pages/man1/nohup.1.html> | GNU side of the same divergence: "If standard input is a terminal, redirect it from an unreadable file" |
| <https://code.claude.com/docs/en/headless> | "Non-interactive mode reads stdin, so you can pipe data in"; `-p` background shells end "about five seconds after Claude has returned its final result **and stdin has closed**" — an open descriptor gates *exit*, not just input |

**Correction to the harvested candidate**, worth carrying into whichever PR merges: it
credited the fix to `nohup (stdin=/dev/null)`. That is wrong on macOS — BSD `nohup`
leaves stdin attached. The portable directive is an explicit `</dev/null`, which is
what both open PRs already say.

I also **could not substantiate** the candidate's stated mechanism (blocking at a
*tool-approval prompt*). For Claude Code the docs say an unpermitted tool makes the run
**abort**, not hang. Flagging it so it does not get promoted into a page later.

### 2. LLM client output cap vs the serving model's window → `backend` (ingested)

This is the conclusion I reversed. My first pass called it a duplicate of
`backend/common/llm/context-window-budget.md` — but that page is one of the orphans: it
is **not in `main` and not in any open PR**. `main` has no LLM page at all, so the
knowledge was genuinely missing. Ingested using that already-authored page.

Claims spot-checked before vouching for it:

| Claim | Check |
|-------|-------|
| `ANTHROPIC_BASE_URL` wording | Quoted verbatim from <https://code.claude.com/docs/en/env-vars>; matches the page exactly |
| The window holds request *and* generation; `max_tokens` is a reservation inside it | <https://platform.claude.com/docs/en/build-with-claude/context-windows> |
| LiteLLM raises `ContextWindowExceededError` as a 400 | <https://docs.litellm.ai/docs/exception_mapping> |
| Base URL is the root, not `/v1` | <https://docs.vllm.ai/en/stable/serving/integrations/claude_code/> sets `ANTHROPIC_BASE_URL=http://localhost:8000` |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` / `CLAUDE_CODE_MAX_CONTEXT_TOKENS` exist despite being absent from the published env-vars page | Re-confirmed in the shipped v2.1.220 binary: **10 and 6 occurrences**, against an `ANTHROPIC_BASE_URL` **positive control at 43** |

That last check is the one claim resting on binary inspection rather than docs, so it
is the one to challenge if you disagree. My first probe returned **0 for everything** —
`claude` resolves to a shell function, so `command -v` yielded a bare name and `strings`
read nothing. The uniform zero was the tell; the positive control is what turned it into
a real measurement. (Which is, with some irony, insight 3.)

**Confidence: `verified`** (as authored — every directive carries an official doc).

### 3. Verification-harness reverse controls → `testing` (ingested)

Also an orphan (`wiki/testing/quality/harness-reverse-controls.md`) — authored by the
dead flush, in no branch and no PR. **Not** covered by `main` or by the open PRs: #8
(`spec-artifact-checks`) and #9 (`document-conformance-checks`) both add *per-check
negative controls*, which is the adjacent layer this page explicitly distinguishes
itself from — "a per-check control asks *can this check go red*, the harness control
asks *can this harness go green*". Ingested, with my own verification folded in.

Sources I checked independently, and what each settles:

| Source | What it establishes |
|--------|---------------------|
| <https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/> | The control is sound in principle: an equivalent mutant has no observable difference to detect and "There is no definitive way for Stryker to find and ignore them" — so a no-op returning *caught* means something other than the assertions is failing |
| <https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/> | **My addition.** `Killed`/`Survived` are modelled apart from `Timeout`, `Runtime error`, `Compile error`, and the score is "detected / valid * 100" — errored cases leave the denominator. That is precisely the accounting error in the field case |
| <https://stryker-mutator.io/docs/stryker-js/troubleshooting/> | Baseline requirement, and "No tests were executed. Stryker will exit prematurely." treated as failure rather than a clean sweep |
| <https://pitest.org/quickstart/basic_concepts/> | Second toolchain agreeing: "non viable", "memory error", "run error" are outcomes distinct from killed |

**Changes I made to the orphan page:** added `Do this` step 6 (score `detected / valid`,
errored cases out of the denominator), added the two Stryker sources above, renumbered
the closing step, bumped `last_verified` to 2026-08-02.

**Confidence: `verified`** (mechanism and scoring rule from two independent framework
specifications; the incident is cited as a dated field reproduction, not as the basis
for the directive).

## Existing-layer check

Routed via `INDEX.md` → domain `index.md` → every page whose "load when" overlapped,
**then** re-run against `origin/main` and `gh pr list` after the contamination surfaced.

**Read in full:** `platforms/index.md`, `platforms/processes/background-services.md`,
`platforms/shells/portable-shell-scripts.md`, `platforms/tools/bsd-vs-gnu-cli.md`,
`debugging/index.md`, `testing/index.md`, `testing/quality/tests-that-cannot-fail.md`,
`backend/index.md`, plus the diffs of PRs #8, #9, #11, #12. Repo-wide greps for
`litellm` / `ANTHROPIC_BASE_URL` / `claude code` and `stdin` / `nohup` / `tty` /
`/dev/null` located every candidate overlap.

| Overlap examined | Finding | Action |
|------------------|---------|--------|
| Candidate 1 vs **PR #11 and PR #12** | Both add the identical page id with the same directive, better sourced than my draft | **Retired.** My draft page deleted, and the supporting edits I had made to `platforms/index.md`, `background-services.md` and `bsd-vs-gnu-cli.md` reverted — they referenced a page id that would not exist in `main`, i.e. a broken-link lint failure |
| Candidate 2 vs `main` | No LLM page exists anywhere in `main`; the file I first read was an orphan | **Reversed to ingest** |
| Candidate 3 vs `testing/quality/tests-that-cannot-fail` | Different trigger: that page audits *one test* that always passes, this audits *the harness* grading them. Its "auditing a whole suite" edge case assumes PIT/Stryker, which supply the baseline gate a hand-rolled script lacks | New page + edge-case row added there + `related:` **both ways** |
| Candidate 3 vs PR #8 / PR #9 | Per-check negative controls — the adjacent layer, not this one | No conflict; the distinction is stated in the page's own edge-case table |
| Candidate 3: my draft vs the orphan | The orphan is the better page (uniform-verdict table, `dryRunOnly`, PIT's equivalent-mutation quote, "all mutants survive unexpectedly"); mine had the scoring rule it lacked | **Merged into the orphan**, my draft deleted |

**Conflicts found: none.** Nothing overwritten, nothing to flag as `contradiction`.

## Routing decision

| # | Insight | Target | New category? |
|---|---------|--------|---------------|
| 1 | Non-interactive CLI blocking on stdin | *(none — already open as PR #12; `platforms`/`processes`)* | n/a |
| 2 | LLM output cap vs serving model's window | `backend` / **`common/llm`** / `context-window-budget.md` (`backend-common-llm-context-window-budget`) | **Yes — new `common/llm` category.** Existing `common/*` categories are api-design, reliability, caching, jobs, errors, auth, orm, concurrency. The nearest fit, `reliability`, owns timeouts/retries between services and would misfile the directive as a transient-failure concern when the 400 is arithmetic. Per `AGENTS.md`, `common/` holds language-agnostic server-side concerns, which an LLM client's token budget is |
| 3 | Verification-harness reverse controls | `testing` / `quality` / `harness-reverse-controls.md` (`testing-quality-harness-reverse-controls`) | No — `quality` already holds the "can this detect a defect" family; this extends it one level up to the measuring apparatus |

**Plumbing:** `backend/index.md` gains the `llm` category and page; `testing/index.md`
gains the page; `log.md` has three entries (2 `ingest`, 1 `dedup`); every `related:` id
and inline `[page-id]` reference resolves. `INDEX.md` unchanged — both domains already
listed and both remain accurately described.

**Format checks:** bodies 73 and 80 lines (limit 120); five required sections each; no
banned vague qualifiers; anti-patterns confined to `Instead of` rows, each paired with a
replacement; branches as tables.

## What I got wrong, and what would prevent it

1. **Untracked leftovers read as merged wiki content.** `reset --hard origin/main`
   leaves untracked files in place, so a flush that dies after writing pages but before
   committing poisons the *next* flush's dedup — in the most misleading direction, by
   making new knowledge look already-covered. I nearly dropped candidate 2 on that
   basis. A `git clean -fd` (or a `git status` check) before the existing-layer step
   would close this; the skill currently prescribes neither.
2. **Open PRs are not part of the dedup step.** The skill's step 2b checks "existing
   wiki layers" only. With 7 open knowledge PRs, candidate 1 had already been flushed
   **twice** (#11 and #12, same page path) and would have become a third.
3. **The queue is not being retired.** These rows were harvested 2026-07-31 and were
   already processed into PRs #11/#12; they came back because the dead flush never ran
   step 5. Retiring them is handled below.

## Cross-check

Cross-Check: independent headless `claude` run (`--permission-mode plan`) re-fetched all
11 cited URLs and audited every quoted string to refute it — **PASS on both pages**, with
5 sourcing defects found and all 5 fixed in the follow-up commit.

| Finding | Status |
|---------|--------|
| **MISQUOTED** — `"all mutants survive unexpectedly"` is not Stryker's wording | **Fixed.** I re-fetched the page and confirmed: the real headings are "All mutants survive - Jest runner" and "All mutants survive - module-alias", and both causes are sandbox mechanics (hidden temp dir; `module-alias/register` unsupported), not the "configuration fault" gloss. Quotes removed, causes attributed to the two sections. This was a fabricated quotation and the single most important catch |
| **OVERREACH** — "Both mutation frameworks build this in" (baseline run) | **Fixed.** Only Stryker is sourced for it; now attributed to Stryker's "Initial test run fails" section and `dryRunOnly` alone |
| **OVERREACH** — "coverage/timing analysis derived from that run" | **Fixed.** The config page supports timing (`netTimeMs`/`overheadMs`) only; coverage claim dropped |
| Minor — "No tests were executed…" generalized to framework policy | **Fixed.** Now labelled as the Vitest runner's message, which is how the doc presents it |
| **UNSUPPORTED ×3** in the LLM page — the 400 message stating the arithmetic; a gateway `max_output_tokens` key; the `/v1` path-append rule | **Fixed.** All three are field-derived and were sitting adjacent to doc citations as if doc-backed; each is now explicitly attributed to the reproduction, and the gateway row no longer invents a config key |

One citation could not be checked: the Google Testing Blog URL renders its body
client-side, so a fetch returns only page chrome. The claim attributed to it is generic
("inserting faults and requiring failure measures detection") and is independently
carried by the PIT and Stryker citations, but flagging it rather than calling it verified.

## Reviewer notes

- **PRs #11 and #12 add the same page path** (`non-interactive-cli-invocation.md`) and
  need dedup against each other regardless of this PR.
- Candidate 1's `nohup` correction and the four sources in §1 are unclaimed by either
  PR; fold them into whichever you keep.
- The `common/llm` category is the only structural addition here — the one decision in
  this PR worth pushing back on.
