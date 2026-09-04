# Knowledge flush — 12 insight(s)

Run `20260903-203800-24176` (auto-flush parent lock reused), branch `knowledge/choiyounggi-20260903-203836`, base `origin/main` @ 484dd9d. Claimed 12 queue rows (`queue-claim.js claim --max 12`): 10 ingested on this branch (6 new pages, 4 merges), 2 folded into open PRs. Lint on the checkout: `wiki-structure-checks.js wiki` → 0 findings; `wiki-lint-prohibitions.js` → 0 violations; every touched page ≤ 120 body lines.

## Verified best-practice

| # | Queue hash | Claim | Sources checked | How verified | Confidence |
|---|-----------|-------|-----------------|--------------|------------|
| 1 | e76b481f | "Drag and drop" copy on a styled dropzone is honest only when `dragover`+`drop` handlers with `preventDefault()` exist; an unhandled drop makes the browser open the file | https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API/File_drag_and_drop | Quoted MDN: "the browser may process them by default (such as opening or downloading the file) even when the file is not dropped into a valid drop target"; drop fires only when dragover is cancelled | verified |
| 2 | e1c0754b | Per-shape `destination-in` chains intersections; draw mask shapes `source-over` on an offscreen canvas and apply once | https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/globalCompositeOperation | MDN definition: content kept "where both the new shape and existing canvas content overlap. Everything else is made transparent" — repeated application is an intersection chain | verified |
| 3 | f9c05d73 (two identical queue rows) | A media query that overrides `position` must also reset the inset properties; an SDK inline `position:relative` beats the author `static` and reactivates a dormant `top` | https://developer.mozilla.org/en-US/docs/Web/CSS/position ; https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_cascade/Specificity | MDN: `static` → "top, right, bottom, left, and z-index properties have no effect"; inline styles "always overwrite any normal styles in author stylesheets"; production repro 217px→22px | verified |
| 4 | 1ba282d0 | Clamp persisted position/scale to domain bounds on the server; shape validation alone lets `x=-9999`/`scale=0.01` through | https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html ; https://zod.dev/api | OWASP syntactic vs semantic validation + range checks; zod `.min()/.max()` reject only, no clamp | verified |
| 5 | 3080d06a | Save-and-restore (or `patch.dict`/`monkeypatch`) instead of `pop` in tearDown; local green with a fallback path is not proof of no pollution | https://docs.python.org/3/library/unittest.mock.html ; https://docs.pytest.org/en/stable/how-to/monkeypatch.html | `patch.dict` "restore the dictionary to its original state after the test"; monkeypatch "All modifications will be undone" | verified (mechanism) / field-tested (fallback masking, 122 failures) |
| 6 | a85300017 | A fixed-pool generator forces repeats ≥ N − k by pigeonhole; ask whether the number would move with X absent, publish pool parameters | https://en.wikipedia.org/wiki/Pigeonhole_principle ; https://en.wikipedia.org/wiki/Scientific_control (general references) | In-memory python3 reproduction: k=10, N=30 → repeats 21 ≥ 20; N=50 → 40 = floor; matches the reported values exactly | verified (reproducible computation) |
| 7 | d9e98911 | Recompute a plan's derived numbers from its own inputs, check the symbol contract and deliverable reachability (`git check-ignore -v`), escalate discrepancies | https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html ; https://git-scm.com/docs/git-check-ignore | WCAG luminance/contrast formulas quoted; `check-ignore -v` semantics quoted; four in-session defects confirmed by the plan owner | verified (method) / field-tested (defects) |
| 8 | 142c89b3 | Run a mass-failing gate against already-merged, shipped code; uniform failure there proves the gate is the defect | Own reproducible check: `test-floor.sh` vs linkly 305f8e2 (PR #81) → exit 3 | Folded into PR #180's page (see Open-PR check) | verified |
| 9 | c5d4ba2e | Multi-name `command -v a b c` is OR in bash/macOS sh (exit 0 if any resolves), exit 1 in zsh; loop per name | https://pubs.opengroup.org/onlinepubs/9699919799/utilities/command.html ; `bash -c 'help command'` | Reproduced this session: bash 5.3 / `/bin/sh` rc 0, zsh 5.9 rc 1 for `command -v ls definitely_missing_xyz`; POSIX synopsis has one `command_name` | verified |
| 10 | e8b72499 | Key alert suppression on the rendered message text, re-send daily, suppress the notification not the retry | https://prometheus.io/docs/alerting/latest/configuration/ ; https://sre.google/sre-book/monitoring-distributed-systems/ ; https://developer.pagerduty.com/docs/events-api-v2/trigger-events/index.html | Sources establish stable-key + re-send window and caller-chosen dedup strings; none prescribes text keying itself, so the page stays field-tested (151→1 send in production) | field-tested |
| 11 | 3e979f78 | Attribute a dirty main checkout to a live worker by mtime, stop it first, transfer by patch, verify, then discard | https://git-scm.com/docs/git-worktree ; https://git-scm.com/docs/git-apply | Folded into PR #179's page (see Open-PR check); git mechanics verified, mtime heuristic field-tested | verified / field-tested |
| 12 | 68257e11 | Widening one check on a node: enumerate the other static checks on the same node/verb; admit the new case at one call site | No external source found (compiler texts describe multi-pass semantic checks without naming this practice) | linkly `_check_aggregate` widened while `_Scope._dimension_of` still rejected; scoped `allow_money` fix with the original regression test unchanged | field-tested |

No URL was invented; every source above was opened and quoted.

## Existing-layer check

Pages read: backend-common-change-impact-widening-a-closed-value-table, backend-common-change-impact-call-site-enumeration, backend-common-errors-diagnostics-from-a-shared-code-path, backend-common-errors-exception-handling, security-input-validation-at-trust-boundaries, frontend-forms-validation-timing, frontend-accessibility-interactive-elements, frontend-design-html-in-canvas, frontend-design-responsive-layout, frontend-rendering-long-lists, frontend-rendering-rerender-and-memoization, testing-data-test-data-and-isolation, testing-flaky-diagnosing-flaky-tests, testing-quality-harness-reverse-controls, qa-deliverables-quantitative-claims-in-a-published-document, qa-document-verification-spec-document-gates, infrastructure-agent-orchestration-autonomous-decision-rulings, infrastructure-agent-orchestration-unattended-worker-questions, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-observability-alerting, infrastructure-observability-suppression-state-and-delivery-failure, platforms-shells-portable-shell-scripts, platforms-environment-path-resolution

Also read: `INDEX.md`, `AGENTS.md`, `templates/page.md`, and the domain indexes for backend, backend/python, frontend, security, infrastructure, platforms, testing, qa, debugging.

| # | Overlap found | Action | Related links |
|---|---------------|--------|---------------|
| 1 | None — forms/accessibility pages never mention drop targets | New page `frontend/forms/dropzone-copy-without-drop-handlers` | ↔ interactive-elements, validation-timing |
| 2 | None — html-in-canvas is a different technique; rendering/ is React perf | New page `frontend/design/multi-shape-canvas-mask` (design owns canvas mechanics) | ↔ html-in-canvas |
| 3 | responsive-layout has no `position`/inset guidance; same trigger family | Merged: edge-case row, Instead-of row, 2 sources, field repro; index load-when extended | — |
| 4 | validation-at-trust-boundaries already says "range" generically | Merged: edge-case row (domain-rule range, clamp vs reject at the write), Instead-of row, OWASP quote + zod source; index load-when extended | — |
| 5 | test-data-and-isolation has the generic "restore in teardown" row | Merged: Do-row (assignment vs `patch.dict`/monkeypatch), edge case (fallback-masked green), Instead-of (`pop`), 2 doc sources + incident. Rows placed mid-table to stay clear of PR #179's appended hunks | — |
| 6 | harness-reverse-controls covers verification harnesses; quantitative-claims covers repo counts — different artifact (a measurement generator) | New page `testing/quality/synthetic-corpus-measurement-floor` | ↔ harness-reverse-controls, quantitative-claims; → stale-artifact-baselines |
| 7 | spec-document-gates has the recompute axis for authored gates; autonomous-decision-rulings / unattended-worker-questions give the escalation channel but not the pre-build verification | New page `infrastructure/agent-orchestration/checkable-claims-in-an-adopted-plan` | ↔ quantitative-claims, spec-document-gates (back-links added there only; the two orchestration pages' `related:` lines are edited by open PRs, so links there are one-directional) |
| 8 | Same incident as PR #180's `assertion-scanner-false-positive-on-unittest-convention`; harness-reverse-controls covers synthetic controls | Fold (PR #180) | ↔ harness-reverse-controls added on that branch |
| 9 | portable-shell-scripts is the shell-semantics home but PR #180 adds ~14 lines to it (would exceed 120 combined); path-resolution owns "how a script locates its correctness-critical tools" and has room | Merged into path-resolution: edge-case row, Instead-of row, 3 sources | — (its `related:` and index line are touched by PR #179) |
| 10 | alerting = what pages; suppression-state = where the mark is written; exception-handling = in-process log-once. None chooses the key | New page `infrastructure/observability/suppression-key-for-a-recurring-failure` | ↔ alerting, suppression-state |
| 11 | PR #179 already adds the detection + patch-transfer recovery row to worktree-isolated-workers | Fold (PR #179) | — |
| 12 | widening-a-closed-value-table's mechanism is inlined table copies; its Do-steps (value grep) cannot find a second validator function | New page `backend/common/change-impact/sibling-validators-on-a-shared-node` | ↔ call-site-enumeration, diagnostics-from-a-shared-code-path; → widening (one-directional: its `related:` is edited by PR #179) |

Conflicts flagged: none — no merged row contradicts an existing directive. Conflict-avoidance with open PRs: rows and sources were inserted mid-table/mid-list in files those PRs also touch (test-data-and-isolation, path-resolution, testing/infrastructure indexes), and `last_verified` bumps use the same date PR #179 writes.

## Open-PR check

Open `knowledge/*` heads listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`:

- #180 `knowledge/choiyounggi-20260903-184706` — fetched; `git diff origin/main origin/<head> -- wiki/` read in full (21 files).
- #179 `knowledge/choiyounggi-20260903-172728` — fetched; diff read in full (36 files).

| # | Overlapping head | Verdict | Detail |
|---|------------------|---------|--------|
| 8 (142c89b3) | #180 `testing/quality/assertion-scanner-false-positive-on-unittest-convention.md` | **fold** | Pushed 75b0354 to that branch: Do-step 4 (run the checker against a shipped commit), Instead-of row, related link, field reproduction (305f8e2). PR comment posted. |
| 11 (3e979f78) | #179 `infrastructure/agent-orchestration/worktree-isolated-workers.md` (escalation → patch-transfer row) | **fold** | Pushed 84eefc9 to that branch: stop-worker-first + mtime attribution appended to the recovery row, new edge-case row for the post-merge symptom, linkly t112 evidence. PR comment posted. |
| 9 (c5d4ba2e) | #180 touches `portable-shell-scripts.md` (jq membership, zsh word-split) — different content | **new** (routed to path-resolution to keep the merged page under 120 lines) | |
| 5 (3080d06a) | #179 touches `test-data-and-isolation.md` (bats cwd row) — different content | **new** (merged mid-table) | |
| 12 (68257e11) | #179 touches `widening-a-closed-value-table.md` `related:` only | **new** | |
| 1, 2, 3, 4, 6, 7, 10 | no open head touches these pages or topics | **new** | |

No sibling duplicate PR was opened; both folds live on the existing PR branches.

## Routing decision

| # | Target | Page | New category? |
|---|--------|------|---------------|
| 1 | frontend / forms | `dropzone-copy-without-drop-handlers` (new) | no |
| 2 | frontend / design | `multi-shape-canvas-mask` (new; `rendering/` is React re-render/list perf, `design/` already holds html-in-canvas) | no |
| 3 | frontend / design | `responsive-layout` (merge) | no |
| 4 | security / input | `validation-at-trust-boundaries` (merge) | no |
| 5 | testing / data | `test-data-and-isolation` (merge) | no |
| 6 | testing / quality | `synthetic-corpus-measurement-floor` (new) | no |
| 7 | infrastructure / agent-orchestration | `checkable-claims-in-an-adopted-plan` (new; the adopter is a worker in an orchestrated run, the recompute technique is linked from qa/document-verification rather than duplicated) | no |
| 8 | testing / quality | fold into PR #180 page | no |
| 9 | platforms / environment | `path-resolution` (merge) | no |
| 10 | infrastructure / observability | `suppression-key-for-a-recurring-failure` (new) | no |
| 11 | infrastructure / agent-orchestration | fold into PR #179 page | no |
| 12 | backend / common / change-impact | `sibling-validators-on-a-shared-node` (new) | no |

Every existing category covered its candidate; no new category was needed. Indexes updated: frontend, security, testing, infrastructure, backend. `log.md` has the ingest entry.

Queue retirement: all 12 claimed rows (10 ingested + 2 folded) retired to `.processed.jsonl`; the duplicate f9c05d73 row in a second session file retired with its twin.
