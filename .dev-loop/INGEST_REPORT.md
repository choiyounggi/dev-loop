# Knowledge flush — 3 insight(s)

Presence assertions that miss additive mutants on a fixed markup contract, zsh colon modifiers after an unbraced parameter, and `git add` exiting 1 after staging a tracked file under an ignored directory. **3 new pages, 5 pages with back-links, 0 folded, 0 dropped, 0 local-layer.**

## Verified best-practice

### 1. Assert a fixed markup contract as exact sets; prove each check with an additive mutant (queue `d9aa7d409982537e`)

- **Claim:** a presentational component's spec fixes its tags, attributes, class tokens and children, while the test run loads none of its CSS (default Vitest) and jsdom renders nothing. Presence matchers (`toHaveClass('a')`, `toHaveAttribute`) fail only when something is removed, so additions (an extra class, an inline `style`, a sibling node) pass. Assert sorted exact sets, and prove each check with a hand-seeded additive mutant.
- **Sources checked:**
  - https://github.com/testing-library/jest-dom#tohaveclass (GitHub main and the installed 7.0.1 README): `toHaveClass` checks "whether the given element has certain classes within its `class` attribute"; `{exact: true}` checks "EXACTLY a set of classes … if it has more than expected it is going to fail".
  - https://developer.mozilla.org/en-US/docs/Web/API/Element/getAttributeNames: "returns the attribute names of the element as an Array of strings".
  - https://www.w3.org/TR/SVG2/styling.html#PresentationAttributes: "Presentation attributes contribute to the author level of the cascade, followed by all other author-level style sheets, and have specificity 0."
  - https://github.com/jsdom/jsdom#unimplemented-parts-of-the-web-platform: layout "as a result of CSS" is unimplemented, and the README states jsdom "does not do any layout or rendering".
  - https://vitest.dev/config/css: "When excluded, CSS files will be replaced with empty strings to bypass the subsequent processing."
  - Tailwind: https://tailwindcss.com/docs/detecting-classes-in-source-files covers how classes are detected and turned into CSS; https://tailwindcss.com/docs/display says "Use sr-only to hide an element visually without hiding it from screen readers".
  - Stryker: https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ plus the StrykerJS v10.0.0 mutator sources.
    - No mutator builds a JSX node (all 21 files scanned), and `string-literal-mutator.ts` skips JSX attribute values.
    - `method-expression-mutator.ts` removes `filter`/`slice`/`charAt`/… calls; `equality-operator-mutator.ts` maps `<` → `<=`; `array-declaration-mutator.ts` fills `[]`.
    - So a default run changes markup only through code the component already runs: a branch, a dropped call, a loop bound, or a filled empty string or array.
- **How verified (local, 2026-10-07, Node 26.7.0, jsdom 30.1.2, jest-dom 7.0.1 matchers):**
  - Contract `<svg class="doodle" fill="none" aria-hidden="true">`: presence checks pass, exact checks pass.
  - Extra class, `style="fill: red"`, `sr-only` sibling: presence checks pass on each, exact checks fail on each.
  - Removed class: both fail.
  - Attribute reorder: `outerHTML` unequal, sorted name sets equal.
  - `getComputedStyle(…).fill`: `rgb(0, 0, 0)` for `fill="none"` (jsdom ignores the presentation attribute), `rgb(255, 0, 0)` for the style mutant.
  - With a `<style>` element present, an unlayered `.italic` rule computes as `italic`, but the same rule inside `@layer utilities` computes as `normal`. Tailwind 4.3.3's `index.css` puts its utilities in that layer.
  - An `sr-only` span with no stylesheet passes `toBeVisible()`.
  - `toHaveClass('btn btn btn', {exact: true})` passes on three distinct tokens, so the page says to list each token once.
- **Field evidence (from the queued candidate; not re-run here):** linkly-invitation, two components. Four test-quality-auditor FAILs were all additive mutants. After the switch to exact lists, the 11 surviving mutants per component all failed.
- **Added to the candidate:**
  - The page applies only when a spec fixes the markup. A new edge-case row on behavior-not-implementation says so.
  - The page prefers sorted sets over string/snapshot comparison.
  - It names what makes CSS invisible: Vitest's default, not jsdom alone.
