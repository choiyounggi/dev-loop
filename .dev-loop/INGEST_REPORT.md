# Knowledge flush — 3 insight(s)

macOS awk aborting on split multibyte text, a lint gate for agent-written Tailwind UI, and proving a function unchanged with an AST comparison. **1 page amended, 2 new pages, 4 back-links. 0 dropped, 0 local-layer.**

## Verified best-practice

### 1. macOS awk: `match()`/`substr()` over Korean text aborts → `LC_ALL=C awk` (queue `d7bc69bc97da5266`)

- **Claim (corrected):** macOS `/usr/bin/awk` (`awk version 20200816`) counts `length`/`RSTART`/`substr` in **bytes**, but POSIX says characters. So `substr(s, RSTART-1, 1)` can return half a character. A regex test on that fragment then aborts under a UTF-8 locale with `towc: multibyte conversion failure` (exit 2). Running the awk under `LC_ALL=C` makes every step byte-based and the abort goes away.
- **Correction to the queued candidate:** the candidate said awk "mixes a byte-based RSTART with character-based substr()". Measured: both are byte-based. The abort comes from the **regex step** decoding a split fragment. A `match()`+`substr()` with no regex test on the fragment did not abort.
- **Sources checked:**
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html: `length`, `match` and `substr` are defined "in characters"; `LC_CTYPE` decides how bytes become characters.
  - https://developer.apple.com/forums/thread/705559: the same `towc` error from macOS `/usr/bin/awk`; the poster reports GNU awk works.
