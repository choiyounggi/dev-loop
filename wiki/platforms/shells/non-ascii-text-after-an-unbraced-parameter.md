---
id: platforms-shells-non-ascii-text-after-an-unbraced-parameter
domain: platforms
category: shells
applies_to: [bash]
confidence: field-tested
sources:
  - https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
  - https://www.gnu.org/software/bash/manual/html_node/Definitions.html
  - https://mail.gnu.org/archive/html/bug-bash/2015-12/msg00030.html
  - "Field case 2026-10-22 (a GitHub Actions run: block extracted and run locally on macOS, bash 5.3): `$X가` printed two broken bytes under LANG=C.UTF-8 and the full value without LANG"
last_verified: 2026-10-22
related: [platforms-shells-colon-after-an-unbraced-parameter, platforms-shells-portable-shell-scripts, platforms-environment-timezone-and-locale, platforms-environment-unicode-text-matching]
---

# Non-ASCII Text Right After an Unbraced Parameter

## When this applies

A shell line puts non-ASCII text (Korean, Japanese, accented Latin, emoji)
straight after an unbraced `$name`: a CI `run:` step `echo "$NAME가 없어"`, a
message `"$count개"`, a log line `"$user님"`. Also when such a line prints an
empty value, broken bytes (`��`), or works in one terminal and not in another.

## Do this

1. **Brace every parameter that non-ASCII text follows: `"${NAME}가 없어"`.**
   The bash manual requires braces "when parameter is followed by a character
   which is not to be interpreted as part of its name". Which bytes count as
   part of a name depends on the locale and the C library, so the unbraced form
   has no single meaning you can test once. The braced form ends the name in
   every shell and every locale.
2. **Test an extracted CI script under the job's own locale.** Print `locale`
   (or `echo "$LANG"`) inside the job, then run the extracted block locally with
   the same value: `env -i LANG=<job value> bash -c '…'`. A test under your
   shell's default locale can pass while the job breaks, or the reverse.
3. **Check the result with a value that has no non-ASCII text nearby** — print
   `"[${NAME}]"` beside the message. When the bracketed value is right and the
   message is wrong, the name boundary is the cause, not the variable.

## Edge cases

| Case | Then |
|------|------|
| Measured on macOS, bash 5.3, `X=ANTHROPIC` | `LANG=C.UTF-8`: `"[$X가 없어]"` printed `[�� 없어]` — an empty value and two broken bytes. No `LANG` (C locale): `[ANTHROPIC가 없어]`. `"${X}가"` was right in both |
| Why only part of the character vanished | `가` is the three bytes `EA B0 80`. The output kept two broken bytes, which fits the name taking the first byte only; that byte-by-byte reading is an inference from this output, not a documented rule. Bash's own character-class test also treats non-ASCII letters as alphabetic in a UTF-8 locale (bug-bash 2015-12) |
| The job runs on a Linux runner | Not measured here; the C library there may classify the same bytes differently. Brace the name whatever the runner (step 1) |
| The line runs in zsh | zsh decides name characters with its own rules and also applies `:` modifiers after an unbraced name ([platforms-shells-colon-after-an-unbraced-parameter]); the braced form is right in both |
| The text after the name is ASCII punctuation (`"$X:"`, `"$X."`, `"$X-1"`) | Bash ends the name there; zsh still consumes some `:letter` pairs — brace when a colon follows |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `"$NAME가 없어"` in a script or `run:` step | Write `"${NAME}가 없어"` | The name boundary depends on the locale; braces fix it in every locale |
| Trust a local run of the extracted block | Run it with the job's `LANG` (step 2) | Without `LANG` the block ran correctly on the same machine where the UTF-8 run broke |

## Sources

- https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html — "The braces are required when parameter is a positional parameter with more than one digit, or when parameter is followed by a character which is not to be interpreted as part of its name"
- https://www.gnu.org/software/bash/manual/html_node/Definitions.html — `name`: "A word consisting solely of letters, numbers, and underscores, and beginning with a letter or underscore"; which bytes are letters is left to the locale
- https://mail.gnu.org/archive/html/bug-bash/2015-12/msg00030.html — bug-bash thread: under a UTF-8 locale bash's `[[:alpha:]]`/`[[:alnum:]]` test treats a non-ASCII letter (`aØb`) as alphabetic, while the identifier rules disagree
- Field case 2026-10-22 (field-tested; a GitHub Actions workflow edited in the linkly repository, run locally on macOS with bash 5.3): `env -i LANG=C.UTF-8 X=ANTHROPIC bash -c 'echo "[$X가 없어]"'` printed `[�� 없어]`; without `LANG` it printed `[ANTHROPIC가 없어]`; `${X}` printed the value in both. Recorded by the originating session; the Linux runner's behaviour was not measured
