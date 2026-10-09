---
id: platforms-tools-unicode-escape-in-a-jq-regex
domain: platforms
category: tools
applies_to: [jq]
confidence: verified
sources:
  - https://jqlang.org/manual/
  - https://www.shellcheck.net/wiki/SC1112
last_verified: 2026-09-27
related: [platforms-tools-jq-dot-rebinding-in-predicates, platforms-shells-escapes-in-shell-string-literals, platforms-environment-unicode-text-matching]
---

# A Non-ASCII Character in a jq Regex Inside a Shell Script

## When this applies

A jq `test()`, `match()`, `sub()`, or `split()` regex must match a non-ASCII
character (a curly apostrophe U+2019, an em dash, a typographic quote) and the
jq program is a shell string literal that shellcheck or another ASCII-only
lint checks; or such a regex stopped matching after you escaped the character.

## Do this

1. **Write the character as a jq string escape with one backslash:**
   `test("’")`. jq's string parser decodes `’` into the character
   before the regex engine (Oniguruma) sees the pattern, so the engine
   receives the literal character.
2. **Run the positive and negative control before committing:**
   `jq -n '"it’s" | test("’")'` must print `true` and the same
   filter with `"\\u2019"` must print `false`.

| Written in the jq program | Regex engine receives | Result on `"it’s"` |
|---------------------------|-----------------------|--------------------|
| `"’"` | the character `’` | `true` |
| `"\\u2019"` | the six characters `’`; Oniguruma's Perl-NG syntax has no `\u` escape | `false` |
| `"\\x{2019}"` | Oniguruma's own code-point escape | `true` — use it when the engine must own the escape, e.g. inside a character class range |

## Edge cases

| Case | Then |
|------|------|
| The jq program is single-quoted at the shell level and contains the literal `’` | shellcheck reports SC1112 on the curly quote; the `’` escape removes the non-ASCII byte from the script and the warning with it |
| The jq program is passed as a double-quoted shell string | shellcheck did not warn on the literal character in reproduction, but the escape still keeps the script ASCII for diffs and other linters |
| The regex needs a range of typographic quotes | `"[‘’]"` — jq decodes both escapes before the engine builds the class |
| The pattern is read from a file with `--rawfile` or `-f` | No shell or jq string decoding happens for `--rawfile` content; write the literal character in the file, or `\x{2019}` for the engine |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Double the backslash "to be safe": `test("\\u2019")` | Use one backslash: `test("’")` | The doubled form hands `\u` to Oniguruma, which does not read it as a code point, and the filter silently returns `false` |
| Paste the literal curly quote into the single-quoted jq program | Use `’` | shellcheck SC1112 fails the script on the non-ASCII quote |

## Sources

- https://jqlang.org/manual/ — "jq uses the Oniguruma regular expression library … jq uses the 'Perl NG' (Perl with named groups) flavor"; string literals support `\uXXXX` escapes
- https://www.shellcheck.net/wiki/SC1112 — "This is a Unicode quote. Delete and retype it (or ignore/doublequote for literal)."
- Local reproduction 2026-09-27 (jq-1.7.1-apple, shellcheck 0.11.0): `test("’")` → `true`; `test("\\u2019")` → `false`; `test("\\x{2019}")` → `true`; `"\\u2019" | explode` → `[92,117,50,48,49,57]`; the single-quoted program with a literal `’` produced two SC1112 warnings, the escaped program none
- Field evidence 2026-09 (memory-loop `correction-signal.bats` case 14): failed with `\\u2019` and passed with `’`; `shellcheck -s bash` went from exit 1 to exit 0