- **How verified (local, 2026-10-06, macOS 26.1, `LANG=en_US.UTF-8`):**
  - `printf '한\n' | awk '{print length($0)}'` → `3` in both locales.
  - `printf '한R1\n' | awk '{match($0,/R[0-9]+/); p=substr($0,RSTART-1,1); if (p ~ /[A-Za-z]/) print "x"}'` → `towc: multibyte conversion failure`, rc=2. With `LC_ALL=C` → rc=0.
  - The real `_cited_rule_ids` awk from dev-loop `skills/wiki-plan/scripts/plan-gate.sh` (PR #242), run without `LC_ALL=C` on `검증 R1–R3 한글`: aborted, rc=2. With `LC_ALL=C`: printed `1 2 3 3 4 5 5`, rc=0.
- **Not verified:** the candidate's claim that Ubuntu's mawk does not fail. gawk and mawk were not installed here, so the page says this is untested.
- **Confidence:** verified (POSIX spec plus a local reproduction).

### 2. Lint gate for agent-written UI in a Tailwind design system (queue `df76e2cefa92769b`)

- **Claim:** turn prose design-system rules into `@shadcn/lint` rules, make lint-clean a done criterion, and loop the agent on diagnostics until the count is 0. On a legacy codebase, start at `warn` with a `--max-warnings` cap, or use ESLint bulk suppressions, and gate on "no new violations".
- **Sources checked:**
  - https://github.com/shadcn-ui/lint (README via `gh api`): Tailwind v4, ESLint/Oxlint, React/Svelte/Vue, the six-rule table, the per-model run table (8/8, 42–117 → 0), "10% to 48% less".
  - https://github.com/shadcn-ui/lint/blob/main/docs/evals.md: methodology, 150+ runs, the rules-only control. Labelled on the page as a **vendor eval**.
  - https://github.com/shadcn-ui/lint/blob/main/docs/adoption.md: warn, then `--max-warnings`, then bulk suppressions.
  - https://eslint.org/docs/latest/use/suppressions and https://eslint.org/blog/2025/04/eslint-v9.24.0-released/: bulk suppressions arrived in v9.24.0.
  - `packages/lint/package.json`: v0.2.0, peer `eslint >=9.30.0`, `node >=20.19`.
- **Confidence:** verified for the tool's documented behaviour and the adoption path. The effect sizes are vendor-measured and labelled as such.

### 3. Prove "function X unchanged" with an AST segment comparison, not a grep over removed diff lines (queue `ee42f6a325200abf`)

- **Claim:** a grep for `^-.*X(` in the diff fails on correct work when a call to X is re-indented. Comparing `ast.get_source_segment` of X at base and in the working tree is exact, and the gate must also be run on a deliberately changed copy.
- **Sources checked:**
  - https://docs.python.org/3/library/ast.html#ast.get_source_segment: signature, returns `None` without position info, added in 3.8.
  - https://git-scm.com/docs/git-show: the `<rev>:<path>` blob form. Checked in the local `git show --help`: "Shows the contents of the file … as they were current in the 10th last commit".
- **How verified (local, Python 3.14.6, scratch git repo):**
  - Wrapping `helper(a)` in `if a:` made the grep gate print `1`.
  - The page's own snippet, extracted from the markdown and run as is, printed `changed: []` (rc=0) on that change and `changed: ['helper']` (rc=1) after one literal inside `helper` was changed.
  - Decorator edge case checked: `get_source_segment` on a decorated `FunctionDef` returns text starting at `def`.
- **Confidence:** verified.

### Review (two fresh-context reviewers: one general, one adversarial; both returned FAIL, every finding fixed and re-checked)

- **Vendor numbers.** The run table is 8/8 for four models and 6/8 for GPT 5.6 Sol, and now says so. The "Instead of" row now reports the control runs per model: Sonnet and Opus also reached zero from rules alone; Haiku missed one task; savings were about 10%, 31% and 48%. The quoted diagnostic is now verbatim from the README.
- **Gaps in the ESLint bulk-suppressions advice, now fixed:**
  - A fixed suppressed violation makes ESLint exit non-zero until `--prune-suppressions`, which is checked against the ESLint docs. A row was added.
  - `--suppress-rule` replaced `--suppress-all`, which hides unrelated lint debt.
  - Bulk suppressions are ESLint-only.
- **Oxlint** lints only script blocks in Vue/Svelte, per the README Frameworks table. A row was added.
- **Lint-clean does not approve the design.** New tokens and variants need review, per evals.md and the red-team escapes. A row was added.
- **awk:**
  - The awk row now warns that under `LC_ALL=C` a non-ASCII literal in a bracket expression becomes a set of single bytes. Reproduced: `printf '가\n' | LC_ALL=C awk '$0 ~ /[–—]/'` matches, and the grouped `(–|—)` does not.
  - The "Linux CI" framing was removed; it had no evidence.
  - The bytes claim now has its own reproduction: RSTART=4, and `substr($0,1,1)` is byte `0xED`.
  - `last_verified` was bumped.
- **Gate snippet:**
  - A misspelled name passed vacuously (`None == None`). It now exits with `not found at base: [...]`.
  - `HEAD:./{path}` replaced `HEAD:{path}`, so the path resolves from the cwd.
  - Re-run on the page's extracted snippet: good → rc=0, typo → rc=1, subdirectory → rc=0, bad → rc=1.
  - The hunk-range "Instead of" row is corrected: base-coordinate `-U0` intersection is sound, and the row now says when it is not.
- **Separately, not in this PR:** the code comment at `skills/wiki-plan/scripts/plan-gate.sh:246` says macOS awk "mixes byte RSTART with character substr()". The measurement shows both are byte-based; the abort comes from regex-decoding a split fragment. The `LC_ALL=C` fix there is still correct; only the comment's mechanism is off.

## Existing-layer check

Pages read: platforms-environment-unicode-text-matching, testing-quality-checks-that-cannot-pass, testing-quality-guard-shape-vs-consequence, testing-quality-source-text-wiring-assertions, frontend-design-custom-property-values-read-from-script

- **Scanned by grep for overlap terms** (not read in full): platforms-shells-portable-shell-scripts, platforms-tools-bsd-vs-gnu-cli (has no awk content), frontend-design-anti-slop-visual-design, frontend-design-product-ui-vs-brand-surface, infrastructure-ci-cd-write-time-limit-guards, infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan. Also the domain indexes for platforms, frontend and testing.
- **`wiki_search` top hits (k=5):**
  - #1: unicode-text-matching (trigger + LC_ALL=C edge case), portable-shell-scripts, unset-versus-empty-parameters, option-like-argument-values.
  - #2: agent-facing-tool-surfaces, startup-time, component-composition, client-vs-server-state. None about design-system enforcement.
  - #3: checks-that-cannot-pass (×4 chunks), evaluating-review-feedback.
- **#1 → merged** into `platforms-environment-unicode-text-matching`: +1 edge-case row, +1 instead-of row, trigger sentence extended, +2 frontmatter sources, +2 Sources entries. That page already owns "a non-ASCII pattern must hold under `LC_ALL=C`". This is the same locale/byte topic with a different tool (awk) and a different failure (abort rather than silent mismatch). No conflict with its existing directive.
- **#2 → new page** `frontend-design-design-system-lint-gate-for-agents`.
  - anti-slop-visual-design states the rule in prose ("only `var(--token)`"), and write-time-limit-guards covers the baseline mechanism generically. Neither covers a design-system linter as an agent done-gate.
  - Back-links added from anti-slop-visual-design and product-ui-vs-brand-surface.
- **#3 → new page** `testing-quality-unchanged-function-gates`.
  - checks-that-cannot-pass covers gates that cannot fail on an unwritten target. guard-shape-vs-consequence covers repo-wide shape guards. source-text-wiring-assertions covers regex-on-source call-presence tests.
  - None covers "prove a named function untouched by a diff". The new trigger and directive (AST segment comparison) are distinct.
  - Back-links added from guard-shape-vs-consequence and harness-reverse-controls.
- **Deferred back-links**, because an open PR rewrites the same `related:` line and an edit here would conflict:
  - checks-that-cannot-pass (#223)
  - source-text-wiring-assertions (#241)
  - changed-files-only-gates (#235)
  - The new pages link to them forward, and the back-links can follow once those PRs land.
- **Lint:** `node scripts/wiki-lint-prohibitions.js wiki` gives `violations: 0`, rc=0. `node scripts/wiki-structure-checks.js wiki` gives `pages: 357, indexes: 13, findings: 0`, rc=0. Every `related:` id in the new and changed pages resolves to an existing page.

## Open-PR check

Open `knowledge/*` heads listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`: #241, #239, #238, #237, #236, #235, #234, #233, #231, #230, #229, #228, #227, #226, #225, #223.

Each head's `wiki/` diff against main was searched for the candidate terms:
- #1: `towc|multibyte|LC_ALL=C|substr|RSTART`
- #2: `shadcn|design.system|tailwind|eslint|bulk suppress|raw color`
- #3: `get_source_segment|not touched|unchanged function|re-indent|removed line`

| Candidate | Hits in open PRs | Verdict |
|-----------|------------------|---------|
| #1 awk towc | #241: 8 hits, all the word "substrings" in its YAML substring-test page. Unrelated. | **new** |
| #2 design-system lint gate | #231, #228: one hit each. An OWASP quote and an ESLint custom-rule tutorial URL. Unrelated. | **new** |
| #3 unchanged-function gate | none | **new** |

Line-level conflicts were avoided where possible:
- #223 rewrites the `related:` line of unicode-text-matching.md, so this PR leaves that line alone. Its new frontmatter source lines are inserted two lines away from it.
- Index rows were inserted after their nearest sibling row, not at the table end where #225, #241 and #226 append.
- `log.md` appends at the end, as every flush does.

## Routing decision

| Insight | Layer | Target |
|---------|-------|--------|
| #1 macOS awk towc | general | `platforms/environment/unicode-text-matching.md` (amended): edge-case row + instead-of row. Index load-when line extended |
| #2 design-system lint gate | general | `frontend/design/design-system-lint-gate-for-agents.md` (new). Row placed after anti-slop-visual-design in `wiki/frontend/index.md` |
| #3 unchanged-function gate | general | `testing/quality/unchanged-function-gates.md` (new). Row placed after checks-that-cannot-pass in `wiki/testing/index.md` |

No new category was needed: each insight fits an existing category.

Layer test:
- #1 names dev-loop's `plan-gate.sh` only as field evidence. The directive holds for any macOS awk script.
- #3 came from a linkly plan. The directive names no linkly code, and the field-evidence line was reworded to "an orchestration plan's task gate".

## Local-layer candidates

none
