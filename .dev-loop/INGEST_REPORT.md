# Knowledge flush — 1 insight(s)

Run `20261029-104612-27366` claimed 11 queue rows: 1 ingested, 2 released as pending duplicates of open PRs, 8 dropped as project-specific plan-gaps.

## Verified best-practice

**43c8d7d514f0714f — a plan that cites rulings from a ledger still being appended to (ingested)**
- Claim: a worker adopting a coordinator plan that cites rulings by id ("C1–C17") must, before signalling plan-ready, list the ledger's ruling ids past the highest one the plan cites and check each against the source line ranges its task copies. The plan's own review only covered rulings that existed when it was written. A ledger modified after the plan is the cue to look; the id comparison is the check.
- Sources checked:
  - https://www.gnu.org/software/make/manual/html_node/Rule-Syntax.html — make treats a target as out of date when it is missing or older than any prerequisite, by modification time. This is the general staleness rule for a derived artifact (here, the plan derived from the ledger). Confirmed through a web search that cited this page; WebFetch was not available in this headless run.
  - Field evidence from the originating session (2026-10-28, worker t1 of an RFC-consolidation run): the rulings file was modified at 16:49:10 and the plan at 16:48:08. The file held C18–C20, which the plan did not cite. C18(2) named rfcs/0016:173, outside t1's range 0016:90–112, so the plan stood.
- Change from the candidate: the candidate made mtime the check. The ingested row makes the ruling-id comparison the check and mtime only the cue. mtime says something changed, not whether the change reaches this task.
- Confidence: **field-tested** (an external source backs the staleness principle; the orchestration-specific rule comes from production experience).

**8a67a97c4afd204c — `grep -q` cuts off vitest's temp-dir cleanup through SIGPIPE (not researched; released)** — released as a pending duplicate before research; see Open-PR check.

**f332524447ff2105 — a gate's repo-wide grep matches its own ledger, and an interactive grep function hides that (not researched; released)** — released as a pending duplicate before research; see Open-PR check.

**8 plan-gap rows (28ffd102c9e362bb, 430224787b03f1d4, b894ed5a8e75847c, d65d6c011f44a782, 22f51684c7ffecf9, 37f2edba42fa6ed4, d149591071a43dde, a79848426e6a748e)** — design decisions for one linkly task: how RFC-0067 is assembled from named RFC line ranges, its title and Status block, re-pointing references, and finding records. Each directive names that repository's own files, RFC numbers and rulings. Not general, so not researched.

## Existing-layer check

Pages read: infrastructure-agent-orchestration-autonomous-decision-rulings, infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan, infrastructure-agent-orchestration-worker-reported-plan-contradiction

Also read: `wiki/infrastructure/index.md`, plus a wiki_search run ("worker adopts coordinator plan but rulings or decisions file changed after the plan was written"). Its top hits were the three pages above, plus backend-common-change-impact-aggregation-layer-of-a-shared-helper (about stale line numbers in a plan, not rulings) and testing-quality-cross-task-stub-assertions (not related).

- No page covers rulings added to the run ledger after a plan was written.
- checkable-claims-in-an-adopted-plan covers recomputing the plan's own claims. Its body is already over the 120-line budget, so no row was added there.
- autonomous-decision-rulings owns the `Ruling:` ledger and already says the ledger is append-only history, so the new case is an edge-case row on that page.
- Merged, no new page. Added the GNU make source and a field-evidence source. Bumped last_verified to 2026-10-29. Added a `related:` link to infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan.
- Extended the page's "When this applies" and its "Load when" cell in `wiki/infrastructure/index.md`. Appended one line to `log.md`.
- Conflicts: none.

## Open-PR check

Open `knowledge/*` heads (`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`): #306, #305, #304, #301, #300, #299, #298, #293. This headless run cannot diff those branches. `gh pr view` was also not permitted, so overlap was judged from each PR's title and changed-file list.

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| 43c8d7d514f0714f (rulings ledger newer than the plan) | None. #300 touches `infrastructure/agent-orchestration/verify-command-in-a-worker-brief.md` (verify commands in a brief, a different trigger). #305 is about deciding superseded spec sections, not ruling freshness. | **new** → ingested |
| 8a67a97c4afd204c (`grep -q` + SIGPIPE leaves a runner temp dir) | #299 ("… grep pitfalls …", `platforms/tools/search-evidence-from-a-wrapped-grep.md`, `platforms/tools/bsd-vs-gnu-cli.md`) | **pending duplicate** → claim released |
| f332524447ff2105 (gate grep self-match; `grep` as an interactive shell function) | #299 (`platforms/tools/search-evidence-from-a-wrapped-grep.md`), #300 (`testing/quality/checks-that-cannot-pass.md`) | **pending duplicate** → claim released |
| 8 plan-gap rows | n/a (project-specific) | dropped, see Local-layer candidates |

## Routing decision

- 43c8d7d514f0714f → `infrastructure/agent-orchestration/autonomous-decision-rulings.md`, as a new Edge-cases row. Existing category, no new category. The fix is a check on the rulings ledger that this page defines, so the row belongs on this page, not on the adopted-plan page (which is also over its line budget).
- 8a67a97c4afd204c, f332524447ff2105 → not routed. Released back to `pending` so a later flush can compare them with the merged #299/#300 content.

## Local-layer candidates

All 8 plan-gap rows belong to project **linkly** (repo checkout `shag`, task t1, RFC-0067 consolidation). Run wiki-ingest inside that project if any are worth keeping; most are one-off decisions for a single task.

- 28ffd102c9e362bb (how RFC-0067 is produced: mechanical assembly script) → `wiki-local/qa/document-verification/mechanical-spec-consolidation.md`
- 430224787b03f1d4 (section-level composition) → `wiki-local/qa/document-verification/mechanical-spec-consolidation.md`
- b894ed5a8e75847c (Full grammar EBNF block order and byte identity) → `wiki-local/qa/document-verification/mechanical-spec-consolidation.md`
- d65d6c011f44a782 (prose order after the EBNF block) → `wiki-local/qa/document-verification/mechanical-spec-consolidation.md`
- 22f51684c7ffecf9 (which references to superseded RFCs are re-pointed) → `wiki-local/qa/document-verification/re-pointing-superseded-references.md`
- 37f2edba42fa6ed4 (relation sentences sharing a line with normative text) → `wiki-local/qa/document-verification/mechanical-spec-consolidation.md`
- d149591071a43dde (RFC-0067 title and Status block) → `wiki-local/qa/document-verification/rfc-status-block.md`
- a79848426e6a748e (recording findings to the decisions ledger) → `wiki-local/infrastructure/agent-orchestration/findings-ledger.md`
