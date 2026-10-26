# Knowledge flush — 2 insight(s) (headless auto-flush run, 2026-10-26)

4 queue rows were claimed this run: 2 ingested as edge rows, 1 dropped as a
duplicate of the merged wiki, 1 dropped as a project-specific plan-gap row.
Nothing was released, and nothing was folded into another branch.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `831eb7e1a4f7b87b`: a client JSON string used as a stored key or held to a byte limit | security | **ingested**: edge row on `security-input-validation-at-trust-boundaries` (verified) |
| `f477f9408b951e78`: replacing exact-text workflow tests with one structural checker | testing | **ingested, corrected**: edge row on `testing-quality-ci-workflow-step-behavior-tests` (field-tested) |
| `18eda0a34f791854`: a same-second, same-size `.py` rewrite runs stale `.pyc` | testing | dropped as a duplicate of `backend-python-language-bytecode-cache-staleness` |
| `4fd103753eedf249`: t1-trust-select plan-gap (which key answers a numbered trust screen) | — | dropped as project-specific (see Local-layer candidates) |

## Verified best-practice

**`831eb7e1a4f7b87b` (confidence: verified).** Claim: when a client-supplied
JSON string becomes a stored key or has a length limit, encode it to UTF-8 at
the boundary and return 400 if that fails. Then enforce the limit on the
encoded byte count, and test both sides of it with 2-, 3- and 4-byte characters.

- https://docs.python.org/3/library/json.html, section "Standard Compliance and
  Interoperability" (confirmed by a docs.python.org-restricted search): the RFC
  "does not explicitly forbid JSON strings which contain byte sequences that
  don't correspond to valid Unicode characters (e.g. unpaired UTF-16
  surrogates)"; "By default, this module accepts and outputs (when present in
  the original str) code points for such sequences".
- https://www.rfc-editor.org/rfc/rfc8259 §8.2: the grammar allows a lone
  surrogate escape such as `"\uDEAD"`, and the behavior of software that
  receives one is unpredictable. The page paraphrases this; it does not quote it.
- https://docs.python.org/3/library/codecs.html, error-handler table: without
  `surrogatepass`, the utf-8/16/32 codecs treat a surrogate code point in a
  `str` as an error. This is the `UnicodeEncodeError` the DB driver hit.
- https://www.rfc-editor.org/rfc/rfc3629 gives the UTF-8 byte widths: 2 bytes
  for U+0080–07FF, 3 for U+0800–FFFF, 4 from U+10000. That checks the
  candidate's numbers: 128 × `é` = 256 bytes, 85 × `가` = 255, 64 emoji = 256.
- Field case from the session: `"\ud800x"` raised inside the sqlite driver
  until the encode check made it return 400.
- This run could not run Python because Bash is limited to the queue tool and
  `gh pr list`. The behavior of the codec and the json module rests on the docs
  above plus the session's field case.

**`f477f9408b951e78` (confidence: field-tested; the directive is corrected).**
The candidate said: delete each old test that goes red on at least one of the
new checker's mutants. That only shows the two tests overlap. An old test that
guards a second property can pass this check and still be deleted unsafely.
The ingested row uses the subset rule instead: delete an old test only when
the new check is red on every mutant that turns that old test red. Keep the
old test (or move its assertion into the new check) when it is red on a mutant
the new check passes. Write a mutant for any old test that no mutant turns red.

- Basis: mutation-score-preserving test-suite reduction. A suite is minimal
  when removing any test lowers the mutant score, so a test can be dropped only
  when the remaining tests kill every mutant it kills.
  - https://www.cefns.nau.edu/~adg326/tr17.pdf
  - https://www.cefns.nau.edu/~adg326/ase16.pdf
  - Both were read **through web-search summaries only**. The PDFs were not
    opened, so nothing on the page quotes them. That is why the row is
    field-tested, not verified.
