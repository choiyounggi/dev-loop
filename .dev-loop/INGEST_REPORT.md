# Knowledge flush — 4 insight(s)

Five queue rows claimed by run `20261011-001850-59042`: four general insights ingested (two merged into existing pages, two new pages, two of the four with a corrected directive), and one project-specific plan gap routed to the local layer. Every claimed row is retired from the queue once this PR is open.

## Verified best-practice

### 1. `claude -p --json-schema` fed by zod 4 — verified, directive corrected

- **Row** `147fe4b85ab22a6e` (session in `wreckfish`). Candidate: delete the top-level `$schema` from `z.toJSONSchema()` output before passing it to `--json-schema`.
- **Result.** The candidate's error and fix both reproduce, but deleting the key is partial: a schema containing `z.tuple()` still fails with `strict mode: unknown keyword: "prefixItems"`. The ingested directive is the documented one, `z.toJSONSchema(schema, { target: 'draft-7' })`.
- **Sources** (each quote re-fetched and matched on 2026-10-11):
  - https://code.claude.com/docs/en/agent-sdk/structured-outputs — "The SDK validates schemas with JSON Schema draft-07, so schemas that declare a newer version are rejected. Zod targets draft 2020-12 by default, so pass `target: "draft-7"` when converting your schema."
  - https://code.claude.com/docs/en/cli-reference — `--json-schema`: "Claude Code exits with an error on an invalid schema"
  - https://ajv.js.org/json-schema.html — draft-07 "is provided as default export"; "To use draft-2020-12 schemas you need to import a different Ajv class"
  - https://zod.dev/json-schema — `target`: `"draft-2020-12"` "Default. JSON Schema Draft 2020-12"
  - https://github.com/anthropics/claude-code/issues/80402 — open: "--json-schema rejects schemas declaring the draft 2020-12 meta-schema (since 2.1.214)"
- **How verified.** Claude Code 2.1.296 with zod 4.6.5, run as `claude --bare -p … --json-schema …` with a fake `ANTHROPIC_API_KEY`, so an accepted schema stops at "Invalid API key" and nothing is billed. Default output: exit 1, 0 bytes of stdout, the 2020-12 error. `$schema` deleted on a plain object: accepted. `$schema` deleted with a tuple: exit 1 on `prefixItems`. `target: 'draft-7'` with a tuple and a recursive schema: accepted. `target: 'draft-4'`: rejected. Ajv 8.20.0's default class reproduces both messages, and the `claude.exe` binary contains them. One real end-to-end run (`--safe-mode`, Haiku, $0.0032) with the draft-7 tuple-and-recursion schema exited 0 with the expected `structured_output`.
- **Confidence:** verified.

### 2. Cutting scraped page text at a noise marker — field-tested

- **Row** `08ee50366aeeda10` (session in `wreckfish`). Candidate: cut only at a marker that sits after the last content item.
- **Sources.** One peer-reviewed source supports the premise, re-fetched and matched: https://doi.org/10.13053/cys-22-2-2959. That is Viveros-Jiménez et al. 2018, *Computación y Sistemas* 22(2), with the full text on SciELO: "Non-relevant content could be placed everywhere in the structure of the document (even in the middle of the text)".
  - Checked with no statement of the cut rule itself: the Mozilla Readability README, the trafilatura docs, the boilerpipe paper (WSDM 2010) and the CleanEval LREC 2008 paper.
  - The boilerpipe paper describes single-article pages, where main content "is surrounded by boilerplate". The list-page interleaving this page covers is a different layout.
- **How verified.** The evidence is the session's measured character offsets on a live third-party site, which this flush did not re-scrape. The page keeps to what those offsets show. One edge case I inferred (removing interleaved blocks as spans) was drafted and then deleted: nothing measured it, and it would delete content when the item anchor closes each item.
- **Confidence:** field-tested.

### 3. "No file was written" under a partial `node:fs` mock in Vitest — verified, directive corrected

