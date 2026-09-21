# Knowledge flush — 10 insight(s)

Claimed queue ids: `7c319808918cb315`, `f2d90d5048826870`, `fb7d73874bac6eaa`,
`5f3e5eb58ec373e4`, `6e83a02b449a8dff`, `7e13d1306fbf40c8`, `e44a20b606874813`,
`70fdb728c543e55f`, `1f52714ea33570c4`, `f4fc1622470f60bb`.
One is a session `★ Insight`; nine are plan-gap rows from
`skills/wiki-plan/scripts/emit-gaps.sh`. Result: **2 new pages** (3 rows
ingested), **4 rows dropped as pending duplicates of #207**, **3 rows dropped as
project-specific**.

## Verified best-practice

**`7c319808918cb315` — a write-time limit guard must let a shrinking write
through when the state is already over the limit.** Confidence: **verified**
(the mechanism — charge or reject only what a write adds — is implemented by
the sources below; the page's two-condition predicate is its statement of that
mechanism, and the Sources section marks rules 2–5 as field evidence).

| Claim | Source checked | How verified |
|-------|----------------|--------------|
| A production quota admission charges only the growth of an update and admits a non-growing one without a quota check | https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/apiserver/pkg/admission/plugin/resourcequota/controller.go | Raw file fetched with curl 2026-09-17 and read: `deltaUsage := quota.SubtractWithNonNegativeResult(inputUsage, prevUsage)`, then `quota.RemoveZeros`, then "if there is no remaining non-zero usage, short-circuit and return". Scope, found by the independent reviewer and now stated on the page: the delta applies per quota only when `evaluator.Matches` the previous object; an update that newly enters a quota's scope is charged in full |
| Lowering a limit below usage leaves existing state alone | https://kubernetes.io/docs/concepts/policy/resource-quotas/ | Raw markdown + live page grepped: "Neither contention nor changes to quota will affect already created resources." |
| Tolerate the pre-existing excess, deny only what the write makes worse | https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#validation-ratcheting | Raw markdown read: "…accept updates to resources that are not valid after the update, provided that each part of the resource that failed to validate was not changed… You cannot use this mechanism to update a valid resource so that it becomes invalid." |
| Same shape for violation counts | https://eslint.org/docs/latest/use/suppressions | Raw markdown + live page grepped: "While the rule will be enforced for new code, the existing violations will not be reported." |

The candidate's own evidence (bats cases starting from a 12000-byte over-budget
file in `groundwork`'s `habits-budget-guard.sh`) is recorded on the page as
field evidence. All seven cited URLs returned HTTP 200 on 2026-09-17 and each
quoted phrase was grepped out of the fetched body, not taken from a summary.

**`e44a20b606874813` (D1 fixed local-layer path) and `70fdb728c543e55f` (D5
local wins on the same trigger), t4-local-layer** — merged into one general
page about layering project-local guidance over a shared body. Confidence:
**field-tested**. The precedence directives are confirmed by the three tool
documents below, but the no-knob path rule, the delta rule and the env-var /
ignored-directory rows rest only on the t4-local-layer planning context (the
plan lives in a task worktree, not in this repository), and a page carries one
confidence value — so it takes the weaker one. The Sources section says which
rule rests on what.

| Claim | Source checked | How verified |
|-------|----------------|--------------|
| Closer/project layer overrides, broader layer stays loaded | https://developers.openai.com/codex/guides/agents-md | Page HTML fetched with curl, tags stripped, sentences read: "Codex concatenates files from the root down… Files closer to your current directory override earlier guidance because they appear later in the combined prompt." |
| Read shared first, local last; last value wins | https://git-scm.com/docs/git-config | Raw `git-config.adoc` + live page grepped: "The files are read in the order given above, with last value found taking precedence over values read earlier." |
| Same rule in a third independent tool | https://spec.editorconfig.org/ | Spec HTML fetched and read: "the pairs from the closer EditorConfig file are read last, so pairs in closer files take precedence." |

Correction made during verification: the candidates cited thenewstack.io, a
Karpathy gist and a hackernoon post. None was needed and none is cited; the
page rests on the three primary tool documents above.

**`f2d90d5048826870`, `fb7d73874bac6eaa`, `5f3e5eb58ec373e4`, `6e83a02b449a8dff`
(t3-status)** — nothing to verify again: identical hashes were verified and
ingested by #207 (see Open-PR check). The rows are a re-emit (`harvestedAt`
05:04Z; the 04:58Z copies are in `.processed.jsonl` as `ingested`).

**`7e13d1306fbf40c8` (t8-index module layout), `1f52714ea33570c4` (t4 D6 local
page schema/ids), `f4fc1622470f60bb` (t4 D8 routing test for wiki-ingest and
knowledge-flush)** — not best-practice claims. Each directive names this
repository's own files and steps (`scripts/wiki-index.py`, `wiki-mcp.py`,
`templates/page.md`, `wiki-structure-checks.js`, wiki-ingest step 3,
INGEST_REPORT section names). They are design rulings that land through their
own tasks (t8-index, t4-local-layer) in AGENTS.md and the skills; no external
source can confirm or refute them and no transferable trigger remains once the
repo names are removed beyond "keep one copy of shared code". **Dropped.**

## Existing-layer check

Routed via `INDEX.md` → infrastructure (ci-cd, config, agent-orchestration),
backend (common/llm, common/change-impact) and qa (process, document-verification).

