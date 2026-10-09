# Knowledge flush — 1 insight (1 page amended, 14 plan-gaps retired as local-layer)

## Verified best-practice

**Insight 4012a55145c1a945 — fallible final assembly runs before commit.**
Claim: when a response or report value is computed at the end of a run from a function that can raise (an average over an empty set, a conversion, a lookup), evaluate it inside the transaction before commit and turn its error into an ordinary operation failure that rolls back; after commit, only reshape values already computed.

Sources checked:
- https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/transaction/support/TransactionSynchronization.html — `beforeCommit`: "exceptions will get propagated to the commit caller and cause a rollback of the transaction"; `afterCommit`: "The transaction will have been committed already", a `RuntimeException` "will be propagated to the caller".
- https://docs.djangoproject.com/en/5.2/topics/db/transactions/ — `atomic`: "If there is an exception, the changes are rolled back"; `on_commit`: "Your callbacks are executed after a successful commit, so a failure in a callback will not cause the transaction to roll back."
- https://www.postgresql.org/docs/current/sql-commit.html — "All changes made by the transaction become visible to others and are guaranteed to be durable if a crash occurs."

How verified: fetched all three pages and quoted the sentences above. Field reproduction from the originating session: a workflow interpreter's response-term evaluation was moved before `repo.commit()`; the regression test went red when the error catch was removed and green with it, and asserted the rolled-back row.

Confidence: **verified**.

## Existing-layer check

Pages read: backend-common-orm-transaction-boundaries, testing-quality-store-assertions-after-a-rolled-back-run, backend-common-errors-async-failure-handling

- `wiki_search` top-5 for the trigger sentence: frontend-data-fetching-query-state-vs-fetch-state, backend-common-integrations-estimate-derived-thresholds, backend-node-boundaries-runtime-validation, backend-common-llm-completion-response-validation, testing-quality-store-assertions-after-a-rolled-back-run. None describes the same situation.
- Closest owner: backend-common-orm-transaction-boundaries. Its "what goes inside the boundary" table already says "slow computation: compute before; only write inside" and "the controller stays outside (serialization is not DB work)". It did not cover computation that can **fail** and must therefore sit before commit. Same topic, new edge → **merged**, no new page.
- Added: one row in the Do-this table, one Edge-cases row, one Instead-of row, a trigger sentence in "When this applies", three sources plus a field-evidence line, `last_verified` 2026-10-04.
- Review: one fresh-context adversarial reviewer (feature-dev:code-reviewer) re-fetched the sources and approved; its one finding (no precedence between the existing "slow computation: compute before" row and the new row) is applied as a final sentence on the new row.
- Conflicts: none. The new row agrees with "keep only DB work inside": the fallible step goes before commit, not between commit and response.
- Related links: added testing-quality-store-assertions-after-a-rolled-back-run to the page's `related:`. That page already links back to backend-common-orm-transaction-boundaries.
- Plumbing: wiki/backend/index.md load-when line extended; log.md ingest line appended. `node scripts/wiki-lint-prohibitions.js wiki/` → violations: 0.

## Open-PR check

Open `knowledge/*` heads listed: #223, #225, #226, #227, #228, #229, #230, #231, #233, #234, #235, #236, #237.

For each one, ran `git diff origin/main...origin/<head> -- wiki/` and grepped added lines for commit/rollback/transaction. None of them touches wiki/backend/common/orm/transaction-boundaries.md. The only matches were unrelated: #234 is about sharing one connection across request transactions, #231 only adds a `related:` link on async-failure-handling, #225 is about optimistic UI patches, and the rest are git/heredoc prose.

Verdict for 4012a55145c1a945: **new**.
Verdict for the 14 plan-gap rows: none overlap an open PR; they are retired as local-layer (below).

## Routing decision

- 4012a55145c1a945 → backend / common/orm / backend-common-orm-transaction-boundaries (merged into existing page). Reason: the directive is about where a step sits relative to the transaction boundary, which this page owns. No new category needed.

## Local-layer candidates

14 plan-gap rows from linkly orchestration run qa1002. Each names linkly's own files, RFCs, or decisions (`impl/lnpl/lower.py`, `interp.py`, `RFC-0061`/`RFC-0062`, `RFC_ROUTES`, `VERB_LEXICON`). They are excluded from this PR and retired from the queue. Target if ever wanted: `wiki-local/backend/<category>/<slug>.md` in the linkly repo. Run wiki-ingest inside that project.

- t210 (9): c4d0c28b0fdf9504, fdfc99325ca6b354, b09d09db744c2d54, 23d5ef43080132f9, fcc5792205767081, 22e6c899fa7e772c, d87a8a4bda0cb8a3, 1d7e8d070878d875, e1e40e6b4f3faaf0
- t211b (5): 545228fe7f18d075, 81220620185427cd, cf8385f12b32b61f, cda72e4bf1eed6ca, 5625140924325116