- **Confidence:** verified.

### 2. zsh: brace a parameter that a colon follows (queue `39b1993baa535992`)

- **Claim:** in native zsh, `$name:X` applies a history-style modifier when `X` is a modifier letter, inside double quotes too. `"+refs/heads/$h:refs/…"` becomes `…xefs/…`. Write `"${h}:refs/…"`.
- **Sources checked:**
  - https://zsh.sourceforge.io/Doc/Release/Expansion.html, `${name}`: braces are not required for "a single subscript or any colon modifiers appearing after the name", an exception that applies "only … if the option KSH_ARRAYS is not set". The Modifiers list includes `f`, `F:expr:`, `w`, `W:sep:`, and the `s` entry documents the `g` prefix.
  - https://zsh.sourceforge.io/Doc/Release/Options.html: `KSH_ARRAYS <K> <S>`, which is on by default in ksh and sh emulation.
- **How verified (local, 2026-10-07, zsh 5.9 arm64, `zsh -f`; bash for comparison):**
  - Refspec: unbraced printed `+refs/heads/knowledge/xefs/remotes/origin/knowledge/x`. The braced form printed the intended refspec. bash kept the colon.
  - Probe with the follower `zz`: `a c e h l q r t u A P Q &` are consumed, `s` fails, and the rest stay literal.
  - Probe with modifier followers `e h r t`: `f g w F` are consumed too (`"$src:feature/login"` → `ature/login`, `"$svc:grpc"` → `apipc`). `F`/`W` before a delimiter and `g` before `&` are also consumed (`"$v:F:2:h"` → `.`).
  - A modifier inside the braces is zsh-only: `${v:h}` gives `dir` in zsh, `dir/file.txt` in bash and `/bin/sh`, and `Bad substitution` in dash.
  - `$img:latest` → `myappatest`; `$svc:http` → `.ttp`; `$var:status` → `dusta`; `$var:sort` → `bad substitution`, exit 1. `$img:focal`, `$host:8080`, `$host:path` and `$a:$b` are unchanged.
  - `emulate sh`, `emulate ksh` and `setopt KSH_ARRAYS` keep the colon literal. `"$h\:refs"` keeps the backslash. `"$svc[1]x"` → `ax`.
- **Added to the candidate:** the candidate named `:r :h :t :e` only. The page lists every consumed letter, the `f g w F` prefixes, the `:s` failure mode, the `KSH_ARRAYS`/emulation exception, and why a backslash is not a fix.
- **Confidence:** verified.

### 3. `git add` exits 1 after staging a tracked file under an ignored directory (queue `ada5b8ae12cf32dd`)

- **Claim:** `git add` naming a tracked file under a directory that an ignore rule matches lists that directory as ignored and exits 1. By then it has staged that file and every other named path that is not itself untracked and ignored, so `git add … && git commit` skips the commit. Stage such files with `git add -u`, stage the rest with a plain `git add`, and compare `git diff --cached --name-status` with the intended list.
- **Sources checked:**
  - https://git-scm.com/docs/git-add: "If you specify the exact filename of an ignored file, git add will fail with a list of ignored files." `-u` "adds no new files". `-f`: "Allow adding otherwise ignored files".
  - https://git-scm.com/docs/gitignore: "Files already tracked by Git are not affected". The exit 1 for a tracked file is not documented anywhere.
  - https://git-scm.com/docs/git-check-ignore: tracked files "are not subject to exclude rules; but see '--no-index'".
  - https://github.com/microsoft/vscode/issues/160653 and https://github.com/gitextensions/gitextensions/issues/10806 (Git 2.38.1.windows.1, "Exit code: 1"): the same behavior, seen independently.
- **How verified (local, 2026-10-07, git 2.50.1 Apple Git-155, one scratch repo per case):**
  - Rule `ign/` or `ign`, also via `.git/info/exclude`: exit 1, both paths staged. `add && commit` left HEAD unchanged.
  - Rule `ign/*` or `ign/t.txt`: exit 0. Rule `*.txt`: lists the untracked `other.txt`, which is not staged; exit 1.
  - Exit 0: `git add -u`, `-f` on a file, `git add .`, a bare `git add -A`, and `git commit -- <path>`. `-f ign/` also stages ignored untracked files. With `advice.addIgnoredFile=false`, the list and exit 1 remain.
  - Deleted tracked file: `git add -u -- <file>` exits 0 and stages `D`, which `--name-only` cannot tell from an update. `-u` on a path the index lacks exits 128 with nothing staged. `-u` on a directory stages deletions.
  - The split chain `git add -- other.txt && git add -u -- ign/t.txt && git commit` exits 0 and commits both.