- Related definition: mutant subsumption (Kurtz/Ammann et al.;
  https://arxiv.org/pdf/1601.06466, also seen only in a search summary). It is
  not cited on the page.
- Field case: the removed `WiringTest`s were run against mutants M2/M4/M5/M7/M8/M10.
  Each removed test failed on at least one, and none failed on the real file.

**`18eda0a34f791854`: not re-researched.** It is a duplicate (see the next
section). The existing page already cites docs.python.org import and cmdline
docs plus PEP 552.

**`4fd103753eedf249`: not researched.** It is a plan-gap row that records one
design decision for the dev-loop repository's own trust-dialog answerer, so
there is no general best-practice to verify.

## Existing-layer check

Pages read: security-input-validation-at-trust-boundaries, backend-common-api-design-idempotency, backend-python-language-bytecode-cache-staleness, testing-quality-ci-workflow-step-behavior-tests, testing-quality-source-text-wiring-assertions

`wiki_search` (k=6) hits considered:

| Candidate | Top hits | Same trigger? |
|-----------|----------|---------------|
| JSON key / UTF-8 bytes | exposing-an-origin-http-api 0.755, default-encoding-in-text-io 0.728, object-key-persistence 0.725, idempotency 0.722, runtime-validation 0.721; second query: minimum-case-set 0.760, multiline-form-values-arrive-with-crlf 0.747 | No page covers unpaired surrogates or byte-vs-character limits. validation-at-trust-boundaries already says "validate length and encoding (valid UTF-8)" for free text, so this is the same trigger family. **Merged** as an edge row there, with a pointer row and `related:` added both ways to idempotency |
| stale `.pyc` | bytecode-cache-staleness 0.774 / 0.773 / 0.764, default-encoding-in-text-io 0.790 (whose row points to bytecode-cache-staleness) | **Same trigger, same directive.** Steps 1–2 and 5 already cover same-size, same-second rewrites. Its `-B`/`PYTHONDONTWRITEBYTECODE` row also shows the candidate's suggested `-B` fix is not enough on its own, because an existing `.pyc` is still read. **Dropped** as a duplicate |
| replace exact-text tests | failing-test-first 0.782, anchor-cases-for-allowlist-regexes 0.774, surviving-mutant-equivalence-triage 0.768, ci-workflow-step-behavior-tests 0.803 (workflow query) | ci-workflow-step-behavior-tests owns exact-text workflow tests and how to replace them. It does not cover deciding which old tests to delete. **Merged** as an edge row. source-text-wiring-assertions was considered but is already 146 lines, over the cap |

No conflicts with existing directives. No page was superseded.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`
returned 4 heads. This run has no git access, so it compared each PR's
changed-file list and body (from `gh pr list --json files,body`) against the
candidates instead of reading their diffs.

| PR | Topics / wiki files touched | Overlap with a candidate |
|----|-----------------------------|--------------------------|
| #300 | Gradle include filters, HMAC key length, Slack webhook probe, secrets in approved commands, `.env` targets, worktree pre-push; touches `security/secrets/secrets-in-code`, `testing/quality/{tests-that-cannot-fail,checks-that-cannot-pass,new-test-outside-a-runner-include-filter}`, `security/index.md`, `testing/index.md` | None. Neither target page is touched |
| #299 | gh paginate, ktlint final newline, command-guard exemptions, grep pitfalls, incidental unique invariants; touches `security/agent-exposure/command-guard-exemption-matching`, `security/index.md` | None |
| #298 | gateway aliases, Spring env-var names, CDN traffic path, stderr in captures | None |
| #293 | git diff algorithm line counts; touches `testing/quality/{diff-algorithm-dependent-line-counts,json-manifest-edit-gates}`, `testing/index.md` | None |

Verdicts:
- `831eb7e1a4f7b87b`: **new**.
- `f477f9408b951e78`: **new**.
- `18eda0a34f791854`: dropped against the merged wiki, not against an open PR.
- `4fd103753eedf249`: excluded by the layer test, so it was not compared.

Possible merge conflicts, not duplicate content:
- `log.md`: every open flush PR appends to it.
- `security/index.md`: also edited by #299 and #300. This PR changes only the `input` row.
- `testing/index.md`: also edited by #293 and #300. This PR changes only the `ci-workflow-step-behavior-tests` row.

## Routing decision

| Candidate | Target | Action |
|-----------|--------|--------|
| 831eb7e1a4f7b87b | security/input/validation-at-trust-boundaries | +1 edge row, +4 sources, `last_verified` 2026-10-26; idempotency gets a pointer row and a related id both ways (its date is unchanged); security index "load when" extended |
| f477f9408b951e78 | testing/quality/ci-workflow-step-behavior-tests | +1 edge row, +2 sources (labelled as read through search summaries) plus the field case; `last_verified` unchanged because the new row is field-tested; testing index "load when" extended |
| 18eda0a34f791854 | — | dropped (duplicate) |
| 4fd103753eedf249 | — | dropped (project-specific plan-gap) |

No new category was needed. Both general rows had their project names removed:
the field case is described as "an event-consume route" and "a CI workflow".

## Local-layer candidates

One row is excluded from this PR. It records a t1-trust-select design decision
for the dev-loop repository's own orchestrate tooling (the `tetra` workspace).
That decision: which digit to send to a numbered Claude Code trust or
bypass-permissions screen, and never to send Enter after it. To keep it, run
wiki-ingest inside that project.

| Row | Decision | Target |
|-----|----------|--------|
| `4fd103753eedf249` | t1-trust-select D2: which key answers a numbered screen | `wiki-local/infrastructure/agent-orchestration/numbered-trust-screen-key.md` (dev-loop repo) |

The two ingested candidates are general. The duplicate's evidence came from
linkly's `RELAY_BATCH_LIMIT`, but its lesson is general and is already in the
bundled wiki.
