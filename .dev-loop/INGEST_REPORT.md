# Knowledge flush — 1 insight (1 page amended, 6 plan-gaps retired as local-layer)

## Verified best-practice

**Insight 8b25925e37a8a29f — comparing CSS colors read through `getComputedStyle`** (frontend).
Claim: canonicalize each color through a canvas pixel (`fillStyle` → `getImageData`), compare delimited tuples like `[r,g,b,a]`, and freeze transitions before re-reading after a style swap.

- Canvas canonicalization and the transition freeze: already on main in `frontend-design-theme-swap-propagation-check` (merged in #251). That page cites MDN `getComputedStyle` (https://developer.mozilla.org/en-US/docs/Web/API/Window/getComputedStyle): an animating property returns its value at the current point of the animation, and sRGB colors at full opacity serialize as `rgb()` while other color spaces keep their own function. Nothing new to verify here.
- The new part is the delimiter. Reproduced in node with `String.prototype.includes`:
  - `#171717` → `23,23,23,255`; `#7b1717` → `123,23,23,255`
  - undelimited `"123,23,23,255".includes("23,23,23,255")` → `true` (false match)
  - bracketed `"[123,23,23,255]".includes("[23,23,23,255]")` → `false`
  - bracketed tuple inside a multi-color `box-shadow` value → still found (`true`)
  - This matches the session evidence: before the brackets, the real-project run reported `#7b1717` as an `#171717` copy (2 stuck instead of 1).
- Confidence: unchanged at `field-tested` for the page. The delimiter rule itself is a deterministic string fact, shown by the reproduction above.

## Existing-layer check

Pages read: frontend-design-theme-swap-propagation-check

- Also read `wiki/frontend/index.md` (domain index, no page id). Repo-wide grep for `oklch|getComputedStyle|getImageData|transition:none` found 7 pages. Only `theme-swap-propagation-check` covers comparing computed colors. The others mention oklch for design or token-reading reasons, not for comparison.
- Overlap: the candidate's directive and two of its three mechanisms (canvas compare, transition freeze) are already on the page: script lines 52–58 and 85–87, plus the oklch edge-case row. The script already brackets tuples (`'[' + … + ']'`), but the page never said why. A future edit could "simplify" the brackets away and bring back the false match.
- Merged, not created: I extended the existing `oklch()` edge-case row with the delimiter reason. I did not add a new row, because the body was already at the 120-line limit and is still at 120 after the edit. I extended the index "load when" line to cover the delimiter case. No conflicts found. No new `related:` links needed, since the page already links the lint-gate page and the custom-property page.
- `scripts/wiki-lint-prohibitions.js wiki/` → rc 0, no finding on the changed page.

## Open-PR check

Open `knowledge/*` heads listed: #249, #244, #241, #239, #238, #237, #236, #235, #234, #233, #231, #230, #229, #228, #227, #226, #225, #223.

- Ran `git diff origin/main...origin/<head> -- wiki/` for each head. No head changes `theme-swap-propagation-check.md`, `custom-property-values-read-from-script.md` or `frontend/index.md`. The only `frontend/design` file in flight is #225's `scrubbed-scroll-animations-under-reduced-motion.md`, which is about scroll animation, not color comparison.
- The keyword matches in #230/#233/#241/#234/#228/#226 are unrelated: they hit "delimiter" in heredoc, NUL-record and GITHUB_OUTPUT contexts.
- Verdict for 8b25925e37a8a29f: **new** (amend the merged page; no open PR carries it).
- Verdict for the 6 plan-gap rows: **drop** (project-specific, see Local-layer candidates).

## Routing decision

- 8b25925e37a8a29f → `frontend/design/theme-swap-propagation-check.md`, Edge cases table, existing `oklch()` row extended. The page already lives in the right category, so no new category is needed.

## Local-layer candidates

These 6 plan-gap rows come from `linkly-seaslug` (the orchestration run `oi1002`, task `tmain`, a merge-conflict resolution plan). Each directive names that repository's own files, RFC numbers or mutation anchors, and would be wrong in another codebase. They are excluded from this PR. Run wiki-ingest inside that project if any are worth keeping:

- a627eeaa296bfccb — `impl/lnpl/drivers.py` exception-class hunk order → wiki-local/backend/errors/linkly-driver-exception-order.md
- 878a08c04289fd74 — `impl/lnpl/testing.py` import-union hunk → wiki-local/backend/structure/linkly-testing-imports.md
- 407dbee55ced307c — `impl/tests/test_mcp_server.py` contract-slots test hunk → wiki-local/testing/structure/linkly-mcp-contract-slots-test.md
- 13fe064f59c95d80 — RFC 0053 → 0061 renumbering sweep → wiki-local/platforms/process/linkly-rfc-renumber-on-merge.md
- d25853f0edf25c8f — mutation-anchor preservation grep after conflict resolution → wiki-local/testing/mutation/linkly-mutation-anchor-preservation.md
- 8b1a4455b376b724 — commit timing (stage, do not commit before coordinator approval) → wiki-local/platforms/process/linkly-merge-commit-timing.md
