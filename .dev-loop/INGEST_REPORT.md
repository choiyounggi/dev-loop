# Knowledge flush — 4 insight(s)

Four lessons from shell gates and visual review: brace a shell variable when non-ASCII text follows it; a passing new-vs-baseline list comparison can be 0 lines against 0; a `\|`-joined basic regex with `$` anchors matched nothing on macOS; a colour-role rule should be measured, not judged from screenshots. **1 new page, 3 edge rows on existing pages, 3 index rows, 4 log entries. 1 row dropped as a duplicate, 1 released as a pending duplicate of open PR #275, 14 released unread.**

Headless autoflush run, claim id `20261022-124048-18072`. `queue-claim.js claim` returned 20 ids. This run had no tool that lists a directory, and queue files are named by session id, so it found rows by opening `~/.dev-loop/queue/<session-id>.jsonl` for the session ids in `~/.claude/history.jsonl` (2026-10-11 onward). 6 claimed rows were found. The other 14 (`97c37473b53e63c2`, `3632d0989f629104`, `9700770d7c05b820`, `3d578bcfcbcc6b97`, `54aeaa8fdee5e0e7`, `0e0e7c7c4cef34c3`, `05df421bf905f5ce`, `1670e43e60cb7fe3`, `1666b8cf32e274ea`, `2df80edab8d41dfb`, `7bfb7541e4e4bd8c`, `410400eb22f77f77`, `5ee53f499cc8d657`, `744090ce219677c0`) sit in files this run could not locate. They were released back to `pending` without being read, so a manual `/dev-loop:knowledge-flush` can pick them up.

## Verified best-practice

1. **`5b37c398f717e032` — brace a parameter that non-ASCII text follows** (field-tested)
   - Claim: `"$NAME가 없어"` breaks under a UTF-8 locale; `"${NAME}가 없어"` is right everywhere.
   - Sources: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html ("The braces are required when … parameter is followed by a character which is not to be interpreted as part of its name"); https://www.gnu.org/software/bash/manual/html_node/Definitions.html (`name` = letters, numbers, underscores; which bytes are letters depends on the locale); https://mail.gnu.org/archive/html/bug-bash/2015-12/msg00030.html (in a UTF-8 locale bash's character classes treat a non-ASCII letter as alphabetic).
   - Evidence: the session's macOS bash 5.3 measurement — `env -i LANG=C.UTF-8 X=ANTHROPIC bash -c 'echo "[$X가 없어]"'` printed `[�� 없어]`, without `LANG` it printed `[ANTHROPIC가 없어]`, and `${X}` was right in both.
   - Correction: the candidate said this matches the GitHub runner. That was **not verified**: nothing was measured on Linux/glibc, and the C library there may classify bytes differently. The page keeps only the directive the bash manual backs, plus the measured macOS result. It tells readers to test under the job's own `LANG` value rather than assuming `C.UTF-8`. The one-byte reading of the broken output is labelled as inference.
2. **`1be71abc38a603ca` — a passing two-list comparison can be 0 vs 0** (verified)
   - Claim: after `grep … | sort -u > list` gates pass, count both lists and cite the runner's own success line.
   - Source: https://www.gnu.org/software/bash/manual/html_node/Pipelines.html ("The exit status of a pipeline is the exit status of the last command in the pipeline, unless the pipefail option is enabled"). The page already cites POSIX grep exit status 1 for "no lines selected".
   - Evidence: the session's G4 gate, where both lists had 0 lines and the pass rested on the `OK (skipped=1)` lines.
3. **`12aa086463fd4e2a` — `\|`-joined BRE with `$` anchors** (verified)
   - Claim: write `grep -Ex 'a|b'` and test one passing and one rejected input.
   - Sources: https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap09.html (9.3.8: `$` is an anchor only as the last character of an entire BRE; at the end of a subexpression it is up to the implementation); https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html (`-x`, `-E`); https://www.austingroupbugs.net/view.php?id=1546 (BRE anchor wording, including `$` before `\|`; implementations differ, as the musl/glibc notes found in the same search show).
   - Evidence: the session's macOS measurement — the BRE filter passed all 3 lines; the `-vEx` form gave 0 on the real status and 2 with stray lines.
   - Wording: "the first `$` is a literal" is consistent with POSIX but was not shown separately, so the page says "consistent with".
4. **`d631595a0e889652` — measure a colour-role rule instead of judging screenshots** (field-tested)
   - Source: https://developer.mozilla.org/en-US/docs/Web/API/Window/getComputedStyle (resolved values, the thing compared).
   - Evidence: the session's two review rounds — a darker danger red `rgb(164,42,36)` was failed as "alarm red" by eye; with `#ff4d3f` and the selector list, the colour was found only on the three allowed elements.

## Existing-layer check

`wiki_search` was run with each trigger (k=4–6).

