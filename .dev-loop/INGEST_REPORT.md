# Knowledge flush — 2 insight(s) (headless auto-flush run 20261029-124846-54962)

This run claimed 24 queue rows:

- **2 ingested** as new pages.
- **17 dropped** as project-specific plan-gap rows.
- **5 released** back to pending: 2 duplicate open PRs #299 / #300, and 3 have queue files this run could not locate.

Nothing was folded into another branch.

Both ingested rows are plan-gap rows (wiki-plan Phase B decisions in the dev-loop repo, `cormorant`, task `t1-env-leak`). As written, each names that repo's files and line numbers, so the row is project-specific. Each carries a general lesson with its own primary source, though. Only that general lesson was ingested, and nothing from the repo except an anonymised field-case line.

| Candidate | Disposition |
|-----------|-------------|
| `692c00d2eab28ea8` bats mechanics for a test that starts a daemon | **ingested**: new page `testing-strategy-long-lived-processes-under-bats` (verified) |
| `fa55495d116a7d7d` where the tmux environment strip happens | **ingested**: new page `platforms-processes-tmux-server-environment-at-start` (verified) |
| `8a67a97c4afd204c`, `f332524447ff2105` | **released**: still pending duplicates of open PRs #299 / #300 (same verdict as runs 20261029-104612-27366 and 20261029-114716-88588) |
| `d1e6468cdb111e8c`, `baac78b023efce53`, `9f1d906f64d671ad` | **released unread**: this run cannot list `~/.dev-loop/queue`, and Read needs an exact file name. Their files are neither `plan-gaps.jsonl` nor `31e98211-….jsonl` |
| 17 other plan-gap rows (see Local-layer candidates) | dropped as project-specific |

## Verified best-practice

**`692c00d2eab28ea8` → bats and long-lived processes (confidence: verified).**
- **Claim:** a process that a bats test leaves running inherits fd 3, and bats waits until every holder of fd 3 closes it. Fix: add `3>&-` to the start command and stop the process in `teardown`.
- **`setup_file`:** processes started there still block bats even with fd 3 closed, so stop them in `teardown_file`.
- **Helpers:** a helper that records the server's address must be called bare. `$(...)` runs it in a subshell, so its variables never reach the test's shell.

Sources:
- https://bats-core.readthedocs.io/en/stable/writing-tests.html — section "File descriptor 3 (read this if Bats hangs)": a background child inherits fd 3 and bats appears frozen.
- https://bats-core.readthedocs.io/en/v1.3.0/writing-tests.html — same section, with the fix `command_name 3>&-`.
- https://github.com/bats-core/bats-core/issues/530 — bats still waits for `setup_file` background processes when fd 3 is closed.
- https://www.gnu.org/software/bash/manual/bash.html#Command-Substitution — command substitution runs in a subshell.
- Field case from the originating plan: a `$(...)` helper left teardown with no socket name, and the run hung on fd 3.

How verified: WebSearch, 2 queries; the second (extended) returned the docs section and issue #530. This headless run has no page fetch, so the docs were read through search summaries.

**`fa55495d116a7d7d` → tmux server environment (confidence: verified).**
- **Claim:** at server start, tmux copies the starting client's whole environment into the global environment, once. Every new window merges global and session environments, with session values winning.
- **So:** strip run-scoped variables with `env -u` (or an `env -i` allow-list) on every call that can start a server.
- **These do not prevent the copy:** `new-session -e` only sets a session value, and `set-environment -g -u` after start leaves a window where the value is live. A strip that runs only after `has-session` reports no server can race.

Sources:
- https://man7.org/linux/man-pages/man1/tmux.1.html — section GLOBAL AND SESSION ENVIRONMENT, plus `update-environment` and hidden (`-h`) variables.
- https://man.openbsd.org/tmux.1 — `new-session -e`. Already a source of `platforms-processes-driving-a-tui-in-a-tmux-pane`.
- The originating plan quoted the local tmux 3.7b man page and the `tmux.c` server-start loop. The page cites that loop only as field context, not as a re-read source.

