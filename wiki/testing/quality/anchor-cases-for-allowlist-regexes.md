---
id: testing-quality-anchor-cases-for-allowlist-regexes
domain: testing
category: quality
applies_to: [general, javascript, python]
confidence: verified
sources:
  - https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/
  - https://docs.python.org/3/library/re.html
  - "Local reproduction 2026-10-08 (Node v26.7.0, Python 3.14.6): a 6-case set against an anchored key pattern and the same pattern without ^"
  - "Field case 2026-10-07 (an 11-case rejection list for an object-key allowlist regex)"
last_verified: 2026-10-08
related: [testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, testing-quality-minimum-case-set, security-input-validation-at-trust-boundaries]
---

# Anchor Cases for an Allowlist Regex

## When this applies

You are writing or reviewing tests for an allowlist regex anchored with `^` and
`$` — a storage key, a path, an id, a file name — or using those tests as the
control that must fail when an anchor is removed.

## Do this

1. **For each anchor, include a bad input that only the unanchored pattern
   accepts.** Malformed values (wrong extension, too short, empty) are rejected
   with or without anchors, so they cannot detect a missing anchor.

| Anchor | Case to add | Built as |
|--------|-------------|----------|
| `^` | A valid value behind a prefix | `'../' + valid`, `'/etc/' + valid`, `'x' + valid` |
| `$` | A valid value followed by a suffix | `valid + '.exe'`, `valid + '/../x'` |
| `$` in Python `re` | A valid value plus one trailing newline | `valid + '\n'` |
| `m` flag (JS) / `re.MULTILINE` | A bad line, a newline, then a valid line | `'../evil\n' + valid` |

2. **Prove each case does its job: delete `^`, run the tests, and require at
   least one failure; then do the same for `$`.** This is the mutation Stryker's
   regex mutator generates (`^abc` → `abc`, `abc$` → `abc`), so a mutation run
   reports the same gap. This check applies to search-style matching (JS
   `test`, Python `re.search`). Under Python `re.fullmatch` the anchors are
   redundant and deleting them never turns a test red: there, run the cases
   with the pattern as written and require every prefix and suffix case to be
   rejected.

## Edge cases

| Case | Then |
|------|------|
| Python, pattern used with `re.search` | `$` also matches "just before the newline at the end of the string": `valid + '\n'` passes `^...$`. Use `re.fullmatch` (or `\Z`) and keep the trailing-newline case |
| Python, pattern used with `re.match` | `re.match` only matches at the start, so deleting `^` changes nothing (the prefix case still fails to match): that mutant is equivalent. Switch to `re.fullmatch` so both ends are explicit |
| The pattern has the `m` flag (JS) or `re.MULTILINE` | `^` and `$` then match at every line; an embedded-newline input passes — drop the flag for single-value allowlists |
| The value is joined into a filesystem path after the check | Keep the prefix case even when anchors are present, and resolve the joined path and check it stays under the base directory ([security-input-validation-at-trust-boundaries]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Fill the reject list with malformed values only | Add one prefix case per `^` and one suffix case per `$` | Removing either anchor leaves every malformed-value result unchanged, so the tests cannot fail |
| Accept "all reject cases pass" as proof the anchors work | Delete each anchor once and watch a test go red | A case set that stays green without the anchor has not tested it ([testing-quality-tests-that-cannot-fail]) |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ — Regex mutator: StrykerJS and Stryker4s mutate regexes with weapon-regex; the mutation table maps `^abc` to `abc` and `abc$` to `abc`
- https://docs.python.org/3/library/re.html — `$` "Matches the end of the string or just before the newline at the end of the string"; `re.fullmatch` returns a match only "If the whole string matches"
- Local reproduction 2026-10-08 (Node v26.7.0, Python 3.14.6): for `^[0-9a-f]{2}\/[0-9a-f]{32}\.jpg$`, the wrong-extension, short and empty cases were rejected both with and without `^`; `'../' + valid` and `'/etc/' + valid` were rejected only with `^`. Python `re.search` matched `valid + '\n'`, `re.fullmatch` did not; JS `/…$/` rejected it; JS `/^…$/m` accepted `'../evil\n' + valid`; Python `re.match` without `^` rejected `'../' + valid`
- Field case 2026-10-07: an 11-case reject list for a storage-key regex — deleting `^` changed 0 of the 11 results; `'../3f/<32 hex>.jpg'` passed only the unanchored pattern