- **Corrected from the candidate:**
  - Only a rule that matches the directory itself triggers it; `dir/*` does not.
  - The candidate's directive was "run add as its own step, commit separately". The page uses the `-u` split, which keeps `&&` chaining, plus a `--name-status` check, because `--name-only` hides a staged deletion.
- **Used in this flush:** step 4 stages the tracked `.dev-loop/INGEST_REPORT.md` (under the ignored `.dev-loop/`) with `git add -u`.
- **Confidence:** verified.

### Review

Two fresh-context reviewers checked the diff before commit.

**General (feature-dev:code-reviewer): PASS with 16 advisories. 12 applied, 4 declined.**
- Applied: index rows now list every distinct use. jsdom source anchor corrected. Page C's trigger and example use `reports/summary.md` instead of this repo's `.dev-loop/`. Two unclear zsh edge rows rewritten. "The inverse:" given an antecedent. Missing measurements added to each page's reproduction bullet.
- Declined: the 4 suggestions to add the new ids to the `related:` lines of behavior-not-implementation, tests-that-cannot-fail, portable-shell-scripts and tool-diagnostics. #223 rewrites exactly those lines (Open-PR check), so the back-links went into body rows and inline links instead. Those resolve and give the same navigation.

**Adversarial (general-purpose, opus): FAIL with 5 blockers and 6 advisories. I reproduced each one before fixing it, and all were applied.**
- *Stryker can add markup*, through `&&`→`||`, `EmptyStringToFilled` on a `className = ''` default, and StrykerJS `ArrayDeclaration` `[]` → `['Stryker was here']`. Round 1's fix listed those routes; round 2 widened it (below).
- *Vitest's element snapshot serializer sorts attribute names* (`Array.from(node.attributes, …).sort()` in vitest 5.0.3). The claim that "a snapshot changes on reorder" is gone; the snapshot row now argues incidental values and unread approvals.
- *jsdom computes inline styles and stylesheet rules.* The page now says the CSS is missing because Vitest drops it by default and jsdom renders nothing, and it adds an edge row for runs that load CSS.
- *zsh also consumes `f g w F`* before a modifier letter. A table row was added.
- *A deleted tracked file stages as `D` under `-u` with exit 0*, which `--name-only` cannot distinguish. `--name-status` is now used everywhere, including the tool-diagnostics back-link row.
- Advisories applied: the `sr-only` source, the Tailwind "maps to a utility" wording, jest-dom's subset-plus-count `exact` (list each token once), "every other named path" qualified, `-u` exit 128 on an unknown path, `-u` directory deletions.

**Round 2 (same adversarial reviewer, on the fixed text): FAIL with 2 blockers and 6 advisories. Each was reproduced, then applied.**
- *My Stryker fix was still too narrow.* Dropped `filter()`/`slice()`/`charAt()` calls and loop bounds (`i < 3` → `i <= 3` adds a child) also change markup. The page now says a default run changes markup only through code the component already runs, and that no operator builds JSX.
- *jsdom skips `@layer` rules,* where Tailwind v4 emits every utility. So loading the CSS does not make `italic` compute, and the edge row now says so.
- Advisories applied:
  - The test does see the sibling's text, and `toBeVisible()` passes on `sr-only`.
  - `F`/`W` are also consumed before a delimiter.
  - "shorter" was false.
  - In-braces modifiers differ by shell.
  - "Give both file paths" was ambiguous.
  - The index row said "the test shows nothing".
- Confirmed OK in round 2: snapshot/serialization claims, every page-C claim (re-run with the `reports/` example), the advisory fixes, and table column counts on all 244 rows.

