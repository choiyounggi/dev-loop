---
id: backend-common-ml-mape-aligned-point-prediction
domain: backend
category: ml
applies_to: [general]
confidence: verified
sources:
  - https://arxiv.org/abs/0912.0902
  - https://arxiv.org/abs/1605.02541
last_verified: 2026-08-07
related: []
---

# Point Predictions from a Median-Predicting Model Scored by MAPE

## When this applies

A regression model is evaluated by MAPE (mean absolute percentage error) and was
trained to predict the conditional median — the standard log-target + L1-loss
setup (LightGBM/CatBoost `regression_l1` on `log(y)`, quantile q50, or any
median regression). The model looks well-fitted yet systematically overshoots
on MAPE, or you are deciding what point value to emit from such a model.

## Do this

The MAPE-optimal point prediction is not the conditional median. MAPE is
1/y-weighted absolute error, so its Bayes rule is the median of the predictive
distribution reweighted by 1/y (Gneiting's med^(-1)); for a lognormal
conditional distribution that equals `median × exp(−σ²)`. A median-predicting
model is therefore a *structural* overpredictor under MAPE, and the gap grows
with conditional variance.

| Case | Do |
|------|----|
| Emitting point predictions under a MAPE metric | Apply a per-row correction `pred × exp(−λσ²)` instead of shipping the raw median |
| Estimating per-row σ | Train quantile models (e.g. q16/q84) and use half the spread in log space: `σ ≈ (log(q84) − log(q16)) / 2` |
| Choosing λ | Start from λ = 0.5, not the theoretical 1.0, and select by holdout consistency across several evaluation periods — accept a λ only if it improves every period, not just the average |
| Deciding between global and per-row correction | Per-row: a single global constant assumes homoscedasticity and undercorrects high-variance rows while overcorrecting low-variance ones |

## Edge cases

| Case | Then |
|------|------|
| The theoretical λ = 1.0 degrades some holdout periods while improving others | Expected — quantile-spread σ estimates are inflated (quantile crossings, spread widened by estimation noise), so full-strength shrinkage overshoots on low-variance segments; back λ off until every period improves |
| The conditional distribution is far from lognormal (heavy point mass, multimodal) | The `exp(−σ²)` form no longer follows; fall back to selecting a multiplicative shrinkage factor purely by holdout search |
| The metric is MAE or RMSE, not MAPE | Do not shrink — the median (MAE) or mean (RMSE) is already the optimal point forecast; this correction only applies to relative-error metrics |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ship raw log-target L1 predictions because the model "predicts the center" | Apply the `exp(−λσ²)` shrinkage before scoring | Under MAPE the center that scores best is the 1/y-weighted median, which sits below the ordinary median |
| Apply the textbook λ = 1.0 because the derivation says so | Validate λ ∈ [0.5, 1.0] on multi-period holdout and keep the value that improves all periods | The derivation assumes σ is exact; a spread-estimated σ is biased upward, so the theory value overcorrects |
| Fix overprediction with one global scale factor tuned on the mean | Use the per-row σ from quantile models | Global scaling ignores heteroscedasticity — precisely the rows where the median-vs-MAPE gap is largest get the wrong correction |

## Sources

- https://arxiv.org/abs/0912.0902 — Gneiting, "Making and Evaluating Point Forecasts" (JASA 106:746–762, 2011): Table 5 gives the Bayes rule per scoring function; for absolute percentage error it is the β-median with β = −1, the median of the 1/y-reweighted predictive distribution
- https://arxiv.org/abs/1605.02541 — de Myttenaere et al., "Mean Absolute Percentage Error for regression models" (Neurocomputing 2016): MAPE-optimal regression is equivalent to 1/y-weighted MAE regression
- Lognormal algebra: for Y ~ LN(μ, σ²), the 1/y-reweighted density is LN(μ − σ², σ²), whose median is `exp(μ − σ²)` = `median(Y) × exp(−σ²)`
- Field validation 2026-08-07 (Seoul commercial-building AVM, LightGBM + CatBoost, log target + L1): λ = 0.5 with q16/q84-spread σ improved MAPE on all 4 holdout years (19.18% → 18.86% excluding 2025 outliers); λ = 1.0 degraded 2 of 4 years — the λ selection practice is field-tested, the shrinkage mechanism itself is the sourced theory above
