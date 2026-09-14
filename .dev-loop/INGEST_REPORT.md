# Knowledge flush — 3 insight(s)

Claimed this run: `780cc9007d23bf67`, `01cc5fdd76565581`, `6db22c1e9830a187`. Outcome: 1 new page, 1 amended page, 1 dropped (superseded).

## Verified best-practice

### 1. `01cc5fdd76565581` — checksum-restored identifiers need a success-path warning → **verified**
- **Claim:** when an importer restores an identifier's lost leading zero (numeric spreadsheet cell) and accepts it because the check digit passes, it must still flag/warn on the successful repair, because a single mod-11 check digit accepts about 1/11 of arbitrary inputs.
- **Sources checked:**
  - https://support.microsoft.com/en-us/office/keeping-leading-zeros-and-large-numbers-1bf7b935-36e1-4985-842f-5dfa51f85fe7 — live-fetched: "Excel automatically removes leading zeros…"; formatting "will not restore leading zeros that were removed prior to formatting"; Power Query can type a column as Text at import; 15-significant-digit precision.
  - https://support.microsoft.com/en-us/excel/set-automatic-data-conversions — live-fetched: "Remove leading zeros and convert to number" automatic conversion (Excel for Microsoft 365 / 2024, Windows + Mac); default converts `00123` to `123`.
  - https://pandas.pydata.org/docs/reference/api/pandas.read_csv.html — `dtype` for reading columns as strings.
- **Reproduction:** ran the real validator (`src/validation/tax_code.py`, weights 31/29/23/19/17/13/7/5/3, check = 10 − (sum mod 11), remainder 0 rejected) against 200,000 seeded random `0`+9-digit inputs → 18,089 passed (**9.04%**); 200,000 random 10-digit inputs → 18,117 (9.06%). Matches the candidate's 18,242/200,000 and the analytic 1/11 ≈ 9.09%. Confirmed the originating fix exists at HEAD of the source repo (`src/company_import.py`: `was_leading_zero_restored` + "restored … verify" warning).

### 2. `6db22c1e9830a187` — stale `.pyc` after a subagent's mutate-and-revert → **verified** (merged into an existing verified page)
- **Claim:** after a mutation-then-revert verification step, clear `__pycache__` before trusting the next suite run; CPython's default timestamp(+size) validation can reuse the mutant's bytecode.
- **Sources:** mechanism already carried and cited by `backend-python-language-bytecode-cache-staleness` (docs.python.org import reference — "storing the source's last-modified timestamp and size"; PEP 552; py_compile; three prior field reproductions). The candidate's case (`"n/a"` → `"N/A"`) is byte-length-preserving, so it falls exactly in the page's documented same-size/same-second window — consistent, no contradiction.
- **What is new:** the actor who mutated was a *delegated* subagent sharing the worktree, so the parent session had no signal to purge. Added as one edge row + one field-reproduction source line. `last_verified` left unchanged (docs not re-fetched this run).

