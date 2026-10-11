# Knowledge flush — 4 insight(s) claimed: 1 new page, 1 merge, 1 dropped as already covered, 1 local-layer

## Verified best-practice

### 1. `a50099e971917b38` — `echo "$VAR"` truncates fetched text at `\c` (zsh / XSI sh)
- **Claim:** when a script stores text it did not write (fetched HTML, file contents, tool output) in a variable and passes it on with `echo "$VAR" | grep …`, zsh's builtin `echo` interprets backslash escapes and `\c` ends the output, so greps silently return nothing. Carry data with `printf '%s\n' "$VAR"` or pipe the producer straight into the consumer.
- **Sources checked:**
  - https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html — `echo [ -neE ]`: "echo recognizes the following escape sequences"; `\c` "suppress subsequent characters and final newline".
  - https://zsh.sourceforge.io/Doc/Release/Options.html — `BSD_ECHO`: "disables backslashed escape sequences in echo strings unless the -e option is specified".
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/echo.html — XSI `echo` recognizes `\c` and ignores all following characters; Application Usage: "New applications are encouraged to use printf instead of echo".
- **How verified:** reproduced 2026-10-11 on macOS 26.1 / zsh 5.9: a 27-byte variable containing `\c`; `echo "$v" | grep -c after-marker` printed `0` under zsh, macOS `/bin/sh` and dash, `1` under bash; `printf '%s\n'`, `echo -E`, and `setopt BSD_ECHO` each printed `1`. The candidate's own evidence (125 KB `libpq-connect.html`, every `echo "$RAW" | grep` empty, `curl | sed | grep` matched) agrees. The candidate said "zsh"; the reproduction widened it to XSI `sh`/dash with bash as the exception, and the page says so.
- **Confidence:** verified.

### 2. `0ed3d5d2828d5597` — BSD `wc -l` pads the count with leading spaces
- **Claim:** on macOS `N=$(wc -l < file)` yields `     398`; `tail -n +"$N"` fails with `illegal offset` and an `until` waiter repeats the failure forever while looking like "still waiting". Strip with `$(( … ))` or `tr -d ' '` and assert all-digits before using it as an offset.
- **Sources checked:**
  - https://github.com/apple-oss-distributions/text_cmds/blob/main/wc/wc.c — `xo_emit_h(xop, " {:lines/%7ju/%ju}", linect)` (7-wide right-aligned field).
  - https://github.com/freebsd/freebsd-src/blob/main/usr.bin/wc/wc.c — same `%7ju` format.
  - https://www.gnu.org/software/coreutils/manual/html_node/wc-invocation.html — "The width of the count fields varies depending on the inputs, so you should not depend on a particular field width".
  - https://man.freebsd.org/cgi/man.cgi?query=wc&sektion=1 and local `man wc` — the man pages document only "written to the standard output" (no width), which is why the source file is cited.
- **How verified:** reproduced 2026-10-11 on macOS 26.1 with a 398-line file: raw `[     398]`, `tail: illegal offset -- +     398: Invalid argument`; `$(( $(wc -l < f) ))` and `tr -d ' '` both gave `398` and `tail` then worked; `[ "$N" -eq 398 ]` passed on the padded value while `case "$N" in *[!0-9]*)` matched it as not-all-digits; GNU `gwc -l < f` printed `398`.
- **Confidence:** verified.

### 3. `850131cacaecd1c7` — same-length Python mutations in the same second reuse the earlier `.pyc`
- **Claim:** run the interpreter with `-B` and delete the module's `__pycache__/*.pyc` before each mutation run, because timestamp+size `.pyc` validation matches two same-length edits made in the same second.
- **Sources checked:** `wiki/backend/python/language/bytecode-cache-staleness.md` (merged on main, `last_verified: 2026-10-06`) already cites https://docs.python.org/3/reference/import.html, PEP 552, and https://docs.python.org/3/using/cmdline.html for exactly this mechanism.
- **How verified:** the existing page's Edge-cases row "Two *different* mutations each change the file by the same number of bytes … written in the same second" states this case with the same remedy, and its row "The tree is read-only, or the harness runs under `-B` / `PYTHONDONTWRITEBYTECODE`" already corrects the candidate's `-B`-first wording (`-B` governs writing only; purge first). Its Sources list carries a field case from 2026-10-06 with two 10-byte-shorter mutations of `wsgi.py` within one second — the same repository and symptom as this candidate's 2026-10-11 evidence.
- **Confidence:** verified, but **dropped as already covered** (no new mechanism, no new remedy; the page is at 101 lines and the 2026-10-11 run adds no fact its 2026-10-06 field case lacks).

### 4. `0b0437866e81266d` — plan-gaps row for `t2-serve-idempotency-unsupported` (anhinga)
- Project-specific ownership/untouched-files decision for one linkly task; names `impl/lnpl/wsgi.py`, `cli.py:1020-1027`, `examples/deploy/README.md:138`. Not verifiable as general knowledge and would be wrong in any other codebase. Routed to the local layer (see below), not ingested here.

## Existing-layer check

