# Knowledge flush — 1 insight (9 claimed rows: 1 ingested, 8 plan-gap rows retired as local-layer / pending-duplicate)

Run id `20260928-155151-10929` (inherited from the auto-flush parent via `DEV_LOOP_FLUSH_RUN_ID`; `flush-lock.sh acquire` answered `already-owned`). Claimed ids: `dd2b3e11fff92997` (session row, repo t7-run-gitflow, ingested) plus 8 `plan-gaps.jsonl` rows listed under Local-layer candidates.

## Verified best-practice

**Claim (row `dd2b3e11fff92997`):** a heredoc body that must expand a shell variable while quoting commands in markdown backtick spans keeps the delimiter quoted (`<<'EOF'`) and substitutes a placeholder afterwards with a tool that treats the replacement as data (python `replace` reading the value from an env var, or GNU `envsubst '$VAR'` with an explicit variable list), or backslash-escapes every backtick under an unquoted delimiter. Mechanism: with an unquoted delimiter the body is expanded like a double-quoted string, so every `` `…` `` span runs as a command in the current cwd/env and its stdout replaces the span; the exit status is `cat`'s, so only stderr and the written file show it.

Sources checked and how:

- https://www.gnu.org/software/bash/manual/html_node/Redirections.html §3.6.6 Here Documents (curled 2026-09-28, tags stripped with sed): "If any part of word is quoted … the lines in the here-document are not expanded. If word is unquoted … all lines of the here-document are subjected to parameter expansion, command substitution, and arithmetic expansion … and '\' must be used to quote the characters '\', '$', and '`'".
- https://zsh.sourceforge.io/Doc/Release/Redirection.html `<<[-] word` (curled the same way): "If any character of word is quoted with single or double quotes or a '\', no interpretation is placed upon the characters of the document. Otherwise, parameter and command substitution occurs … and '\' must be used to quote the characters '\', '$', '`'".
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html §2.7.4 Here-Document (curled): "If no part of word is quoted, all lines of the here-document shall be expanded for parameter expansion, command substitution, and arithmetic expansion."
- Reproduction 2026-09-28 in a scratch git repo under the project's `.claude/tmp/` (removed afterwards), bash 5.3.15 and zsh 5.9 on macOS: `cat <<EOF > notes.md` with the prose `` `git branch crew/qa` then `frobnicate --all` `` → rc 0, stderr only `frobnicate: command not found`, file content `Next run  then .`, and `git branch --list` showed the new `crew/qa` branch (zsh: `crew/qa4` likewise). The three remedies — `<<'EOF'` + python placeholder replace from `$V`, `<<EOF` with `` \` ``, and `<<'EOF'` piped through `envsubst '$TASK'` — each wrote the prose intact with the variable expanded and created no branch. Also observed: `envsubst` turns `\$TASK` into `\t7` (backslash has no quoting meaning there), recorded as an edge case.
- Field evidence from the session row: an unquoted notes heredoc printed `fatal: a branch named 'crew/qa' already exists` — the prose `git branch crew/qa` had run against the worktree's repo.

Result: **confidence: verified** (three official manuals + reproduction). `applies_to: [bash, zsh, posix-sh]`.

## Existing-layer check

Pages read: platforms-shells-escapes-in-shell-string-literals, platforms-shells-command-text-inspected-before-execution, platforms-shells-portable-shell-scripts, platforms-processes-non-interactive-cli-invocation, infrastructure-ci-cd-unparseable-workflow-file

