---
id: qa-process-blind-llm-judgment-of-a-visual-rule
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://arxiv.org/abs/2310.13548
  - https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
  - https://arxiv.org/abs/2306.05685
  - https://arxiv.org/abs/2404.18796
  - https://arxiv.org/abs/2305.04388
  - "Field case 2026-10-09 (a generated-sprite variant task: a pixel/colour-distance rule replacing 'distinguishable at a glance', checked by blind LLM-subagent judgments over two review rounds)"
last_verified: 2026-10-09
related: [qa-process-fresh-context-code-review, backend-common-change-impact-corpus-sweep-before-a-rejection-rule]
---

# Checking a Measurable Rule That Stands In for a Human-Eye Criterion

## When this applies

An acceptance criterion is judged by eye ("the variants are distinguishable at
a glance", "the icon reads at 16 px"), you replace it with a measurable rule —
changed pixels, colour distance, region counts — and you use LLM subagents
(vision models) as the judges that check the rule matches what a viewer sees.

## Do this

1. **Brief the judge blind.** Give it the images and the viewer's question
   ("can you tell these two apart at a glance? which pairs are hard?"). Leave
   out the rule, the threshold, the expected answer and which pairs you are
   worried about. A belief stated in the prompt, even a weak one, moves a
   model's answer toward it.
2. **Ask for the reasoning first and the verdict last**, one line per pair.
3. **Read every line of the answer, not only the final yes/no.** A pair the
   judge calls weak, close or "only the shirt differs" fails the rule check,
   even when its last line says "yes, all distinguishable".
4. **Run three judges on the same images and treat a split as a failure.** A
   re-run with a fresh judge (Edge cases) counts as one more judge in the tally. In
   the field case, judges disagreed about the same pair (only the top colour
   differed). A pair that passes only some judges is not distinguishable at a
   glance.
5. **Put two thresholds in the rule: one per cue and one for the whole pair.**
   Per cue: hair, top, silhouette, each measured on its own layer. Whole pair:
   measured on the two composited images. A per-cue count measures the layer
   before other parts cover it, so it overstates what is visible. In the field
   case a hair recolour changed 76 cells on its layer, but only 39 cells differed
   between the two final images.
6. **Score the judges' failed pairs with the rule before you change it**
   ([backend-common-change-impact-corpus-sweep-before-a-rejection-rule]): every
   pair the judges flagged must fail the new rule.

| Judge output | Treat as |
|--------------|----------|
| Every pair passes, no pair mentioned as weak, all judges agree | Rule check passed for this image set |
| Final "yes" but a pair named as weak or close | That pair fails |
| Judges split on a pair | That pair fails |
| A judge names a pair the rule passes | The rule is too loose: measure that pair (step 6) and tighten the rule |

## Edge cases

| Case | Then |
|------|------|
| The judge's reasoning and its verdict disagree | Use the pair-level text, and re-run that pair with a fresh judge. A model's stated reasoning can also misstate why it decided (Turpin et al.), so one judge's text is not final either |
| You need to reproduce a judge's finding | Fix the generator seed and save the exact images the judge saw |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Tell the judge "the rule should make these distinct, confirm" | Ask the viewer's question with no rule and no expected answer (step 1) | In a text QA study, a user suggesting a wrong answer lowered accuracy by up to 27% for one model (Sharma et al.); a judge told the expected outcome is exposed to the same pull |
| Grep the judge's last line for "yes" | Read every pair line (step 3) | The qualified pairs are in the body, not the summary line |
| Accept the rule on one judge's pass | Use several judges and fail any split (step 4) | Single judges carry their own biases; a panel of judges is the documented answer to that |
| Set one threshold on per-layer pixel counts | Add a whole-pair threshold on the final images (step 5) | Parts that cover each other make per-layer counts larger than the visible difference |

## Sources

- https://arxiv.org/abs/2310.13548 — Sharma et al. 2023, sycophancy (quotes from the paper body, §3.3, not the abstract): "The user suggesting an incorrect answer can reduce accuracy by up to 27% (LLaMA 2; Fig. 3)"; "even weakly expressed beliefs can substantially affect AI assistant behavior" (step 1)
- https://platform.claude.com/docs/en/test-and-evaluate/develop-tests — "Use a grader model with thinking on, so that it reasons before it produces an evaluation score. This increases evaluation performance, particularly for tasks requiring complex judgment" (step 2)
- https://arxiv.org/abs/2306.05685 — Zheng et al. 2023: LLM judges show "position, verbosity, and self-enhancement biases, as well as limited reasoning ability" (step 4)
- https://arxiv.org/abs/2404.18796 — Verga et al. 2024: a single judge brings intra-model bias; "We propose instead to evaluate models using a Panel of LLm evaluators (PoLL)" (step 4)
- https://arxiv.org/abs/2305.04388 — Turpin et al. 2023: "CoT explanations can systematically misrepresent the true reason for a model's prediction" (edge case 1)
- Field case 2026-10-09 (field-tested, no external source): steps 3, 5 and 6 and the thresholds come from four blind judgments in round 1 and a seed-17 reproduction in the third audit. In round 2, the rule received to fix the failed pairs would have passed 5 of the 6 named pairs. No general source was found for the per-cue overstatement in step 5
