# Knowledge flush — 4 insight(s)

Queue drained: 4 pending candidates across 3 session files. **2 ingested, 2 dropped**
as in-flight duplicates of open PR #51.

## Verified best-practice

### 1. Harness-vs-run-path fixture synthesis (`cd4826874fdb6acc`) — **verified**

**Claim.** When a spec/test harness and the production entry point each synthesize
the program's input from different declaration sets, a guard whose operand is absent
from the harness's narrower fixture evaluates not-true and the run reports
"guard false / step skipped, exit 0" — which reads as a defect in the program under
test but is an artifact of the harness's fixture scope.

**Sources checked.**

- https://www.postgresql.org/docs/current/functions-comparison.html — "Ordinary
  comparison operators yield null (signifying "unknown"), not true or false, when
  either input is null. For example, `7 = NULL` yields null"; and
  `NULL::boolean IS TRUE` → `f`. An unknown operand lands on the not-true side,
  where it is indistinguishable from a present-and-false operand.
- https://jqlang.org/manual/ — `.foo` on an object lacking that key produces `null`;
  `if` takes the else branch "if A produces a value other than false or null".
  Same collapse in a second, unrelated expression language.
- https://istqb-glossary.page/branch-coverage/ — "The percentage of branches that
  have been exercised by a test suite" — grounds the "a skipping run is evidence
  about the skip direction only" directive.

**How verified.** Two reproductions run this session, not just cited:

- Local (Python 3.14.6 + jq 
  `/usr/bin/jq`, macOS): one guard `shipment.ready` over a one-entity fixture
  returned `False`, over the full fixture returned `True`, and the one-entity result
  compared *equal* to the result on an explicit `{"shipment": {"ready": false}}` —
  the two causes are one observable. `echo '{"order":{}}' | jq '.shipment.ready'`
  → `null`, and both inputs took the `else` branch.
- Field (carried by the candidate, lnpl spec runner): the runner built its payload
  from `sample_payload([first_entity])` while `run`/`diff`/mode-B used
  `sample_payload(all_entities)`; injecting only the missing second-entity field
  moved the same workflow from `STATUS: completed STEPS: 1 SKIPPED: 1` to
  `STEPS: 2 SKIPPED: 0` with no other change. Three separately-filed major bugs
  traced to that one narrowing.

**Confidence: verified.** The semantic mechanism is doc-confirmed in two languages
and locally reproduced; the design directive (one synthesizer, explicit
author-overridable narrowing) is supported by the field before/after. Recorded as
`verified` with both reproductions written into the page's Sources so a reader can
re-run them.

### 2. Negative-control anchor rot in a doc-as-spec gate (`52dcf45adfc479f9`) — **verified**

**Claim.** When a gate's negative control builds its mutant by quoting the whole
target row — key cells and prose cells — an ordinary rewording of the prose stops
the match; the substitution returns the document unchanged rather than raising, the
check runs against the *original* and passes as it should, and the control reports
green while mutating nothing. Anchor on the key-column prefix and assert the
mutation applied.

**Sources checked.**

- https://docs.python.org/3/library/stdtypes.html — `str.replace`: "Return a copy of
  the string with all occurrences of substring *old* replaced by *new*." The
  documented signature carries no not-found error and no substitution count. (The
  docs do not state the not-found case explicitly, so it was reproduced rather than
  cited — see below.) `str.count` returns `0` for an absent substring.
- https://docs.python.org/3/library/re.html — `re.subn` "Perform the same operation
  as `sub()`, but return a tuple `(new_string, number_of_subs_made)`" — the counted
  form that makes "it applied" checkable without a separate assertion.
- Already-cited in the target page and re-used: https://pitest.org/ (a mutant is
  killed when a test fails) and https://eslint.org/docs/latest/integrate/nodejs-api
  (an `invalid` case must declare the errors it expects).

**How verified.** Local reproduction 2026-08-07 (Python 3.14.6, macOS): a control
quoting `| security | jwt | rejects unsigned tokens |` against a document whose cell
had been reworded to `… at the edge` produced `mutant == doc` — mutation not
applied, no exception raised. The same mutation anchored on the prefix
`| security | jwt |` applied. `re.subn` reported `0` substitutions for the stale
anchor and `1` for the prefix pattern. Field origin: linkly
`impl/tests/test_enforcement_matrix.py::test_a_short_row_raises_rather_than_reading_as_empty_cells`,
where only `assertNotEqual(mutant, original, "the mutation did not apply")`
surfaced it; re-anchoring returned the suite to 37/37.

**Confidence: verified.**

### 3–4. The two dropped candidates

`28fd6dfedea1b338` (worktree guardrail escalation on read-only cross-worktree
access) and `ba3b56aded3e6191` (orca terminal-binding failure taxonomy) were not
independently re-verified, because open PR #51 already carries both with *stronger*
evidence — see **Open-PR check**. Notably #51's reproduction **corrects** the
premise of `28fd6dfedea1b338`: the candidate asserts the guardrail fires on
read-only access, while #51 reproduced that plain reads of a sibling worktree
(`grep`, `awk`, `cat`, `git -C … status`) all pass, and the rule fires only when a
write verb or an absolute-path redirect co-occurs anywhere in the same command
string. Ingesting the candidate as written would have contradicted a better-sourced
open PR.

## Existing-layer check

Routed via `INDEX.md` → `testing` (both ingested candidates concern automated test
code, not release process). Read `wiki/testing/index.md` and `wiki/qa/index.md`
in full, then every page whose "load when" line overlaps.

Pages read: testing-quality-spec-artifact-checks, testing-quality-harness-reverse-controls, testing-quality-differential-run-agreement, testing-data-test-data-and-isolation, qa-exploratory-guard-true-path-coverage, backend-common-change-impact-call-site-enumeration

