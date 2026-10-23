---
id: platforms-shells-stderr-merged-into-a-captured-value
domain: platforms
category: shells
applies_to: [bash, zsh, sh, general]
confidence: verified
sources:
  - https://www.gnu.org/software/bash/manual/bash.html#Redirections
  - https://docs.python.org/3/library/sys.html#sys.stdout
last_verified: 2026-10-23
related: [platforms-processes-tool-diagnostics-without-a-failing-exit-code, platforms-shells-redirection-order-for-a-silenced-write, platforms-processes-parsing-cli-structured-output, platforms-shells-echo-of-text-you-did-not-write]
---

# A Captured Value That Also Carries the Helper's Stderr

## When this applies

A shell script captures a helper's output (`VAR="$(python3 helper.py 2>&1)"`) and
then uses `$VAR` as a value — a path, an id, a key to compare — rather than as
text to show a person. Also when such a script times out or exits with an
unexpected code while a check like `[ -n "$VAR" ]` passed.

## Do this

1. **Have the helper print the value on a labelled line** (`TICK=/path/to/file`,
   `SECRET_SOURCE=env`).
2. **Capture once with the exit status, then extract by prefix:**

   ```sh
   OUT="$(python3 helper.py 2>&1)"; rc=$?
   TICK="$(printf '%s\n' "$OUT" | sed -n 's/^TICK=//p')"
   [ "$rc" -eq 0 ] || { printf 'helper failed (rc=%s): %s\n' "$rc" "$OUT" >&2; exit 1; }
   ```

   Warnings on stderr (DeprecationWarning, a library banner) can land before or
   after the labelled line; the prefix extraction ignores both, and when the
   label is absent the value is empty, so the script's existing "not set" branch
   still runs. `$OUT` keeps the full text for the error message.
3. **Match a sibling block that already does this.** When the same script
   extracts another value by prefix, copy that shape for the new value.

| Capture | Use it when |
|---------|-------------|
| `$(cmd 2>&1)` whole | The text goes to a person (print, log, error message) |
| `$(cmd 2>/dev/null)` | The helper's stdout is the value alone, and losing its warnings is acceptable |
| `OUT=$(cmd 2>&1); rc=$?` then `sed -n 's/^KEY=//p'` on `$OUT` | You need the value, the diagnostics, and the helper's exit status |
| `$(cmd 2>&1 \| sed -n 's/^KEY=//p')` | Only when a failed helper and a missing label may be handled the same way — the pipeline's status is `sed`'s, so a crash reads as "label absent" and `set -e` does not stop |

## Edge cases

| Case | Then |
|------|------|
| Python stdout goes to a pipe | It is block-buffered while stderr is not, so stderr text can appear *before* stdout text written earlier — do not rely on "the value is the first line" |
| The value itself may legitimately start with the label text | Choose a label that cannot occur in the value (`__TICK__=`), or emit JSON and parse it ([platforms-processes-parsing-cli-structured-output]) |
| Several labelled lines with the same key | `sed -n …p` returns all of them; add `\| tail -n 1` (or make the helper print once) so the value stays one line |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Use `"$(cmd 2>&1)"` as a path or id | Capture with `rc=$?`, then extract the labelled line with `sed -n 's/^KEY=//p'` | One warning makes the value two lines; `-n` checks still pass and `stat`/`test` just fail, so the bug surfaces as a timeout or a wrong exit code |
| Guard the value with `[ -n "$VAR" ]` | Guard the extracted value, or test the target directly (`[ -f "$VAR" ]`) | A polluted value is non-empty |

## Sources

- https://www.gnu.org/software/bash/manual/bash.html#Redirections — `2>&1` duplicates stderr onto the current stdout; inside `$(...)` that is the capture
- https://docs.python.org/3/library/sys.html#sys.stdout — when not interactive, stdout is block-buffered while stderr is line-buffered, which makes the interleaving order unreliable
- Local reproduction 2026-10-23 (zsh 5.9, Python 3, macOS): a helper printing `TICK=/var/run/tick.json` plus one stderr warning gave a 2-line `$(… 2>&1)` value for a warning emitted before *and* for one emitted after the value (the trailing warning was printed first); `[ -n ]` passed, `stat` on the value returned rc 1; the `sed -n 's/^TICK=//p'` form returned exactly the path in all three cases and an empty string when the label was absent. A helper that printed to stderr and exited 3: the one-pipeline form gave rc 0 and an empty value; the capture-first form gave rc 3 with the diagnostic in `$OUT`
- Field case 2026-10 (a detector-enable script): an existing gate in the same file extracted `SECRET_SOURCE=` by prefix and was safe; a newly added block used the whole `2>&1` capture as a file path, so a warning turned the mtime read into 0 and the script waited 90 s and exited 5
