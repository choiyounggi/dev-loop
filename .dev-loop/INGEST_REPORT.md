# Knowledge flush — 5 insight(s) → 2 pages

Queue drained: 5 pending candidates across 3 sessions. Four of them describe the
same situation at different granularity and were folded into one page (AGENTS.md
"one case per page" cuts by _situation_, not by candidate); the fifth is
unrelated and got its own page.

| #   | Candidate (hash)   | Claim                                                                                                                                                | Outcome                                                                  |
| --- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| 1   | `f997639131d8ec9e` | Validate a grep gate on a conforming sibling file before adopting it                                                                                 | Folded → `testing-docs-as-spec-document-conformance-checks` (Do this §2) |
| 2   | `739b75ed972c6078` | Token-presence gates are blind three ways; split into structure / modality / row-completeness / cross-reference axes with per-axis negative controls | Folded → same page (Do this §3)                                          |
| 3   | `2e3fcd105c8512fa` | Persist `s3.upload()` `Key`, not `Location`                                                                                                          | New page `backend-common-storage-object-key-persistence`                 |
| 4   | `39dfae0d5a813cb4` | Pair a coverage check with a value-validity check, each with its own negative control                                                                | Folded → same page (Do this §4)                                          |
| 5   | `18dc623000d54f07` | Split Markdown rows on unescaped pipes only                                                                                                          | Folded → same page (Edge cases + Instead of)                             |

## Verified best-practice

### Insights 1, 2, 4 — controls on a document-conformance check → `confidence: verified`

**Claim.** A checker is unproven until it has been run against both a conforming
input (must PASS) and a deliberately-broken input (must FAIL), one control per
check; presence checks do not establish correctness.

Sources checked:

- **ESLint `RuleTester`** — https://eslint.org/docs/latest/integrate/nodejs-api#ruletester —
  fetched; requires both a `valid` array (rule must not fire on compliant code)
  and an `invalid` array whose cases must assert the errors the rule produces.
  This is the positive/negative control pair as an enforced API shape.
- **Semgrep rule tests** — https://docs.semgrep.dev/writing-rules/testing-rules —
  fetched; `ruleid:` annotates true positives and `ok:` true negatives, both in
  the same test file. Second independent tool converging on the same requirement.
- **Google Testing Blog, mutation testing** — https://testing.googleblog.com/2021/04/mutation-testing.html —
  already cited elsewhere in this wiki; supports "insert a fault, require the
  check to fail" as the measure of detection.
- **JSON Schema `required`** — https://json-schema.org/understanding-json-schema/reference/object —
  fetched; `required` asserts key presence and constrains no value (a required
  property may even be `null`). This is the canonical statement of the
  coverage-vs-validity split that insight 4 hit empirically.

**How verified.** The two linter sources are official docs for tools whose entire
job is "run a rule against a document/AST", and both mandate the two-sided test.
The candidates' own evidence (an independent auditor's 8 mutations passing a
16-gate suite; a `Bogus` cell surviving a coverage check) is the field half.
Insight 1's specific mechanism — a missing target file makes _every_ pattern
red, so red carries no information about the pattern — is a direct logical
consequence, and the candidate reports the positive control actually run
(7 sections matched on the conforming sibling `rfcs/0005`).

### Insight 5 — unescaped-pipe splitting of GFM table rows → `confidence: verified`

- **GFM spec, tables extension** — https://github.github.com/gfm/#tables-extension- —
  fetched. Cells are "separated by pipes (`|`)", and Example 200 shows you
  "include a pipe in a cell's content by escaping it, **including inside other
  inline spans**" (`f\|oo`, and an escaped pipe inside a code span and inside
  emphasis). So `\|` is legal cell content and `split("|")` overcounts a correct
  row.
- **Reproduced here.** Ran the candidate's `re.split(r"(?<!\\)\|", row)` over both
  new pages: cell counts come out uniform per table (4/4/4/4, then 3×6, 2×8,
  3×7). The two rows in this PR that carry an escaped pipe in their text are
  exactly the rows a naive split would have mis-flagged — the rule's own page is
  its positive control.

### Insight 3 — persist `Key`, not `Location` → `confidence: verified`

