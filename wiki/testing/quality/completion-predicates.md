---
id: testing-quality-completion-predicates
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://www.gnu.org/software/grep/manual/grep.html
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html
  - https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap09.html
last_verified: 2026-08-05
related: [testing-quality-checks-that-cannot-pass, testing-quality-tests-that-cannot-fail, platforms-shells-portable-shell-scripts, platforms-processes-background-services]
---

# A Predicate That Decides When Background Work Is Finished

## When this applies

You are writing the "everything is done" condition a monitor, wait loop, or
polling script uses to decide that background work (parallel tasks, a job fan-out,
a batch of agents) has completed, by matching a status marker in a status file or
command output. Also when such a monitor declared completion far sooner than the
work could have finished.

## Do this

1. **Run the predicate once while the work is provably unfinished, and require it
   to report not-done, before wiring it to anything.** This is the control that
   separates "the predicate detects completion" from "the predicate is constant
   true". A predicate first observed in the finished state has never been shown to
   discriminate — the mirror of the never-seen-passing gate in
   [testing-quality-checks-that-cannot-pass].

2. **Decide completion by counting, not by absence.** Require
   `done_count == total_count`, both counted explicitly:

```sh
done=$(grep -cF '[completed]' "$status")
total=$(wc -l < "$status")
[ "$done" -eq "$total" ] && echo "ALL COMPLETE" || echo "in progress ($done/$total)"
```

3. **Match a status marker containing regex metacharacters with `grep -F`.**
   GNU grep's `-F` "interpret[s] patterns as fixed strings, not regular
   expressions". Markers written as `[completed]`, `(ok)`, `task.done`, or
   `+finished` all carry metacharacters; `[...]` is a POSIX bracket expression
   that matches *one* character from the set, so `[completed]` matches any line
   containing `c`, `o`, `m`, `p`, `l`, `e`, `t`, or `d`.

4. **Keep the literal out of any nesting that can eat its escaping.** When the
   command passes through a wrapper, `ssh`, `tmux send-keys`, a hook, or a
   double-quoted string, the backslashes in `\[completed\]` are consumed one layer
   at a time and the pattern silently degrades into the bracket expression. `-F`
   removes the escaping requirement, so no layer can strip it
   ([platforms-shells-portable-shell-scripts]).

5. **Give not-done and cannot-read distinct outcomes.** When the status source is
   missing or unreadable, report that, rather than folding it into either verdict:
   a monitor that treats an unreadable file as "no incomplete lines" reports
   completion for work it never observed.

6. **State the expected count before the run.** When the predicate reports
   complete at a count you did not expect, the predicate is the unknown.

## Edge cases

| Case | Then |
|------|------|
| The status source has a trailing line without a newline | Count records with `grep -c ''` rather than `wc -l`; `wc -l` counts newlines and undercounts the last record, so the equality never holds |
| Status lines can carry several markers (`[completed] [retried]`) | Count lines, not occurrences — `grep -c` prints "a count of matching lines", so a line with two markers still counts once |
| Some units legitimately end in a non-completed terminal state (failed, skipped) | Make the predicate `terminal_count == total_count` over the full terminal set, and report the breakdown; otherwise a permanently failed unit blocks the loop forever |
| Total is not knowable from the status source | Pass the expected total in from whatever dispatched the work, and fail the monitor when the observed total exceeds it |
| The marker is a substring of another marker (`[complete]` inside `[completed]`) | Match the delimited form (`grep -cF '[complete]'` plus a length or suffix check), and verify with one line of each on a fixture |
| The predicate must run where only a regex is accepted | Escape the metacharacters and verify the pattern against a fixture containing one matching and one non-matching line before adopting it |
| The status source is empty on the first poll (no items yet) | Require a non-zero item count as part of the done condition — `0 == 0` is the same arithmetic as "all complete" ([testing-quality-checks-that-cannot-pass]) |
| Items can reach a terminal state that is not success (`failed`, `cancelled`) | Count each terminal state separately and make the loop's exit status name which one it saw; folding them into "not running" reports a failed run as a finished one |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Test completion with `grep -qv '[completed]'` ("no unfinished lines left") | Count matches and compare to the total | `[completed]` is a bracket expression matching any one of those letters, so nearly every line matches, the inverted search selects nothing, and the monitor reports completion on its first poll |
| Write the literal as `'\[completed\]'` and pass it through a wrapper or `send-keys` | Pass it as `-F '[completed]'` | Each nesting layer consumes one level of backslash; `-F` has no escaping to lose |
| Trust a monitor because it printed the right thing once the work had finished | Run it against a mid-flight status file and require not-done | A constant-true predicate is also correct at the end; only the unfinished state tells the two apart |
| Treat a missing status file as "nothing incomplete" | Exit with a distinct code and message for unreadable input | Absence of evidence is reported as completion, which is the failure mode that looks like success |
| Arm a completion monitor after watching it report "done" correctly once | Run it once against the incomplete state and require "not done" first | A predicate that matches everything also reports "done" correctly at the end; only the incomplete state separates it from a constant |
| Conclude "all done" from an empty leftover list | Compare a finished count to a total count, both non-zero | An over-matching pattern empties the leftover list, which reads identically to real completion |

## Sources

- https://www.gnu.org/software/grep/manual/grep.html — `-F`/`--fixed-strings`: "Interpret patterns as fixed strings, not regular expressions"; `-c`/`--count`: "print a count of matching lines for each input file"; `-v`/`--invert-match`: "Invert the sense of matching, to select non-matching lines", and with `-v`, `-c` counts non-matching lines
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html — exit status 0 = lines selected, 1 = no lines selected, >1 = an error occurred, so a read error and a genuine no-match are distinguishable
- https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap09.html — a bracket expression `[...]` matches a single character from the enclosed set; this is what turns a literal marker into an eight-letter character class
- Field reproduction 2026-08-04 (macOS, BSD grep): a three-line status file with one `[completed]` and two in-flight lines — `grep -c '[completed]'` returned 3 (every line), `grep -qv '[completed]'` selected nothing so the "no unfinished lines" test reported ALL COMPLETED, and `grep -cF '[completed]'` returned 1 against a total of 3. The original incident was an eight-task fan-out with one task complete, reported by its monitor as "ALL 8 TASKS COMPLETED" on the first poll. With a four-item board where one status word contained every letter in `{c,o,m,p,l,e,t,d}`, the "no unfinished" check still reports completion while the counting predicate correctly reports one of four done
