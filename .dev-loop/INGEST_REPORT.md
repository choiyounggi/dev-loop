# Knowledge flush — 1 insight(s)

Headless autoflush run, 2026-11-06 (claims by run `20261106-124649-3684`). Claimed 3 candidates: 1 ingested as a new page, 2 released back to `pending` as pending duplicates of open PRs.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `873d73b347fd363a` — group near-duplicate templated examples before CV; threshold from out-of-fold predictions; rejection rate on a held-out set | testing hint → backend/ml | **ingested** — new page `backend-common-ml-grouped-cross-validation-for-templated-examples` (verified) |
| `b5863e2d758c98fb` — Claude Code behind a gateway still sends bootstrap/penguin_mode requests while a claude.ai login remains | platforms | released — pending duplicate of open #328 / #298 |
| `fc76dc4dfa08ecde` — Docker-gated schema validator: skip vs fail, known-bad document | testing | released — pending duplicate of open #300 / #317 |

## Verified best-practice

**`873d73b347fd363a` — confidence: verified** (the method is backed by official docs; the specific cutoff and IDF setting are field measurements and the page labels them that way).

- Claim: when intent-classifier examples come from templates or paraphrases, split CV by near-duplicate groups (`GroupKFold` / `StratifiedGroupKFold`), choose the rejection threshold from out-of-fold predictions only, and measure the rejection rate on a separate out-of-scope set.
- Sources checked (WebSearch; this run has no WebFetch, so pages were confirmed through search summaries, not fetched):
  - https://scikit-learn.org/stable/modules/cross_validation.html — §3.1.2.4 "Cross-validation iterators for grouped data": "The i.i.d. assumption is broken if the underlying generative process yields groups of dependent samples"; samples in the validation fold must come from groups not in the paired training fold; `GroupKFold`, `StratifiedGroupKFold`, `GroupShuffleSplit`, `LeaveOneGroupOut`.
  - https://scikit-learn.org/stable/modules/classification_threshold.html — §3.3: `TunedThresholdClassifierCV` tunes the decision threshold with internal cross-validation; `cv="prefit"` only with a new validation set.
  - https://aclanthology.org/D19-1131/ — Larson et al., EMNLP 2019 (CLINC150): the out-of-scope threshold is chosen on validation data; out-of-scope recall is reported apart from in-scope accuracy.
  - Field evidence from the source session: 123 weather templates formed 69 groups; F1 went from 0.854 to 0.828 (the threshold-selection change landed in the same run, and the page says so); one known pair scored 0.66 with IDF and 0.77 without.
- Changed from the candidate: the candidate stated "no IDF, cosine ≥ 0.75" as the rule. The page gives the n-gram/single-link method as one working recipe, adds "use the template id as the group id when you have it", and turns the IDF choice into a measurement step (score known copy and non-copy pairs, then choose). A single cutoff from one dataset is not general. Added `StratifiedGroupKFold` for intents with few groups and an edge row for single-link chaining.
- Not verified externally: that IDF lowers similarity between near-copies in general. This rests on the session's measured pair, and the page cites it as a field measurement.

**`b5863e2d758c98fb`, `fc76dc4dfa08ecde`** — released before verification (see Open-PR check).

## Existing-layer check

Pages read: backend-common-ml-benchmark-relative-signal-classification, backend-common-ml-mape-aligned-point-prediction, backend-common-llm-korean-summary-line-dedupe-by-bigram-overlap