How verified: WebSearch, 2 queries; the second (extended) returned the man7 section body as a summary. The macOS `/bin/sh` vs `dash` row for non-shell variable names is a field measurement and is labelled as one on the page.

Not researched: the 5 released rows and the 17 dropped plan-gap rows.

## Existing-layer check

Pages read: platforms-processes-driving-a-tui-in-a-tmux-pane, testing-strategy-signal-delivery-to-a-process-under-test, testing-strategy-calls-that-must-not-block

Also read: `wiki/testing/index.md`, `wiki/platforms/index.md`, `templates/page.md`, and the tail of `log.md`.

`wiki_search` (k=5) runs:

| Query | Top hits |
|-------|----------|
| bats test hangs when a background process or daemon inherits file descriptor 3 | testing-strategy-signal-delivery-to-a-process-under-test 0.740, platforms-shells-redirection-order-for-a-silenced-write 0.736, mobile-lifecycle-process-death-and-state 0.720, testing-mocking-destructive-operations-on-shared-daemons 0.719 |
| bats-core test helpers setup teardown temp dir | testing-data-test-data-and-isolation 0.760, testing-quality-path-resolver-fixtures-with-coincident-cwd 0.756, testing-data-artifact-leakage-from-a-suite 0.756, debugging-methodology-hiding-a-tool-to-reproduce-its-absent-branch 0.714 |
| tmux server copies the client environment into the global environment only at server start | backend-common-orm-prisma-7-config-env-and-generated-client 0.750, backend-python-boundaries-runtime-validation 0.737, platforms-tools-plugin-mcp-server-registration 0.727, platforms-environment-timezone-and-locale 0.723 |
| tmux new-session send-keys launching worker sessions environment variables | platforms-processes-driving-a-tui-in-a-tmux-pane 0.745, infrastructure-agent-orchestration-session-completion-gates 0.741, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts 0.737, platforms-shells-portable-shell-scripts 0.734 |

Findings:
- No page covers bats fd 3. `calls-that-must-not-block` covers a single blocking call in Python, and `signal-delivery` covers SIGINT being ignored in `&` jobs. Neither covers the runner waiting on an inherited descriptor.
- No page covers the tmux global environment. `driving-a-tui-in-a-tmux-pane` is about `send-keys` delivery, and `session-completion-gates` is about `TMUX`/`TMUX_PANE` identifying a pane.
- So both are new pages in existing categories. Bodies are about 60 and 55 lines.
- Related links added both ways: the bats page ↔ `testing-strategy-calls-that-must-not-block`, and the tmux page ↔ `platforms-processes-driving-a-tui-in-a-tmux-pane`. The two new pages also link each other. One-way links go to `testing-strategy-signal-delivery-to-a-process-under-test`, `testing-mocking-destructive-operations-on-shared-daemons`, `testing-quality-tests-that-cannot-fail`, `platforms-processes-spawning-an-agent-cli-from-a-server` and `testing-data-test-data-and-isolation`. Back-links were not added to those, to keep this PR off pages that open PRs might touch.
- Conflicts: none.

## Open-PR check

Open `knowledge/*` heads: #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. This run has no git access, so overlap was judged from each PR's changed-file list (`gh pr list --json files`) and, for #307/#308, their bodies.

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| 692c00d2eab28ea8 (bats fd 3) | None by trigger. No open PR touches `testing/strategy/`. #293, #300 and #301 edit `wiki/testing/index.md` in other categories (`quality`), so this is a merge-conflict risk, not duplicate content | **new** → ingested |
| fa55495d116a7d7d (tmux global environment) | None by trigger. No open PR touches `platforms/processes/` tmux pages. #299 edits `platforms/processes/parsing-cli-structured-output.md` and #298 edits `platforms/processes/tool-diagnostics-without-a-failing-exit-code.md`, neither about tmux or environment inheritance. #298/#300 edit `infrastructure/config/environment-config.md` (application config, not process environment) | **new** → ingested |
| 8a67a97c4afd204c (`grep -q` and SIGPIPE) | #299 (`platforms/tools/search-evidence-from-a-wrapped-grep.md`) | **pending duplicate** → released |
| f332524447ff2105 (gate grep matches its own ledger) | #299, #300 (`testing/quality/checks-that-cannot-pass.md`) | **pending duplicate** → released |
| d1e6468cdb111e8c, baac78b023efce53, 9f1d906f64d671ad | not judged (content unread) | released |
| 17 plan-gap rows | n/a (project-specific) | dropped |