**Round 3 (same reviewer, on the round-2 text): PASS, no findings.** It re-confirmed the StrykerJS scan (21 files; only `string-literal-mutator.ts` mentions JSX, to skip it), the `@layer` behavior, the `toBeVisible` result and every page-B and page-C value. It noted one rare edge: the boolean-literal mutator flips `hidden={false}` to `hidden=""`. That case is now in the page's list, and the claim reads "JSX with no expressions gives it none of these".

## Existing-layer check

Pages read: platforms-shells-portable-shell-scripts, testing-quality-behavior-not-implementation, testing-quality-tests-that-cannot-fail, testing-quality-unasserted-return-fields, testing-quality-surviving-mutant-equivalence-triage, testing-quality-expectation-sets-with-one-distinct-value, testing-quality-default-values-under-test, testing-e2e-e2e-stability, frontend-design-custom-property-values-read-from-script, frontend-design-design-system-lint-gate-for-agents, infrastructure-ci-cd-changed-files-only-gates, platforms-shells-unset-versus-empty-parameters, platforms-shells-escapes-in-shell-string-literals, platforms-processes-tool-diagnostics-without-a-failing-exit-code, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, platforms-tools-jq-dot-rebinding-in-predicates

- **How far each page was read:** the first four in full. For the rest, "When this applies" plus the rows the overlap grep hit. Indexes read: `INDEX.md`, `wiki/testing/index.md` (quality section in full) and `wiki/platforms/index.md` (every section).
- **`wiki_search` top 5 (k=5) for each candidate's trigger:**
  - #1: custom-property-values-read-from-script ×3 (jsdom `getComputedStyle` for custom properties), design-system-lint-gate-for-agents, e2e-stability ("styling classes are not contracts", which is about selectors, not asserted output). None has this trigger.
  - #2: portable-shell-scripts ×3, changed-files-only-gates, unset-versus-empty-parameters. None covers colon modifiers.
  - #3: worktree-isolated-workers ×3, shared-run-state, checkable-claims-in-an-adopted-plan. None covers `git add`'s exit status.
- **Grep across `wiki/`:** `modifier|colon` (zsh), `git add|paths are ignored|addIgnoredFile|gitignore` (git), and `toHaveClass|getAttributeNames|mutant|snapshot` (testing). No page states any of the three directives. The adversarial reviewer searched all 375 pages independently and found the same.
- **Merge vs. new:** all three are new triggers, so all three are new pages.
  - #2's first choice was a row in portable-shell-scripts' step-4 table of bash→zsh inversions. That page is at the 120-line body limit, so its table intro links the new page instead.
- **Conflicts:** none contradict. One tension is resolved explicitly. behavior-not-implementation advises against snapshots of whole component trees; the new page applies only when a spec fixes the markup, and a new edge-case row on behavior-not-implementation says so.
- **Links added:** back-links go in body rows (or `related:` where no open PR edits it).
  - behavior-not-implementation: edge-case row → markup-contract-assertions.
  - tests-that-cannot-fail: edge-case row → markup-contract-assertions.
  - unasserted-return-fields: `related:` += markup-contract-assertions.
  - portable-shell-scripts: inline link in the step-4 intro → colon-after-an-unbraced-parameter. No new line; the page stays at 120.
  - tool-diagnostics-without-a-failing-exit-code: edge-case row for the opposite-direction case → staging-tracked-files-under-an-ignored-directory.

## Open-PR check

