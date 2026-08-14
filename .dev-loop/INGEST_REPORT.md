# Knowledge flush — 4 insight(s)

## Verified best-practice

**1. Headless-browser QA shows empty data → probe with a desktop Chrome UA before diagnosing an outage** (from chungyak-alimi session, 2026-08-14)
- Claim: commercial sites' API gateways classify the headless default UA as a bot and reject only the data APIs (4xx) while the page shell/static assets load, so the failure masquerades as a server outage; swapping to a regular Chrome UA is the cheapest discriminating probe.
- Verified: fetched Chromium source `headless/lib/browser/headless_browser_impl.cc` (raw.githubusercontent.com, 2026-08-14) — `const char kHeadlessProductName[] = "HeadlessChrome";` with the comment "Product name for building the default user agent string", i.e. the headless UA is distinguishable by construction. Checked developer.chrome.com/docs/chromium/headless (no UA statement there — not cited). Field evidence from the session: dabangapp.com/map/apt markers/room-list APIs all 400 under default headless UA, 200 after a Chrome/131 UA override.
- Confidence: **verified** (source code + field reproduction).

**2. Re-anchor SL/TP-style absolute triggers to the actual fill at the confirmation-recording point** (from auto-trading-bot session, 2026-08-14)
- Claim: absolute triggers derived from a pre-execution price estimate survive slippage unchanged, collapsing the designed band; recompute them ratio-preserving from the actual fill, once, in the function that records the fill.
- Verified: freqtrade.io/en/stable/stoploss/ (fetched) — stoploss defined as a ratio of entry ("a stoploss of -10% is placed exactly 10% below the entry point"), and with stoploss-on-exchange the order is placed after the buy order fills; en.wikipedia.org/wiki/Slippage_(finance) — decision-time vs execution price divergence is inherent to market orders. Live incident: 6 real positions exited TAKE_PROFIT at +0.06%–+0.42% against a +2% design; `mark_filled()` re-anchor restored the band, regression tests red on pre-fix code (this repo's PR #3, 464 tests green).
- Confidence: **verified** (official docs pattern + reproduced incident + discriminating regression tests).

**3. A permanent test suite must not assert ambient working-tree state; prove scope from the introducing commit's diff** (from dev-loop session, 2026-08-14)
- Claim: the tree a permanent suite inspects is whoever-runs-it's in-progress state; any uncommitted sibling file fails it spuriously.
- Verified: bazel.build/reference/test-encyclopedia (fetched) — "Tests should be hermetic: that is, they ought to access only those resources on which they have a declared dependency"; "If tests are not properly hermetic then they do not give historically reproducible results". Field evidence: dev-loop reviews/i83-insight-emission-r1.md — reproduced spurious failure, rewrite to commit-diff evidence → 521/521.
- Confidence: **verified**.

**4. Guard history-dependent checks with `git rev-parse --is-shallow-repository`; a depth-1 boundary commit reports every tracked file as added** (from dev-loop session, 2026-08-14)
- Claim: actions/checkout's default `fetch-depth: 1` grafts a parentless boundary commit, so `git log --diff-filter` / `merge-base` answer falsely rather than erroring; skip honestly on shallow clones or deepen the fetch per job.
- Verified: actions/checkout README ("Only a single commit is fetched by default"); git-scm.com/docs/git-rev-parse (`--is-shallow-repository`); **fresh local reproduction this session** (git 2.50.1, 2026-08-14): `--depth 1` clone of the 306-file dev-loop repo → `--is-shallow-repository` = true, `git log -1 --diff-filter=A --name-only` listed 306/306 files as added.
- Confidence: **verified**.

## Existing-layer check

Pages read: qa-process-scope-purity-checks, qa-environments-test-environment-parity, testing-e2e-e2e-stability, testing-quality-checks-that-cannot-pass, backend-common-integrations-robots-txt-and-source-selection

- Insight 1: `qa/environments/test-environment-parity` is staging-vs-prod parity — different trigger; `backend/common/integrations/robots-txt-and-source-selection` covers UA group matching for crawler policy (adjacent, not duplicate) → **new page**, related-linked both ways to robots-txt and to `testing-e2e-e2e-stability`.
- Insight 2: no backend/common page covers estimate-vs-actual anchoring (integrations pages cover externally-owned names and robots policy) → **new page** under the existing `integrations` category (the gap is between your request/estimate and the external system's confirmed outcome).
- Insight 3: `qa/process/scope-purity-checks` owns proving scope purity from `git status` — same territory, complementary directive (which *evidence source* per gate lifetime) → **merged** into that page (Do #4 table, edge-case row, instead-of row, Bazel source, related link). No conflict: the existing page's working-tree guidance remains correct for one-shot gates that own their tree.
- Insight 4: no existing page covers shallow-clone history semantics (`checks-that-cannot-pass` is unwritten-target gates; `harness-reverse-controls` is harness scoring) → **new page** `testing/quality/history-dependent-checks-on-shallow-clones`, related-linked both ways to scope-purity-checks and checks-that-cannot-pass.
- Domain indexes updated: qa (new environments row; scope-purity "load when" extended), testing (new quality row), backend (new integrations row). `log.md` ingest entry appended. Prohibition lint: 62/62 directives compliant, 0 violations.

## Open-PR check

Listed 26 open `knowledge/*` heads (#47–#92) via `gh pr list --search "head:knowledge/"`, fetched all heads, and diffed each against `origin/main -- wiki/` grepping for overlap terms (user-agent/headless/bot-detect, shallow/fetch-depth, slippage/stop-loss/take-profit/re-anchor/fill price, working-tree/git status/diff-filter/scope-purity). Hits were incidental only:
- #64 (choiyounggi-20260808-004155): "headless" in an AskUserQuestion-in-Docker citation; "working tree"/"git status" in orchestration liveness context — different insights.
- #61 (choiyounggi-20260807-213244): "re-anchor" refers to test-fixture literal anchors — different concept.
- #50/#51 heads: `git status` appears in worker-resume prompts and the harness-reverse-controls index line — different insights.

Verdict per candidate: **all 4 new** (no fold, no drop). No sibling PR carries any of these insights.

## Routing decision

| Insight | Target | Rationale |
|---------|--------|-----------|
| 1 headless UA bot-block | `qa/environments/headless-browser-bot-blocking` (new page, existing category) | Harvest hint qa; the failing dimension is the *test client environment* vs a real user's browser — environments category; exploratory/bug-reports rejected (it is a diagnosis-of-environment case, not a session-design or report-format case) |
| 2 SL/TP re-anchor | `backend/common/integrations/estimate-derived-thresholds` (new page, existing category) | Language-agnostic server-side concern; `integrations` already owns consuming external systems' responses — the insight is precisely the estimate/actual gap in an external system's confirmed outcome. No new category needed |
| 3 working-tree assertions | merge into `qa/process/scope-purity-checks` | Merge-before-create: same territory (proving scope purity), complementary directive; harvested "testing" hint re-routed to the page that owns the case (testing index already cross-points release-process → qa) |
| 4 shallow-clone history | `testing/quality/history-dependent-checks-on-shallow-clones` (new page, existing category) | The artifact being written is automated-check code — testing/quality alongside checks-that-cannot-pass/harness-reverse-controls; infrastructure rejected (the fix lives in the check and its workflow stanza, not in pipeline design) |

One PR, no auto-merge. Queue rows for all 4 candidates will be retired to `.processed.jsonl` after the PR opens.
