# Knowledge flush — 1 insight(s) (headless auto-flush run, claims 20261103-103021-84531)

5 queue rows were claimed this run: 1 ingested (merged into an existing page),
4 released. Nothing was dropped and nothing was folded into another branch.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `d5d55a5aa36c946f` — zsh runs a multi-word command stored in a variable as one command name | platforms | **ingested** — merged into `platforms-shells-portable-shell-scripts` (verified) |
| `fc76dc4dfa08ecde` — docker-run schema validator test: skip vs fail, known-bad document | testing | released — plausible overlap with open PRs #300 / #317 |
| `df1515d721c90d64` — gate CHECK timeout when one check runs the suite N times | testing | released — plausible overlap with open PR #317 |
| `63053db1289c8c67` | unknown | released — row could not be read in this run (see below) |
| `ff1c87af4b580dfb` | unknown | released — row could not be read in this run (see below) |

The headless sandbox blocked listing `~/.dev-loop/queue/`, and `node -e` needed
approval, so queue files could only be opened by guessing their session-id file
names from `~/.claude/history.jsonl`. Three of the five claimed rows were found
that way. The other two were released unread so the next flush (or the manual
skill) can process them; they were not ingested or retired.

## Verified best-practice

**`d5d55a5aa36c946f` — confidence: verified.** Claim: in zsh, `P='perl x.pl'; $P args`
fails `no such file or directory: perl x.pl`, because zsh does not word-split an
unquoted parameter expansion. Wrap the fixed command in a function
(`P() { perl x.pl "$@"; }`), and in a batch of edits count a per-file success marker
instead of trusting trailing output.
- https://zsh.sourceforge.io/FAQ/zshfaq03.html (zsh FAQ ch. 3) and the zsh-users copy
  https://www.zsh.org/mla/users/2001/msg00351.html — an unquoted `$var` is not split
  by default; `SH_WORD_SPLIT` / `${=var}` exist for sh compatibility; arrays are the
  native form. Confirmed through a web-search summary; the pages were not fetched
  (WebFetch is not allowed in this run). The page already cites the zsh Expansion
  manual (14.3) for the same rule.
- https://mywiki.wooledge.org/BashFAQ/050 — "variables hold data, not code"; code
  belongs in functions, dynamic arguments in arrays. Confirmed through a web-search
  summary of the FAQ.
- Field reproduction (session evidence, 2026-11-02, dev-loop t3-plugin-root-quoting):
  `(eval):8: no such file or directory: perl .claude/tmp/pin.pl` for each of 11 files
  while the trailing `sed` output looked normal; after switching to a function, 11
  `ok tests/...` lines.

`fc76dc4dfa08ecde` and `df1515d721c90d64` were released before verification (see
Open-PR check). `63053db1289c8c67` and `ff1c87af4b580dfb` were not read.

## Existing-layer check

Pages read: platforms-shells-portable-shell-scripts

wiki_search hits reviewed (snippets only, not opened): infrastructure-ci-cd-changed-files-only-gates,
platforms-shells-unmatched-glob-in-a-command-argument,
infrastructure-agent-orchestration-gate-evidence-exit-code-class,
debugging-methodology-hiding-a-tool-to-reproduce-its-absent-branch,
qa-process-completion-claims, testing-strategy-import-time-side-effects.

- **platforms-shells-portable-shell-scripts** — merge target for `d5d5`. It already
  has the core rule: step 4 table row "Unquoted `$var` holding `cmd -flag`" (zsh keeps
  it one word and fails `no such file`) and the Instead-of row "Put a command plus its
  flags in one variable". Both offered only "binary path in the variable, flags as
  separate words / array". The candidate adds the function form for a whole command,
  and a batch-edit failure mode where every call fails but trailing output looks
  normal. Changes: the two existing rows gained the function form, one new edge row
  covers the batch case (count `ok <file>` markers against the file count), one
  Sources bullet (BashFAQ/050) plus one field-reproduction bullet, BashFAQ/050 added
  to frontmatter `sources`, `last_verified` 2026-11-03. The Instead-of row
  "Trust a trailing `echo "done"` as proof a step ran" already states the general
  verify-the-state rule; the new edge row applies it to this batch case only. No conflicting directive. The page body was already about 120 lines
  before this merge; it is now about 124 — a wiki-lint split candidate.
- **infrastructure-agent-orchestration-gate-evidence-exit-code-class** — its edge row
  says an `exit=142` timeout is out of its scope ("raise `GATE_CHECK_TIMEOUT`"), so
  `df15` has no merged owner yet. Recorded for the next flush; no edit.
- **debugging-methodology-hiding-a-tool-to-reproduce-its-absent-branch** — covers the
  PATH-hiding half of `fc76`. Recorded for the next flush; no edit.

## Open-PR check

Open `knowledge/*` heads at flush time (`gh pr list --repo choiyounggi/dev-loop
--state open --json number,headRefName --search "head:knowledge/"`): #319, #318, #317,
#315, #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293.
This headless run cannot `git diff` them; overlap was judged from each PR's title and
changed-file list (`gh pr list ... --json number,title,files`).

- `d5d55a5aa36c946f` — **new**. No open PR changes
  `wiki/platforms/shells/portable-shell-scripts.md`. The open PRs that touch
  `platforms/shells` (#298 redirection order, stderr in a captured value; #299 command
  text inspected before execution) cover different triggers.
- `fc76dc4dfa08ecde` — **drop (plausible overlap) → released**. Its point is "a
  validator that is skipped or always says valid looks like a pass". #300 edits
  `testing/quality/tests-that-cannot-fail.md` and `checks-that-cannot-pass.md`; #317
  edits `checks-that-cannot-pass.md`.
- `df1515d721c90d64` — **drop (plausible overlap) → released**. A check killed by its
  timeout is a check that cannot pass. #317 ("self-matching gate CHECKs ... done-gates")
  edits `testing/quality/checks-that-cannot-pass.md` and `completion-predicates.md`.
- `63053db1289c8c67`, `ff1c87af4b580dfb` — not compared (unread); released.

## Routing decision

- `d5d55a5aa36c946f` → `platforms` / `shells` → merged into
  `wiki/platforms/shells/portable-shell-scripts.md` (step 4 table, edge row,
  Instead-of row, Sources). No new page or category. The page's trigger and the
  platforms index line are unchanged, so `wiki/platforms/index.md` and `INDEX.md`
  were not edited.
- `log.md` has one entry appended for this run.

## Local-layer candidates

none
