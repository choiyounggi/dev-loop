---
id: platforms-shells-line-by-line-read-loops
domain: platforms
category: shells
applies_to: [bash, sh, zsh]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/read.html
  - https://mywiki.wooledge.org/BashFAQ/001
  - https://mywiki.wooledge.org/BashFAQ/089
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html
  - https://man.openbsd.org/ssh
  - https://docs.docker.com/reference/cli/docker/compose/exec/
last_verified: 2026-10-01
related: [platforms-shells-portable-shell-scripts, platforms-processes-non-interactive-cli-invocation, platforms-tools-bsd-vs-gnu-cli, testing-quality-tests-that-cannot-fail, infrastructure-agent-orchestration-gate-evidence-exit-code-class]
---

# Shell Loops That Read Input One Line at a Time

## When this applies

A shell script walks its input with `while read … done < file`, `<<<"$text"`, or
`< <(cmd)` — a gate checker, a batch runner, a parser, a text-insertion helper.
Also when such a loop handles fewer items than the input holds and reports no
error: the last line is skipped, or everything after the first item never runs.

## Do this

1. **Write the loop header as `while IFS= read -r line || [ -n "$line" ]`.**
   `read` fills the variable and still returns non-zero when it reaches
   end-of-file before a newline, so a final line with no terminator is read and
   then dropped by a plain `while read`. Inputs built with `printf '%s'`, `$(…)`
   capture, or `<<<` on a value that came from command substitution commonly end
   that way. `IFS=` keeps leading/trailing whitespace; `-r` keeps backslashes.

2. **Give every stdin-reading command in the loop body its own stdin.** Each
   command in the body inherits the loop's stdin, which is the input being
   iterated. A command that reads stdin drains the remaining lines and the loop
   ends after one pass with exit 0.

| Body command | Do |
|--------------|----|
| `ssh host cmd` | `ssh -n host cmd` or `ssh host cmd </dev/null` |
| `docker compose exec -T svc cmd`, `docker exec -i`, `kubectl exec -i` | Append `</dev/null` — `-T` only disables the TTY; stdin is still forwarded |
| `ffmpeg` | `ffmpeg -nostdin …` |
| An unknown or changing set of commands (a runner that executes commands from a list) | Move the loop's input off fd 0: `while IFS= read -r line <&3 \|\| [ -n "$line" ]; do …; done 3< file` |

3. **Start a verdict variable at the failing value.** A gate that sets `ok=1`
   before the loop and clears it on a bad line reports "pass" when the body runs
   zero times. Initialize to fail, set pass only after at least one line was
   examined, and count the lines handled so "0 examined" is its own outcome.

4. **Prove the loop with a known-bad input and an item count.** Feed an input
   whose only bad line is the last, unterminated one and require the gate to
   refuse it; for a runner, assert the number of items executed equals the
   number of input lines ([testing-quality-tests-that-cannot-fail]).

## Edge cases

