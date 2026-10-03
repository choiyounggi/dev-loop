# Knowledge flush — 1 insight (+26 plan-gap rows retired as local-layer)

Run id `20261003-220928-9795` (auto-flush; lock inherited from `hooks/auto-flush.sh`). 27 rows claimed: 1 harvested `★ Insight` (`a427206df3949b03`), 26 `plan-gaps.jsonl` rows.

## Verified best-practice

**a427206df3949b03 — quote a glob meant for the program; an empty enumeration is unverified until a known-present file appears.**

Claim: an unquoted `--include=*.py` run through zsh is not executed (`no matches found`), and inside a pipeline the result is an empty list that reads as "nothing missing". Quote the pattern; require a positive control before trusting an empty enumeration.

Sources checked:
- https://zsh.sourceforge.io/Doc/Release/Options.html — `NOMATCH` (`<C> <Z>`, on in zsh emulation): "If a pattern for filename generation has no matches, print an error, instead of leaving it unchanged in the argument list." `NULL_GLOB` deletes the pattern instead and overrides `NOMATCH`.
- https://www.gnu.org/software/bash/manual/html_node/Filename-Expansion.html — bash leaves an unmatched word unchanged unless `nullglob` (word removed) or `failglob` (error, command not executed) is set.
- https://www.gnu.org/software/grep/manual/grep.html — `--include=glob` / `--exclude=glob`: grep does its own wildcard matching on each file's base name while recursing (so the pattern must reach grep literally).

Reproduction (2026-10-03, macOS, zsh 5.9, bash 5.3.15), in a scratch dir holding `sub/a.py`:
- zsh unquoted: `zsh:1: no matches found: --include=*.py`, rc 1 — also with a `b.py` in the cwd (the shell matches the whole word, prefix included).
- zsh quoted and bash unquoted: `./sub/a.py`, rc 0.
- zsh `… | sort > out.txt`: rc 0, `out.txt` 0 lines (the silent-empty failure from the original session).
- zsh function: the skipped command is followed by the next line, function returns 0; `$(…)` yields an empty string.
- bash `failglob`: `no match: --include=*.py`, rest of the `bash -c` line skipped; bash `nullglob`: flag deleted, `sub/b.txt` listed too.
- A file named `--include=x.py` in the cwd: both shells substitute it, list nothing, exit 0.

One claim in the original candidate was corrected: "when the unquoted glob matches nothing in the cwd" — in practice it essentially never matches (the `--include=` prefix is part of the word), so zsh fails every time.

Confidence: **verified** (official zsh/bash/grep docs + local reproduction of every table row).

## Existing-layer check

`wiki_search` top-5 for the trigger: infrastructure-ci-cd-changed-files-only-gates (x3 chunks), testing-quality-checks-that-cannot-pass (x2 chunks). Neither covers unmatched-glob behavior: changed-files-only-gates is about splitting an unquoted `$FILES` list; checks-that-cannot-pass is about a gate never observed passing against a known-good input (adjacent to step 3 of the new page, linked).

`grep -rli 'no matches found|nomatch|unquoted glob|--include' wiki` on main: one unrelated hit (security/authn/retiring-a-replaced-auth-gate.md). The zsh-vs-bash table in portable-shell-scripts covers word splitting, `=word`, and array indexing, not `NOMATCH`.

Merge-before-create: the natural merge target, platforms-shells-portable-shell-scripts, is at exactly 120 body lines (measured with awk), so a row there would break the ≤120 limit. escapes-in-shell-string-literals is about backslash escapes inside quoted patterns, a different trigger. → **new page**.

Pages read: platforms-shells-portable-shell-scripts, platforms-shells-escapes-in-shell-string-literals, backend-common-change-impact-call-site-enumeration, testing-quality-checks-that-cannot-pass, infrastructure-ci-cd-changed-files-only-gates

