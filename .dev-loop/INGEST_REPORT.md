# Knowledge flush — 12 insight(s)

Flush run `20260903-213946-4161` (headless auto-flush, lock re-entered under the parent hook's run id). Queue rows are keyed by `hash`. Outcome: 4 new pages, 3 merges into existing pages, 4 folds pushed to open knowledge PRs, 1 dropped as a pending duplicate.

## Verified best-practice

Every external quote below was re-checked against the raw page with `curl -sL … | grep` on 2026-09-03 (not only through a summarizing fetch), except where noted.

1. **520214f2e52d14c4 — sequential artifact numbers across parallel workers** → `confidence: verified`. Claim: the coordinator assigns RFC/ADR/migration numbers at dispatch; a worker's branch point cannot see a sibling's unmerged number and distinct filenames merge without conflict, so the uniqueness lint runs on the merged tree. Sources: Django migrations topic ("two migrations with the same number"), Django `makemigrations --merge` ("Enables fixing of migration conflicts"), Rails 3.2 migrations guide (creation-time timestamps to avoid clashes), git-merge ("incorporated in the final result verbatim"), adr-tools issue #102 (two devs both denote ADR 6). Field evidence: linkly t112/t119 both created RFC-0034.
2. **3fb0fd84e5ec5aa4 — inbound validation ownership when a plan splits a process boundary across tasks** → `confidence: verified`. Source: OWASP Input Validation Cheat Sheet ("as early as possible in the data flow, preferably as soon as the data is received from the external party"). Field evidence: agent-crew M2 `handle_envelope` missing `validate()` caught only by integration review.
3. **e5bc5ce7cb8508b4 — vendor benchmark claims for a memory/RAG tool** → `confidence: verified`. Sources: LoCoMo paper (arXiv 2402.17753), Zheng et al. LLM-as-a-judge (arXiv 2306.05685, "over 80% agreement"), Zep blog disputing Mem0's LoCoMo SOTA claim, Mem0's counter-reply (getzep/zep-papers#5, "58.44%"), OpenViking `stat_judge_result.py` (QA and Import token usage counted separately) and `judge.py` ("be generous with your grading"). The candidate's `judge.py:239` line reference no longer matches the 203-line file; the leniency instruction itself is confirmed and the page says so.
4. **b5e0cd6b60242fb6 — element crop screenshots (`clip` from `boundingBox()`)** → `confidence: field-tested`. Playwright semantics verified (element screenshot via `locator.screenshot()`, `clip` option, `boundingBox()` is viewport-relative and scroll-dependent); the Aside CLI clip misbehaviour itself is single-session field evidence, not reproduced here (no browser run). Directive generalised to: element-screenshot primitive first, read back the first crop before a batch, fall back to full-page capture on a persistent wrong-region clip.
5. **a019efb64f7bf316 — WebFetch summary vs raw page** → `confidence: verified`. Source: Claude Code tools reference ("runs the prompt against the content using a small, fast model. For most fetches, Claude receives that model's answer, not the raw page"; "use curl via Bash for the unprocessed page"). Field evidence re-confirmed: the tmap-skopenapi `routeSequential30` page contains the exact string "경유지는 최대 30개까지 설정할 수 있습니다." in the raw response.
6. **c2665906bb4df3a9 — Steps-prose resilience guarantee needs its own test** → `confidence: verified` (merged into an already-verified page). Source: SWE book ch12 ("A behavior is any guarantee that a system makes…"). Field evidence: wt-t4-event-push task 03 auditor FAIL→PASS after one added test.
7. **ee33bdf217330afe — split a CI fact-checker's "fabricated" verdict** → `confidence: verified` for the evidence (dev-loop PR #164 is public and merged; commit `f5d2395` message confirmed via `gh api`), directive itself field-tested; merged into a `field-tested` page.
8. **e040b9a62688a56e — Depends-on table vs Steps prose** → fold (see Open-PR check); field evidence only, no new external source claimed.
9. **a3560e8f5bd8f249 — brief workers to write measured counts** → fold; field evidence only (linkly t119 vs t112/t115/t117).
10. **0fa9c12c34ec038c — doc-currency gates inside the doc task** → fold; field evidence only (linkly enf0829, 10 integration failures).
11. **4977fec4fae1c1db — route worker edits through Bash when the guard is Bash-only** → fold; field evidence only. The claim that Edit/Write ignore cwd could not be confirmed in the Claude Code docs (only the Read tool section says "always pass absolute paths"), so the inserted row relies on the page's existing verified evidence that Edit/Write bypass a Bash-matched hook and does not state the cwd claim.
12. **a2023caa7c6da204 — multi-name `command -v`** → dropped, pending duplicate: PR #181's `path-resolution.md` already carries this exact edge case, instead-of row, POSIX synopsis source and the same local reproduction.

## Existing-layer check

Pages read: platforms-environment-path-resolution, security-input-validation-at-trust-boundaries, qa-document-verification-spec-document-gates, qa-deliverables-quantitative-claims-in-a-published-document, infrastructure-agent-orchestration-worktree-isolated-workers, qa-process-completion-claims, platforms-tools-harness-mediated-tool-results, testing-quality-minimum-case-set, qa-process-evaluating-review-feedback, qa-process-llm-review-pipelines, qa-document-verification-generated-reference-drift-gates, backend-common-llm-context-window-budget, qa-process-adversarial-change-review, qa-bug-reports-reproducible-reports, qa-environments-browser-console-capture-gaps

Also read on open-PR heads (not on this checkout): checkable-claims-in-an-adopted-plan, sibling-validators-on-a-shared-node (#181); semantic-conflicts-after-parallel-merge, verify-command-in-a-worker-brief (#179); ours-resolution-on-a-mixed-content-conflict, forward-references-in-a-numbered-protocol (#180).

- **Merged (3):** WebFetch-summary case → `harness-mediated-tool-results` (new when-this-applies sentence, edge-case row, instead-of row, source, field context; index cell widened). Steps-prose guarantee → `minimum-case-set` (edge-case row, instead-of row, SWE-book quote + field evidence; index cell widened). Split verdict → `evaluating-review-feedback` (edge-case row, instead-of row, PR #164 source; index cell widened). None of these three pages is touched by an open knowledge PR.
- **Created (4):** `infrastructure/agent-orchestration/sequential-identifiers-across-parallel-workers`, `infrastructure/agent-orchestration/inbound-validation-ownership-in-task-decomposition`, `backend/common/llm/vendor-benchmark-claims-for-an-llm-tool`, `qa/environments/element-crop-screenshots`. Each has an index row and a log line.
- **Conflicts flagged:** none. The inbound-validation page agrees with `security-input-validation-at-trust-boundaries` ("validate at the consumer boundary anyway") and adds the task-decomposition angle.
- **Related links:** new pages link to existing ones; back-links added on `qa-process-adversarial-change-review`, `backend-common-llm-context-window-budget`, `qa-process-llm-review-pipelines`, `qa-environments-browser-console-capture-gaps`, `qa-bug-reports-reproducible-reports`. Back-links deliberately NOT added on `worktree-isolated-workers`, `shared-run-state`, `spec-document-gates`, `validation-at-trust-boundaries`, `quantitative-claims-in-a-published-document`, `completion-claims`: their `related:`/frontmatter lines are rewritten by PR #179/#180/#181 and a second edit would conflict at merge. Owner may add them after those PRs land.
- Lint on this branch: `wiki-structure-checks` 279 pages / 0 findings, `wiki-lint-prohibitions` 0 violations, all touched pages ≤ 120 body lines.

## Open-PR check

Open `knowledge/*` heads listed via `gh pr list --search "head:knowledge/"`: #179 `knowledge/choiyounggi-20260903-172728`, #180 `knowledge/choiyounggi-20260903-184706`, #181 `knowledge/choiyounggi-20260903-203836`. Each was fetched and diffed against `origin/main -- wiki/`.

| Candidate | Overlapping open head | Verdict |
|-----------|-----------------------|---------|
| a2023caa7c6da204 multi-name `command -v` | #181 `path-resolution.md` (identical edge case + reproduction) | **drop** (pending duplicate) |
| e040b9a62688a56e Depends-on table vs Steps prose | #181 `checkable-claims-in-an-adopted-plan.md` (same trigger: checking an adopted plan) | **fold** → pushed as `4bc6de8` on #181 + PR comment |
| a3560e8f5bd8f249 workers write measured counts | #180 `ours-resolution-on-a-mixed-content-conflict.md` (merge-time count reconciliation) | **fold** → pushed as `3b78273` on #180 + PR comment |
| 0fa9c12c34ec038c doc-currency gates in the doc task | #179 `verify-command-in-a-worker-brief.md` (what the brief's verify line names) | **fold** → pushed as `e242b2c` on #179 + PR comment |
| 4977fec4fae1c1db Bash-routed edits under a Bash-only guard | #179 `worktree-isolated-workers.md` (Edit/Write bypass + matcher widening) | **fold** → same commit `e242b2c` on #179 |
| 520214f2e52d14c4 sequential numbers | #179 `semantic-conflicts-after-parallel-merge.md` (enum/match semantic conflicts), #180 `ours-resolution` (count conflicts) — adjacent, different trigger (distinct new files, no conflict at all) | **new** |
| 3fb0fd84e5ec5aa4 inbound validation ownership | #181 `validation-at-trust-boundaries.md` edit (spatial-value clamping) — different trigger | **new** (separate page; no edit to the security page to avoid conflicting with #181) |
| e5bc5ce7cb8508b4 vendor benchmark claims | #181 `synthetic-corpus-measurement-floor.md` (measuring on your own corpus) — different trigger | **new** |
| b5e0cd6b60242fb6 element crop screenshots | none | **new** |
| a019efb64f7bf316 WebFetch summary | #181 touched `quantitative-claims-in-a-published-document.md` related line only | **new** (merged into `harness-mediated-tool-results`, untouched by open PRs) |
| c2665906bb4df3a9 Steps-prose guarantee | none (`minimum-case-set.md` untouched) | **new** (merge) |
| ee33bdf217330afe split verdict | #179 touched `completion-claims.md`, not `evaluating-review-feedback.md` | **new** (merge) |

Lint (`wiki-structure-checks`, `wiki-lint-prohibitions`) was run on each fold branch after the edit: 0 findings, 0 violations; fold pages remain ≤ 120 body lines (83/55/73/93 for #181/#180/#179 verify/#179 worktree).

## Routing decision

| Insight | Target |
|---------|--------|
| 520214f2 sequential numbers | `infrastructure/agent-orchestration/sequential-identifiers-across-parallel-workers` — NEW page; agent-orchestration already owns worker briefs and shared run state |
| 3fb0fd84 inbound validation ownership | `infrastructure/agent-orchestration/inbound-validation-ownership-in-task-decomposition` — NEW page; the lesson is about which task's brief carries the decision, so orchestration rather than security (linked to the security page) |
| e5bc5ce7 vendor benchmark claims | `backend/common/llm/vendor-benchmark-claims-for-an-llm-tool` — NEW page; backend/common/llm owns consuming LLM tooling; no new category needed |
| b5e0cd6b element crop screenshots | `qa/environments/element-crop-screenshots` — NEW page; qa/environments already holds browser-tooling gaps (console capture, bot blocking) |
| a019efb6 WebFetch summary | merged into `platforms/tools/harness-mediated-tool-results` — same class (a tool result mediated before the agent sees it) |
| c2665906 Steps-prose guarantee | merged into `testing/quality/minimum-case-set` — it is a "which cases are required" rule |
| ee33bdf2 split verdict | merged into `qa/process/evaluating-review-feedback` — it is a response-to-review-finding rule |
| e040b9a6 / a3560e8f / 0fa9c12c / 4977fec4 | folded into PR #181 / #180 / #179 / #179 pages respectively (see Open-PR check) |
| a2023caa multi-name `command -v` | dropped — already on #181 `platforms/environment/path-resolution` |

No new category was added; every insight fit an existing domain/category.
