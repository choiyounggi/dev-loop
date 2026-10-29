# Knowledge flush — 1 insight(s) (headless auto-flush run, 2026-10-29)

Run `20261029-114716-88588` claimed 21 queue rows: 1 ingested as a new page, 16 dropped as project-specific plan-gap rows, 4 released back to pending (2 plausible duplicates of open PRs, 2 whose queue files this run could not locate). Nothing was folded into another branch.

| Candidate | Disposition |
|-----------|-------------|
| `e696706cb40ae30e`: Korean particle agreement after re-pointing a numeric reference | **ingested**: new page `qa-document-verification-korean-particles-after-a-token-rewrite` (field-tested) |
| `8a67a97c4afd204c`, `f332524447ff2105` | **released**: plausible duplicates of open PRs #299 / #300 (same verdict as run 20261029-104612-27366) |
| `d1e6468cdb111e8c`, `baac78b023efce53` | **released unread**: their queue files could not be located (this run cannot list `~/.dev-loop/queue`; Read needs an exact file name) |
| 16 plan-gap rows (listed under Local-layer candidates) | dropped as project-specific |

## Verified best-practice

**`e696706cb40ae30e` (confidence: field-tested).** Claim: when a script rewrites a token inside Korean prose and a particle is attached to it, grep the rewritten tokens with the next characters, classify the old and new token by the final sound of how it is read aloud, and fix only the occurrences whose class flipped. Byte-level fidelity checks cannot see this.

Change from the candidate: the candidate used two classes (vowel vs consonant ending). Research showed (으)로 needs a third class, because a ㄹ-final word takes 로, not 으로. Digits 1/7/8 (일/칠/팔) end in ㄹ, so they sit with the consonant class for 이/가, 은/는, 을/를, 과/와 but with the vowel class for (으)로. The page uses a three-class table. It also states that a number ending in 0 is read with a place unit (십/백/천/만) or 영/공, all consonant-final.

Sources checked (all read through web-search summaries; this headless run has no page fetch):
- https://www.koreanvalley.com/korean-grammar/korean-subject-particles — 이 after a final consonant, 가 after a vowel.
- https://www.koreanvalley.com/korean-grammar/the-object-particles-and — 을 after a final consonant, 를 after a vowel.
- https://ko.wiktionary.org/wiki/%EB%A1%9C — 로 after no final consonant or a ㄹ final consonant; 으로 after any other final consonant.
- https://jakup.com/tools/josa — a particle tool that classifies a number by its spoken reading (1 = 일 → ㄹ, 3 = 삼 → ㅁ). This is a tool's convention. The search found no National Institute of Korean Language rule specific to Arabic numerals, and the page says so.
- Field case from the originating session (RFC-consolidation run): a worker recorded `RFC-0067가` after rewriting `RFC-0002가`. In the consolidated RFC, `grep -noE 'RFC-00(6[6-9]|7[0-7]).?.?'` found 49 re-points: two with attached particles (`RFC-0066이`, `RFC-0068이`) kept their class, plus `RFC-0071의` (의 does not alternate).

Why field-tested, not verified: the particle rules are standard grammar, but every external source was read through a search summary, and the digit-reading convention rests on a tool's documentation plus one field case.

Not researched: the 2 rows released as open-PR duplicates, the 2 rows released unread, and the 16 plan-gap rows (each records one design decision for one repository).

## Existing-layer check

Pages read: qa-document-verification-editing-a-gated-document, platforms-environment-unicode-text-matching

Also read: `wiki/qa/index.md` (whole domain index) and `log.md` (tail).

`wiki_search` (k=5) runs:

| Query | Top hits |
|-------|----------|
| Korean particle 이/가 은/는 을/를 agreement after replacing a number or reference token in prose | backend-common-llm-korean-summary-line-dedupe-by-bigram-overlap 0.767, platforms-environment-unicode-text-matching 0.766, platforms-shells-non-ascii-text-after-an-unbraced-parameter 0.758, backend-node-language-string-replace-replacement-patterns 0.748, backend-common-integrations-wrapping-quotes-in-a-frontmatter-value 0.743 |
| renumbering cross-references in documents: re-point old document ids to new ids, check surrounding text | testing-quality-spec-artifact-checks 0.872, testing-quality-schema-additions-under-a-golden-gate 0.855, qa-deliverables-generated-artifacts-as-deliverable-source 0.738, qa-document-verification-superseding-a-knowledge-record 0.737, testing-quality-checks-that-cannot-pass 0.732 |