### 3. `780cc9007d23bf67` — evaluate per-row rejection rules against the whole batch's domain set → **dropped (superseded / contradicted)**
- **Claim:** in a batch path that fans one upstream result out to many rows, evaluate per-row rejection rules (e.g. "email domain == page domain → reject") against the batch's full set of source domains.
- **Verification result:** the originating codebase later reversed this. Batch extraction now writes one row per page (commit `b89f8c6`, "write one extracted_contacts row per page in batch extraction", issue #13), and `tests/test_ai_extractor.py::test_extract_batch_email_domain_matching_no_batch_page_stays_valid` pins that batch-wide domain widening **wrongly** flags a row whose email matches a *sibling* page's domain — the exact directive this candidate proposes. The evidence paths cited in the candidate (`.orchestration/archive-20260910-cv0910/reviews/…`) no longer exist on disk. The directive as written is not a best-practice, so it is not ingested. (The salvageable idea — attribute each fanned-out result to its own source — would need its own candidate and sourcing.)

## Existing-layer check

Pages read: backend-python-language-bytecode-cache-staleness, testing-quality-mutation-harness-file-custody, backend-common-change-impact-aggregation-layer-of-a-shared-helper, databases-schema-design-column-data-types

Also read: `INDEX.md`, `wiki/backend/index.md`, `wiki/testing/index.md`, `wiki/qa/index.md`, `wiki/infrastructure/index.md` (grep), `wiki/security/index.md` (grep); keyword sweep of `wiki/` for `pycache|.pyc|bytecode|checksum|leading zero|check digit|mod-11|fan-out|batch`.

- **Candidate 2 (pyc):** `bytecode-cache-staleness` already owns the trigger and directive (purge `__pycache__` between edit iterations; "regression persists after a clean revert" Instead-of row). Same trigger, same directive → **merged** (edge row + source), no new page. `mutation-harness-file-custody` is adjacent (restore custody, not cache) and already linked through `harness-reverse-controls`; no change needed.
- **Candidate 1 (checksum):** no page covers import-time identifier repair. `column-data-types` only states "national ids → TEXT, leading zeros are data" (storage side). → **new page** `backend-common-integrations-checksum-restored-identifiers`; `related:` to `databases-schema-design-column-data-types`, `backend-common-integrations-consumer-required-fields`, `security-input-validation-at-trust-boundaries`; backlink added on `column-data-types`.
- **Candidate 3 (batch fan-out):** nearest page `aggregation-layer-of-a-shared-helper` (same helper in two aggregation layers) — different trigger; no conflict to flag because the candidate was dropped.
- Conflicts flagged: none.

## Open-PR check

Listed open heads (`gh pr list --search "head:knowledge/"`): #189 `knowledge/choiyounggi-20260910-162026`, #188 `…-20260908-154412`, #187 `…-20260906-213635`, #186 `…-20260906-013856`, #185 `…-20260906-003745`, #183 `…-20260904-133717`, #182 `…-20260903-214027`, #181 `…-20260903-203836`, #180 `…-20260903-184706`, #179 `…-20260903-172728`.

For each: `git fetch origin <head>` then `git diff origin/main...origin/<head> -- wiki/`, scanning the changed-file list for the target pages and the added lines for `pycache|.pyc|bytecode|leading zero|checksum|check digit|fan-out|per-row|batch`.

- No open head touches `bytecode-cache-staleness.md` or `column-data-types.md`. Keyword hits were unrelated (GIL bytecode switching in #189, per-row reorder locking in #185, batch screenshots in #182, queued-row retirement in #186).
- #187 adds `backend/common/integrations/contact-details-from-scraped-pages.md` (same category as the new page, different trigger: main-content scrapers dropping contact regions); #185/#187 add `integrations/` rows to `backend/index.md` — row-level index edits, no content overlap.
- Verdicts: `01cc5fdd76565581` → **new**; `6db22c1e9830a187` → **new** (merge into an existing main-branch page, no open PR carries it); `780cc9007d23bf67` → not ingested (dropped on verification, no open PR carries it either).

## Routing decision

| Candidate | Domain / category | Page | Action |
|-----------|-------------------|------|--------|
| `01cc5fdd76565581` | backend / common/integrations | `wiki/backend/common/integrations/checksum-restored-identifiers.md` | new page + `backend/index.md` integrations row + backlink on `databases/schema-design/column-data-types` |
| `6db22c1e9830a187` | backend / python/language | `wiki/backend/python/language/bytecode-cache-staleness.md` | +1 edge row, +1 field-reproduction source |
| `780cc9007d23bf67` | — | — | dropped: superseded by later code and regression test |

No new category. `integrations` was chosen over `security/input` because the concern is repair and provenance of values from an external file format, not trust-boundary rejection. It was chosen over `databases/schema-design` because the loss happens before storage.