Overlaps found and resolution:

| Candidate | Page examined | Verdict |
|-----------|---------------|---------|
| Fixture parity | `testing-quality-differential-run-agreement` | Adjacent, not the same. It governs *citing an agree verdict* when the two sides model different state; this candidate is about the two sides being fed different *synthesized input*, and about attributing a skip. Cross-linked both ways, created new. |
| Fixture parity | `qa-exploratory-guard-true-path-coverage` | Closest existing page — it already says a guard-skipping run is evidence about the skip path only. It does **not** cover *why* the guard was false (an absent operand) or the fixture-parity fix. New page carries the causal/diagnostic half and defers the coverage rule to that page by id. Cross-linked both ways. |
| Fixture parity | `testing-data-test-data-and-isolation` | Owns fixture ownership/isolation; its closest row is "a factory whose shape depends on a value the test also passes to the code under test". Different case (a value vs. the declaration *scope*, and no diagnostic half). Cross-linked, created new rather than stretching that page's trigger. |
| Anchor rot | `testing-quality-spec-artifact-checks` | **Same trigger** — it already owns "one negative control per check in a doc-as-spec repo" and Markdown-table row parsing, but says nothing about how to *locate* the mutation site or that the control must prove it mutated. **Merged** (merge-before-create). |
| Anchor rot | `testing-quality-harness-reverse-controls` | Related but harness-level: it covers a *uniform* verdict across the whole harness ("every case survives → the harness never applied the mutation"). This candidate is a *per-control* rot that leaves the other controls working, so the harness-level uniformity signal never fires. Added the reciprocal `related:` link; content stayed in spec-artifact-checks. |

Conflicts flagged: none among the ingested pages. One conflict *avoided* — see the
`28fd6dfedea1b338` note above (candidate premise vs. PR #51's reproduction);
resolved by dropping the candidate, not by overwriting anything.

Related-links added (both directions): the new page ↔ `testing-data-test-data-and-isolation`,
`testing-quality-differential-run-agreement`, `qa-exploratory-guard-true-path-coverage`;
plus `testing-quality-harness-reverse-controls` → `testing-quality-spec-artifact-checks`.

## Open-PR check

Open `knowledge/*` heads listed at flush time: **#58, #57, #56, #55, #52, #51, #50,
#49, #47**. Fetched and diffed against `origin/main` for the heads whose titles
overlapped any candidate's trigger — #51 (`knowledge/dch0202-20260806-183029`),
#58 (`knowledge/choiyounggi-20260807-191239`), #57 (`knowledge/choiyounggi-20260807-163902`).

| Candidate | Overlapping open PR | Verdict |
|-----------|--------------------|---------|
| `cd4826874fdb6acc` — harness fixture narrower than the run path | none (#58 touches `backend/common/change-impact`; #57 touches `testing/strategy/signal-delivery-to-a-process-under-test`; #51 touches orchestration/security/qa) | **new** — ingested |
| `52dcf45adfc479f9` — negative-control literal anchor rot | none (no open head touches `testing/quality/spec-artifact-checks.md`) | **new** — ingested (merged into the existing page) |
| `28fd6dfedea1b338` — worktree guardrail, read-only escalation | **#51**, `wiki/infrastructure/agent-orchestration/worktree-isolated-workers.md` (+4 rows, +1 dated local reproduction) | **drop** — the open PR carries the same directive ("Budget the round trip … and state in the worker's first brief that reads are approved") plus a reproduction that corrects the candidate's mechanism claim. Nothing unique to push. |
| `ba3b56aded3e6191` — orca terminal-binding taxonomy | **#51**, `wiki/infrastructure/agent-orchestration/pane-delivery-confirmation.md` (+4 Do rows, +1 Instead-of row, +1 dated field-observation source) | **drop** — 1:1 coverage of all four sub-claims (idle-prompt check before binding; worker-done is a report, not the end of the turn; runtime-unavailable → wait and bind a fresh unit; agent-unconfigured → close the pane and create a worker-mode agent; worktree passed alongside the pane). Nothing unique to push. |

Both dropped candidates are the same pair that flushes **#56, #57 and #58** each
dropped as in-flight duplicates of #51 — they keep re-crossing the auto-flush
threshold because #51 has not merged. They are being retired to
`.processed.jsonl` in this flush (step 5), so they will not re-queue.

## Routing decision

| Insight | Target | New category? |
|---------|--------|---------------|
| Harness-vs-run-path fixture synthesis | **new page** `testing/data/harness-vs-run-path-fixtures.md` (`testing-data-harness-vs-run-path-fixtures`) | No — `testing/data` already exists and owns fixture construction. The case is a distinct trigger from `test-data-and-isolation` (synthesis parity + skip attribution vs. ownership/isolation), so it is a page, not a row. |
| Negative-control anchor rot | **merged** into `testing/quality/spec-artifact-checks.md` — new `Do this` step 3 (anchor by key-column prefix + assert `mutant != original`; `re.subn` count as the alternative), 3 edge-case rows, 1 `Instead of` row, 2 sources, `last_verified` → 2026-08-07 | No |
| `28fd6dfedea1b338`, `ba3b56aded3e6191` | not routed — dropped to `.processed.jsonl` | — |

Plumbing updated: `wiki/testing/index.md` (`## data` gains the new page with its
"load when" line), `log.md` (one `ingest` entry, one `dedup` entry). Page body
lengths: new page 65 lines, `spec-artifact-checks` 115 lines — both under the
120-line limit. All `related:` ids in every touched page resolve against `wiki/`
(checked mechanically).
