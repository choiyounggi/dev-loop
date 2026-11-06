---
id: backend-common-ml-grouped-cross-validation-for-templated-examples
domain: backend
category: ml
applies_to: [general]
confidence: verified
sources:
  - https://scikit-learn.org/stable/modules/cross_validation.html
  - https://scikit-learn.org/stable/modules/classification_threshold.html
  - https://aclanthology.org/D19-1131/
  - "Field measurement 2026-11-06 (Korean intent-classifier rebuild, weather intent): 123 templated examples formed 69 near-duplicate groups; grouped CV F1 0.828 vs 0.854 per-example; one pair scored 0.66 with IDF and 0.77 without"
last_verified: 2026-11-06
related: [backend-common-llm-korean-summary-line-dedupe-by-bigram-overlap, backend-common-ml-mape-aligned-point-prediction]
---

# Cross-Validating a Classifier Trained on Templated or Paraphrased Examples

## When this applies

You report a cross-validation score, or tune a rejection (fallback / out-of-scope)
threshold, for a text classifier whose training examples were generated from
templates, slot fills or paraphrases — an intent classifier, a FAQ matcher, a
chatbot NLU — so several examples are near-copies of one another
("날씨 알려줘" / "날씨 알려줘요").

## Do this

1. **Group near-duplicates first, then split by group.** Build one group id per
   cluster of near-identical examples, and pass it as `groups` to a group-aware
   splitter. scikit-learn's guide: the i.i.d. assumption "is broken if the
   underlying generative process yields groups of dependent samples", and every
   sample in a validation fold must come from groups absent from its training fold.

| Need | Splitter |
|------|----------|
| K-fold score, classes roughly balanced | `GroupKFold` |
| K-fold score, some intents have few groups | `StratifiedGroupKFold` (keeps class shares per fold while keeping each group whole) |
| One train/validation split | `GroupShuffleSplit` |

2. **Build the groups from surface similarity the templates produce.** A
   working recipe: character 2–3-gram vectors, cosine similarity, link every pair
   at or above a cutoff, and take the connected components (single-link) as
   groups. When the template source is known, the template id is the simplest
   group id — use it directly.
3. **Pick the n-gram weighting by measuring known near-duplicate pairs.** With IDF
   on, a rare n-gram that differs between two copies (a sentence-final `요`) gets a
   large weight and pulls their similarity down; in the field measurement one
   pair dropped from 0.77 to 0.66, below a 0.75 cutoff, so the two copies landed
   in different groups. Score a handful of pairs you know are copies and a
   handful you know are distinct, and choose the weighting and cutoff that
   separate them.
4. **Choose the rejection threshold from out-of-fold predictions only.** Collect
   each example's score from the fold that did not train on it
   (`cross_val_predict` with the same `groups`), then pick the threshold there.
   scikit-learn's `TunedThresholdClassifierCV` follows the same rule: the
   threshold is tuned by internal cross-validation, not on the data that is
   scored at the end.
5. **Measure the rejection rate on a separate out-of-scope set the model never
   trained on.** Report in-scope accuracy/F1 and out-of-scope recall as two
   numbers (the CLINC150 protocol: threshold picked on validation, OOS recall =
   correctly rejected out-of-scope queries / all out-of-scope queries).
6. **Report the grouped score next to the per-example score once.** A large drop
   from per-example to grouped CV means the first number was measuring
   memorized near-copies; publish the grouped one.

## Edge cases

| Case | Then |
|------|------|
| Single-link chaining merges one intent into a few huge groups | Print the largest group's share of its intent; when one group holds most of an intent, raise the cutoff or group by template id |
| An intent has fewer groups than folds | Reduce `n_splits` to the smallest per-intent group count, or merge that intent's evaluation into a leave-one-group-out run |
| Near-copies span two intents (same phrasing, different label) | Keep them in one group across labels; split by group, and log the pair as a labeling conflict for the data owner |
| Threshold chosen, then data regenerated from changed templates | Rebuild the groups and re-pick the threshold; groups and threshold are tied to one data snapshot |
| No out-of-scope examples exist yet | Write or collect a small out-of-scope set before quoting a rejection rate; a threshold tuned on in-scope data alone has no measured false-accept rate |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run plain `KFold` / `StratifiedKFold` over templated examples | Split with `GroupKFold` / `StratifiedGroupKFold` on near-duplicate groups | Copies of the same sentence sit on both sides of the split and the score measures recall of memorized phrasing |
| Tune the threshold on the same predictions you report | Tune on out-of-fold predictions; report on a held-out set | A threshold fitted to the reported data inflates that report |
| Quote a rejection rate measured on the training examples | Measure it on an out-of-scope set the model never saw | Training examples are in-scope by construction, so the rate says nothing about unseen queries |

## Sources

- https://scikit-learn.org/stable/modules/cross_validation.html — §3.1.2.4 "Cross-validation iterators for grouped data": the i.i.d. sentence quoted above; `GroupKFold`, `StratifiedGroupKFold`, `GroupShuffleSplit`, `LeaveOneGroupOut`; samples in a validation fold come from groups not represented in the paired training fold
- https://scikit-learn.org/stable/modules/classification_threshold.html — §3.3: `TunedThresholdClassifierCV` tunes the decision threshold with internal cross-validation; `cv="prefit"` only with a new validation set
- https://aclanthology.org/D19-1131/ — Larson et al., EMNLP 2019 (CLINC150): out-of-scope threshold chosen on validation; out-of-scope recall reported separately from in-scope accuracy
- Field measurement 2026-11-06 (Korean intent classifier, weather intent): 123 template-generated examples → 69 groups at character 2–3-gram cosine ≥ 0.75 without IDF, single-link; F1 0.854 (per-example) → 0.828 (grouped; the threshold-selection change landed in the same run, so the drop is not from grouping alone); one known pair 0.66 with IDF vs 0.77 without
