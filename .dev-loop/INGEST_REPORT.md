# Knowledge flush — 6 insight(s)

Six harvested insights become 3 new pages and 3 edge rows on existing pages. Two candidates are corrected rather than taken as written: one blamed the wrong grep, and one restated a fact the wiki already had.

Claimed for run `flush-20261023-142052-26089`: 6 of the 83 claimable rows. The other 77 (26 insights + 51 plan-gaps) were released unread for later flushes, keeping this PR one reviewable batch. This batch follows the still-open #298, which comes from the same contributor and covers different topics.

## Verified best-practice

| Row | Claim | Verification | Confidence |
|-----|-------|--------------|------------|
| `464e2f99dd9f1a0e` | Aggregates over `gh api --paginate` (`length`, `last`) must run over all pages: `--slurp \| jq 'add \| …'`, not `--jq` | The gh manual (cli.github.com/manual/gh_api, same text in `gh api --help`) says "Each page is a separate JSON array or object. Pass `--slurp` to wrap all pages of JSON arrays or objects into an outer JSON array". Reproduced on gh 2.87.3 with `repos/cli/cli/pulls/9000/reviews?per_page=1`: `--jq 'length'` printed `1 1 1`, a piped `jq 'length'` printed `3`, and `--slurp` + `map(length)\|add` printed `3`. **Changed from the candidate:** it recommended the plain pipe, which merged pages on 2.87.3 but contradicts the manual's wording, so the page recommends the documented `--slurp` form and keeps the pipe as an edge row | verified |
| `9276633c189491e9` | ktlint's end-of-file newline direction comes from `.editorconfig` `insert_final_newline`; `false` means "must not end with a newline" | Read ktlint 1.8.0 `FinalNewlineRule.kt`: `true` emits "File must end with a newline (\n)", `false` emits "Redundant newline (\n) at the end of file", both auto-correctable; `InsertFinalNewLineEditorConfigProperty.kt` has `defaultValue = true`. EditorConfig spec: "Set to true ensure file ends with a newline when saving and false to ensure it doesn’t". Older ktlint READMEs say `false` *disables* the rule, and the page flags that as outdated | verified |
| `11cd75850a5893cc` | Match a command-guard exemption with a full match on the shlex-extracted endpoint token, not a substring of the command | Python docs for `shlex.split` ("Split the string s using shell-like syntax") and `re.fullmatch`. Reproduced on 7 commands: a substring exemption allowed all seven. A tokenizer that skipped values only for `-f`/`--jq`/`-X` still let through `-t <exempt-path>`, `repos/../r/…` and an unknown option. The full option table from `gh api --help`, plus `..` rejection and "unknown option means not exempt", allowed only the two real shapes | verified |
| `46f59fe5ff46ecdf` | A mid-pattern `$` makes a grep presence check read 0 | **Mechanism corrected.** The candidate blamed BSD grep BRE, but `/usr/bin/grep` (BSD 2.6.0) matched all four test patterns. The Bash tool's `grep` is a shell function running bundled ugrep 7.8.4 with `-G`, and that is what counted 0 (rc 1) for `OLD=$(cat`, `a$b`, `x${y}`, `price $5`; `[$]`, `\$` and `-F` matched under both. POSIX §9.3.8: "A <dollar-sign> ('$') shall be an anchor when used as the last character of an entire BRE" | verified |
| `d4c45969ee6fa70c` | A file list handed to a scanner collapses into one argument and the scan reports "clean" | The zsh no-word-split half is already in infrastructure-ci-cd-changed-files-only-gates. The new fact is BSD `grep -Z`. macOS `man grep`: "-Z, --decompress Force grep to behave as zgrep" vs "--null Prints a zero-byte after the file name". GNU manual: `-Z`/`--null` outputs "a zero byte (the ASCII NUL character) instead of the character that normally follows a file name". Reproduced: BSD `grep -lZ` printed 0 NULs and `xargs -0` received 1 argument; `--null` printed 2 NULs and gave 2 arguments | verified |
| `b102d23e72af80f2` | Before making an application-computed `seq` atomic, declare the "one active row" rule the composite key was enforcing by accident, as a partial unique index | PG docs on Read Committed: "a SELECT query … sees only data committed before the query began; it never sees either uncommitted data or changes committed by concurrent transactions". PG docs Example 11.3 shows a partial unique index for "only one 'successful' entry". Reproduced on a throwaway PostgreSQL 16.11 cluster (TCP 127.0.0.1:54999, created in the session scratch dir and stopped afterwards) with two concurrent deactivate-then-insert transactions on a sequence-numbered `seq`: with only `unique(parent, seq)` both committed and 2 rows were active; with the partial unique index the second waited, then failed with `duplicate key value violates unique constraint`, leaving 1 active row | verified |

