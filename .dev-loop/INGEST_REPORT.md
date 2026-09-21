# Knowledge flush — 3 insight(s)

3 claimed candidates → 2 distinct insights: 1 new page, 1 merge into an existing page (2 duplicate candidates folded into it), 0 drops.

| Queue id | Insight | Outcome |
|----------|---------|---------|
| `8c0693fbeb1dca30` | Greedy regex merges adjacent tokens in extractor fixtures | New page `testing-data-adjacent-tokens-in-extractor-fixtures` |
| `fe22774ea41d523f` | Subagent 429 on a model-scoped (Fable) limit → per-invocation `model` override | Merged into `infrastructure-agent-orchestration-usage-limit-paused-workers` |
| `2f27db59be18d9c2` | Same insight as `fe22774ea41d523f`, from a second session | Duplicate within this batch; used as the second field observation on that merge |

## Verified best-practice

**1. Adjacent tokens in fixture text for a greedy pattern extractor** (`8c0693fbeb1dca30`) — `confidence: verified`

- Claim: a regex whose repeated character class admits separators (`\d[\d\s.\-()]{6,18}\d`) greedily merges two occurrences separated only by class-member characters into one span capped at the repeat's maximum, whose digits match neither original. So the test should assert the extractor's own spans first, and per-occurrence fixtures should use a separator outside the class.
- Sources checked:
  - https://docs.python.org/3/library/re.html — "The '*', '+', and '?' quantifiers are all greedy; they match as much text as possible"; `re.finditer` returns non-overlapping matches, scanned left-to-right.
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Quantifier — "Quantifiers are greedy by default … until the maximum is reached"; lazy `?` matches as few times as possible.
- How verified: reproduced with CPython `re` this session.
  - `"- 1900068889\n- 1900068889"` → one match `'1900068889\n- 1900068'` (20 chars = 1 + 18 + 1).
  - Pipe-separated → two clean matches.
  - Real-shaped footer `"090 123 4567 028 3822 1234"` → one merged match.
  - Also reproduced and added as edge cases:
    - Unbounded `+` merges both numbers (20 digits).
    - Lazy `{6,18}?` truncates `090 123 4567` to `090 123 4`, and pipe-separated `1900068889` to `19000688`.
- The session's field evidence (independent test-quality auditor caught it; pipe-delimiting fixed it) matches the reproduction.

**2. Subagent failing on a model-scoped limit → per-invocation model override** (`fe22774ea41d523f` + `2f27db59be18d9c2`) — mechanism `verified`; the Fable-specific 429 text is `field-tested`

- Claim: when a subagent call fails at once with `rate_limit`/HTTP 429 naming one model (`claude-fable-5-1`), re-issue the identical call with `model: "sonnet"`. The subagent definition's model is independent of the session's model, and the limit is scoped to that model.
- Sources checked:
  - https://code.claude.com/docs/en/sub-agents#choose-a-model (raw `.md` fetched). Resolution order: "1. The per-invocation `model` parameter 2. The subagent definition's `model` frontmatter 3. `CLAUDE_CODE_SUBAGENT_MODEL` 4. The main conversation's model". Before v2.1.251 the env var ranked first.
  - https://code.claude.com/docs/en/errors (raw `.md` fetched): "The session and weekly limits are shared across all models … The Opus and Sonnet limits each apply only to requests to that model family, so switching to a model outside the family with `/model` keeps you working". Also the `Fable limit reached · continuing on Fable 5.1 uses usage credits … nothing was sent` message for unattended sessions.
  - https://code.claude.com/docs/en/model-config#fable-and-usage-credits — Fable usage can bill to usage credits behind a consent prompt.
  - Local check: dev-loop 1.21.0 `agents/test-quality-auditor.md` and `agents/integration-reviewer.md` both declare `model: fable`. That explains why only the subagent failed while the session kept working.
- Honest gap: the docs do not print the exact `You've reached your Fable limit … model sent to the API` 429 text. That wording is cited only as a field observation (2 independent sessions on 2026-09-14, both of which succeeded after the override).
- The page stays `verified` because its directive rests on the documented resolution order and model-family scoping.

## Existing-layer check

Pages read: infrastructure-agent-orchestration-usage-limit-paused-workers, testing-quality-tests-that-cannot-fail, testing-data-test-data-and-isolation

Also read: `INDEX.md`, `wiki/testing/index.md` (every quality/data/strategy load-when line), and the `agent-orchestration` rows of `wiki/infrastructure/index.md`. I also grepped `wiki/` for `greedy|regex|finditer|adjacent`, `rate.?limit|429`, and `model override|subagent.*model|fable`.