- **S3 `CompleteMultipartUpload` API reference** — https://docs.aws.amazon.com/AmazonS3/latest/API/API_CompleteMultipartUpload.html —
  fetched. `Key` is documented as "The object key of the newly created object";
  `Location` is documented only as "The URI that identifies the newly created
  object", with **no encoding guarantee**. That asymmetry is the load-bearing
  fact: only one of the two fields has a contract.
- **`AWS.S3.ManagedUpload` docs** — https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3/ManagedUpload.html —
  fetched. Callback data carries `Location`, `ETag`, `Bucket`, `Key`;
  `minPartSize = 1024 * 1024 * 5` and default `partSize` is 5 MB. Confirms the
  candidate's 5,242,880-byte boundary and that `Key` is present on both paths.
- **`lib/s3/managed_upload.js` source** — https://github.com/aws/aws-sdk-js/blob/master/lib/s3/managed_upload.js —
  fetched from `raw.githubusercontent.com`. `finishSinglePart` builds
  `data.Location` from `endpoint.protocol + '//' + endpoint.host + httpReq.path`
  and sets `data.Key` from `params.Key`; `finishMultiPart` takes the service's
  `Location` and applies only `.replace(/%2F/g, '/')`. Exactly the two producers
  the candidate described, verified line-for-line against current master.
- **aws-sdk-js issue #1158** — https://github.com/aws/aws-sdk-js/issues/1158 —
  fetched. Reported side by side: multipart returns
  `…/stream-uploads%2Fkokoko.gif`, single-part returns `…/stream-uploads/kokoko.gif`,
  and `Key` is identical in both. Independent confirmation that `Location` is
  path-dependent and `Key` is stable.
- **aws-sdk-js-v3 issue #5656** — https://github.com/aws/aws-sdk-js-v3/issues/5656 —
  fetched. Same structural split in v3 `lib-storage`: `__uploadUsingPut`
  constructs `Location` client-side, `CompleteMultipartUploadCommand` does not.
  Widened `applies_to` to `[aws-s3, aws-sdk-js-v2, aws-sdk-js-v3]`. (Closed for
  staleness — no maintainer fix, so the directive is the workaround, not a bug
  that has since been patched.)

