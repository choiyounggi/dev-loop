---
id: debugging-performance-attributing-a-benchmark-speedup
domain: debugging
category: performance
applies_to: [general]
confidence: verified
sources:
  - https://www.brendangregg.com/activebenchmarking.html
  - https://www.brendangregg.com/blog/2018-06-30/benchmarking-checklist.html
  - https://gernot-heiser.org/benchmarking-crimes.html
last_verified: 2026-10-02
related: [debugging-performance-profile-before-optimizing, debugging-methodology-hypothesis-testing, testing-quality-harness-reverse-controls, qa-deliverables-quantitative-claims-in-a-published-document, backend-common-llm-vendor-benchmark-claims-for-an-llm-tool]
---

# Attributing a Benchmark Speedup to a Specific Code Change

## When this applies

A benchmark run (yours or someone else's) reports a speedup or slowdown between
a "before" and "after" arm, and you are about to name which code change caused
it — in a commit message, PR description, README, or report. Also applies when
reviewing a PR that cites a benchmark number as evidence a specific change helped.

## Do this

1. **Find the exact construction of the baseline ("before") arm in the harness
   before naming a contributor.** Read the harness code, not the plausible
   story — locate the line that builds the baseline's config/pipeline/client and
   list every flag, feature toggle, and mocked/short-circuited step it sets.
2. **For each candidate contributing change, confirm its code path actually ran
   differently between the two arms.** A change contributes zero to the
   measured delta if the harness's baseline arm never reaches the code the
   change touches, or reaches it with a value that makes the change's effect
   moot (a timeout set to 0, a call mocked out, a cache pre-warmed only on one
   side).
3. **Trace the value, not the name, to its read site.** A knob the harness
   passes (`delay_seconds=0.0`) can be shadowed by a different default read
   deeper in the call stack (`default_config.DELAY_SECONDS`) if the component
   under test does not consult the harness's config for that value — grep for
   where the changed code actually reads its input, not where the harness sets
   it.
4. **When several changes landed in the same "after" arm, isolate each one's
   contribution before crediting all of them.** Re-run the benchmark with only
   the candidate change applied against the same baseline config; the
   plausible story ("we removed a sleep, so it's faster") is not evidence on
   its own — an untested co-change can be doing all the work.
5. **Run each arm several times and compare the delta against the run-to-run
   spread before attributing it.** When the before/after gap is smaller than the
   spread between repeated runs of the same arm, report it as noise, not a
   speedup; when it is larger, record the run count and spread beside the number.
   Caching, CPU frequency boost, GC, and background jobs perturb a single run.
6. **Explain the limiting factor before publishing the number.** State what
   made the after-arm's result the value it is (CPU-bound loop, network round
   trip removed, cache hit) — a number without a named mechanism is not yet an
   attribution, it is an observation.

| Check before attributing | Fails when |
|---|---|
| Baseline arm's harness-level config for the changed knob | The harness zeroes/mocks/short-circuits the exact setting the change touches, so the "before" cost was already absent in the measurement |
| Where the changed code reads that setting | The component reads a package-level/module default instead of the harness's injected config, so the harness's knob never reached the code path |
| Whether the change's code path executed at all in the baseline arm | A feature flag, early return, or stub in the baseline arm skips the code entirely — the delta then measures something else that also changed |
| Run-to-run spread of each arm | One run per arm; the delta is inside the variance of repeated runs of the same arm |
| Attribution when multiple changes landed together | Only one change was benchmarked in isolation; the others are credited by narrative, not measurement |

## Edge cases