- `INDEX.md` → platforms (shell portability). `wiki/platforms/index.md` read in full; the `shells` category is the fit.
- `grep -rli 'heredoc|here-doc|here document' wiki/` → 4 files: `command-text-inspected-before-execution` (a heredoc-built file does not exist at gate time), `non-interactive-cli-invocation` (feed stdin from a heredoc), `unparseable-workflow-file` (heredoc indentation in YAML `run:`), `worktree-isolated-workers` (unrelated). None describes body expansion.
- `wiki_search` (k=5) on the trigger sentence: four hits on `escapes-in-shell-string-literals` (its double-quoted-backtick rows for `grep -F` patterns) and one on `unparseable-workflow-file`. `escapes-in-shell-string-literals` "When this applies" is a regex/pattern **string literal**; `portable-shell-scripts` has the one-line edge row "Message text must contain a command example → single-quote or write to a file". Neither covers a heredoc body (a different quoting mechanism — the delimiter, not the quotes), the variable-plus-backtick conflict, the placeholder/`envsubst`/escape choice, or auditing an executed span. → **new page**, one case: `heredoc-body-expansion-with-backtick-prose`. No conflict: the new page defers the single-line-argument case back to `escapes-in-shell-string-literals` in an edge row.
- `related:` on the new page → escapes-in-shell-string-literals, portable-shell-scripts, command-text-inspected-before-execution. Reciprocal link added on `command-text-inspected-before-execution` (no open PR touches it). Reciprocal links on `escapes-in-shell-string-literals` and `portable-shell-scripts` are **deferred**: open PR #223 rewrites both pages' `related:` lines, so a second edit of the same line would conflict on whichever merges second; add them after #223 lands.
- `INDEX.md` platforms row left unchanged for the same reason (open PR #227 rewrites that row); its existing "shell portability" wording already routes shell writes to the platforms index, where the new row carries the specific trigger.
- Lint on the edited checkout: `node scripts/wiki-lint-prohibitions.js wiki` → `directives: 79, violations: 0` (baseline on untouched main was also 79 / 0, so `tests/wiki-lint-prohibitions.bats` needs no count bump); `node scripts/wiki-structure-checks.js wiki` → `pages: 354, indexes: 13, findings: 0` (baseline 353 / 0); `bats tests/wiki-lint-prohibitions.bats tests/wiki-structure-checks.bats tests/wiki-index.bats tests/wiki-index-freshness.bats tests/wiki-agent-gate.bats tests/wiki-contradiction.bats` → `1..131`, 131 ok, 0 not ok. New page body: 72 lines.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` → #223 (`knowledge/choiyounggi-20260927-220735`), #225 (`…-082803`), #226 (`…-092831`), #227 (`…-103056`), #228 (`…-134840`), #229 (`…-145025`). Each head fetched; `git diff origin/main origin/<head> -- wiki/` grepped for `heredoc|here-doc|here document|command substitution|backtick` → 0 added lines in every head. #223 adds `shells/redirection-order-for-a-silenced-write` (stderr/stdout ordering of a silenced write — a different situation).

Verdict per candidate: `dd2b3e11fff92997` → **new**. The 8 plan-gap rows → **drop**: six of them (`f8274e8a574a39af`, `f541156192eeee35`, `4bac29ffc7930e3c`, `72355943be4f08f4`, `1958e49958fa5319`, `cae239f03ddab2cd`) are byte-identical re-harvests of rows PR #229's report already retired as local-layer, and the remaining two (`da8b9f803d9aa21a`, `cadd2dc7b02ea111`) are two more harvests of the same `interp.eval_value` decision #229 retired under `ff968018e51af793`. Nothing new; retired again so they stop re-crossing the auto-flush threshold.

## Routing decision

- `dd2b3e11fff92997` → `wiki/platforms/shells/heredoc-body-expansion-with-backtick-prose.md` (id `platforms-shells-heredoc-body-expansion-with-backtick-prose`), existing category `shells` — it is the shell-quoting family the category already holds (string-literal escapes, gate-inspected command text); no new category.
- Plumbing: `wiki/platforms/index.md` (+1 row after `escapes-in-shell-string-literals`), `log.md` (ingest entry), `wiki/platforms/shells/command-text-inspected-before-execution.md` (reciprocal `related:`).

## Local-layer candidates

All 8 `plan-gaps.jsonl` rows are wiki-plan "no owning wiki page" design records for seagrass (linkly), task t172-money-set-and-guards; each directive names that repository's own functions, RFC numbers and pinned test lines and would be wrong in another codebase. Target `wiki-local/backend/python/<slug>.md` in that repo — run `wiki-ingest` inside the project if any is wanted there:

- `f8274e8a574a39af` `_check_dimensions` message names RFC-0051 only when `"money"` participates → `money-mismatch-message-cites-rfc-0051`
- `da8b9f803d9aa21a`, `cadd2dc7b02ea111` `interp.eval_value` `Ref` branch gains a Money dict case (shape dispatch) → `money-runtime-shape-dispatch`
- `f541156192eeee35` `money.py` `sub`/`mul_int` pure, import-free, own ±INT64 check → `money-sub-mul-int-domain-check`
- `4bac29ffc7930e3c` `_condition_holds` spec-only Money order comparison opened → `money-order-comparison-in-spec`
- `72355943be4f08f4` RFC-0051 status Draft + Updates chain per RFC-0007 §2.2 → `wiki-local/qa/document-verification/rfc-0051-updates-chain`
- `1958e49958fa5319` t177 declared-field rule reaches `_dimension_of` through the generic reference loop → `numeric-predicate-declared-field-rule`
- `cae239f03ddab2cd` `RFC_ROUTES["0051"]`, generated grammar prose, README/CHANGELOG/ENFORCEMENT rows → `rfc-0051-registry-rows`
