# Knowledge flush — 12 insight(s)

Run `20260906-213602-52875` (headless auto-flush), branch `knowledge/choiyounggi-20260906-213635`.
Claimed 12 rows with `queue-claim.js claim --max 12`; 18 rows remain pending for later flushes.
Outcome: 6 new pages, 5 merges into existing pages (one reconciling a contradiction), 0 drops, 0 folds.

## Verified best-practice

1. **Pointer-attracted particle field collapses (8a6e99abdfe31e54)** — `p += (t−p)·k` with a
   stationary pointer is a contraction; nodes converge onto the cursor. Sources checked:
   Wikipedia Banach fixed-point theorem ("admits a unique fixed point"), MDN `pointerleave`
   ("moved out of the hit test boundaries"), MDN `requestAnimationFrame` ("paused in most
   browsers when running in background tabs"). Field: cover-letter review
   `.orchestration/reviews/t2-hero-code-intro-r1.md` F1 (collapse to ~8.7e-8 px; fix
   `POINTER_INNER_RADIUS=32`, clamped step, out-of-bounds null, 1000-step test; 374 green).
   Confidence: **verified** (mechanism doc-backed; numbers field).
2. **Firecrawl `onlyMainContent` drops the regions that hold contact details (407808eb70bcaf43)**
   — docs.firecrawl.dev `/scrape` reference: `onlyMainContent` default `true`, "Only return the
   main content of the page excluding headers, navs, footers, etc."; `includeTags`/`excludeTags`
   exist. `tel:` preservation is not documented — kept as field data (22/30 sites expose `tel:`,
   16/30 have the number only outside main content, 0/30 gain a number from JS rendering).
   Confidence: **verified** (mechanism) with the survey stated as field measurement.
3. **"Ask the user" binds only when the question tool is named and a hook checks the transcript
   (ebbe51aeb2082d16)** — code.claude.com hooks doc: PreToolUse input carries `transcript_path`,
   exit code 2 blocks. dev-loop PR #136 (merged 2026-08-23) introduced the wording without the
   tool name; PR #144 (merged 2026-08-25) named `AskUserQuestion` and added
   `hooks/orchestrate-ask-gate.sh` (present on main; 27 bats cases). Confidence: **field-tested**
   directive on top of doc-verified hook mechanics (page stays `field-tested`).
4. **Column-0 line in `run: |` silently unregisters a workflow (d5776de0b6e9bedb)** — YAML 1.2.2
   §8.1.2 "terminated when encountering a line which is less indented"; GitHub workflow-syntax
   doc: without `name` the file path is displayed; `gh workflow run` manual: needs
   `on.workflow_dispatch`. Local repro: Ruby Psych fails at `line 13 column 1`; two `-m` flags
   parse. Field: groundwork PR #16 (merged; 422 before, `sync dev-loop pin` listed after). The
   "listed as active with no triggers" behavior is observed, not documented — said so on the
   page. Confidence: **verified**.
5. **Actions may not create PRs until the repo setting is on (e88fdc004757a742)** — docs.github.com
   Actions settings page ("Allow GitHub Actions to create and approve pull requests") and REST
   `actions/permissions/workflow` with `can_approve_pull_request_reviews`. groundwork now reports
   `true`; PR #18 (bot, closed) → #22 (bot, merged). Confidence: **verified**.
6. **Personal-repo ruleset refuses an `Integration` bypass actor (d58c3d2dc6afce8f)** — REST
   rules reference lists `Integration` as an actor type; the personal-repo 422 is NOT in the
   docs (agent searched; only `OrganizationAdmin` is documented as personal-inapplicable). Field:
   groundwork ruleset 21371046 exists with `bypass_actors: []`, `pull_request` rule at 0
   approvals, required checks `bats/shellcheck/version-sync`. Row marked field-observed on the
   page; the page as a whole stays **verified** because the recommended path (PR + self-merge)
   rests on documented settings.
7. **GITHUB_TOKEN-pushed branches get no check runs (5a15e973f89b9ab8)** — docs.github.com
   `github_token`: "events triggered by the GITHUB_TOKEN will not create a new workflow run"
   (exceptions `workflow_dispatch`/`repository_dispatch`); PAT/App token advised. `gh pr merge`
   manual (`--auto`, `--delete-branch`), auto-delete-branches doc, cli/cli#9073 (open: `--auto -d`
   does not delete). Field re-checked live: PR #22 check-runs `total_count=0`, #25 and #27 = 6,
   `delete_branch_on_merge=true`. Confidence: **verified**.
