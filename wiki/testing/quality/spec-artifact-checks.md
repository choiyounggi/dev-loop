---
id: testing-quality-spec-artifact-checks
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://json-schema.org/draft/2020-12/json-schema-validation
  - https://eslint.org/docs/latest/integrate/nodejs-api
  - https://pitest.org/
  - https://github.github.com/gfm/
  - https://docs.python.org/3/library/stdtypes.html
  - https://docs.python.org/3/library/re.html
last_verified: 2026-08-07
related: [testing-quality-tests-that-cannot-fail, testing-quality-schema-additions-under-a-golden-gate, testing-quality-harness-reverse-controls, backend-common-api-design-unenforced-declarations]
---

# Checks That Verify a Spec or Mapping Artifact

## When this applies

You are writing or reviewing an automated check that an artifact conforms to a
source of truth: a mapping table that must hold a row per rule, a key per field,
or a case per enum; ids that must resolve across documents; required sections in
an RFC. Includes doc-as-spec repos where the artifact is Markdown.

## Do this

1. **Split coverage from value validity into two named checks.** Coverage asks
   "is every required row/key/case present". Value validity asks "does each
   cell's value exist in the canonical enum, schema, or id set". A set-equality
   check on row *names* is blind to cell contents, so a table reaches 100%
   coverage while a cell holds a typo'd, empty, or swapped value. This is the
   split JSON Schema draws between `required` — "every item in the array is the
   name of a property in the instance" — and `enum`, where the instance's *value*
   must equal one of the listed elements.

2. **Give each check its own negative control, mutating only what that check
   owns.** Rerun the whole harness per mutation and require exactly the owning
   check to turn red while the others hold their prior verdict:

| Check | Mutation that must redden it | Other checks must hold at |
|-------|------------------------------|---------------------------|
| Coverage — every required row/key/case present | Delete one required row | Their prior verdict |
| Value validity — each cell in the canonical set | Replace one cell with a value absent from that set | Coverage stays green |
| Cross-document id resolution | Repoint one id at a target that does not exist | Coverage and validity stay green |

   Seeding a fault and requiring a failure is the mutation-testing mechanic — a
   mutant is killed when a test fails. Requiring *which* check fails is a
   convention this page adds on top of it, so that each verdict names a distinct
   property. Pair every mutation with a must-pass input, the form an ESLint rule
   test takes when its `invalid` cases declare the errors they expect.

3. **Locate the mutation site by the row's key columns and assert the mutation
   applied.** A control that quotes the whole target line — key cells *and* prose
   cells — stops matching the first time someone rewords the prose, and a text
   substitution that matches nothing returns the artifact unchanged rather than
   raising. The control then runs a check against the *original* document, the
   check passes as it should, and the control reports green while mutating
   nothing. Anchor on the stable prefix and make "it applied" its own assertion:

```python
mutant = "".join("| security | jwt |\n" if line.startswith("| security | jwt |")
                 else line for line in doc.splitlines(keepends=True))
assert mutant != doc, "the mutation did not apply"
```

   `re.subn` carries the same evidence as a count — require it to equal the
   number of rows you meant to mutate, not merely to be non-zero.

4. **Print which check caught each seeded fault**, so a green run states what was
   proven rather than only that something ran.

5. **Report the verdict in the words the checks earned.** When only coverage ran,
   the result is "mapping present"; "mapping verified" requires the validity
   check to have run and to have its own negative control.

6. **Parse Markdown tables by splitting on unescaped pipes, then unescape each
   cell**, before asserting cell counts or per-column values:

```python
row = re.sub(r"(?<!\\)\|$", "", re.sub(r"^\|", "", row.strip()))
cells = [c.replace(r"\|", "|").strip()
         for c in re.split(r"(?<!\\)\|", row)]
```

   GFM lets a cell hold a literal pipe as `\|` — common in EBNF and enum docs
   (`create\|update\|delete`). Measured 2026-07-29 (Python 3.9.6): for such a
   row, `split("|")` yields 7 cells while the unescaped-pipe split yields 5,
   matching the table's 5-cell header. Strip the outer delimiters with the
   anchored patterns above rather than `.strip("|")`: `.strip` removes a *run* of
   pipes, so a cell ending in an escaped pipe loses it and keeps a dangling
   backslash, and every per-column comparison against that cell then compares the
   wrong string. Unescape the escapes your cells actually carry — the line above
   handles `\|`, while `\\` and `\_` survive into the compared value.

## Edge cases

