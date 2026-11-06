# Knowledge flush — 1 insight(s)

Headless autoflush run, 2026-11-06 (claims by run `20261106-134854-81372`). Claimed 3 candidates: 1 ingested as a new page, 2 released back to `pending` as pending duplicates of open PRs.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `2c78c188c0a60329` — Apple Silicon: measure CPU fp32 / MPS fp32 / MPS fp16 p95 for batch-1 embedding inference; re-check accuracy after fp16 | platforms hint → backend/ml | **ingested** — new page `backend-common-ml-inference-device-choice-on-apple-silicon` (verified) |
| `b5863e2d758c98fb` — Claude Code behind a gateway still sends bootstrap/penguin_mode requests while a claude.ai login remains | platforms | released — pending duplicate of open #328 / #298 |
| `fc76dc4dfa08ecde` — Docker-gated schema validator: skip vs fail, known-bad document | testing | released — pending duplicate of open #300 / #317 |

## Verified best-practice

**`2c78c188c0a60329` — confidence: verified.** Official docs and PyTorch issue measurements back the method. The speed numbers are one machine's field measurement, and the page labels them that way.

- Claim: on Apple Silicon, for one-sentence-per-call transformer inference, do not choose the device from the "MPS loses at small batch" rule. Measure CPU fp32, MPS fp32 and MPS fp16 p95 on the target machine, and re-check the task metric after switching to fp16.
- Sources checked (WebSearch; this run has no WebFetch, so pages were confirmed through search summaries, not fetched):
  - https://docs.pytorch.org/docs/2.14/notes/mps.html — the MPS backend, `is_available()` / `is_built()`, and the macOS/device requirement.
  - https://github.com/pytorch/pytorch/issues/148219 — measured per-op dispatch overhead: 1-element `mul` 24.5 µs on MPS (24.2 µs dispatch) vs 0.9 µs on CPU. This is why the rule holds for tiny ops.
  - https://github.com/pytorch/pytorch/issues/77799 — BERT inference about 2× slower on MPS than CPU in the report. The rule of thumb is real for some shapes, so the page asks you to measure.
  - https://sbert.net/docs/sentence_transformer/usage/efficiency.html — fp16 "can speed up inference on GPUs at a minimal loss of model accuracy". That is "minimal", not "zero", which supports the re-check step.
  - https://sbert.net/examples/sentence_transformer/applications/computing-embeddings/README.html — the model is placed "on the most performant available device, e.g. cuda or mps" when `device` is unset. This supports the "pin the device" step.
  - https://github.com/huggingface/sentence-transformers/pull/4169 — Transformers v5 loads the checkpoint dtype, so half precision can land on CPU and be "significantly slower than float32". This became an edge row.
  - https://github.com/kkollsga/kglite/pull/208 — a third-party server forced CPU because MPS placement grew memory by several GB (bge-m3 ~30 ms MPS vs ~65 ms CPU). This supports the memory row and gives an independent case of MPS winning at batch 1.
  - Field evidence from the source session: M4 Pro, torch 2.15. `arctic-embed-l-v2.0-ko` p95 was 46.0 / 20.6 / 13.5 ms (CPU fp32 / MPS fp32 / MPS fp16). Qwen3-Embedding-0.6B was 62.6 / 30.7 / 18.7 ms. The fp16 model kept F1 at 0.931.
- Changed from the candidate:
  - Added "pin `device` and `dtype` explicitly", because the library auto-selects MPS and Transformers v5 loads the checkpoint dtype.
  - Added warm-up exclusion and version recording.
  - Turned "re-check accuracy" into "re-run the task metric on the eval set".
  - Added a decision table, a small-model edge row, a memory row and a half-precision-on-CPU row.
  - The "600M급" size claim became an edge row stated as a field measurement, not a general size cutoff.
- Not verified externally: the exact model size at which MPS starts to beat CPU at batch 1. The page gives no cutoff and tells the reader to measure.

**`b5863e2d758c98fb`, `fc76dc4dfa08ecde`**: released before verification (see Open-PR check).

## Existing-layer check

Pages read: backend-common-llm-self-hosted-model-load-latency, debugging-performance-profile-before-optimizing, backend-common-ml-mape-aligned-point-prediction