Pages read: backend-common-change-impact-corpus-sweep-before-a-rejection-rule, infrastructure-ci-cd-changed-files-only-gates, backend-common-llm-binding-instructions-for-agents, backend-common-llm-progressive-disclosure-artifacts, infrastructure-config-environment-config, qa-process-release-gates, infrastructure-agent-orchestration-escape-hatch-uses-as-a-knowledge-gap-signal

- Quota guard: `grep -rliE "ratchet|quota|over budget|shrink|…" wiki/` → 14
  files, none about a write-time limit guard (hits are rate limiting, memory
  budgets, flex-shrink, clock monotonicity). `grep -rlE "PreToolUse|pre-commit|admission"`
  → 5 files, none on a deny predicate. Nearest neighbour
  corpus-sweep-before-a-rejection-rule covers *introducing* a rejection rule
  over an existing corpus, not the predicate of a limit guard over an
  over-limit state → **new page** `wiki/infrastructure/ci-cd/write-time-limit-guards.md`
  (87 lines), with a pointer to the neighbour in "When this applies".
- Local layer: `git grep -liE "knowledge base|shared (wiki|knowledge)|project-specific|AGENTS\.md|CLAUDE\.md" origin/main -- wiki/`
  → 8 files (5 without the `knowledge base` alternative); binding-instructions-for-agents (how to word a rule) and
  progressive-disclosure-artifacts (tiering one corpus) are adjacent, neither
  covers a second layer or precedence between layers → **new page**
  `wiki/backend/common/llm/project-local-layer-over-shared-guidance.md` (76 lines).
  Two rows (D1, D5) merged into it rather than two pages.
- No conflicting directive found in either area.
- Independent adversarial review (fresh-context agent, read-only) ran before
  the commit: 6 findings, all applied — Kubernetes claim scoped to quotas the
  previous object matched, violation-set row rewritten (a count misses a
  swapped violation), occurrence-count condition added to the replace-all
  approximation, local-layer page downgraded verified → field-tested, this
  report's grep count corrected.
- Related links added both ways: corpus-sweep-before-a-rejection-rule,
  changed-files-only-gates, session-completion-gates ↔ write-time-limit-guards;
  binding-instructions-for-agents, progressive-disclosure-artifacts,
  environment-config ↔ project-local-layer-over-shared-guidance.
- `wiki/infrastructure/index.md` ci-cd table +1 row; `wiki/backend/index.md`
  llm table +1 row; `log.md` +1 ingest entry.
- Checks after the edit: `node scripts/wiki-structure-checks.js wiki` →
  pages 280 / indexes 13 / findings 0; `node scripts/wiki-lint-prohibitions.js wiki`
  → directives 75, violations 0 (bats pin unchanged at 75);
  `bats tests/wiki-structure-checks.bats tests/wiki-lint-prohibitions.bats tests/wiki-lint-model-era.bats`
  → `1..34`, 0 `not ok`.

## Open-PR check

Open `knowledge/*` heads listed 2026-09-17: #207, #205, #191, #190, #189, #188,
#187, #186, #185, #183, #182, #181, #180, #179. For every head,
`git diff origin/main...origin/<head> -- wiki/` added lines were grepped for
the quota terms (`ratchet|quota|over budget|over limit|shrink|admission controller`)
and the layering terms (`project-local|local layer|closer file|nearest|last value|layered|AGENTS.override|shared knowledge`).
Hits were read one by one: #189 (benchmark delta "shrinks"), #188 (the word
"quotation"), #185 (OKLCH "shrinking ratios"), #181 (`flex-shrink`), #187
("nearest heading", "nearest attractor") — all unrelated. #207 is the only
real overlap, by exact queue hash.

| Candidate | Verdict |
|-----------|---------|
| `7c319808918cb315` (limit guard must admit shrinking writes) | new |
| `e44a20b606874813` (fixed local-layer path) | new |
| `70fdb728c543e55f` (local wins on the same trigger) | new (merged with the row above into one page) |
| `f2d90d5048826870` (log verb for supersede/retire) | drop — pending duplicate of #207, same hash, nothing new |
| `fb7d73874bac6eaa` (ingest third case) | drop — pending duplicate of #207 |
| `5f3e5eb58ec373e4` (status vs. confidence) | drop — pending duplicate of #207 |
| `6e83a02b449a8dff` (template optional status lines) | drop — pending duplicate of #207 |
| `7e13d1306fbf40c8` (t8-index module layout) | drop — project-specific (not a pending duplicate) |
| `1f52714ea33570c4` (local page schema/ids) | drop — project-specific (not a pending duplicate) |
| `f4fc1622470f60bb` (routing test in wiki-ingest/knowledge-flush) | drop — project-specific (not a pending duplicate) |

Note for the reviewer: the four t3-status rows were emitted twice (04:58Z and
05:04Z) and the second copies entered the queue although the same hashes are
in `.processed.jsonl`, so an already-processed hash can re-enter the queue. That is a harvester behaviour worth an issue; it is not
addressed in this PR.

## Routing decision

- `7c319808918cb315` → `infrastructure / ci-cd / write-time-limit-guards` (new
  page, existing category). The candidate's domain hint was infrastructure;
  ci-cd already owns the other "what does this gate actually decide" page
  (changed-files-only-gates). No new category needed.
- `e44a20b606874813` + `70fdb728c543e55f` → `backend / common/llm /
  project-local-layer-over-shared-guidance` (new page, existing category). The
  llm category is where the root index routes "authoring agent-facing
  artifacts"; infrastructure/config was considered and kept as a related link
  because its pages are about per-environment service settings.
- Seven rows → no page (4 pending duplicates of #207, 3 project-specific).