8. **`testcontainers.community.redis` (401fd399afd7f97b)** — upstream `src/testcontainers/redis.py`
   shim emits the exact DeprecationWarning; `community/redis/__init__.py` is the new home;
   commit ab6cca8e (2026-06-05) in release `testcontainers-v4.15.0` (PyPI 2026-07-24). Local
   repro in a fresh Python 3.13 venv: warning printed, same class object, identical constructor
   signature, 45 shims ↔ 45 `community/` packages. Confidence: **verified**.
9. **Reproduce a shell bug under the script's own interpreter (c04820c7f2947876)** — bash manual
   Aliases ("Aliases are not expanded when the shell is not interactive"), Bash Startup Files,
   zsh Files (`.zshrc` only "if the shell is interactive"). Field: dev-loop issue #145 (exists,
   closed). On this machine today `command -v grep` is `/usr/bin/grep` in both contexts, so the
   ugrep half is field-only; the directive is doc-backed. Confidence: **verified** mechanism,
   field example.
10. **Assertion boundary vs symptom (c4350dda424a817e)** — Wikipedia Regression testing ("record a
    test that exposes the bug"); field: linkly-crew PR #10 (public, merged) `core.rs:426-431`.
    Confidence: **field-tested** rows on two `field-tested`/`verified` pages.
11. **Mock fabricates an id the producer formats differently (7ad0888f88a13776)** — Google Testing
    Blog "Don't mock types you don't own" ("assumptions built into mocks may get out of date"),
    Fowler ContractTest, Pact docs; field: linkly-crew PR #10 (`derive.ts` vs `dispatch.rs`,
    0/125 → 25/25). A Stripe "ids are opaque" quote the agent could not re-fetch was NOT cited.
    Confidence: **verified**.
12. **Homebrew clang ignores `SDKROOT` (57aa89b96c58268f)** — the trigger already had a page
    (`compiler-sysroot-on-macos`, verified 2026-08-29) whose step-2 row says "Export SDKROOT;
    clang reads it as the default sysroot". Local repro on Homebrew clang 22.1.8 CONTRADICTS
    that row for Homebrew LLVM: `clang -###` loads
    `etc/clang/arm64-apple-darwin25.cfg` = `-isysroot …/MacOSX26.sdk` (absent), so `SDKROOT`
    (unset / xcrun path / CLT path) all fail; `-isysroot` works; `--no-default-config` +
    `SDKROOT` works. Mechanism sourced: clang UsersManual configuration files
    (`--no-default-config`), Homebrew `llvm.rb` `write_config_files`. The candidate's own
    "SDKROOT is not a fix" claim is therefore correct **for Homebrew LLVM only**, so the
    contradiction was reconciled as a condition (see routing). Confidence: **verified**.

## Existing-layer check

Pages read: platforms-toolchains-compiler-sysroot-on-macos, infrastructure-agent-orchestration-unattended-worker-questions, platforms-shells-portable-shell-scripts, platforms-environment-path-resolution, platforms-tools-bsd-vs-gnu-cli, debugging-methodology-reproduce-first, testing-mocking-what-to-mock, backend-common-llm-binding-instructions-for-agents, qa-process-completion-claims, infrastructure-ci-cd-pipeline-structure, frontend-design-html-in-canvas, backend-common-integrations-robots-txt-and-source-selection, testing-strategy-failing-test-first, testing-quality-write-path-assertions

Also read the PR-only page testcontainers-reaper-on-docker-desktop-macos on the #186 branch
(different trigger: Ryuk socket mount, not import paths) and the root `INDEX.md` plus the
infrastructure, testing, frontend, backend, debugging, qa, platforms domain indexes.

- grep of main for `workflow_dispatch`, `can_approve`, `bypass_actors`, `GITHUB_TOKEN`,
  `testcontainers`, `firecrawl`/`onlyMainContent`, `wire format`: no hits → new pages 1–6.
- `AskUserQuestion` hits only unattended-worker-questions (worker-side out-of-band channel; a
  different trigger) → merged into binding-instructions-for-agents (body rows + sources; the
  `related:` line was left untouched because #179 rewrites it — the back-link to
  unattended-worker-questions is in the new edge-case row text instead).
- `sysroot` hits compiler-sysroot-on-macos → **conflict flagged and reconciled**: the step-2
  `SDKROOT` row now carries the "when no `-isysroot` reaches the driver" condition, a new edge
  row explains the Homebrew config file, an Instead-of row and three Sources bullets were added;
  `log.md` records it as a reconciled contradiction. Frontmatter untouched (#179 rewrites
  `related:`), so the new URLs live in the body Sources section only.
