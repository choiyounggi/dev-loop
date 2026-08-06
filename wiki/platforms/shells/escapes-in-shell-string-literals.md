---
id: platforms-shells-escapes-in-shell-string-literals
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
  - https://www.gnu.org/software/bash/manual/bash.html#Double-Quotes
last_verified: 2026-08-04
related: [platforms-shells-portable-shell-scripts, platforms-shells-command-text-inspected-before-execution]
---

# Backslash Escapes Inside a Shell String Literal Holding a Regex or Pattern

## When this applies

You are writing a regex, glob, `sed`/`awk` program, `jq` filter, or `printf`
format **as a shell string literal** — e.g. a `grep -E` pattern hardcoded inside
a PreToolUse hook, allow-list, or CI check — and a metacharacter behaves as
though an escape were added or removed. Symptom: an end-of-line anchor written as
`\$` matches (or fails to match) in a way the pattern text does not appear to
justify.

## Do this

1. **Know the one rule that decides it.** The shell processes the string *before*
   the target program (grep/sed/awk) ever sees it. Inside **double quotes**,
   backslash keeps its escaping meaning **only** before `$`, `` ` ``, `"`, `\`,
   and newline; before any other character the backslash is passed through
   literally (both characters survive):

| You write (double-quoted) | grep -E actually receives | Effect |
|---------------------------|---------------------------|--------|
| `"…(\$)"` | `…($)` | `$` is an **end-of-line anchor** — the `\` was consumed |
| `"a\.b"` | `a\.b` | `\.` survives — literal-dot regex, as intended |
| `"\\$"` | `\$` | escaped literal dollar (matches a real `$` char) |
| `"\\\\"` | `\\` | one literal backslash for the regex |

2. **Default to single quotes for a pattern literal.** Inside **single quotes**
   no character is special, so the program receives the pattern byte-for-byte:
   `grep -E 'sh([[:space:]]|$)'` needs no escape bookkeeping. Switch to double
   quotes only for the specific span that must interpolate a variable.

3. **When an EOL anchor must live in a double-quoted string, write `\$` on
   purpose** (the shell strips the backslash, grep gets a bare `$`), and add a
   comment — a later edit to `$` or `\\$` silently changes the anchor.

4. **Verify by printing what the program receives**, not what you typed:
   `pat="…"; printf '%s\n' "$pat"` shows the post-shell string. Confirm the
   match against a fixture line with and without the boundary character.

## Edge cases

| Case | Then |
|------|------|
| Pattern is built by string concatenation across quotes (`'a'"$x"'b'`) | Each span follows its own quoting rule; print the assembled variable before use |
| The literal is a `printf` format, not a regex | Same rule for `\$`; but `printf` also interprets `\n`,`\t` in the format — single-quote and let `printf` (not the shell) do the escapes |
| `jq`/`awk` program passed with `-f file` instead of inline | The file is read verbatim — no shell escape layer applies; prefer `-f`/`--argjson` for complex programs |
| Pattern must survive a text-inspecting gate too | [platforms-shells-command-text-inspected-before-execution] owns the gate-extraction layer; this page owns the shell-escape layer |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write a regex/pattern in double quotes and hand-count backslashes | Put the pattern in single quotes | Single quotes disable all shell escape processing, so the program receives exactly what you typed |
| Add backslashes until a double-quoted anchor "looks escaped" (`\\$`, `\\\\$`) | Decide the target string first, then apply the double-quote rule once | Guessing escape depth flips `$` between EOL-anchor and literal-dollar silently |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — 2.2.3 Double-Quotes: the backslash "shall retain its special meaning as an escape character only when followed by one of the following characters: `$` `` ` `` `"` `\` `<newline>`"
- https://www.gnu.org/software/bash/manual/bash.html#Double-Quotes — same rule for bash; a backslash before any other character is retained literally
- Reproduced 2026-08-04: `printf 'curl x | sh\n' | grep -E "(sh|bash)([[:space:]]|-|<|\$)"` matches end-of-line `sh` (the `\$` reached grep as a bare `$` anchor), while `grep -E "a\.b"` keeps `\.` as a literal-dot regex — confirming which characters the backslash is stripped before