- Insight 1: no existing page covers greedy-quantifier merging in test fixtures.
  - Grep hits were about regex *gates*, not extraction fixtures: `source-text-wiring-assertions`, `completion-predicates`, `checks-that-cannot-pass`.
  - → **created new**.
  - Related links added both ways with `testing-data-test-data-and-isolation` (fixture construction) and `testing-quality-tests-that-cannot-fail` (a test green for the wrong reason).
- Insight 2: `usage-limit-paused-workers` owns model-scoped limits and the `/model` switch → **merged**. Changes:
  - New step 7 (subagent per-invocation override).
  - 4 new edge-case rows: override rerun fails again; Fable consent in unattended sessions; `CLAUDE_CODE_SUBAGENT_MODEL` on CLI < v2.1.251; auditor model substitution + `availableModels`.
  - 1 new Instead-of row, and 2 new sources plus a field observation.
  - Index load-when extended.
- **Drift corrected (not a contradiction):** the page said only the *Opus* limit is model-scoped. The current errors doc also lists `You've hit your Sonnet limit`, scoped to the Sonnet family. I updated the marker row, the "only one worker stopped" edge row, and the Instead-of "Why" cell, and bumped `last_verified` to 2026-09-14.
- No conflicting directive found.

Lint results on this branch:

- `node scripts/wiki-structure-checks.js wiki` → `pages: 277, indexes: 13, findings: 0`.
- `wiki-lint-prohibitions.js` → 2 violations. Both predate this PR and sit outside `wiki/` (`plans/harvest-dedupe-processed/...`, `tests/fixtures/prohibitions/bad.md`). Neither changed page is flagged.
- `wiki-lint-model-era.js`:
  - `usage-limit-paused-workers` is reported as `model-coupled, no verified_model`. It was already flagged that way on `main`, since the page mentions Claude/Opus and no wiki page carries `verified_model`.
  - I tried `verified_model: claude-opus-5` (the model this flush ran on). The lint rejected it as "not in current set" because the script's `DEFAULT_CURRENT` is still `['opus-4', 'fable-5']`.
  - I left the field off to match every other page, rather than picking a value just to pass. Refreshing `DEFAULT_CURRENT` is a separate owner decision.

## Open-PR check

Listed open `knowledge/*` heads with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`: #190, #189, #188, #187, #186, #185, #183, #182, #181, #180, #179. For each, I diffed its own changes with `git diff origin/main...origin/<head> -- wiki/` and grepped the added lines for `greedy|finditer|adjacent|regex merge|model-scoped|Fable limit|subagent model|per-invocation`. No added lines matched.

- Insight 1 (`8c0693fbeb1dca30`) — verdict **new**.
  - No open head adds a regex/extractor-fixture page.
  - The closest is #187's `backend/common/integrations/contact-details-from-scraped-pages.md`, which covers *where* to read phone numbers (`tel:` links, header/footer vs main content), not how a regex tokenizes adjacent numbers. That's a different trigger, so no overlap.
- Insights 2/3 (`fe22774ea41d523f`, `2f27db59be18d9c2`) — verdict **new** (merge into the main-branch page).
  - #180 touches `usage-limit-paused-workers.md`, but only its `related:` line (it adds `login-expiry-during-unattended-turns`). No content overlap.
  - This PR leaves that `related:` line unchanged, so the two PRs should not conflict on that line.
  - `2f27db59be18d9c2` duplicates `fe22774ea41d523f` within this batch, so it is folded into the same merge rather than dropped.
- Merge-order note: #188, #181, and #179 also edit `testing/data/test-data-and-isolation.md`, and #188/#183 edit `tests-that-cannot-fail.md`. This PR only appends one id to each page's `related:` list, so any conflict is a one-line `related:` union.

## Routing decision

- Insight 1 → `testing` / `data` / new page `wiki/testing/data/adjacent-tokens-in-extractor-fixtures.md`.
  - The lesson is about *constructing fixture input* so each synthetic occurrence stays a distinct token. That is the `data` category ("tests need fixture data and you are choosing how to create it").
  - `quality` was the runner-up (a test that passes for the wrong reason). It is linked through `related:` instead, because the directive acts on the fixture, not the assertion strategy.
  - No new category needed.
- Insights 2/3 → `infrastructure` / `agent-orchestration` / existing page `wiki/infrastructure/agent-orchestration/usage-limit-paused-workers.md`.
  - That page already owns "which usage limit was hit decides the move", and a subagent is an orchestrated worker billed to the same seat.
  - `platforms/processes` was rejected: the fix is a model-routing decision inside the orchestrator, not an OS/CLI invocation difference.
  - No new category needed.