- No page covers particle agreement after a token rewrite. `unicode-text-matching` is about matching Korean text with grep/regex (code points, normalization, awk byte offsets), not about grammatical agreement after a rewrite. `editing-a-gated-document` is about text gates breaking on rewording. The spec-artifact pages are about ids resolving, not the prose around them.
- Created one new page instead of merging, because no existing page's trigger fits. Body is about 60 lines.
- `related:` on the new page: qa-document-verification-superseding-a-knowledge-record (re-pointing references to a superseded record), qa-document-verification-editing-a-gated-document, platforms-shells-non-ascii-text-after-an-unbraced-parameter (also a Korean particle attached to a substituted value), platforms-environment-unicode-text-matching. Back-links were not added, to keep this PR from editing pages that open PRs might touch.
- Added one row to the `document-verification` table in `wiki/qa/index.md` and one line to `log.md`.
- Conflicts: none.

## Open-PR check

Open `knowledge/*` heads (`gh pr list --repo choiyounggi/dev-loop --state open --json number,headRefName --search "head:knowledge/"`): #307, #306, #305, #304, #301, #300, #299, #298, #293. This run has no git access, so overlap was judged from each PR's changed-file list (`gh pr list --json files`) and, for #305, its body.

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| e696706cb40ae30e (Korean particles after a token rewrite) | None by trigger. #305 edits `qa/document-verification/superseding-a-knowledge-record.md` with a row about deciding which sections an amendment replaced; it has no particle or wording content. #304 edits `qa/process/completion-claims.md`. No open PR touches Korean text handling. | **new** → ingested |
| 8a67a97c4afd204c (`grep -q` and SIGPIPE) | #299 (grep pitfalls, `platforms/tools/search-evidence-from-a-wrapped-grep.md`) | **pending duplicate** → released |
| f332524447ff2105 (gate grep matches its own ledger) | #299, #300 (`testing/quality/checks-that-cannot-pass.md`) | **pending duplicate** → released |
| d1e6468cdb111e8c, baac78b023efce53 | not judged (content unread) | released |
| 16 plan-gap rows | n/a (project-specific) | dropped |

Possible merge conflicts, not duplicate content: `wiki/qa/index.md` (#304 and #305 also edit it, in different rows) and `log.md` (every open flush PR appends to it).

## Routing decision

- e696706cb40ae30e → `qa/document-verification/korean-particles-after-a-token-rewrite.md`, new page in an existing category. The domain hint was `qa`, and `document-verification` owns automated checks over document deliverables, which is where a rewrite's check list lives. The general form is any token rewrite inside Korean text. The page also has an edge row for templates and i18n.
- Project-specific details (RFC numbers, task names) appear only in the field-case source line.
- No new category.

## Local-layer candidates

These 16 rows are excluded from this PR. Each records one design decision from wiki-plan Phase B for a single task. To keep any of them, run wiki-ingest inside that project.

| Row | Project | Decision | Target |
|-----|---------|----------|--------|
| 703c038c4e2cff12 | linkly (`shag`) | t5 RFC-0072 §1 production block content and order | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| aaa5aee77ff2e7e6 | linkly (`shag`) | t5 RFC-0072 §1 prose units and order | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| da44fbc670bb9772 | linkly (`shag`) | t5 cross-RFC per-unit hash comparison | `wiki-local/qa/document-verification/cross-rfc-unit-equality.md` |
| 80c15ba6f768c903 | linkly (`shag`) | t4 how RFC-0069/0070 are produced (pinned manifests, build.sh) | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 36144195bfec2b75 | linkly (`shag`) | t4 order of units inside a composed section | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| ce1cc8a6eb6222b8 | linkly (`shag`) | t4 RFC-0069 §2 composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 348b44d058b38035 | linkly (`shag`) | t4 grammar productions | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 4fb3e32f4a9d90d1 | linkly (`shag`) | t4 headings and title | `wiki-local/qa/document-verification/rfc-status-block.md` |
| cbcb88efcd56851e | linkly (`shag`) | t4 relation text and quote containers | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 4985dc6c9fad7359 | linkly (`shag`) | t4 Status block of RFC-0069/0070 | `wiki-local/qa/document-verification/rfc-status-block.md` |
| a467d9853cd3de77 | linkly (`shag`) | t4 RFC-0048 contamination | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| c8615f2a589eebf8 | linkly (`shag`) | t4 RFC-0052 single-row binding delta | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 9745c911f7075a1e | linkly (`shag`) | t4 sentences an updater's restatement drops | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 00232b8f8800502c | linkly (`shag`) | t4 relative references inside carried updater text | `wiki-local/qa/document-verification/re-pointing-superseded-references.md` |
| cac14dbe3a1f0867 | linkly (`shag`) | t4 §Examples of RFC-0069 | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 7669b8098be66ad5 | dev-loop (`cormorant`) | t2-skill-prose: keep a page's `last_verified` when no source was re-checked | `wiki-local/qa/document-verification/last-verified-bumps.md` |