| Case | Then |
|------|------|
| The knob the harness sets has a same-named default elsewhere in the codebase (env var, module constant, class default) that the exercised code path actually reads | Confirm which value wins by adding a temporary print/log at the read site during a harness run, not by reading the harness's construction call alone — construction and consumption can disagree |
| The "before" and "after" arms were run as separate benchmark invocations, not from the same harness config builder | Diff the two arms' effective config (dump it rather than assuming it), because a config default can differ between an old and a new invocation of the same script |
| The benchmark predates the change under review (already published, cited in a PR) | Re-run it with the suspected knob deliberately un-zeroed in the baseline arm and confirm the delta shrinks or disappears — a benchmark that cannot reproduce its own claimed mechanism should not be cited as attributing to it |
| The pass/fail rule for a run is a ratio to that run's own early window ("worst interval stays within N× of its first-interval mean") and you apply it to the patched arm | Fix the band once, from the unpatched arm — N× the median of the unpatched runs' first-interval means — and judge every run of both arms against that absolute band, written down before the patched runs; when a patched run's worst interval is above N× its own first interval, also read its per-interval series — a rising series is a regression the absolute band does not catch, a flat series with one spike is jitter; run each arm at least 3 times and report the absolute values beside any ratio. A change that removes the cost also lowers the patched arm's own denominator, so a small absolute excursion becomes a larger multiple and the rule can read a healthy run as still failing |
| No single change explains the whole delta after isolation | Report the unattributed remainder rather than folding it into the last change measured — an unexplained delta is a gap, not evidence for whichever change was tested last |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Credit a change because the headline number moved and the story is plausible | Read the baseline arm's harness config for the exact knob the change touches, and trace it to its read site | A knob the harness sets to zero for both arms makes the corresponding change contribute nothing to the delta, no matter how real the change is elsewhere — the story and the number can both be true while the attribution is backwards |
| Cite a benchmark number without naming what limited the "before" time | State the limiting factor (what made it slow) before publishing the delta | A number with no named mechanism cannot be checked by a reader, and often turns out to explain a different arm than intended |
| Judge a patched run by a multiple of its own first-window mean | Judge it against a band derived from the unpatched arm, in absolute units | The denominator moved with the patch: a run whose worst interval is ~1% of the unpatched arm's can still exceed "2× its own baseline" |
| Attribute a multi-change PR's speedup to "the changes" collectively | Re-run the baseline with each candidate change applied alone | Collective credit hides that one change (or an unrelated harness detail) did all the work |

## Sources

- https://www.brendangregg.com/activebenchmarking.html — "casual benchmarking: you benchmark A, but actually measure B, and conclude you've measured C"; verify what is being exercised while the benchmark runs rather than trusting the intended target
- https://www.brendangregg.com/blog/2018-06-30/benchmarking-checklist.html — "5. Does it reproduce? If you run the benchmark ten times, how consistent are the results? There may be variance (e.g., due to caching or turbo boost) or perturbations (e.g., system cron tasks, GC) that skew a single benchmark result"; "Can they explain why the benchmark result was X, and not 2X (twice as fast)? ie, what is the limiting factor?"; a misconfiguration (e.g. a firewall silently blocking traffic) can make a benchmark client believe it measured something it never ran
- https://gernot-heiser.org/benchmarking-crimes.html — "it does not at all follow that" a measured throughput delta equals the overhead of the change believed to cause it; comparisons must be made against the real, correctly configured baseline, not an assumed one
- Field evidence (a Python web-scraping pipeline, 2026-09-09): its `scripts/bench_pipeline.py:354` constructed the "before" arm with `Pipeline({"delay_seconds": 0.0, ...})`; `src/local_scraper.py:126` read `default_config.DELAY_SECONDS` (3.0) rather than the pipeline's injected value. The benchmark's headline speedup was attributed to a removed 3-second sleep, whose cost was already zero in the baseline arm's measurement; the actual driver was a real ~3s-per-host cost added by the sleep's replacement
- https://gernot-heiser.org/benchmarking-crimes.html — "Relative numbers only": "Always give complete result, not just ratios (unless the denominator is a standard figure)"; "No indication of significance of data": "Raw averages, without any indication of variance, can be highly misleading"
- Field evidence 2026-10-02 (an HTTP service under a 150 rps × 90 s open-loop load, 3 runs per arm): unpatched worst-interval latency 386 / 422 / 413 ms; patched 4.73 / 4.32 / 4.08 ms with 0 errors. The pre-registered rule was "worst interval ≤ 2× the run's own first-interval mean"; the patch lowered that mean from about 7 ms to about 2.3 ms, so patched run 1 scored about 2.05× and read as "still collapsing" while sitting at roughly 1% of the unpatched arm. Against a band of 2× the unpatched first-interval median (about 14 ms) all three patched runs pass and all three unpatched runs fail
