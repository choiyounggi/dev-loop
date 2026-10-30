---
id: testing-quality-prometheus-exposition-parsing-in-test-helpers
domain: testing
category: quality
applies_to: [prometheus, openmetrics, python, general]
confidence: verified
sources:
  - https://prometheus.io/docs/instrumenting/exposition_formats/
  - https://prometheus.github.io/client_python/parser
  - https://www.robustperception.io/openmetrics-is-released
  - https://prometheus.io/docs/instrumenting/escaping_schemes/
last_verified: 2026-10-30
related: [infrastructure-observability-logs-metrics-signals, testing-data-adjacent-tokens-in-extractor-fixtures, testing-quality-anchor-cases-for-allowlist-regexes, testing-quality-tests-that-cannot-fail]
---

# Parsing Prometheus Exposition Text in a Test Helper

## When this applies

A test helper reads a `/metrics` response (Prometheus text format) and splits each
sample line with a hand-written regex such as `name\{([^}]*)\}\s+value`. The code
under test starts emitting label values that contain `}` — most often route
templates like `route="/order/{id}"`, which is the label shape metrics guidance
recommends — and the helper now raises "unparseable line" or drops samples, so the
failure looks like a bug in the code under test.

## Do this

1. **Read a red metrics test as a possible helper bug first.** In the text format,
   a label value is "any sequence of UTF-8 characters" in which only backslash,
   double-quote and line feed must be escaped (`\\`, `\"`, `\n`). A `}` or `{` inside
   the quotes is valid output. A `[^}]*` label-set match stops at the first brace in
   a value, so it rejects lines the format allows.
2. **Prefer a real parser when the test environment has one.** In Python,
   `prometheus_client.parser.text_string_to_metric_families(text)` yields families
   with each sample's name, labels and value. It is more lenient than the Go
   reference parser, so it proves values, not strict format conformance.
3. **When the helper must stay a regex, match each quoted value as one unit.**
   For the label set use `\{((?:[^}"]|"(?:[^"\\]|\\.)*")*)\}`: outside quotes any
   character but `}` or `"`; inside quotes any character but `"` or `\`, or a
   backslash escape. Then split pairs with `(\w+)="((?:[^"\\]|\\.)*)"` and unescape
   `\\`, `\"`, `\n` before comparing values.
4. **Keep one negative case next to the fix.** Assert that an unclosed label set
   (`broken{a="x" 1`) still raises, so the wider pattern did not turn the helper
   into one that accepts anything.
5. **Add one fixture line per escape class** — a value with `}`, one with `\"`, one
   with `\\` — so a later "simplification" of the regex goes red.

## Edge cases

| Case | Then |
|------|------|
| A label value contains an escaped quote followed by `}` (`a="x\"}"`) | The quote-aware pattern consumes `\"` as an escape and keeps going; a pattern that treats every `"` as a delimiter ends the value early. Keep this exact line as a fixture |
| The endpoint serves OpenMetrics (`Content-Type: application/openmetrics-text`) | The exposition must end with an explicit `# EOF` line, so a regex helper written for the text format reports that line as unparseable. Use an OpenMetrics-aware parser rather than adding one more special case to the regex |
| Metric or label names outside `[a-zA-Z_:][a-zA-Z0-9_:]*` (UTF-8 names, quoted inside the braces) | `\w+` no longer matches the name; switch to a real parser instead of growing the regex |
| The helper counts series by grepping for the metric name | A brace in a value does not break the count, but a value that contains the metric name does; anchor the name at line start |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Change the route label to drop or replace the braces so the helper parses it | Fix the helper's pattern or use a parser | The template label is correct, bounded-cardinality output; changing production to suit a test regex hides the helper's defect |
| Widen the label match to `.*` | Use the quote-aware pattern and keep the unclosed-set negative case | `.*` accepts malformed lines, so the helper stops detecting broken exposition |

## Sources

- https://prometheus.io/docs/instrumenting/exposition_formats/ — text format: "`label_value` can be any sequence of UTF-8 characters, but the backslash (`\`), double-quote (`"`), and line feed (`\n`) characters have to be escaped as `\\`, `\"`, and `\n`, respectively"
- https://prometheus.github.io/client_python/parser — `from prometheus_client.parser import text_string_to_metric_families`, iterating families and samples (name, labels, value); the project README notes the parser is more lenient than the Go reference parser
- https://www.robustperception.io/openmetrics-is-released — "OpenMetrics requires an explicit # EOF at the end of the exposition, so that partial scrapes can be detected and treated as failed"
- https://prometheus.io/docs/instrumenting/escaping_schemes/ — names outside the legacy character set can appear inside double quotes in the exposition, where `\`, `\n` and `"` "MUST be escaped with a backslash"
- Field reproduction 2026-10-29 (Python unittest helper over a server's `/-/metrics` output): the line `lnpl_http_requests_total{route="/order-service/order/{id}",...} 2` raised "unparseable exposition line" under `\{([^}]*)\}`; with the quote-aware pattern above the 265-test module passed, and `broken{a="x" 1` still raised