- Indexes read: `INDEX.md`, `wiki/backend/index.md` (full), `wiki/platforms/index.md` (full).
- `wiki_search` hits considered (3 queries: the device-choice/p95 phrasing, "Apple Silicon MPS GPU embedding model inference", and the fp16 accuracy phrasing). Top hits:
  - `backend-common-reliability-timeouts-and-retries`
  - `debugging-concurrency-intermittent-failures`
  - `databases-selection-vector-search-engine-selection`
  - `backend-common-ml-mape-aligned-point-prediction`
  - `debugging-performance-profile-before-optimizing`

  No hit covers choosing an inference device or dtype.
- `debugging-performance-profile-before-optimizing` owns the general method: measure distributions (median and p95), and separate cold runs from warm runs. The new page applies it to one decision (device and dtype) and links to it instead of restating it. Not a merge target: its trigger is "something is slow", not "choosing a device".
- `backend-common-llm-self-hosted-model-load-latency` covers warm-up for a model server (Ollama), not in-process device choice. Linked, not merged.
- `platforms` has no ML or accelerator category, and its scope is OS differences that break code. Device choice is a model-serving decision, so it does not fit there.
- Created: new page `wiki/backend/common/ml/inference-device-choice-on-apple-silicon.md`.
- Related links: the new page links to both pages above. Back-links were added to both pages' `related:`.
- Conflicts: none.
- `wiki/backend/index.md`: one row added at the top of the `ml` table. `log.md`: one ingest entry appended.
- Not edited: the root `INDEX.md` backend line and the `common` summary row in `wiki/backend/index.md`. Open PR #298 edits `INDEX.md`, and #329/#315/#298/#334 edit `wiki/backend/index.md`. The `ml` table row is enough to route there.

## Open-PR check

23 open `knowledge/*` PRs: #334, #332, #331, #330, #329, #328, #324, #319, #318, #317, #315, #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. This headless run cannot fetch or diff branch content. Overlap was judged from each PR's title and changed-file list (`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/" --json number,title,files`), plus #334's report body.

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| `2c78c188c0a60329` inference device choice on Apple Silicon | None on trigger. #334 adds `backend/common/ml/grouped-cross-validation-for-templated-examples.md`, which is about model-evaluation splits, a different trigger. It also adds one row to the same `ml` index table; its position could not be diffed from here. This PR inserts its row at the top of that table. If the two rows land next to each other, the merge conflict is two independent rows, and keeping both resolves it. No open PR touches `debugging/performance/` or `backend/common/llm/self-hosted-model-load-latency.md`. The platforms PRs (#328, #324, #319, #309, #299, #298) cover agent CLIs, shells, tmux and tools, not ML inference | **new** |
| `b5863e2d758c98fb` gateway + leftover claude.ai login | #328 edits `platforms/processes/spawning-an-agent-cli-from-a-server.md` with `ANTHROPIC_BASE_URL`/`ANTHROPIC_AUTH_TOKEN` gateway rows. #298 adds `backend/common/llm/gateway-model-alias-resolution.md`. Same trigger family, and both PRs are still open | **pending duplicate → claim released** |
| `fc76dc4dfa08ecde` Docker-gated schema validator: skip vs fail | #300 and #317 edit `testing/quality/checks-that-cannot-pass.md` (and #300 also `tests-that-cannot-fail.md`). Same theme (a validator that skips or always passes), and both PRs are still open. This run could not locate the row's queue file. Its summary is taken from #334's report, which read it | **pending duplicate → claim released** |

## Routing decision

- `2c78c188c0a60329` → `backend` / `common/ml` → new page `wiki/backend/common/ml/inference-device-choice-on-apple-silicon.md`.
  - The candidate's domain hint was `platforms`. That domain covers OS-level differences that break code across macOS/Linux/Windows, and this lesson is about which device a model runs on, which `backend/common/ml` owns.
  - The directive is general: any PyTorch transformer served one request at a time on Apple Silicon. Project names and numbers appear only in the field-evidence Sources line.
  - No new category.

## Local-layer candidates

none

## Queue bookkeeping

- Retired in place (`status: retired`, `retiredBy`, `retiredAt`, `outcome`), the same way earlier headless runs retired rows: `2c78c188c0a60329`.
- Released back to pending with `queue-claim.js release`: `b5863e2d758c98fb`, `fc76dc4dfa08ecde`.
- Reviewer note: `b5863e2d758c98fb` and `fc76dc4dfa08ecde` have now been released by seven or more consecutive runs while #298/#300/#317/#328 stay open. Merging or closing those PRs, or one manual `/dev-loop:knowledge-flush` (which can diff them), would clear them.
