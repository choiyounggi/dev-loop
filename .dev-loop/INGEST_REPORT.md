# Knowledge flush — 1 insight(s) (headless auto-flush run 20261030-112310-27790)

This run claimed 13 queue rows. Results: 1 ingested, 2 dropped as duplicates of
the merged wiki, 1 released because it plausibly overlaps open knowledge PRs, and
9 released unread because this headless run could not find their queue files.
Nothing was folded into another branch.

## Verified best-practice

| Row | Claim | Verification | Confidence |
|-----|-------|--------------|------------|
| `248ccfddbcc612a1` | A test helper that parses Prometheus exposition text with a label-set regex like `\{([^}]*)\}` rejects valid lines once label values contain `}` (route templates such as `/order/{id}`). Prefer a real parser. If the helper must stay a regex, match each quoted value as one unit, and keep one negative case showing an unclosed label set is still rejected | https://prometheus.io/docs/instrumenting/exposition_formats/: "label_value can be any sequence of UTF-8 characters, but the backslash, the double-quote, and the line-feed characters have to be escaped". So `}` is legal inside the quotes. https://prometheus.github.io/client_python/parser documents `prometheus_client.parser.text_string_to_metric_families`, and the README notes this parser is more lenient than the Go one. https://www.robustperception.io/openmetrics-is-released confirms the required `# EOF` line, which backs the OpenMetrics edge row. https://prometheus.io/docs/instrumenting/escaping_schemes/ backs the quoted-UTF-8-names edge row. The session evidence was the line `...{route="/order-service/order/{id}",...} 2` raising "unparseable exposition line" under the old regex; with the quote-aware regex, 265 tests passed and `broken{a="x" 1` still raised. The page's regex was not re-run in this headless run because Bash `python3` needs approval here. It is the session's own pattern, wrapped in `\{...\}` | verified |
| `9cce9c1914fef241` | A test-floor gate marks a unittest `self.assertX` file as `no-assertion`: read the floor's Python pattern and treat the result as a false negative | Not re-researched. The merged page already owns this exact trigger (see below) | dropped (duplicate) |
| `bb8b376ef7f0506e` | In-place mutate/restore probes on Python source can run stale `.pyc` bytecode. Use `-B` or delete `__pycache__` | Not re-researched. The merged page already covers it with official docs. That page also shows the candidate's "run each probe with `python -B`" option is not enough on its own: `-B` only stops writing, and an existing stale `.pyc` is still read | dropped (duplicate) |

## Existing-layer check

Pages read: testing-quality-assertion-scanner-false-positive-on-unittest-convention, backend-python-language-bytecode-cache-staleness, infrastructure-observability-logs-metrics-signals

Indexes read: `wiki/testing/index.md` (full).

- `248ccfddbcc612a1`: `wiki_search` on Prometheus label parsing returned no page on that trigger. The top hits were config-value escaping, allowlist-regex anchors, and frontmatter quote stripping. A search for Prometheus metrics found `infrastructure-observability-logs-metrics-signals`. That page tells you to label with the route template (`/users/{id}`), which is exactly the label shape that breaks the naive regex. **New page** `testing-quality-prometheus-exposition-parsing-in-test-helpers`. `related:` links to that observability page, which gets a back-link, and to `testing-data-adjacent-tokens-in-extractor-fixtures`, `testing-quality-anchor-cases-for-allowlist-regexes` and `testing-quality-tests-that-cannot-fail`. No conflict.
- `9cce9c1914fef241`: `testing-quality-assertion-scanner-false-positive-on-unittest-convention` already covers it. Its trigger is a floor that greps for bare `assert`/`pytest.raises` and flags `self.assertX` files. Its step 6 already says to read the classifier and treat the result as `floor=unknown`, and a 2026-10-15 field row shows the same `test-floor.sh` `analyze_pytest` miss. Nothing new, so the row was **dropped as a duplicate** and retired.
- `bb8b376ef7f0506e`: `backend-python-language-bytecode-cache-staleness` already covers the mtime+size validation, purging `__pycache__` between mutants, re-verifying after the revert, and the row where a delegated auditor mutated the files. It also corrects the candidate on `-B`. **Dropped as a duplicate** and retired.

## Open-PR check

There are 14 open `knowledge/*` heads: #317, #315, #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. This headless run has no git access, so it could not diff them. Instead it compared candidates against each PR's changed-file list (`gh pr list --json files`).

| Row | Overlapping open PR | Verdict |
|-----|---------------------|---------|
| `248ccfddbcc612a1` | None. No open PR touches Prometheus/metrics parsing or `infrastructure/observability/`. #299 edits `platforms/processes/parsing-cli-structured-output.md`, which is about CLI tool output, a different trigger. Several PRs touch other rows of `wiki/testing/index.md` only | new |
| `9cce9c1914fef241` | #315 edits `assertion-scanner-false-positive-on-unittest-convention.md`, but the merged page already holds this row | drop (duplicate of merged wiki) |
| `bb8b376ef7f0506e` | None touches the bytecode page | drop (duplicate of merged wiki) |
| `fc76dc4dfa08ecde` (Docker-gated schema validator: skip vs fail via a `REQUIRE` env var, plus a known-bad document) | #300 and #317 both edit `testing/quality/checks-that-cannot-pass.md`, and #300 also edits `tests-that-cannot-fail.md`. A validator that is skipped or always says "valid" is that page's core theme | released (pending duplicate) |

## Routing decision

- `248ccfddbcc612a1` → `testing/quality/prometheus-exposition-parsing-in-test-helpers.md` (new page), with a row in the `quality` table of `wiki/testing/index.md`. No new category. The lesson is about whether a test's own parsing helper can be trusted, which fits `quality`. `data` holds fixture-construction pages. The domain hint `testing` was followed. The directive is general: any repo whose tests parse `/metrics`. The project run appears only in a Sources line.
- `9cce9c1914fef241`, `bb8b376ef7f0506e` → no edit (duplicates). Rows retired in place with `status: retired`, an `outcome`, `retiredBy` and `retiredAt`.
- Released without routing: `fc76dc4dfa08ecde` (open-PR overlap, above). Also `1d01cb971e07f6cb`, `33ffb8688290c9c1`, `063108972d150963`, `cb3954d76f244491`, `fdbac2d18d580e0c`, `7a851159bdab0e27`, `ee3362544f6d9162`, `aa190116f0c2596a` and `4b0c7878166d1fa8`. This run's sandbox blocks listing `~/.dev-loop/queue/`. Session files can only be found by guessing their session-id names, and those rows sit in files that come after `76896825-…` in sort order, which could not be found from `~/.claude/history.jsonl` session ids. They were released unread for a later manual flush.

## Local-layer candidates

none