| Case | Then |
|------|------|
| The loop is the right side of a pipe (`cmd \| while read …`) | Variables set in the body are lost in bash (the loop runs in a subshell); feed the loop with `< <(cmd)` or a here-string instead, and keep the `\|\| [ -n "$line" ]` guard |
| The body command genuinely needs input | Feed it from a file or here-string of its own (`cmd <payload.txt`), never from the inherited loop input ([platforms-processes-non-interactive-cli-invocation]) |
| Adding `</dev/null` changes the command's behavior (it switches to a batch mode) | Keep the command's stdin as-is and move the loop to fd 3 (step 2, last row) |
| A step silently "kept stale evidence" in a multi-gate runner | Suspect an earlier gate that drained the list: compare the count of gates executed with the count listed before reading any single gate's result |
| You need to insert multi-line text before a marker line and the script must run on macOS and Linux | Use this read loop with `printf '%s\n'` and print the block when the marker matches. `awk -v var="$multiline"` fails on macOS's awk with `newline in string` (exit 2) — POSIX says a newline "shall not occur within a string constant", and `-v` values are parsed as one. For awk, pass the text through the environment and read `ENVIRON["var"]`, which is not escape-processed |
| An awk variable or function is named `close`, `length`, `index`, or another builtin | Rename it — builtin function names are reserved, and the error names the syntax rather than the collision |
| Input may contain NUL-delimited records (`find -print0`) | `while IFS= read -r -d '' f` in bash; the unterminated-last-record guard still applies |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `while read line; do …; done <<<"$text"` in a checker | `while IFS= read -r line \|\| [ -n "$line" ]` | A one-line input without a trailing newline runs the body zero times; a default-pass verdict then approves everything |
| Debug "only the first host/gate ran" by adding retries or sleeps | Add `</dev/null` to the body command that reads stdin, or iterate on fd 3 | Nothing failed — the remaining input was consumed, so there is nothing left to retry |
| Pass a multi-line shell value with `awk -v` | A read loop, or `ENVIRON` | BSD awk rejects the newline; gawk accepts it, so the script passes on Linux CI and fails on a Mac |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/read.html — EXIT STATUS: `>0` when "End-of-file was detected or an error occurred"; the variable is still assigned from the partial line
- https://mywiki.wooledge.org/BashFAQ/001 — "if the last line is not terminated by a newline character … `read` will read it but return false, leaving the broken partial line in the `read` variable(s)"; the `|| [[ -n $line ]]` idiom
- https://mywiki.wooledge.org/BashFAQ/089 — "if a command inside the loop also reads stdin, it can exhaust the input file"; fixes: `</dev/null`, `ssh -n`, `ffmpeg -nostdin`, or `read … <&3` with `done 3< file`
- https://man.openbsd.org/ssh — `-n` "Redirects stdin from /dev/null (actually, prevents reading from stdin)"
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html — "A <newline> shall not occur within a string constant"; `-v assignment` operands are interpreted as string tokens with escape processing
- https://docs.docker.com/reference/cli/docker/compose/exec/ — "By default, Compose will enter container in interactive mode and allocate a TTY"; `-T, --no-tty` "Disable pseudo-TTY allocation" — the flag removes the TTY, not the stdin attachment
- Local reproduction 2026-10-01 (macOS, bash 3.2.57 and zsh, `/usr/bin/awk` version 20200816): `printf 'one\ntwo' | while IFS= read -r l; do …` ran the body once (`one`); with `|| [ -n "$l" ]` it ran twice. `while read -r x; do echo "item $x"; cat >/dev/null; done < in.txt` over three lines printed `item 1` only; with `cat </dev/null` and with `read -u 3 … done 3< in.txt` all three printed. `awk -v var="$(printf 'a\nb')" '{print var}'` exited 2 with `awk: newline in string a`, the same value exported and read as `ENVIRON["v"]` printed both lines, and `BEGIN{close=1}` exited 2 with `syntax error`
- Field evidence 2026-09-29 (a Bash permission gate, first version): `cat ~/.ssh/id_ed25519 | pbcopy`, a `psql DELETE`, and `cargo build` were all classified "read-only fast path" because the per-stage loop over a here-string never ran and the verdict stayed at its initial `ok=1`; after adding `|| [ -n "$stage" ]`, 15 known-bad commands were refused (33 tests passed)
- Field evidence 2026-09-29 (a 7-gate check runner looping `done < "$GATES_TMP"`): a gate running `docker compose exec -T postgres psql` consumed the rest of the list, so the next gate never executed and kept stale evidence; with `</dev/null` on that command all 7 gates ran
- Field evidence 2026-09-29 (a bash installer inserting a block before a marker line, Darwin 25.1): the `awk -v` form failed with `newline in string`; the read-loop form passed 13/13 bats cases including fixtures with `%s`, a trailing backslash, and CRLF
