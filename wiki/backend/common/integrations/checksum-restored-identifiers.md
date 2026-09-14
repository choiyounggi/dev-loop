---
id: backend-common-integrations-checksum-restored-identifiers
domain: backend
category: integrations
applies_to: [general]
confidence: verified
sources:
  - https://support.microsoft.com/en-us/office/keeping-leading-zeros-and-large-numbers-1bf7b935-36e1-4985-842f-5dfa51f85fe7
  - https://support.microsoft.com/en-us/excel/set-automatic-data-conversions
  - https://pandas.pydata.org/docs/reference/api/pandas.read_csv.html
last_verified: 2026-09-14
related: [databases-schema-design-column-data-types, backend-common-integrations-consumer-required-fields, security-input-validation-at-trust-boundaries]
---

# Identifiers Repaired by a Check Digit During Import

## When this applies

An import reads identifiers (tax codes, business registration numbers, account
numbers) from a spreadsheet or a CSV exported from one, the column was a numeric
cell so the leading zero is gone (`0101096393` arrives as `101096393` or
`101096393.0`), and the importer pads the zero back and accepts the result when
the identifier's check digit passes. Also any other repair (re-inserting a
dropped digit, fixing a transposition) whose only confirmation is a check digit.

## Do this

1. **Emit a row-level warning for every successful repair, naming the raw and the
   repaired value**, in addition to the warning for a failed repair. A check
   digit confirms plausibility, not identity: a single mod-11 check digit accepts
   roughly 1 in 11 arbitrary inputs, so a wrongly repaired code is accepted
   silently at that rate unless the success path also reports.
2. **Carry the repair as a flag on the stored record** (`tax_code_restored`, or a
   warnings list keyed by row), not only in a transient log line — downstream
   stages need to know which values the user never typed.
3. **Measure the check's false-accept rate before citing it as confirmation.**
   Feed a few hundred thousand random inputs of the repaired shape through your
   own validator and report the pass fraction. The expected figure for a weighted
   mod-11 digit that rejects remainder 10 is 1/11 ≈ 9.1%.
4. **Decide how a repaired value may gate downstream work:**

| The identifier is used as | Do |
|---------------------------|----|
| A display/search field only | Keep the repaired value with its flag and warning |
| A deciding field — a mismatch rejects pages, merges, or records | Require independent confirmation (registry lookup, user acknowledgement) before it gates; until then, route mismatches to review instead of rejecting |
| A join key into another system | Confirm against that system before joining; a false repair joins to a real, unrelated entity |

5. **Stop the loss at the source when you control the reader.** For CSV, read the
   column as text (pandas `dtype=str`, or Power Query's "Text" column type per
   Microsoft); the zero is still in the file. For an `.xlsx` numeric cell the zero
   is not stored at all, so only the repair path (with steps 1–4) is available —
   ask for a text-formatted re-export when the value is a deciding field.

## Edge cases

| Case | Then |
|------|------|
| The numeric cell comes through as a float string (`101096393.0`) | Strip the `.0` before the length test; otherwise the repair branch never runs and the row is rejected as malformed |
| A branch suffix is present (9 + 3 digits became 12 digits) | Pad and re-split (`0101096393-001`) before validating; validate the base part only if the scheme checks only the base |
| More than one repair passes the check (zero padded at different positions, two transpositions) | Reject as ambiguous and warn; picking the first passing candidate turns a 1/11 false-accept into a coin toss among valid-looking codes |
| The identifier has 16+ digits | Excel keeps 15 significant digits and zeroes the rest; no check digit can recover that — reject and request a text re-export |
| The user fixes the source and re-imports | Clear the flag only when the new raw value is full-length and passes as entered |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Warn only when the repaired value fails the check | Warn on every repair, pass or fail | The passing-but-wrong case is the one nobody else will catch — measured 9.04% of random 9-digit bodies pass |
| Store the repaired value exactly as if the user had entered it | Store it with a restored flag | A false repair used as a deciding field makes every true record for that entity look mismatched, and the data vanishes without an error |
| Apply a text/custom number format to the column after the zeros are gone | Re-import the column as text, or repair with a flag | Microsoft: formatting "will not restore leading zeros that were removed prior to formatting" |

## Sources

- https://support.microsoft.com/en-us/office/keeping-leading-zeros-and-large-numbers-1bf7b935-36e1-4985-842f-5dfa51f85fe7 — "Excel automatically removes leading zeros, and converts large numbers to scientific notation"; custom formatting "will not restore leading zeros that were removed prior to formatting"; Get & Transform (Power Query) can set a column to Text at import; 15 significant digits of precision
- https://support.microsoft.com/en-us/excel/set-automatic-data-conversions — the "Remove leading zeros and convert to number" automatic conversion option (Excel for Microsoft 365 / 2024, Windows and Mac), which is on by default
- https://pandas.pydata.org/docs/reference/api/pandas.read_csv.html — `dtype` parameter for reading columns as strings
- Measurement 2026-09-14 (Vietnamese MST validator, weights 31/29/23/19/17/13/7/5/3, check digit = 10 − (sum mod 11), remainder 0 rejected): 200,000 random `0`+9-digit inputs → 18,089 passed (9.04%); 200,000 random 10-digit inputs → 18,117 (9.06%). An independent reviewer in the originating session measured 18,242/200,000 on the same validator
- Field context 2026-09-14 (company-import for a Vietnamese contact crawler): the importer restored leading zeros under a checksum gate and warned only on failure; the tax code is a deciding field for page identity, so a false restoration would mark the company's real pages as mismatched. The fix added a success-path warning ("restored … leading 0 lost in a numeric cell, verify")