Pages read: platforms-shells-portable-shell-scripts, platforms-shells-escapes-in-shell-string-literals, platforms-tools-bsd-vs-gnu-cli, backend-python-language-bytecode-cache-staleness, platforms-shells-option-like-argument-values, platforms-shells-line-by-line-read-loops, testing-quality-completion-predicates

- **Candidate 1:** `wiki_search` top-5 (k=5) were all sections of `platforms-shells-escapes-in-shell-string-literals` (0.78–0.77) and `platforms-shells-portable-shell-scripts` (0.78). Both are about escapes in *literals you typed* (regex/pattern quoting), not about `echo` processing escapes inside *data*; `bsd-vs-gnu-cli` has one edge row ("Any flags passed to `echo` — use `printf` for anything beyond a bare literal string") that names the remedy without the trigger or the `\c` mechanism. Repo-wide grep for `builtin echo|echo interprets|BSD_ECHO|xpg_echo|echo -e` found no page owning it. No conflict. → **created** `wiki/platforms/shells/echo-of-text-you-did-not-write.md` (id `platforms-shells-echo-of-text-you-did-not-write`, 63 body lines). `related:` added both ways with `portable-shell-scripts`, `escapes-in-shell-string-literals`, `option-like-argument-values`, `line-by-line-read-loops`, `bsd-vs-gnu-cli` (frontmatter only on the 120-line `portable-shell-scripts`).
- **Candidate 2:** `wiki_search` top-5: `testing-quality-completion-predicates` (0.76, `wc -l` undercounts an unterminated last line — a different defect), `platforms-shells-line-by-line-read-loops` ×2, `platforms-tools-bsd-vs-gnu-cli` (0.75, the per-command BSD/GNU table), `platforms-filesystems-trailing-separator-under-realpath`. Repo-wide grep for `wc -l <|leading space|illegal offset|tr -d` found no page covering the padding. `bsd-vs-gnu-cli` is the same trigger class (same command name, different userland output) → **merged** into it: one table row (`Line count as a number`), one Edge-cases row, one Instead-of row, three sources + a reproduction line, `last_verified` 2026-07-10 → 2026-10-11 (69 → 62 body lines after the frontmatter grew). No conflict with the page's existing `wc -l` "count items by lines" advice; the new row qualifies how to consume that count.
- **Candidate 3:** `wiki_search` top-5 led with `backend-python-language-default-encoding-in-text-io` (0.84, links to the staleness page) and `backend-python-language-bytecode-cache-staleness` edge_case + trigger (0.83, 0.81). Read in full; it already carries this exact case and corrects the candidate's `-B` emphasis. → **dropped** as duplicate; nothing added.
- **Candidate 4:** not routed into the bundled wiki (local layer).

## Open-PR check

Open `knowledge/*` heads listed with `gh pr list --search "head:knowledge/"`: #265 (`knowledge/choiyounggi-20261009-222812`), #266 (`…20261010-021455`), #268 (`…20261011-002014`), #269 (`…20261011-022522`), #270 (`…20261011-193253`), #271 (`…20261011-213648`), #272 (`…20261011-223623`). Non-knowledge open PR #267 (`fix/autoflush-opt-in`) touches no wiki page.

Each head was fetched and `git diff origin/main origin/<head> -- wiki/` was grepped for `builtin echo|echo interprets|BSD_ECHO|xpg_echo|illegal offset|wc -l <|leading space|right-align|__pycache__|.pyc|same number of bytes|same length`: zero added lines in all seven. #270 touches `mutation-harness-file-custody`, `surviving-mutant-equivalence-triage` and `harness-reverse-controls`, but its only bytecode-related line is an unchanged `related:` entry. #265 and #266 touch `wiki/platforms/index.md` on other rows (no overlap with the two rows edited here). File-level overlap of this PR with open heads: `wiki/platforms/index.md` (#265, #266, #270 — different rows, merges line-wise), `wiki/testing/quality/*` untouched here.

Verdicts: candidate 1 **new**; candidate 2 **new**; candidate 3 **drop** (duplicate of merged main, not of an open PR); candidate 4 **drop** from this PR (local layer).

## Routing decision

| Candidate | Target | Action |
|-----------|--------|--------|
| 1 echo `\c` | `platforms/shells` → `echo-of-text-you-did-not-write.md` | new page; `shells` fits (shell builtin semantics across zsh/sh/bash); index row added |
| 2 wc padding | `platforms/tools` → `bsd-vs-gnu-cli.md` | merge (table row + edge + instead-of + sources); index "load when" extended |
| 3 pyc same-second | `backend/python/language` → `bytecode-cache-staleness.md` | already covered; no edit |
| 4 plan-gaps | local layer | excluded |

No new category.

## Local-layer candidates

- `0b0437866e81266d` (project `anhinga` / linkly, task `t2-serve-idempotency-unsupported`): ownership and untouched-file ruling for the 501-on-`Idempotency-Key` change (`wsgi.py`, `lexer.py`, `docs/serving.md`, `relay` 501 handling in `cli.py` deferred to t3). Target `wiki-local/backend/http/idempotency-key-refusal-ownership.md` in that repository — run `wiki-ingest` inside that project.
