---
id: testing-quality-diff-algorithm-dependent-line-counts
domain: testing
category: quality
applies_to: [git]
confidence: field-tested
sources:
  - https://git-scm.com/docs/git-diff
  - https://arxiv.org/abs/1902.02467
  - "Field case 2026-10-22 (an orchestration task gate on a README edit): default `--numstat` printed `20 20`, `--diff-algorithm=histogram` and `patience` printed `19 19`, a line-by-line compare found 19 differing lines"
last_verified: 2026-10-22
related: [testing-quality-json-manifest-edit-gates, testing-quality-unchanged-function-gates, testing-quality-checks-that-cannot-pass]
---

# Changed-Line Counts Depend on the Diff Algorithm

## When this applies

A plan, review, or done-gate expects an exact changed-line count for a text
file (`git diff --numstat`, `--stat`, or `git diff | grep -c '^[+-] '`), and the
edited lines sit on both sides of an unchanged line: table rows, then a blank
line, then a prose line; two edited paragraphs with one untouched line between
them.

## Do this

1. **Check the edit's content, not a count, when you can.** Assert the exact
   lines the edit should produce: the expected file text, or the exact set of
   `+`/`-` lines. When the edit replaces lines one for one (both versions have
   the same number of lines), a positional line-by-line compare of base and
   working tree gives a count that no diff algorithm can change.
2. **When the gate must stay a count, pin the algorithm in the command.** Write
   `git diff --diff-algorithm=histogram --numstat -- <path>` (or `patience`) in
   the plan, use the same command to compute the expected number, and record
   the command next to the number. Git offers several algorithms (`myers`,
   `minimal`, `patience`, `histogram`). They can pair lines differently, so the
   same edit can get different added/deleted counts.
3. **Pinning also removes the machine's own setting.** The `diff.algorithm`
   config changes what a bare `git diff` uses. A number measured on a machine
   with `diff.algorithm=histogram` can fail on a runner that uses the default
   `myers`, and the reverse.
4. **Run the gate on the planned edit before adopting it.** A count gate that
   has never run on a known-good edit can fail on correct work
   ([testing-quality-checks-that-cannot-pass]). If it fails, compare
   algorithms first (step 5) before you call the edit wrong.
5. **When a count is one higher than planned, run the other algorithms.** Run
   `--diff-algorithm=histogram`, `patience` and `minimal`. If any of them gives
   the planned number and a line-by-line compare agrees, the content is right.
   Only the default algorithm's pairing is off: it pulled an unchanged line
   (often a blank one) into the neighbouring changed block.

## Edge cases

| Case | Then |
|------|------|
| The edit inserts or deletes lines, so a positional compare does not line up | Use the exact `+`/`-` line set or the expected file text (step 1); a positional compare only fits one-for-one replacements |
| The gate counts a JSON manifest edit | Compare the parsed documents ([testing-quality-json-manifest-edit-gates]); JSON's comma rule changes the count even with a single algorithm |
| The gate must prove a named function is untouched | Compare the function's source segment ([testing-quality-unchanged-function-gates]), not diff lines |
| You need the smallest possible diff, not a readable one | `--minimal`: git says it spends extra time "to make sure the smallest possible diff is produced", so the default does not promise that |
| The gate reads `--stat` instead of `--numstat` | Same issue: both report the counts of the diff git produced; pin the algorithm the same way |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Fix a red count gate by changing the expected number to what your machine prints | Pin `--diff-algorithm` in both the measurement and the gate, or switch to a content check | The new number holds only for that algorithm and that machine's `diff.algorithm` setting |
| Call an edit wrong because `--numstat` is one higher than planned | Run histogram/patience and a line-by-line compare first (step 5) | The default algorithm can count an unchanged blank line as removed and re-added |

## Sources

- https://git-scm.com/docs/git-diff (fetched 2026-10-22) — `--diff-algorithm` lists `default`, `myers`, `minimal`, `patience`, `histogram`; `myers`: "The basic greedy diff algorithm. Currently, this is the default."; `--minimal`: "Spend extra time to make sure the smallest possible diff is produced."; `--numstat`: "shows number of added and deleted lines in decimal notation". The same page's note that a non-default `diff.algorithm` config is overridden with `--diff-algorithm=default` was seen in a web-search summary of the git man pages, not in the fetched text
- https://arxiv.org/abs/1902.02467 — Nugroho, Hata, Matsumoto, "How different are different diff algorithms in Git?" (Empirical Software Engineering; ICSE 2020 journal-first). On 14 Java projects, Myers and Histogram gave different added/deleted-line results: 0.8%–6.2% for added lines and 1.4%–7.6% for deleted lines. Read only through a web-search summary in this run, not fetched
- Field case 2026-10-22 (an orchestration task's README edit: changed table rows, a blank line, then a changed prose line): default `git diff --numstat` printed `20 20`; `--diff-algorithm=histogram` and `--diff-algorithm=patience` printed `19 19`; a Python line-by-line compare found 19 differing lines, and the blank line between the two blocks was byte-identical (`od -c` showed `\n` on both sides). The plan's expected count was 19. One field case, so this page is field-tested
