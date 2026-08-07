# Knowledge flush — 1 insight ingested (2 dropped as pending-duplicates of open PR #51)

Queue drained: 3 pending candidates across 2 session files.

## Verified best-practice

**Ingested — MAPE-aligned point prediction** (from `avm-hackathon-jycho` session):

- **Claim:** A regression model trained to predict the conditional median (log target + L1 loss) and scored by MAPE is a structural overpredictor; the MAPE-optimal point prediction is the median of the 1/y-reweighted predictive distribution, which equals `median × exp(−σ²)` for a lognormal conditional. Correct per-row with `pred × exp(−λσ²)`, σ estimated from q16/q84 quantile spread, λ selected from 0.5 by multi-period holdout consistency rather than the theoretical 1.0.
- **Sources checked:**
  - https://arxiv.org/abs/0912.0902 — Gneiting, "Making and Evaluating Point Forecasts" (JASA 106:746–762, 2011). Table 5: the Bayes rule under absolute percentage error is the β-median with β = −1 (median of the y⁻¹-reweighted predictive distribution). Confirmed via WebSearch against arxiv.org and the tandfonline JASA record.
  - https://arxiv.org/abs/1605.02541 — de Myttenaere, Golden, Le Grand, Rossi, "Mean Absolute Percentage Error for regression models" (Neurocomputing 2016). Confirms MAPE-optimal regression ≡ 1/y-weighted MAE regression. The citation given in the raw candidate was checked and is real (also mirrored at hal.science/hal-01312590).
  - Lognormal algebra re-derived independently: for Y ~ LN(μ, σ²), y⁻¹·f(y) normalizes to LN(μ − σ², σ²), whose median is exp(μ − σ²) = median(Y)·exp(−σ²).
- **Verification result:** the shrinkage mechanism and its direction are **verified** against the two papers plus the closed-form derivation. The practical λ = 0.5 starting point and the "quantile spread overestimates σ" claim rest on the session's holdout evidence only (Seoul commercial-building AVM, LightGBM + CatBoost: λ = 0.5 improved MAPE on all 4 holdout years, 19.18% → 18.86% excluding 2025 outliers; λ = 1.0 degraded 2 of 4 years) — that part is **field-tested** and the page's Sources section says so explicitly. Page frontmatter is `confidence: verified` for the sourced mechanism, with the field-tested scope of the λ practice stated inline.

**Dropped candidates** (both from the linkly r3 orchestrate session) — see Open-PR check; neither was ingested, so no verification pass was spent upgrading them.

## Existing-layer check

Routing went INDEX.md → backend → domain index. A full-text sweep of the checkout's `wiki/` for `mape`, `percentage error`, `lognormal`, `quantile`, `lightgbm`, `calibration` returned **zero hits** — nothing in any layer covers regression-model point-prediction calibration, so this is a create, not a merge. The closest existing category is `backend/common/llm`, whose pages cover *consuming* LLM completion APIs, not training/evaluating predictive models; I opened its nearest page to confirm the trigger space does not overlap (it gates on HTTP completion responses, not on metrics or point forecasts).

Pages read: backend-common-llm-completion-response-validation

No conflicts flagged. `related:` left empty — no genuinely adjacent page exists yet (the new category is a seed; future ML ingests should link here). Plumbing updated: `wiki/backend/index.md` gained a `### ml` section with a load-when line, the common-subtree route line and root `INDEX.md` backend line both mention MAPE-aligned point-prediction calibration, and `log.md` has the ingest entry.

## Open-PR check

Open `knowledge/*` heads listed via `gh pr list --search "head:knowledge/"`: #47 (`knowledge/dch0202-20260806-130040`), #49 (`knowledge/dch0202-rsquare-20260806-142309`), #50 (`knowledge/dch0202-20260806-172420`), #51 (`knowledge/dch0202-20260806-183029`), #52 (`knowledge/dch0202-rsquare-20260807-100149`).

Per-candidate verdicts:

- **Candidate 1 — worktree_escape guardrail escalation on cross-worktree reads** (linkly): **drop**. Fetched and diffed `origin/knowledge/dch0202-20260806-183029` (#51) against main: its `wiki/infrastructure/agent-orchestration/worktree-isolated-workers.md` additions already carry this insight in strictly better form — including the exact "budget the escalation round trip (read → approve → clear escalations/ → restart the watcher) and state in the worker's first brief that reads are approved" row. #51 additionally *corrects* the raw candidate: its local reproduction (guardrails 1.2.0) shows pure reads pass and the rule fires only when a main-root mention co-occurs with a write verb or an absolute-path redirect — the candidate's blanket "fires on read-only access" phrasing is the pre-correction version. Nothing unique to fold; retired as pending-duplicate.
- **Candidate 2 — Orca dispatch binding taxonomy (idle-prompt check; runtime_unavailable vs agent_unconfigured vs terminal_worktree_mismatch)** (linkly): **drop**. The same #51 diff's `wiki/infrastructure/agent-orchestration/pane-delivery-confirmation.md` additions carry all four rows (bind only on idle prompt because "done" is a report not the turn's end; wait-and-rebind for occupied runtime; close pane + new worker-mode agent for a dead one; always pass worktree with pane) citing the same three 2026-08-06 field incidents the candidate cites. Nothing unique to fold; retired as pending-duplicate.
- **Candidate 3 — MAPE-aligned point prediction** (avm-hackathon): **new**. No overlap with any open head — #47/#49/#50/#52 are testing/shell/encoding-themed and #51's wiki diff (11 files) touches no ML content. Ingested here.

## Routing decision

- **Candidate 3 → `backend/common/ml/mape-aligned-point-prediction.md`** (id `backend-common-ml-mape-aligned-point-prediction`), **new category `ml`** under backend/common. Justification for the new category: the harvested domain hint was `backend`, and the backend domain's 12 existing categories (api-design, auth, caching, change-impact, concurrency, errors, integrations, jobs, llm, orm, reliability, storage) all cover server-side application code concerns; none covers training or evaluating a predictive model. `llm` is the nearest name but its scope is consuming LLM completion APIs from server code — putting metric-aligned regression calibration there would corrupt its load-when gate. No other domain fits better (databases owns SQL/schema; qa owns release process). The category seeds with one page.
- Candidates 1–2: no routing — dropped as pending-duplicates of open PR #51 (see above); their queue rows are retired to `.processed.jsonl` so the auto-flush cannot re-surface them.