## Existing-layer check

Pages read: platforms-tools-search-evidence-from-a-wrapped-grep, platforms-tools-bsd-vs-gnu-cli, infrastructure-ci-cd-changed-files-only-gates, platforms-processes-parsing-cli-structured-output, platforms-tools-jq-dot-rebinding-in-predicates, platforms-shells-command-text-inspected-before-execution, security-input-validation-at-trust-boundaries, security-agent-exposure-capability-flag-across-adapters, testing-quality-checks-that-cannot-pass, databases-transactions-isolation-level-selection, databases-schema-design-soft-delete, databases-indexing-partial-and-expression-indexes, backend-common-llm-project-local-layer-over-shared-guidance

`wiki_search` (k=5) per candidate trigger:

| Candidate | Top hits | Same trigger? |
|-----------|----------|---------------|
| gh paginate + jq | minimum-case-set 0.79, infinite-scroll 0.72, cloud-cli-invocation-bounds 0.71 | No. New page |
| ktlint final newline | non-interactive-cli-invocation 0.74, evaluating-review-feedback 0.74 | No. New page; the only `.editorconfig` mention is project-local-layer (precedence of nested files), which is not adjacent enough to link |
| guard exemption | checks-that-cannot-pass 0.74, command-text-inspected-before-execution 0.74, validation-at-trust-boundaries 0.74 | No. command-text-inspected covers composing a command *for* a gate, not writing the gate's exemption. Linked both ways |
| `$` in a grep pattern | (searched as "wrapped grep") search-evidence-from-a-wrapped-grep | Same trigger, new failure mode. Merged as an edge row |
| file list collapses | changed-files-only-gates 0.77 / 0.74 / 0.73 | zsh half is a duplicate there. The `grep -Z` half is merged into bsd-vs-gnu-cli as a table row |
| seq numbering | catalog-statistics 0.79, reading-execution-plans 0.77, index-selection 0.76, soft-delete 0.76 | isolation-level-selection's trigger covers check-then-act and its insert-if-absent row; soft-delete owns live-row partial uniqueness. The incidental-invariant twist was missing, so it is merged as an edge row with soft-delete linked both ways |

No conflicts with existing directives. One pre-existing table defect was fixed because this PR edits the same index: in `wiki/platforms/index.md`, the `jq-dot-rebinding-in-predicates` row had unescaped `|` inside code spans (`$arr | index(.)`, `. as $x | $arr | index($x)`), which split the row into 5 cells. They are now `\|`, giving 2 cells.

## Open-PR check

Open `knowledge/*` heads:
- #298 (gateway aliases, Spring env names, CDN traffic path, stderr in captures, app-written status column).
- #293 (git diff algorithm and changed-line counts, `testing/quality`).

Neither carries any of these six topics, so every candidate gets the verdict **new**. Shared files: #298 also inserts a row in `wiki/platforms/index.md`, in the shells table, while this PR edits the tools table, so the hunks are apart. Both PRs append to `log.md`, the same known conflict every open flush PR has.

## Routing decision