Possible merge conflicts, not duplicate content: `wiki/testing/index.md` (#293, #300, #301), `wiki/platforms/index.md` (#298, #299), and `log.md` (every open flush PR appends to it).

## Routing decision

- `692c00d2eab28ea8` → `testing/strategy/long-lived-processes-under-bats.md`. It is a new page in an existing category. `strategy` already holds the harness-mechanics pages it sits beside (`signal-delivery-to-a-process-under-test`, `calls-that-must-not-block`).
- `fa55495d116a7d7d` → `platforms/processes/tmux-server-environment-at-start.md`. It is a new page in an existing category. `processes` owns tmux pane mechanics (`driving-a-tui-in-a-tmux-pane`) and the environment a spawned child gets (`spawning-an-agent-cli-from-a-server`).
- No new category.
- Repo-specific details (line numbers, helper names, the GROUNDWORK_ variable prefix) were left out of the directives. They appear only in generic form in the field-case lines.

## Local-layer candidates

These 17 rows are excluded from this PR. Each records one wiki-plan Phase B design decision for a single task. To keep any of them, run wiki-ingest inside that project.

| Row | Project | Decision | Target |
|-----|---------|----------|--------|
| 5302bf04b6b15c6c | linkly (`shag`) | t8 rule-7 public contract of `rfc_lint.py` | `wiki-local/qa/document-verification/rfc-lint-rule7.md` |
| 32e1f2001ef439bb | linkly (`shag`) | t8 source of "who updates which section" (`Updated-by:` only) | `wiki-local/qa/document-verification/rfc-lint-rule7.md` |
| b42493f53212bb59 | linkly (`shag`) | t8 no-regression contract (C28) | `wiki-local/qa/document-verification/rfc-lint-rule7.md` |
| 2d283fc00e495053 | linkly (`shag`) | t8 test placement in `impl/tests/test_rfc_lint.py` | `wiki-local/testing/quality/rfc-lint-test-layout.md` |
| 3e25c0ce05dfb984 | linkly (`shag`) | t8 hand-off record for t9 (RosterPinTest) | `wiki-local/qa/document-verification/rfc-lint-rule7.md` |
| 96a7b3d4848b90f0 | linkly (`shag`) | t7 §1 Full Grammar composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 002f8d533f96feed | linkly (`shag`) | t7 cross-RFC unit equality (C6, C19, C20, C29) | `wiki-local/qa/document-verification/cross-rfc-unit-equality.md` |
| 957e06938cb2e214 | linkly (`shag`) | t6 how RFC-0075/0077 are produced (pinned build.sh) | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 6052c18a27fee0d5 | linkly (`shag`) | t6 source snapshot and preflight against merged RFC-0070 | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| b9c678dbb9b66231 | linkly (`shag`) | t6 RFC-0075 §5 composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 8ddce4726589ad52 | linkly (`shag`) | t6 RFC-0075 §6 composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 3164997d10cc7236 | linkly (`shag`) | t6 RFC-0075 §1–§3 composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| bafeea34913960a4 | linkly (`shag`) | t6 relation text, quotes and pointer lines | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| aab9ff18ed91744b | linkly (`shag`) | t6 Status blocks of RFC-0075/0077 | `wiki-local/qa/document-verification/rfc-status-block.md` |
| 4a86878c5bda1bac | linkly (`shag`) | t6 RFC-0048 contamination | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 911b1de9596df50e | linkly (`shag`) | t6 cross-RFC unit equality (c6check.sh) | `wiki-local/qa/document-verification/cross-rfc-unit-equality.md` |
| 6ed0459efb004b5b | linkly (`shag`) | t6 silent-drift sweep findings | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