- reproduce-first (untouched by any open PR): two edge rows + two Instead-of rows + sources +
  frontmatter (`sources`, `last_verified`, `related` += path-resolution, completion-claims).
- completion-claims: one claim/evidence row inserted after "Bug fixed" and one Sources bullet
  before the superpowers bullet — positions chosen so #179's hunks (last table row, appended
  sources) stay one unchanged line away. Frontmatter untouched (#179 rewrites it).
- what-to-mock: one edge-case row linking the new producer-wire-format page; #179/#183 rewrite
  its frontmatter and #183 edits the Do table and Sources, so nothing else was touched.
- Back-links NOT added (frontmatter owned by open PRs): html-in-canvas → pointer page (#181),
  what-to-mock → producer-wire-format (#179/#183), unattended-worker-questions → binding
  instructions (frontmatter untouched by PRs but the row text link suffices).
- Index rows: 6 new rows (infrastructure ci-cd ×2, backend integrations, testing data, testing
  mocking, frontend design); load-when text extended on compiler-sysroot (platforms),
  binding-instructions (backend), reproduce-first (debugging), completion-claims (qa).
- Lint: `wiki-structure-checks.js wiki` 282 pages / 0 findings; `wiki-lint-prohibitions.js wiki`
  0 violations; every new page ≤ 65 body lines, merged pages ≤ 94.

## Open-PR check

Open `knowledge/*` heads listed and fetched: #186 (20260906-013856), #185 (20260906-003745),
#183 (20260904-133717), #182 (20260903-214027), #181 (20260903-203836), #180 (20260903-184706),
#179 (20260903-172728). Each diffed against `origin/main -- wiki/` and grepped for the candidate
terms (GitHub Actions, GITHUB_TOKEN, firecrawl, community.redis, AskUserQuestion, corr-, ugrep,
`/bin/sh`, assertion boundary, wire format).

| Candidate | Overlapping open head | Verdict |
|-----------|-----------------------|---------|
| 8a6e99ab pointer field | none (#181 "spatial clamp" is server-side coordinate validation) | new |
| 407808eb Firecrawl | none | new |
| ebbe51ae ask-tool gate | #179 touches binding-instructions `related:` only; #180 unattended-worker-questions is worker-side | new (merge on main page, body only) |
| d5776de0 YAML block scalar | none | new |
| e88fdc00 create-PR setting | none | new |
| d58c3d2d ruleset bypass | none | new |
| 5a15e973 required checks | none | new |
| 401fd399 testcontainers import | #186 testcontainers-reaper (Ryuk socket; different trigger) | new (separate page; no link to the PR-only page so main stays link-clean) |
| c04820c7 shell repro path | #180/#181 edit portable-shell-scripts / path-resolution bodies on other rows | new (merged into reproduce-first, which no PR touches) |
| c4350dda assertion boundary | #179 edits completion-claims (different rows) | new (rows placed away from its hunks) |
| 7ad0888f mock wire format | #183 edits what-to-mock Do table + Sources | new (own page + one edge row) |
| 57aa89b9 sysroot | #179 touches compiler-sysroot `related:` only | new (body-only merge) |

No fold and no pending-duplicate drop this run. The earlier sibling hash 35922b00 (same
sysroot trigger, 2026-08-05) is already `processed`; this row added the config-file mechanism
that page lacked, so it was merged rather than dropped.

## Routing decision

| Candidate | Target | Page |
|-----------|--------|------|
| 8a6e99ab | frontend/design | **new** `pointer-attracted-particle-fields` |
| 407808eb | backend/common/integrations | **new** `contact-details-from-scraped-pages` |
| ebbe51ae | backend/common/llm | **merge** `binding-instructions-for-agents` |
| d5776de0 | infrastructure/ci-cd | **new** `unparseable-workflow-file` |
| e88fdc00 + d58c3d2d + 5a15e973 | infrastructure/ci-cd | **new** `workflow-authored-pull-requests` (one situation — a workflow landing its own PR — with four settings as a decision table) |
| 401fd399 | testing/data | **new** `testcontainers-python-community-namespace` |
| c04820c7 | debugging/methodology | **merge** `reproduce-first` |
| c4350dda | qa/process + debugging/methodology | **merge** `completion-claims` (claim/evidence row) and `reproduce-first` (edge row) |
| 7ad0888f | testing/mocking | **new** `producer-wire-format-in-mocks` + edge row in `what-to-mock` |
| 57aa89b9 | platforms/toolchains | **merge** `compiler-sysroot-on-macos` (contradiction reconciled as a condition) |

No new category: ci-cd, integrations, data, design, mocking, methodology, process, llm and
toolchains all cover their candidates' triggers under their existing "route here" lines.