All 23 open `knowledge/*` heads were listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`: #257, #256, #255, #254, #253, #249, #244, #241, #239, #238, #237, #236, #235, #234, #233, #231, #230, #229, #228, #227, #226, #225, #223.

The added lines of each head's `git diff origin/main...origin/<head> -- wiki/` were searched per candidate:

- **#1** (`toHaveClass|toHaveAttribute|getAttributeNames|classList|additive|exact (list|set|class)|markup contract|extra class|inline style|toMatchObject|jsdom`): hits in #253 (a theme-swap row naming inline `style=`), #234 (an "exact list of registered names"), #225 (a fake IntersectionObserver under jsdom) and #223 (a jsdom mock socket). None overlaps.
- **#2** (`zsh` near `modifier|colon`, `\$[a-z_]+:[a-z]`): one false positive, #241's PowerShell `$env:GITHUB_OUTPUT`. The zsh content in #235 (NOMATCH globs), #230 (heredocs), #233 (read loops), #223 (redirection) and #255 (globs) covers other behaviors.
- **#3** (`git add|paths are ignored|addIgnoredFile|add -f|git commit`): #223's new `platforms/tools/gitignore-directory-reinclusion.md` has the row "The file to keep is already tracked … later modifications are tracked regardless of the rule". Same situation, different point: #223 covers re-including a file, not `git add`'s exit 1. The #233 and #230 hits are unrelated.

| Candidate | Verdict | Note |
|-----------|---------|------|
| #1 markup-contract assertions | new | — |
| #2 zsh colon modifiers | new | — |
| #3 `git add` exit 1 | new | Same trigger as #223, different directive. #223's page is not on main, so this PR cannot link it yet. Once both merge, cross-link `platforms-tools-gitignore-directory-reinclusion` and `platforms-tools-staging-tracked-files-under-an-ignored-directory` |

**Merge-conflict notes:**
- #223 rewrites the `related:` line of behavior-not-implementation, tests-that-cannot-fail, portable-shell-scripts, tool-diagnostics-without-a-failing-exit-code and worktree-isolated-workers. This PR leaves those lines unchanged, so the two PRs do not conflict there.
- The new index rows sit at slots no open PR inserts at: after unasserted-return-fields in `wiki/testing/index.md`, and after env-var-off-switches and jq-dot-rebinding-in-predicates in `wiki/platforms/index.md`. A scratch-repo test showed git merges two insertions one line apart cleanly.
- `log.md` is appended at the end, like every open PR. Whichever merges second resolves that one append.

## Routing decision

| Insight | Layer | Target |
|---------|-------|--------|
| #1 markup-contract assertions | general | `wiki/testing/quality/markup-contract-assertions.md` (new); row after unasserted-return-fields in `wiki/testing/index.md` |
| #2 zsh colon modifiers | general | `wiki/platforms/shells/colon-after-an-unbraced-parameter.md` (new); row after env-var-off-switches in `wiki/platforms/index.md` |
| #3 `git add` exit 1 | general | `wiki/platforms/tools/staging-tracked-files-under-an-ignored-directory.md` (new); row after jq-dot-rebinding-in-predicates in `wiki/platforms/index.md` |

- **No new categories.** testing/quality holds assertion-strength pages; platforms/shells holds shell-semantics pages; platforms/tools holds CLI-behavior pages (bsd-vs-gnu-cli, jq-dot-rebinding-in-predicates).
- **Why not frontend for #1:** the directive is about what a test asserts. frontend/design pages are about building UI.
- **Why not platforms/processes for #3:** tool-diagnostics-without-a-failing-exit-code covers the opposite case (warnings with exit 0). #3 is specific to git staging, so it gets its own page plus a back-link row there.

## Local-layer candidates

none

## Run notes

- **Lock (same as #257):** `hooks/auto-flush.sh` holds the flush lock as `20261007-205826-82630` and exports that id. Step 0 of `skills/knowledge-flush/SKILL.md` generates a fresh id, so the first acquire printed `held 20261007-205826-82630 15s` (exit 3). The process tree showed the holder is this session's parent. Re-acquiring with the inherited id printed `already-owned`, and the lease was refreshed during the run (TTL 900 s).
- **Inherited worker identity (new):** the spawned flush also inherited the worker's `TMUX`/`TMUX_PANE` (tmux session `lo-2-inv1`, pane `%263`) and its working directory, the t1b task worktree. So `hooks/loop-gate.sh` gate 1 matched this session to t1b's status record (`phase=implementing`) and blocked a stop with "Finish the loop-implement cycle". The live t1b worker was still running in that pane. This flush did not emit a `status-update` for t1b and ran no tmux command that writes.
- **Lint after the edits:**
  - `node scripts/wiki-structure-checks.js wiki` → `pages: 362, indexes: 13, findings: 0` (baseline 359 pages, 0 findings).
  - `node scripts/wiki-lint-prohibitions.js wiki` → `violations: 0` (baseline 0).
  - Both checkers flagged a defect injected into a scratch copy of a new page, so they do scan the new pages.