| Candidate | Target | Action |
|-----------|--------|--------|
| 464e2f99dd9f1a0e | platforms/tools/gh-api-paginate-with-jq | new page |
| 9276633c189491e9 | backend/java/kotlin/ktlint-final-newline-from-editorconfig | new page |
| 11cd75850a5893cc | security/agent-exposure/command-guard-exemption-matching | new page |
| 46f59fe5ff46ecdf | platforms/tools/search-evidence-from-a-wrapped-grep | +1 edge row, +2 sources |
| d4c45969ee6fa70c | platforms/tools/bsd-vs-gnu-cli | +1 table row, +2 sources; zsh half already covered |
| b102d23e72af80f2 | databases/transactions/isolation-level-selection | +1 edge row, +4 sources |

No new categories. The guard page goes to security/agent-exposure: it covers the controls placed around an agent's tool use, and command guards are one of those controls.

## Independent review

A fresh-context subagent, read-only on this checkout, re-ran every reproduction. It got the same results for gh paginate, the wrapped-grep `$`, BSD `grep -Z`, ktlint 1.8.0 and the lints, and it confirmed the quotes except one. Its verdict was CHANGES_REQUESTED, and all findings were resolved:

| Finding | Resolution |
|---------|------------|
| Guard page: skipping values only for `-f`/`--jq`/`-X` lets `gh api -t <exempt-path> repos/o/r/pulls -X POST` through, because gh's `-t` and `-p` take a value | Reproduced: the naive tokenizer exempted the `-t`, `..` and unknown-option rows. Confirmed with read-only GETs that gh routes to the endpoint, not to the `-t`/`-p` value. Step 2 now carries `gh api --help`'s full table of value-taking and boolean options and treats unknown options as not exempt. The bypass table grows to 7 rows, including `repos/../r/pulls/1/comments`, which passes the full match alone and is caught by the `..` rule |
| Isolation row used the banned qualifier "usually" | Rephrased as a condition: "(one active row per parent, when the write deactivates the previous row)" |
| `re.fullmatch` quote ended "Match object"; current docs say "Match" | Quote corrected |
| gh page: `add \| length` is wrong for GraphQL pages, which are objects merged shallowly | GraphQL edge row now collects nodes, `[.[].data.<path>.nodes[]] \| length`, following gh's manual example, and step 1 limits `add` to REST array pages |
| ktlint page: the "older docs say false disables" claim had no source | ktlint 0.40.0 README line 48 cited |
| Report named the sibling PR's branch; isolation field case named a member-to-building table | The sibling is referred to as #298 only; the field case now says "a parent-to-child relation table" |
| Pre-existing broken `jq-dot-rebinding` index row | Fixed (see Existing-layer check) |

## Decision Log

- **Intent:** land the next reviewable batch from the queue (6 of 83 rows), choosing candidates that could be checked against primary sources or reproduced locally.
- **Excluded alternatives:**
  - Ingesting `46f59fe5` and `464e2f99` as written. Rejected: reproduction showed the wrong mechanism (BSD grep vs the wrapped ugrep) and an undocumented recommendation (the plain pipe vs `--slurp`).
  - A new page for `d4c45969`. Rejected: its zsh half already exists.
  - Reproducing the seq race on the shared dev databases. Rejected in favour of a throwaway local PostgreSQL cluster.
- **Where to look:**
  - The guard page's option table, which is now the security-relevant part.
  - The isolation edge row's claim that atomic numbering turns an error into two active rows.
  - The `$` row on the wrapped-grep page.
- Self-review: independent subagent review, 1 round — 7 findings, all resolved (see "Independent review").

Cross-Check: an independent fresh-context subagent re-ran every reproduction and quote check. Its 7 findings were resolved, the guard bypass with a new reproduction and gh's own option table.

## Local-layer candidates

none. Two candidates' evidence named one company's internal tables, classes and history rows. The ingested rows keep only the general mechanism and describe each field case generically.