| Case | Then |
|------|------|
| A check's negative control also reddens another check | The checks overlap; narrow the mutation or the check's scope until each mutation reddens exactly one, so each verdict names a distinct property |
| The canonical value set lives in another document | Resolve each value against that document at check time; a value list copied into the checker drifts silently once the source document changes |
| The source list the mapping is checked against is itself derived (a parsed enum, a globbed file set) | Assert the parsed list's length against a known count before comparing; a source list that parses to zero items makes coverage pass vacuously |
| Asserting a fixed cell count on body rows | Enforce it as your repo's convention and state it as one: GFM requires only the header row to match the delimiter row in cell count, while body rows with fewer cells get empty cells inserted and excess cells are ignored |
| The artifact is generated rather than hand-written | Point the must-pass input at a committed golden output of the generator, so a generator change reddens the check instead of silently redefining the spec |
| A cell legitimately holds no value (a rule with no mapped target) | Give the validity check an explicit sentinel to accept (`—`, `n/a`) and assert that sentinel's spelling, so an empty cell stays distinguishable from an intended blank |
| A control that was green for months turns red right after a prose-only edit to the artifact | Read it as the anchor rotting, not the rule breaking — the control had been mutating nothing and the edit exposed it. Re-anchor on the key columns; the months of green verdicts it produced are not evidence |
| The mutation must target a whole row that has no stable key prefix | Anchor on the row's index within the parsed table rather than on its text, and assert the parsed row count first so a re-ordered table fails loudly |
| Several controls in the harness share one anchor string | Give each its own anchor and its own applied-assertion; one rotted shared anchor silently disarms every control that reuses it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Report "mapping verified" from a check that compares row names against a source list | Name that check "coverage" and add a separate value-validity check before claiming verification | Presence and correctness are different properties — the same distinction as `required` versus `enum` |
| Add every check, mutate one thing, and confirm the harness goes red | Mutate once per check and require the owning check to be the one that reddens | One red proves some check fired, not that each check detects the defect it claims to own |
| Split Markdown rows with `row.split("\|")` and assert the cell count | Split on unescaped pipes and unescape each cell first | An escaped `\|` inside a cell inflates the naive count, so the checker reports a false "broken table" on a document that renders correctly |
| Treat a green coverage run over a parsed source list as proof of completeness | Assert the parsed list's item count first, then compare sets | An empty source list satisfies set equality against anything, so coverage passes while nothing was checked |
| Build a control's mutant by quoting the target row verbatim, prose cells included | Match on the key columns and assert the result differs from the original | Prose gets reworded by ordinary work; the substitution then matches nothing and hands the check the unmutated document, which passes correctly and leaves the control green |

## Sources

- https://json-schema.org/draft/2020-12/json-schema-validation — `required`: "An object instance is valid against this keyword if every item in the array is the name of a property in the instance"; `enum`: "An instance validates successfully against this keyword if its value is equal to one of the elements in this keyword's array value" — presence and value are separate keywords
- https://eslint.org/docs/latest/integrate/nodejs-api — `RuleTester#run()` takes `valid` and `invalid` case arrays, and an invalid case must declare `errors`: the checker's must-fail input states the failure it expects
- https://pitest.org/ — "Faults (or mutations) are automatically seeded into your code, then your tests are run. If your tests fail then the mutation is killed, if your tests pass then the mutation lived"; line coverage "measures only which code is executed by your tests. It does not check that your tests are actually able to detect faults in the executed code"
- https://github.github.com/gfm/ — tables extension: "Include a pipe in a cell's content by escaping it, including inside other inline spans"; "The header row must match the delimiter row in the number of cells. If not, a table will not be recognized"; for body rows, "If there are a number of cells fewer than the number of cells in the header row, empty cells are inserted. If there are greater, the excess is ignored"
- Local reproduction 2026-07-29 (Python 3.9.6, macOS): a 5-column row whose third cell holds `create\|update\|delete` splits to 7 cells with `split("|")` and to 5 cells with `re.split(r"(?<!\\)\|", …)`, matching the 5-cell header
- https://docs.python.org/3/library/stdtypes.html — `str.replace`: "Return a copy of the string with all occurrences of substring *old* replaced by *new*" — the signature carries no not-found error and no substitution count, so a stale anchor yields the original text; `re.subn` "return a tuple `(new_string, number_of_subs_made)`" is the counted form
- Local reproduction 2026-08-07 (Python 3.14.6, macOS): a control quoting `| security | jwt | rejects unsigned tokens |` against a document whose cell had been reworded to `… at the edge` produced `mutant == doc` (mutation not applied, no exception); the same mutation anchored on the prefix `| security | jwt |` applied. `re.subn` reported `0` substitutions for the stale anchor and `1` for the prefix pattern
- Field reproduction 2026-08-07 (linkly `impl/tests/test_enforcement_matrix.py::test_a_short_row_raises_rather_than_reading_as_empty_cells`): revising the rationale cell of the `security jwt` row stopped the literal anchor from matching; only `assertNotEqual(mutant, original, "the mutation did not apply")` surfaced it. Re-anchoring on the `| security | jwt |` prefix returned the suite to 37/37
- Cross-checked against GitHub's own renderer 2026-07-29 (`POST /markdown`, `mode: gfm`): the row `|a|b\||` renders as two cells, `a` and `b|`; the anchored-delimiter snippet above returns `['a', 'b|']`, while `.strip("|")` returns `['a', 'b\\']` — the defect the delimiter-stripping note describes
