---
id: security-data-masking-verification
domain: security
category: data
applies_to: [general]
confidence: field-tested
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
  - "Local reproduction (lnpl 0.2.0, 2026-08-05): one `--json` run held the raw planted card number at result.bindings while the trace/log channel showed `***`; an unmasked control field appeared in both"
last_verified: 2026-08-29
related: [security-data-pii-handling, testing-quality-harness-reverse-controls, qa-exploratory-override-control-pairs]
---

# Verifying Masking Across Every Output Channel

## When this applies

You are about to claim that masking/redaction of a sensitive field works — a
logger filter, type-driven DSL masking, a serializer — or a masking check has
passed on one channel, or you are reviewing an automated/differential "masking
PASS" verdict from the platform itself.

## Do this

1. **Enumerate every distinct output channel the runtime produces**, then grep
   the raw secret value in each one:

| Channel | Where masking is typically applied |
|---------|-------------------------------------|
| Result payload / API response | Not by a logger filter — the response never passes through it |
| Trace / log stream | The usual home of masking (logger filter, log-record rewrite) |
| Human-readable / pretty output | Separate serializer from the JSON path — check both |
| Generated artifacts (OpenAPI examples, docs) | Generated from schema/IR, not through the logger |
| Error reports / crash dumps | Third-party SDK payloads need their own scrub hooks ([security-data-pii-handling]) |

   Masking is implemented per-channel; a check that passes on one channel
   proves presence there, not enforcement anywhere else.
2. **Plant a known, distinctive raw value** (a test card number such as
   `4111111111111111`) so the grep is exact and cannot false-match.
3. **Pair every channel's grep with a negative-control field that must appear
   unmasked in the same channel.** A channel where the control is also absent
   was not captured at all — the "no raw value" result is vacuous
   ([testing-quality-harness-reverse-controls]).
4. **Treat the platform's own masking verdict as scoped to the channels it
   compares.** Ask which channels the check reads before accepting its PASS: a
   differential check that only compares masked-clean channels reports PASS
   while the raw value sits in the result payload.

## Edge cases

| Case | Then |
|------|------|
| The value is transformed before output (formatted, truncated, chunked) | Grep distinctive substrings of the raw value as well as the whole |
| Structured and human-readable output serialize separately | Run the channel sweep once per serialization mode (`--json` and default) |
| Masking is type-driven (a `Password`-typed field) | Verify per channel anyway — the type triggers masking only in the layers wired to honor it |
| A new output channel is added later (export, webhook, metrics label) | Re-run the sweep; channel enumeration is release-scoped, not one-time |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Claim masking works after seeing `***` in the log | Grep the raw value in every enumerated channel of the same run | The log is one channel; the result payload in the same output file can carry the raw value |
| Accept the tool's "masking PASS" verdict | Determine which channels the verdict compares, then sweep the rest yourself | The verdict is a claim about the compared channels only |
| Check only that the raw value is absent | Also require the negative-control field present in each channel | An empty or uncaptured channel makes absence meaningless |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html — scoped to the logging channel only: lists "Authentication passwords" and "Bank account or payment card holder data" as data to be "removed, masked, sanitized, hashed, or encrypted" rather than recorded in logs. It does not address the result payload, pretty output, generated artifacts, or error-report channels, and does not itself prescribe the cross-channel sweep methodology — that comes from the local reproduction below, where the same masking check passed on the log channel while the raw value sat unmasked in the result payload
- Local reproduction (2026-08-05, lnpl 0.2.0 runner): a `Password`-typed field fed the planted value `4111111111111111`; one `--json` output held the raw value at `.result.bindings.account.cardSecret` and `***` at `.trace.logs[0].payload.cardSecret`; the unmasked control field `label` appeared in both channels. Matches the originating QA case, where the platform's differential check reported "PASS 4/4 masking" while the raw card number sat in `result.bindings`