- Indexes read: `INDEX.md`, `wiki/backend/index.md` (full).
- `wiki_search` top hits considered for the candidate's trigger (3 queries: English trigger, ML-leakage phrasing, the Korean trigger sentence): `platforms-tools-agent-permission-classifier-denials`, `testing-quality-spec-artifact-checks`, `backend-common-ml-benchmark-relative-signal-classification`, `backend-common-llm-korean-summary-line-dedupe-by-bigram-overlap`, `testing-strategy-test-level-choice`. No hit covers model-evaluation leakage, grouped CV or out-of-scope thresholds. The "classifier" hits refer to the permission classifier, which is unrelated.
- `backend/common/ml` holds two model pages (MAPE point prediction, benchmark-relative signals). Neither covers evaluation splits, so this is a **new page** in that category rather than a merge.
- `backend-common-llm-korean-summary-line-dedupe-by-bigram-overlap` uses character-bigram overlap against a threshold for Korean text. It is the closest technique but has a different trigger (removing duplicate summary lines). It is linked, not merged.
- Related links: the new page links to the Korean dedupe page and the MAPE page. Back-links were added to both pages' `related:`.
- Conflicts: none.
- `wiki/backend/index.md`: one row added to the `ml` table. `log.md`: one ingest entry appended.
- Not edited: the backend row in root `INDEX.md` and the `common` row at the top of `wiki/backend/index.md`. Open PR #298 edits `INDEX.md`, and #329/#315/#298 edit `wiki/backend/index.md`, so changing those summary lines would likely conflict. The `ml` table row is enough to route there. Reviewer: add "grouped CV of templated classifier data" to the INDEX.md backend line after those PRs land if you want it in root routing.

## Open-PR check

22 open `knowledge/*` PRs: #332, #331, #330, #329, #328, #324, #319, #318, #317, #315, #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. This headless run cannot fetch or diff branch content, so overlap was judged from each PR's title and changed-file list (`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/" --json number,title,files`).

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| `873d73b347fd363a` grouped CV for templated examples | None. No open PR touches `backend/common/ml/`, model evaluation, or classifier thresholds. #315/#310/#301/#293/#317/#318/#319 touch `wiki/testing/index.md` rows on other triggers. #329 edits `wiki/backend/index.md` in the `api-design` section, not `ml` | **new** |
| `b5863e2d758c98fb` gateway + leftover claude.ai login | #328 edits `platforms/processes/spawning-an-agent-cli-from-a-server.md` with `ANTHROPIC_BASE_URL`/`ANTHROPIC_AUTH_TOKEN` gateway rows. #298 adds `backend/common/llm/gateway-model-alias-resolution.md`. Same trigger family (Claude Code behind a gateway). This matches the verdicts of runs #329, #330, #331 and #332, and both PRs are still open | **pending duplicate → claim released** |
| `fc76dc4dfa08ecde` Docker-gated schema validator: skip vs fail | #300 edits `testing/quality/checks-that-cannot-pass.md` and `tests-that-cannot-fail.md`. #317 edits `checks-that-cannot-pass.md`. A validator that is skipped or always says "valid" is their theme. This run read the row (queue file located through `~/.claude/history.jsonl`). The verdict is the same as runs #318, #319, #324 and #328, and both PRs are still open | **pending duplicate → claim released** |

## Routing decision

- `873d73b347fd363a` → `backend` / `common/ml` → new page `wiki/backend/common/ml/grouped-cross-validation-for-templated-examples.md`. The candidate's domain hint was `testing`, but the testing domain covers automated tests of code (levels, fixtures, mocks, flaky tests). This lesson is about evaluating a trained model's score, which the existing `backend/common/ml` category (model output calibration, signal grading) owns. The directive is general: any classifier trained on templated or paraphrased text. The source project appears only in a Sources line. No new category.

## Local-layer candidates

none

## Queue bookkeeping

- Retired in place (`status: retired`, `retiredBy`, `retiredAt`, `outcome`), the same way earlier headless runs retired rows: `873d73b347fd363a`.
- Released back to pending with `queue-claim.js release`: `b5863e2d758c98fb`, `fc76dc4dfa08ecde`.
- Reviewer note: `b5863e2d758c98fb` and `fc76dc4dfa08ecde` have now been released by six or more consecutive runs while #298/#300/#317/#328 stay open. Merging or closing those PRs, or one manual `/dev-loop:knowledge-flush` (which can diff them), would clear them.