**One scope correction against the candidate.** The candidate asserted the
multipart form is specifically `space → +`. What is _documented/reproduced_ in
public sources is the slash case (`/` → `%2F`, visible in #1158 and implied by
the SDK's `%2F`-only repair). The `+`-for-space observation is field evidence
from the originating production incident, consistent with form-urlencoding but
not shown in a cited source. The page therefore labels the encoding column
"Observed form" and does not claim a documented `+` contract; the **directive**
(store `Key`) is fully verified and does not depend on which character it is.

## Existing-layer check

Pages read before routing:

| Read                                                                                                    | Why                                              | Result                                                                                                                                                                                                                                                                                                                    |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INDEX.md`                                                                                              | Domain routing                                   | testing vs qa vs backend decided below                                                                                                                                                                                                                                                                                    |
| `wiki/testing/index.md` (all 8 "load when" lines)                                                       | Overlap scan                                     | No page covers document/spec checking                                                                                                                                                                                                                                                                                     |
| `wiki/testing/quality/tests-that-cannot-fail.md` (full)                                                 | Nearest neighbour — owns "prove a test can fail" | **Overlap, not duplication.** It owns mutation-and-require-red for _test code_ (its never-fails table is Jest/mock/async-shaped). It has no positive-control half and nothing about documents. Kept separate; the new page `related:`-links it and routes to it from an edge-case row ("subject is code, not a document") |
| `wiki/testing/quality/minimum-case-set.md`, `behavior-not-implementation.md`                            | Overlap scan                                     | Case selection / assertion targets for code; no conflict. `minimum-case-set` added to `related:`                                                                                                                                                                                                                          |
| `wiki/qa/index.md` + `process/release-gates.md`, `acceptance-criteria.md`                               | Insights 2 and 5 were tagged `domain: qa`        | `release-gates` is about _which_ gates a release must clear, not whether a gate can fail — no overlap. `acceptance-criteria` owns "make the requirement testable", which is upstream of "check the document encodes it"; linked in `related:` and in an edge-case row so the two compose                                  |
| `grep -ril` over `wiki/` for mutation / markdown / negative control / linter / lint rule / docs-as-spec | Whole-wiki dedup                                 | Only `tests-that-cannot-fail` hit meaningfully; the rest are incidental word matches in frontend/security/backend pages                                                                                                                                                                                                   |
| `wiki/backend/index.md` + all 8 `common/` categories                                                    | Insight 3 routing                                | No storage/object-storage page exists                                                                                                                                                                                                                                                                                     |
| `grep -ril` over `wiki/` for s3 / multipart / object storage / presigned / url-encod                    | Whole-wiki dedup for insight 3                   | Zero real hits (`column-data-types.md` and `severity-and-priority.md` match on unrelated substrings)                                                                                                                                                                                                                      |

**Conflicts flagged:** none. No existing directive is contradicted or overwritten;
both pages are additive.

**Merge-before-create decision.** Insights 1/2/4/5 merged into a single _new_
page rather than appended to `tests-that-cannot-fail`: appending would have
pushed that page past its one-case scope (test code → documents) and mixed two
trigger sets in one "When this applies". They merged with _each other_ because
they share one situation — writing a checker whose subject is a document — which
is why 5 candidates produced 2 pages, not 5.

**Related-links added:**
`testing-docs-as-spec-document-conformance-checks` → `testing-quality-tests-that-cannot-fail`,
`testing-quality-minimum-case-set`, `qa-process-acceptance-criteria`.
`backend-common-storage-object-key-persistence` → `backend-common-api-design-idempotency`
(backfill retry behaviour), `backend-node-boundaries-runtime-validation`.
All five ids verified to resolve to existing files; no duplicate ids in `wiki/`.

## Routing decision

### 1. `wiki/testing/docs-as-spec/document-conformance-checks.md` — NEW category

- **Domain `testing`** over `qa` (two candidates were tagged `qa`): the artifact
  being authored is an automated check, which `INDEX.md` routes to testing; `qa`
  is scoped to release _process_. Routing by "which artifact do you change"
  (AGENTS.md step 1) puts it in testing.
- **New category `docs-as-spec`** rather than `quality`. Every existing testing
  category — strategy, quality, data, mocking, flaky, async, e2e — is organized
  around testing _executable code_, and their mechanics (assertions, fixtures,
  fake timers, selectors) do not apply when the subject is a Markdown document.
  Filing under `quality` would have made the "load when" line collide with
  `tests-that-cannot-fail`'s, which is the drift condition AGENTS.md invariant 1
  warns about. Single-page categories are already the norm here (`async`, `e2e`,
  `data`, `mocking`, `flaky` each hold one page).
- Index updates: new section in `wiki/testing/index.md` with a "load when" line
  enumerating all four distinct uses (authoring the check pre-document; choosing
  the mutation; a gate that passed on a degraded document; Markdown table
  parsing); testing's "Route here for" preamble and the root `INDEX.md` testing
  row both extended with "checks whose subject is a document rather than code".

### 2. `wiki/backend/common/storage/object-key-persistence.md` — NEW category

- **Domain `backend`, subtree `common`** rather than `node`. The directive
  ("persist the identifier the service documents as canonical; derive URLs at
  read time") is language-agnostic and reproduces in v2 and v3 — AGENTS.md says
  common owns the principle and the stack page owns the mechanics, and there are
  no Node-runtime mechanics here beyond the SDK field names.
- **New category `storage`.** The eight existing `common/` categories are
  api-design, reliability, caching, jobs, errors, auth, orm, concurrency —
  none covers object storage. `api-design` is about this service's own contract,
  not a dependency's response shape; `orm` is DB persistence.
- Index updates: new `### storage` section in `wiki/backend/index.md` (placed
  before `reliability`), plus "object-storage references" added to the `common`
  subtree route line and to the backend row of the root `INDEX.md`.

## Invariants checked

- Body length: 73 and 60 lines (limit 120).
- Every `related:` id resolves; no duplicate ids across `wiki/`.
- Both pages listed in their domain `index.md`; both domains in `INDEX.md`.
- Two `## [2026-07-30] ingest` entries appended to `log.md`.
- Positive guidance only: every "don't" lives in an `Instead of` row paired with
  its replacement and a why.
- Table cell counts re-verified with the unescaped-pipe splitter this PR
  documents.