| Row | Pages read | Finding | Action |
|-----|------------|---------|--------|
| `5b37c398f717e032` | colon-after-an-unbraced-parameter (zsh `:` modifiers), portable-shell-scripts | Closest family, but the colon page is zsh-only by title and `applies_to`; portable-shell-scripts is already at about 121 body lines | **Create** a sibling page; `related:` added both ways with the colon page; also links portable-shell-scripts, timezone-and-locale, unicode-text-matching |
| `1be71abc38a603ca` | checks-that-cannot-pass | Its "output is piped" row covers grep's error 2 hidden by a pipe, not two empty lists compared equal | **Merge** an edge row |
| — | search-evidence-from-a-wrapped-grep, unmatched-glob-in-a-command-argument (shown in search hits) | Adjacent, not merged | — |
| `12aa086463fd4e2a` | anchor-cases-for-allowlist-regexes, scope-purity-checks | Neither covers BRE `$` before `\|`. scope-purity-checks has the `$`-anchoring row for porcelain filters and already links anchor-cases | **Merge** an edge row into anchor-cases; added `shell` to `applies_to`; reverse `related:` link added |
| `d631595a0e889652` | blind-llm-judgment-of-a-visual-rule, theme-swap-propagation-check | No colour-role measurement row. Possible conflict: the blind-brief step says to hide the rule from the judge | **Merge** an edge row that scopes the blind brief to perception questions; for a fact about elements, the value is the rule. `related:` both ways |
| `c0d3c103586e607c` | assertion-scanner-false-positive-on-unittest-convention | Same trigger and directive (test-floor `/assert[ \t]/` misses `self.assert*`; trust the auditor); merged 2026-10-15 from an earlier row | **Drop** as duplicate; also names dev-loop's own script |

No conflicting directive was overwritten, and no contradiction was flagged.

Pages read: platforms-shells-colon-after-an-unbraced-parameter, platforms-shells-portable-shell-scripts, platforms-environment-unicode-text-matching, platforms-environment-timezone-and-locale, testing-quality-checks-that-cannot-pass, testing-quality-anchor-cases-for-allowlist-regexes, qa-process-scope-purity-checks, qa-process-blind-llm-judgment-of-a-visual-rule, frontend-design-theme-swap-propagation-check, testing-quality-assertion-scanner-false-positive-on-unittest-convention

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --json number,headRefName,title,files --search "head:knowledge/"` returned one PR:

- **#275** `knowledge/autoflush-20261012-150339-99224` — "cap test-runner workers so per-file Testcontainers DBs don't exhaust the Docker VM".
- Files: `wiki/testing/flaky/diagnosing-flaky-tests.md`, a new `wiki/testing/flaky/docker-vm-oversubscription-under-parallel-containers.md`, `wiki/testing/data/testcontainers-reaper-on-docker-desktop-macos.md`, `wiki/testing/index.md`, `log.md`.

This headless run cannot diff that branch, so overlap was judged from domain, category and trigger:

| Row | Verdict | Reason |
|-----|---------|--------|
| `0a0ccc4ca0904514` (e2e failures that move between tests under CPU contention) | **Pending duplicate — released** | Same testing/flaky trigger: resource contention reads as tests failing at random. #275 edits diagnosing-flaky-tests.md and adds a resource-exhaustion page. Ingest it manually after #275 lands |
| `5b37c398f717e032` | new | platforms/shells; #275 touches no platforms page |
| `1be71abc38a603ca` | new | testing/quality gate semantics; #275 touches flaky/data only |
| `12aa086463fd4e2a` | new | Same reason as the row above |
| `d631595a0e889652` | new | qa/process; #275 touches no qa page |
| `c0d3c103586e607c` | drop | Already in the merged layer (see above) |

Shared file: #275 and this flush both edit `wiki/testing/index.md` and `log.md`, in different rows (quality vs flaky) and at append-only log lines. Expect a trivial merge.

## Routing decision

| Row | Target | Change |
|-----|--------|--------|
| `5b37c398f717e032` | platforms / shells / **new** `wiki/platforms/shells/non-ascii-text-after-an-unbraced-parameter.md` | Index row in `wiki/platforms/index.md` |
| `1be71abc38a603ca` | testing / quality / `checks-that-cannot-pass.md` | Edge row + Pipelines source; index line extended |
| `12aa086463fd4e2a` | testing / quality / `anchor-cases-for-allowlist-regexes.md` | Edge row + 3 POSIX/Austin Group sources + field case; index line extended. Chosen over scope-purity-checks because the lesson is about regex anchors, not about `git status` scope |
| `d631595a0e889652` | qa / process / `blind-llm-judgment-of-a-visual-rule.md` | Edge row + MDN source + field case; index line extended |

No new category was needed.

Retired with outcome (`status: retired`, `retiredBy`/`retiredAt`): the 4 ingested rows and `c0d3c103586e607c` (dropped: duplicate). Released to pending: `0a0ccc4ca0904514` and the 14 unlocated rows.

## Local-layer candidates

none