Conflicts: none. Related links: new page links to all five. Back-link added on infrastructure-ci-cd-changed-files-only-gates. Back-links on portable-shell-scripts, escapes-in-shell-string-literals, checks-that-cannot-pass (rewritten by #223) and call-site-enumeration (rewritten by #231) **deferred** to avoid merge conflicts on those `related:` lines.

Lint: `node scripts/wiki-structure-checks.js ~/.dev-loop/repo/wiki --layer bundled` → `pages: 356, indexes: 13, findings: 0`, rc 0. `node scripts/wiki-lint-prohibitions.js` → 3 violations, all pre-existing outside `wiki/` (plans/…, skills/graph-setup/…), none on the new page. New page body: 63 lines.

## Open-PR check

Open `knowledge/*` heads diffed against main (`git diff origin/main...origin/<head> -- wiki/ INDEX.md`): #223, #225, #226, #227, #228, #229, #230, #231, #233, #234.

- Grep of every head's wiki diff for `no matches found|NOMATCH|nullglob|--include=`: one hit, in #223 — a vitest `-t nomatch` filter, unrelated.
- Shell-category PRs: #223 (redirection-order-for-a-silenced-write), #230 (heredoc-body-expansion-with-backtick-prose), #233 (line-by-line-read-loops) — different triggers.
- Index placement: #233 inserts after line 18 and #230 after line 19 of `wiki/platforms/index.md`, #223 after line 23; this PR inserts after the `unset-versus-empty-parameters` row (line 21) so no hunk touches theirs. `log.md` appends conflict as in every flush.

Verdict for a427206df3949b03: **new**.

## Routing decision

- a427206df3949b03 → `platforms/shells`, new page `wiki/platforms/shells/unmatched-glob-in-a-command-argument.md` (id `platforms-shells-unmatched-glob-in-a-command-argument`). Shell expansion behavior is the cause; the candidate's `domain: debugging` hint was overridden because the fix is a shell-quoting rule, and the debugging angle (empty enumeration) is carried by step 3 and the checks-that-cannot-pass link. No new category.

## Local-layer candidates

All 26 `plan-gaps.jsonl` rows are wiki-plan Phase B decisions naming linkly's own files (`impl/lnpl/*.py`, `docs/*.md`, RFC-0052, `.orchestration/*`, `examples/deploy/*`). Excluded from this PR and retired; run wiki-ingest inside that project if any is worth keeping.

| Rows | Task | Target | Project |
|------|------|--------|---------|
| 9ea52047c7bafed9, 3928ccce3c53eb4a, 5991206585add27b, be69ab1edb95dfdd | t197 doc follow-through, read-miss raise site, RFC-0052 section 4 text (two rows) | wiki-local/backend/persistence/read-miss-without-seeding.md | linkly |
| 3cf28a54959fc278, b616a55432340048, b38f2fd77dcc7da6, 4380ecedaf5bbf88, e4d9a8942e01a214 | t198 diagnostic codes, guard-scoped binding check, test module, README counts | wiki-local/backend/diagnostics/guard-scoped-binding-escape.md | linkly |
| 288f108aeeb38a4d, 49979f4c79df2ac8, bdd5affbc97acee9 | t183 `_touch` docstring, TCK list, decomposition | wiki-local/backend/persistence/fake-driver-row-count.md | linkly |
| 43e1d5e9eed7e9a9, a6d580c96574df05, 041b6a094d03d3ee, b6e268c1a75961c8, 976e2cef3792e62b, fef6f4b3411a68b5 | t190 GHCR image name, RELEASING / deploy README / CI-GATES docs, changelog, blackboard | wiki-local/infrastructure/release/container-image-job.md | linkly |
| bd277c8bd3a44e1a, 2da8bcb1de354b02, 3595ddece91643f1, 2478b86b1926cae8, 0f85f9561a5c0b41 | t187a docs sync, blackboard, deploy tests, secret-leak scope, suite gate | wiki-local/infrastructure/deploy/serving-env-variables.md | linkly |
| cc0ee395c0b29f60, eb1f4b4be43f641e, c57db25512ad8340 | t204 textual-order tracking, IR shape, interp runtime path | wiki-local/backend/compiler/derived-field-assignment.md | linkly |
