---
id: testing-quality-polling-completion-predicates
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
last_verified: 2026-08-04
related: [testing-quality-harness-reverse-controls, testing-quality-tests-that-cannot-fail, testing-quality-checks-that-cannot-pass, platforms-shells-portable-shell-scripts]
---

# A Poll Loop's "Everything Finished" Predicate

## When this applies

You are writing or reviewing a monitor, watcher, or wait loop that decides
"all the work is done" by matching text in a status file or command output,
and that verdict gates something downstream (merging, reporting, starting the
next stage). Also when such a monitor announced completion suspiciously early.

## Do this

1. **Run the predicate against the not-yet-done state and require it to answer
   "not done", before you let it gate anything.** A completion predicate is only
   evidence if it can report "not yet"; observing it say "done" proves nothing on
   its own. This is the negative control that
   [testing-quality-harness-reverse-controls] requires of any harness that scores
   its own subject — here the correct control verdict is *incomplete*.
2. **Decide completion by counting: require the finished count to equal a
   non-zero item total.** An over-matching pattern then shows up as a mismatch
   between two numbers instead of disappearing into an empty leftover list.

| Predicate shape | Verdict when the pattern over-matches |
|-----------------|----------------------------------------|
| "no line fails to match `done`" (`grep -v … \| grep -q .`) | Every line matches, nothing is left over, and the loop reports complete on its first poll |
| "count of `done` lines equals count of item lines" | Over-matching inflates both sides unequally and the mismatch stays visible |

3. **Match status tokens literally with `grep -F`.** POSIX `grep` treats a pattern
   as a basic regular expression by default; `-F` makes it "Match using fixed
   strings. Treat each pattern specified as a string instead of a regular
   expression." A status token wrapped in square brackets is the dangerous case:
   as a BRE, `[completed]` is a bracket expression matching *one character* from
   `{c,o,m,p,l,e,t,d}`, so it matches almost any English status word.
4. **Re-assert the pattern at the layer that finally runs it.** Each shell,
   `ssh`, `tmux send-keys`, or `-c "…"` hop re-parses quoting, so a backslash that
   escaped a bracket in the source can be gone by the time `grep` sees it; a
   literal-string flag survives every hop where an escape does not
   ([platforms-shells-portable-shell-scripts]).
5. **Bound the loop with a deadline and exit with a status distinct from
   success** when it expires, so "never finished" cannot be read as "finished".

## Edge cases

| Case | Then |
|------|------|
| The status source is empty on the first poll (no items yet) | Require a non-zero item count as part of the done condition — `0 == 0` is the same arithmetic as "all complete" ([testing-quality-checks-that-cannot-pass]) |
| Items can reach a terminal state that is not success (`failed`, `cancelled`) | Count each terminal state separately and make the loop's exit status name which one it saw; folding them into "not running" reports a failed run as a finished one |
| A status line can hold two tokens at once (`[completed] after [retry]`) | Count matching *items*, keyed by item id, rather than matching lines |
| The pattern is supplied by config or an argument | Validate it at startup against one known-incomplete fixture, so a mistyped pattern fails at launch rather than at the first poll |
| The monitor drives an automated merge or deploy | Add the control run to the pipeline itself, not just to development — a predicate that silently degrades to always-true ships the same failure |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Arm a completion monitor after watching it report "done" correctly once | Run it once against the incomplete state and require "not done" first | A predicate that matches everything also reports "done" correctly at the end; only the incomplete state separates it from a constant |
| Write `grep '[completed]'` for a bracketed status token | Write `grep -F '[completed]'` | As a BRE the brackets are a bracket expression matching a single character from the enclosed set, not the literal token |
| Escape the brackets (`\[completed\]`) and pass the pattern through nested shells | Pass the token to `-F` and leave it unescaped | Every quoting hop can consume the backslash; `-F` carries no escapes to lose |
| Conclude "all done" from an empty leftover list | Compare a finished count to a total count, both non-zero | An over-matching pattern empties the leftover list, which reads identically to real completion |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html — "-F  Match using fixed strings. Treat each pattern specified as a string instead of a regular expression"; patterns are otherwise treated as basic regular expressions
- https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html — §9.3.5 RE Bracket Expression: a bracket expression enclosed in `[]` matches a single character from the enclosed set
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — shell quote removal, i.e. why an escape can be consumed before the utility sees the pattern
- Field reproduction 2026-08-04 (task-board monitor): with 1 of 4 tasks complete, the board `t1 [completed] / t2 [implementing] / t3 [dispatch] / t4 [reviewing]` left `grep -v '[completed]'` with **zero** leftover lines — every status word contains a character from `{c,o,m,p,l,e,t,d}` — so the "nothing unfinished" predicate announced completion on the first poll. `grep -cF '[completed]'` returned 1 against 4 total lines and reported "still running" correctly; the same monitor then tracked four real state transitions