- **Row** `dbb1dc5c25c35cd4` (task `t6b` in `linkly-invitation`). Candidate: widen the spread `importOriginal()` mock to `promises`, `node:fs/promises` `open`, and the `write`/`open` APIs, then prove each channel with a mutant.
- **Result.** Widening the named keys is not enough. `import fs from 'node:fs'` reads the `default` export, which the spread copies from the real module, so 4 of 6 write channels still wrote real files after widening. The ingested page leads with an empty-directory assertion. For mock-based suites it adds `mocked.default = mocked`, a separate `node:fs/promises` mock (or the Vitest docs' memfs `__mocks__`), and one mutant per channel.
- **Sources** (quotes re-fetched and matched): https://vitest.dev/guide/mocking/modules ("The factory method accepts an importOriginal function that will execute the original module and return its module object"), https://vitest.dev/guide/mocking/file-system ("we recommend using memfs"; `__mocks__/fs.cjs` and `__mocks__/fs/promises.cjs`; both `vi.mock('node:fs')` and `vi.mock('node:fs/promises')`), and https://nodejs.org/api/fs.html (Promises API history). On Node 26.7.0, `require('node:fs').promises === require('node:fs/promises')` printed `true`.
- **How verified.** A research agent built a six-channel reproduction (Vitest 5.0.3, Node 26.7.0). I re-ran it myself: `Tests 8 failed | 10 passed (18)`, with real files for every channel the page marks "missed". I then ran my own red/green pairs:
  - `default` fix: `6 passed`, with no real file; its control without the fix failed 4 (`4 failed | 2 passed`, real files for a, d, e, f).
  - Call recording under the fix: `6 passed`, every channel reached a recording mock.
  - memfs `__mocks__`: `6 passed`, every write landed in `vol`; its control without the `node:fs/promises` mock failed 2 (`2 failed | 4 passed`).
- **Confidence:** verified.

### 4. A diff that edits one count in a document — field evidence verified, merged

- **Row** `384928a50f467385` (integration run in `linkly`). Candidate: when one count in a section changes, recheck every count, list and number in that section.
- **Sources.** The page already cites the Write the Docs documentation principles ("prevent any parallel maintenance … of the same information across multiple sources") and Google's docguide.
  - A research pass found no style guide or tool that checks restated counts for agreement. It checked the Google developer style guide's numbers and timeless-documentation pages, the Microsoft Writing Style Guide's numbers page and its Vale package, Vale's `consistency` check, Python doctest and Sphinx substitutions; all are adjacent, none on point.
  - The "recheck every number in the section" procedure therefore stands on the field incident.
- **How verified.** `git -C linkly show 1a68da3 -- README.md` changes the bold line from "64 RFCs" to "65 RFCs" and the Draft paragraph from "seventeen" to "eighteen". Review finding F1 (`.orchestration/archive-20261010-oi1010/reviews/t2-write-miss-not-found-r1.md`) records the stale paragraph (46 + 1 + 17 = 64 against the stated 65), and that `tests.test_readme_currency` pins only the bold line. That paragraph was a spelled-out breakdown, so a search for the old total "64" would not have found it. The merged row says this.
- **Confidence:** the page stays `verified`. The new rows rest on this field incident, which the page's Sources now records.

### 5. Plan gap `9594b5cd202978fb` — not ingested (local layer)

Its directive names linkly's own `repo_policy.seeded_entities`, RFC-0064/RFC-0052, `docs/backends.md` and the `lnpl run/spec/serve --backend fake` commands, so it would be wrong in another codebase. See Local-layer candidates.

## Existing-layer check

`wiki_search` (k=5) per candidate trigger, then grep and the domain indexes:

| Candidate | wiki_search top 5 | Overlap found | Decision |
|---|---|---|---|
| 1 | structured-output-schema-from-zod (4 chunks), security-input-validation-at-trust-boundaries | structured-output-schema-from-zod owns "converting a zod schema for Claude structured output" for the API and SDK; nothing on the CLI flag | Merge: directive 4 with a five-row table, one Instead-of row, sources, trigger clause, index row extended |
| 2 | retiring-a-provisional-marker (2), word-level-union-merge-reassembly, validation-timing, completion-response-validation | None. Grep found contact-details-from-scraped-pages (main-content filtering for contact details), a different trigger in the same category | New page in backend/common/integrations; `related` both ways with contact-details-from-scraped-pages |
| 3 | typescript-6-global-types (2), what-to-mock, extracted-method-this-binding, control-signals-vs-primary-artifacts | what-to-mock covers proving a negative for child processes via DI, not module mocks of `node:fs`. masking-verification's channel sweep is about output masking, not write channels | New page in testing/mocking; `related` both ways with what-to-mock and tests-that-cannot-fail |
| 4 | json-manifest-edit-gates, cloud-cli-invocation-bounds, retiring-a-provisional-marker (2), ui-hardening-against-real-content | Vector search missed it. The qa index and grep found quantitative-claims-in-a-published-document, which already says "fix every copy" across documents but not same-section breakdowns or a test that pins one line | Merge: trigger clause, one edge-case row, one Instead-of row, field-incident source, index row extended |
| 5 | differential-run-agreement, audit-columns-as-update-evidence, not-null-check-and-lifecycle-callbacks, persistence-context, online-schema-changes | n/a (local layer) | Not ingested |

Conflicts flagged: none; no existing directive is contradicted. Read in full: structured-output-schema-from-zod, contact-details-from-scraped-pages, what-to-mock, quantitative-claims-in-a-published-document. The others were read at trigger and matching-line level.

Pages read: backend-node-boundaries-structured-output-schema-from-zod, platforms-processes-parsing-cli-structured-output, platforms-processes-non-interactive-cli-invocation, backend-node-boundaries-runtime-validation, backend-node-boundaries-zod-4-checks-continue-after-a-failure, backend-common-integrations-contact-details-from-scraped-pages, testing-mocking-what-to-mock, testing-quality-tests-that-cannot-fail, testing-quality-absence-assertions-over-generated-output, testing-data-artifact-leakage-from-a-suite, security-data-masking-verification, qa-deliverables-quantitative-claims-in-a-published-document, qa-document-verification-rationale-prose-after-a-config-value-change

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` returned #266 (`knowledge/choiyounggi-20261010-021455`) and #265 (`knowledge/choiyounggi-20261009-222812`). #267 (`fix/autoflush-opt-in`) is not a knowledge head.

`git diff origin/main...origin/<head> -- wiki/` for both:
- #266 adds request-body-reader-cancel, unresponsive-first-nameserver, done-criteria-in-a-split-task-piece and plugin-dependencies-after-an-update, plus related-link edits.
- #265 adds wrapping-quotes-in-a-frontmatter-value, review-diff-base-after-a-sibling-merge, chaining-workflows-past-a-github-token-event, search-evidence-from-a-wrapped-grep and blind-llm-judgment-of-a-visual-rule, plus amendments.

Neither shares a trigger with any candidate, and neither touches the four target pages.

| Candidate | Verdict |
|---|---|
| 1 zod → `--json-schema` | new |
| 2 scraped-text noise marker | new |
| 3 `node:fs` partial mock | new |
| 4 count restatements | new |
| 5 plan gap | not ingested (local layer) |

`git merge-tree --write-tree` of this branch against each head conflicts only in `log.md` (both PRs append at its end, as #265 and #266 do to each other). `wiki/backend/index.md`, `wiki/backend/node/index.md` and `wiki/qa/index.md` auto-merge. `.dev-loop/INGEST_REPORT.md` will also conflict, since each flush rewrites it.

## Routing decision

| Candidate | Layer | Target page | Action |
|---|---|---|---|
| 1 `147fe4b85ab22a6e` | bundled | `wiki/backend/node/boundaries/structured-output-schema-from-zod.md` | merge |
| 2 `08ee50366aeeda10` | bundled | `wiki/backend/common/integrations/cutting-scraped-text-at-a-noise-marker.md` | new page; integrations already holds the scraping pages |
| 3 `dbb1dc5c25c35cd4` | bundled | `wiki/testing/mocking/proving-no-file-was-written.md` | new page; mocking owns module-mock pitfalls |
| 4 `384928a50f467385` | bundled | `wiki/qa/deliverables/quantitative-claims-in-a-published-document.md` | merge |
| 5 `9594b5cd202978fb` | local | see below | excluded |

No new category. Gates: `node scripts/wiki-structure-checks.js wiki` gives `pages: 428, indexes: 13, findings: 0` (baseline 426 pages / 0 findings). `node scripts/wiki-lint-prohibitions.js wiki` gives `violations: 0`, the same as baseline. The model-era report is unchanged at 44 candidates. Running the five wiki-related bats files gave `1..78`, all ok.

## Independent review

A fresh-context adversarial reviewer reviewed the diff: a separate subagent, read-only on this checkout, with its own scratch directory. It did the following:
- Re-fetched every new source and confirmed each quote verbatim.
- Rebuilt the zod → `--json-schema` matrix on Claude Code 2.1.296 with a fake key. All five table rows reproduced, and default `Ajv` against `Ajv2020` matched the Sources bullet.
- Rebuilt a two-channel Vitest reproduction. The default-import channel was missed without `default` and caught with it; the named-import channel was caught in both.
- Read linkly's commit `1a68da3` and review finding F1, and searched the wiki for duplicate triggers.
- Re-ran both lint scripts on a `git archive` snapshot.

Verdict: APPROVE, with three minor findings, all fixed before this PR:

| Finding | Resolution |
|---|---|
| Scraping page: "began at character 300 of 4,103 … a first-occurrence cut left 542 characters" does not reconcile arithmetically | Reworded: 300 is the marker's offset in the scraped text and 542 is the stored result's length. The session recorded both, not the step between them |
| Count page: `git show 1a68da3` shows the fixed end state, not the stale paragraph the bullet describes | The stale state is now cited to review finding F1 in the run's archived review file. The commit is cited only for the end state, where "64 RFCs" → "65 RFCs" and "seventeen" → "eighteen" change together |
| `log.md` used "merged (field evidence)" where every other entry puts the page's `confidence` value | Changed to "merged (verified)", matching the page's frontmatter |

By design, the reviewer did not reproduce the one real end-to-end `structured_output` run, because paid API calls were out of its scope. Its precondition, the CLI accepting the draft-7 schema, did reproduce.

## Local-layer candidates

| Row | Project | Target |
|---|---|---|
| `9594b5cd202978fb` — Planning t2-write-miss-not-found: deciding Default seed rule for update-first and delete-first entities | linkly (`/Users/choeyeong-gi/Desktop/workspace/linkly`) | `wiki-local/testing/data/t2-write-miss-not-found-default-seed-rule.md` — run wiki-ingest inside that project |

It is a wiki-plan Phase B decision that names linkly's own modules, RFCs and commands. It is excluded from this PR and retired from the queue.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
