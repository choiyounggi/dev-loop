# Knowledge flush — 3 insight(s)

## Verified best-practice

**1. `__file__`-relative data files break after non-editable install → package data + `importlib.resources`** (hash `a9e3db01b9b1ceb1`, linkly session)
- Claim: a Python package locating runtime data files via `__file__`-relative paths works in editable/`PYTHONPATH` runs but fails after `pip install .`; data files must be declared as package data and resolved via `importlib.resources`.
- Sources checked (fetched this flush): https://setuptools.pypa.io/en/latest/userguide/datafiles.html — "It is strongly recommended that, if you are using data files, you should use `importlib.resources` to access them"; `__file__` manipulation "isn't compatible with PEP 302-based import hooks, including importing from zip files"; `include_package_data`/`package_data` control wheel contents. https://docs.python.org/3/library/importlib.resources.html — resources "do not have to exist as physical files and directories"; `as_file()` yields a real path and cleans up extractions.
- Field evidence: linkly v0.4.0 `lnpl build` rc=4, grammar path resolved to `.venv/lib/python3.13/mlir/lnpl.irdl.mlir` (absent from the wheel) while `PYTHONPATH=impl` built fine.
- **Confidence: verified** (official docs + field reproduction).

**2. Orchestrator-injected coordination env leaks into harness test suites** (hash `03b0983bb4a5d9d8`, dev-loop session)
- Claim: when an orchestration worker runs the harness's own test suite, injected `LO_*`/`GROUNDWORK_*` vars leak into the scripts under test — tests fail against the unset-env baseline AND test writes land in the live run's shared state (watcher then monitors the wrong session). Unset injected vars in setup; pass tempdir state paths explicitly.
- Sources checked: dev-loop issue #100 (OPEN, root cause section marked "verified 2026-08-14") — 6 deterministic `launch-session.bats` failures reproduced with `env LO_RUN_ID=… bats` on a clean checkout; live `t90.json` found rewritten with bats tempdir paths and a foreign session name. The env-merge mechanism (`env` merges into the inherited environment unless `-i`) is already sourced on the target page (pubs.opengroup.org env spec).
- **Confidence: field-tested** (reproducible in-repo evidence; no additional external doc needed beyond what the page already cites).

**3. Reflowing prose that tests assert as a single-line substring** (hash `4b8d97490dc0ed5e`, dev-loop session)
- Claim as harvested: "macOS bash 3.2 matches a newline-split phrase in `[[ ]]`, so only ubuntu CI fails."
- **Mechanism correction — the harvested claim is false.** Measured this flush on bash 3.2.57: `[[ "$s" == *"return to step 1"* ]]` does NOT match a newline-split phrase (NOMATCH on both old and new bash). What actually differs by platform: `set -e; [[ 1 -eq 2 ]]; echo REACHED` prints REACHED on bash 3.2 — under bash ≤4.0 a failing mid-test `[[ ]]` doesn't abort, so the broken assertion passes silently on macOS while bash ≥4.2 CI fails it. `tests/orchestrate-review-pass.bats:81` uses exactly this mid-test `[[ ]]` form.
- Field evidence: two reproductions (dev-loop PR #94 §O3; PR #102 'return to step 1 of the dispatch', fixed by reflow commit 9cbc065).
- **Confidence: verified** (directive verified with the corrected mechanism; the wrong mechanism was NOT ingested).

## Existing-layer check

Pages read: qa-document-verification-editing-a-gated-document, testing-data-test-data-and-isolation, infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-worktree-isolated-workers

- Grepped main's `wiki/` for `__file__`/`importlib`: zero hits → insight 1 is not covered anywhere; **created new page** (a stale local-only branch `knowledge/dch0202-20260805-144711` once drafted a related page but has no PR and is not in main — not an open-PR obligation).
- `testing-data-test-data-and-isolation` already carries the generic absent-variable `unset` row and the env-derived-write-path row; insight 2's *injected-orchestration-env → live-state corruption* angle was missing → **merged** (+1 Do row, +1 edge case, +1 field-incident source), related-links added both ways with `infrastructure-agent-orchestration-shared-run-state`. No conflict with existing directives.
- `qa-document-verification-editing-a-gated-document` covers anchor inventory before editing; its Substring anchor row lacked the reflow/line-wrap breakage mode and the platform-invisible-failure twist → **merged** (extended Substring row, +1 edge case, +1 Instead-of row, +2 sources), cross-linking existing `testing-quality-tests-that-cannot-fail`. No conflict.
- `node scripts/wiki-lint-prohibitions.js`: 61 directives, 0 violations after edits.

## Open-PR check

Listed 27 open `knowledge/*` heads (gh pr list, head:knowledge/) and grepped `git diff origin/main...<head> -- wiki/` across all fetched knowledge branches for `importlib|__file__|package data|LO_|GROUNDWORK_|ambient env|unset|bats|bash 3.2|normalize_ws|line-wrap|whitespace`.

- Insight 1: no open head touches Python packaging/`__file__` → **new**.
- Insight 2: no open head touches injected-env test isolation (the generic absent-var row in old branch `dch0202-20260805-103148` / closed PR #28 is already in main) → **new**.
- Insight 3: **partial fold into PR #47** (`knowledge/dch0202-20260806-130040`) — #47 already carries the runtime mechanism (bats mid-test `[[ ]]` trap under bash ≤4.0, tests-that-cannot-fail row, COMPAT + bats-gotchas sources). That part is NOT re-ingested here; a comment noting the two additional field reproductions (PR #94/#102) is left on #47. The document-editing side (reflow breaks single-line substring anchors; whitespace-normalize new phrase gates) is absent from #47 and from main → merged into `editing-a-gated-document` here as **new**.

## Routing decision

| Insight | Target | Decision |
|---------|--------|----------|
| 1 — data files & install paths | `backend/python/packaging/data-files-and-install-paths.md` | **New page, NEW category `packaging`** — existing backend/python categories (concurrency, boundaries, serving, language) cover runtime behavior, not distribution/wheel contents; harvested "platforms" hint rejected (platforms = OS-level differences, this is install-mode-level). backend/python index + backend index + root INDEX updated |
| 2 — injected coordination env | `testing/data/test-data-and-isolation.md` | **Merge** — trigger is "how a suite isolates state", same page that owns the absent-var and env-write-path rows; orchestration cross-link to shared-run-state rather than a new agent-orchestration page (the actor is the test author, not the brief author) |
| 3 — reflow vs substring anchors | `qa/document-verification/editing-a-gated-document.md` | **Merge** — exact trigger match ("editing a document automated text gates check"); gate-authoring half folded as guidance pointing at whitespace-normalized comparison; runtime-mechanism half deferred to open PR #47 (fold) |
