---
id: testing-data-adjacent-tokens-in-extractor-fixtures
domain: testing
category: data
applies_to: [python, javascript, general]
confidence: verified
sources:
  - https://docs.python.org/3/library/re.html
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Quantifier
last_verified: 2026-09-14
related: [testing-data-test-data-and-isolation, testing-quality-tests-that-cannot-fail]
---

# Adjacent Tokens in Fixture Text for a Greedy Pattern Extractor

## When this applies

A test feeds free text holding two or more occurrences of a token (phone number,
amount, id) to an extractor built on a regex whose repeated character class admits
separators — whitespace, `.`, `-`, `(`, `)`, newline — such as
`\d[\d\s.\-()]{6,18}\d`. The fixture places the occurrences with only class-member
characters between them (`"- 1900068889\n- 1900068889"`), and the test asserts
something about each occurrence downstream (filtered, deduplicated, counted, labeled).

## Do this

1. **Assert the spans the extractor itself returns on the fixture, as the test's
   first assertion**, before any downstream assertion:
   ```python
   assert [m.group() for m in PHONE_RUN_RE.finditer(text)] == ["1900068889", "1900068889"]
   ```
   A greedy repeat consumes every class-member character it reaches, up to the
   repeat's maximum, so two neighbours separated only by class members merge into one
   span — and a span capped by `{m,n}` ends mid-number, so its digits match neither
   original. The downstream assertion then runs on one malformed token, not two.
2. **Choose the separator by what the test is about:**

| Fixture intent | Separator between occurrences |
|----------------|-------------------------------|
| Per-occurrence handling (filter, dedupe, label attribution) | A character outside the class — `\|`, `;`, a letter, or a label word (`Hotline: … Fax: …`) |
| How the extractor splits real adjacent numbers | Class-member separators, in a test of its own whose expected spans come from the specification, not from the output |
| Realistic page text copied from a source | The real markup's separators, with the span assertion from step 1 first |

3. **Write the tokenization case as its own test when real inputs put numbers side by
   side with only spaces or line breaks** (a footer line such as
   `090 123 4567 028 3822 1234`). There the merge is a production defect, not a
   fixture artifact; write its expected spans from the specification so the test goes
   red on the merge instead of recording it.

## Edge cases

| Case | Then |
|------|------|
| The repeat has no upper bound (`[\d\s.\-()]+`) | Both tokens merge into one span holding both digit runs (20 digits for two 10-digit numbers); a digit-count validator rejects it, so both occurrences vanish |
| The pattern ends in `\d` after a capped repeat | Backtracking gives back only to the last digit inside the cap, so the merged span is exactly `1 + max + 1` characters long, not cut at a token boundary |
| A lazy repeat (`{6,18}?`) is proposed as the fix | It stops at the first point the trailing `\d` can match: `090 123 4567` yields `090 123 4`, and even pipe-separated `1900068889` yields `19000688`. Decide the boundary from the token's format (digit count per numbering plan) and test both a spaced single number and two adjacent numbers |
| The extractor normalizes text before matching (collapses newlines, strips markup) | Assert spans on the normalized string the matcher receives, not on the raw fixture |
| The fixture test was green before the separator was changed | Revert the separator and confirm the span assertion reddens — see [testing-quality-tests-that-cannot-fail] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Repeat a bare token on consecutive lines to test per-occurrence filtering | Join the occurrences with a separator outside the matcher's class and assert the match count first | Class-member separators merge the occurrences into one malformed span, so the test exercises a token that never existed |
| Trust a green downstream assertion on a multi-occurrence fixture | Assert the extractor's spans on that fixture as the first assertion | The downstream result can be right for the wrong reason when an occurrence vanished at extraction |

## Sources

- https://docs.python.org/3/library/re.html — "The `'*'`, `'+'`, and `'?'` quantifiers are all greedy; they match as much text as possible"; `re.finditer` yields "all non-overlapping matches for the RE pattern in string. The string is scanned left-to-right, and matches are returned in the order found"
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Quantifier — "Quantifiers are greedy by default, which means they try to match as many times as possible until the maximum is reached, or until it's not possible to match further"; a lazy `?` makes the quantifier "match as few times as possible"
- Reproduction 2026-09-14 (CPython `re`): `(?:\+\s?84[\s.\-]*)?\(?\d[\d\s.\-()]{6,18}\d` on `"- 1900068889\n- 1900068889"` → one match `'1900068889\n- 1900068'` (20 chars); on `"- 1900068889 | - 1900068889"` → two matches `'1900068889'`; on `"090 123 4567 028 3822 1234"` → one match `'090 123 4567 028 382'`. `\d[\d\s.\-()]+\d` on the newline fixture → one 23-char match with 20 digits. `\d[\d\s.\-()]{6,18}?\d` on `"090 123 4567"` → `'090 123 4'`; on `"1900068889 | 1900068889"` → `'19000688'` twice
- Field observation 2026-09-14 (company-contact extractor, site-phone filtering test): the fixture repeated one number on adjacent `- ` lines; an independent test-quality audit found only one malformed occurrence reached the filter; pipe-delimiting the fixture restored two distinct matches, confirmed by re-running `finditer`
