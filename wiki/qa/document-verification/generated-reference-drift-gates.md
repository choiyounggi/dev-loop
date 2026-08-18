---
id: qa-document-verification-generated-reference-drift-gates
domain: qa
category: document-verification
applies_to: [general]
confidence: verified
sources:
  - https://pkg.go.dev/cmd/go — the `^// Code generated .* DO NOT EDIT\.$` convention for marking generated source
  - https://prettier.io/docs/en/cli — `--check` reports unformatted files and exits 1, "helpful inside the CI pipelines"
  - https://google.github.io/styleguide/docguide/best_practices.html — change docs in the same CL as the code; link to a fact rather than restating it
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools — the description supplied to the model is "by far the most important factor in tool performance"
last_verified: 2026-08-09
related:
  [
    qa-document-verification-spec-document-gates,
    qa-deliverables-generated-artifacts-as-deliverable-source,
    backend-common-api-design-unenforced-declarations,
    testing-quality-tests-that-cannot-fail,
  ]
---

# A Reference Document Listing a Closed Vocabulary That an Agent Will Read Back

## When this applies

You are writing or reviewing the reference material that ships with a plugin, skill,
prompt, or SDK and enumerates a **closed vocabulary** the caller must draw from — DSL
verbs, config keys, diagnostic codes, enum members — and the caller is a model that
will emit those tokens from what you wrote. Or: such a reference exists, hand-written,
and you must decide what gates it.

## Do this

1. **Generate the enumerated part from the owning constant.** The generator imports the
   compiler/runtime table (`VERB_LEXICON`, `SEVERITY_OF`, the schema enum) and renders
   the rows. Hand-write only the surrounding narrative — what the vocabulary is for,
   what is out of scope ([qa-deliverables-generated-artifacts-as-deliverable-source]).
2. **Give the generator a `--check` mode that exits non-zero on any difference**, and
   call it from the test suite, not only from a release script. `--check` regenerates
   into memory and compares against the committed file.
3. **Put a machine-readable generated banner on line 1**, naming the owning module and
   the command that rewrites the file, and stating which test fails if it is edited by
   hand. Assert the banner's presence in the suite so a new output file cannot ship
   without it.
4. **Add coverage assertions against the constant itself**, separately from `--check`:

| Assertion | What it proves | What it catches that the others miss |
|-----------|----------------|--------------------------------------|
| `--check` exits 0 | The committed file equals the generator's current output | A hand edit, a stale commit, a forgotten regeneration |
| Every member of the constant appears in the document | The generator's extractor reaches the whole table | An extractor that filters, truncates, or silently skips a member |
| Each row's derived column equals the constant's value for that member | The column is derived, not typed in | A generator that hardcodes one value for every row — it regenerates happily and `--check` stays green |
| The derived column holds more than one distinct value | The column carries information | A degenerate table that is technically "derived" from a constant that is itself uniform |

5. **Route the reader to the generated file, not to a second copy.** When a README or
   skill body needs the vocabulary, link the generated reference rather than restating
   rows; a restatement is a third copy that drifts against both.

## Edge cases

| Case | Then |
|------|------|
| The vocabulary lives in a hand-written example (a golden `.lnpl`, a quickstart snippet) rather than a table | The example is a consumer of the vocabulary, so gate it the same way: compile or execute it in the suite and assert the diagnostic count is zero. An out-of-lexicon token there is what the model copies |
| The runtime ignores unknown members instead of rejecting them | Raise the priority of this gate rather than lowering it — the drift surfaces as a step that silently does nothing, so no run, log, or exit code reports it ([backend-common-api-design-unenforced-declarations]) |
| The generator cannot import the owning module where the check runs (docs-only CI job) | Have the code-side job emit the constant as a data file and diff the document against that file in the same pipeline |
| A member exists in the document but not in the constant | Fail naming the direction — a removed constant leaves a documented token that nothing implements, and the model will emit it |
| The reference is partly prose the generator cannot express | Split the file: generated table section plus a hand-written section, and scope `--check` to the generated section's delimiters so prose edits do not fail the gate |
| Regenerating produces churn on every run (timestamps, dict ordering) | Sort deterministically and drop the timestamp; a generator whose output is unstable makes `--check` a coin flip, and the team turns it off |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Hand-write the vocabulary reference because the list is short and stable | Generate it and gate it with `--check` from the first commit | The list is closed, so every future addition to the constant is a silent omission here; short lists drift as reliably as long ones |
| Treat a green `--check` as proof the document matches the code | Add the per-member coverage and derived-column assertions from the Do table | `--check` compares the file to the generator, so a wrong generator is self-consistent and green |
| Restate a few "important" rows in the README next to a link to the reference | Link only, and let the reference carry every row | The restated subset is what a reader loads first, and it is the copy nobody regenerates |
| Add a comment asking humans not to edit the file | Write a parser-matchable banner and assert it in the suite | A polite comment is not a gate; the banner plus the test is what turns an edit into a failing run |

## Sources

- https://pkg.go.dev/cmd/go — "To convey to humans and machine tools that code is
  generated, generated source should have a line that matches the following regular
  expression (in Go syntax)": `^// Code generated .* DO NOT EDIT\.$`, placed before the
  first non-comment text. A machine-readable banner, not a prose request.
- https://prettier.io/docs/en/cli — `--check` "will output a human-friendly message and
  a list of unformatted files, if any" and returns "exit code `1` in the second case,
  which is helpful inside the CI pipelines" — the check-mode-as-gate shape this page
  applies to generated documents.
- https://google.github.io/styleguide/docguide/best_practices.html — "Change your
  documentation in the same CL as the code change"; and where a fact is owned
  elsewhere, "Link to it instead" of writing your own copy.
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools —
  "Provide extremely detailed descriptions. This is by far the most important factor in
  tool performance." The reference is the model's picture of the vocabulary; when it
  drifts, the model's output drifts with it, confidently.
- Local reproduction 2026-08-09 (`linkly`, lnpl 0.3.0): `python
  scripts/gen_plugin_references.py --check` exits 0 against the committed references,
  and `impl/tests/test_plugin_references.py` runs it inside the suite —
  `test_check_mode_detects_a_hand_edit` and `test_check_mode_reports_a_missing_file`
  both assert `returncode == 1`, and `test_generated_files_carry_the_do_not_edit_banner`
  asserts the line-1 banner. The coverage layer is separate and deliberate:
  `test_every_diagnostic_code_reaches_the_document_with_its_grade` documents that
  "`--check` alone cannot see this: it compares the committed file against the
  generator's own output, so a generator that hardcoded every grade to `warning` would
  regenerate happily and stay green", with
  `test_the_grade_column_is_not_a_single_repeated_value` as its negative control.
- Local reproduction 2026-08-09 (same repo, the counter-example): the hand-written
  golden `examples/login.lnpl` drifted out of the verb lexicon, and
  `impl/tests/test_cli_diagnostics.py::test_compile_reports_all_six_and_still_succeeds`
  pins the result — `rc == 0` with `err.count("unknown-verb") == 3`. Three of its steps
  compile to nothing while the compile reports success, which is the failure mode a
  generated-and-gated reference removes at the source.
