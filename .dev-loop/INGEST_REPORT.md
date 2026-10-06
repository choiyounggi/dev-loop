# Knowledge flush — 3 insight(s)

Claimed 27 queue rows (run id `20261007-004436-74724`): 3 `★ Insight` candidates and 24 `plan-gap` rows. Result: 2 new pages (insights 1 and 2 share one page), 2 back-links, 3 index/log rows; 24 plan-gaps retired as local-layer.

## Verified best-practice

**Insight 1 — Next.js 16 built CSS lives in `.next/static/chunks/`, not `.next/static/css/`** (row `ef8cd55ff96a447d`)
- Claim: under Next 16 the default `next build` uses Turbopack and writes CSS chunks beside JS chunks; a webpack-era glob `.next/static/css/*.css` matches nothing, so a verify command built on it can never pass (zsh aborts with `no matches found`).
- Sources: https://nextjs.org/blog/next-16 (Behavior Changes table: "Turbopack is now the default bundler for all apps; opt out with `next build --webpack`"; build banner `▲ Next.js 16 (Turbopack)`).
- Reproduction 2026-10-07, next@16.3.8, minimal App Router app with one CSS import, in a project-local scratch dir (deleted afterwards):
  - Default build: banner `▲ Next.js 16.3.8 (Turbopack)`; `find .next/static -name '*.css'` → `.next/static/chunks/1bb-rre_qc00j.css`; `ls -d .next/static/css` → No such file or directory.
  - Known-bad/contrast arm: `next build --webpack` → banner `▲ Next.js 16.3.8 (webpack)`, CSS at `.next/static/css/095cf7daa880d79a.css` — so the path is bundler-dependent and `find` covers both.
  - zsh `grep -l x .next/static/css/*.css` with no CSS there → `zsh:1: no matches found`, rc 1; `/bin/bash` → `grep: ...: No such file or directory`, rc 2.
- The exact chunk path is not stated in the Next docs; it rests on the reproduction. Confidence: **verified** (official default-bundler statement + reproducible two-arm check).

**Insight 2 — pin the tsconfig that `next build` writes** (row `0e927a3537586109`)
- Claim: Next 16 treats `jsx: react-jsx` as mandatory and appends `.next/types/**/*.ts` and `.next/dev/types/**/*.ts` to `include`, re-serializing the file; a hand-written `jsx: preserve` config is rewritten on every build; pinning the build's own output makes later builds no-ops.
- Sources: https://nextjs.org/docs/app/api-reference/config/typescript (v16.3.8: `next dev`/`next build` "add a `tsconfig.json` file with the recommended config options"; `next-env.d.ts` regenerated, belongs in `.gitignore`, must be in `include`); https://nextjs.org/blog/next-16 ("`next dev` and `next build` now use separate output directories" — why `.next/dev/types` appears); create-next-app v16.3.8 `templates/app/ts/tsconfig.json` and `templates/app-tw/ts/tsconfig.json` fetched with curl — both ship `"jsx": "react-jsx"` and the two `.next/**/types` include globs.
- Reproduction: first build printed "The following mandatory changes were made to your tsconfig.json: … jsx was set to react-jsx (next.js uses the React automatic runtime)" and "include was updated to add '.next/dev/types/**/*.ts'"; sha256 after build 1 and build 2 identical (`243562f4…e233`).
- Source code: next v16.3.8 `packages/next/src/lib/typescript/writeConfigurationDefaults.ts` (curl) — `jsx` always `value: 'react-jsx'`; `esModuleInterop`/`resolveJsonModule` omitted under `module: preserve` (TS ≥5.4); `isolatedModules` omitted under `verbatimModuleSyntax: true`; include globs from `getTypeDefinitionGlobPatterns(distDir)`. https://nextjs.org/docs/app/api-reference/config/next-config-js/distDir for the `<distDir>` edge row.
- CI guard checked in a scratch repo: `git diff --exit-code` on an untracked file → rc 0 (so the page pairs it with `git ls-files --error-unmatch`, rc 1 when untracked); tracked + modified → rc 1.
- Confidence: **verified**.

**Insight 3 — per-project hook policy lost when the shell sits in a nested repo** (row `1f8019e5875d72e3`)
- Claim: a hook that finds its project config by walking from the shell directory up to `git rev-parse --show-toplevel` stops at a nested clone's root, so the stricter global rule decides; keep the persistent shell at the project root and address the nested repo with `git -C` / one-command subshells.
- Sources: https://code.claude.com/docs/en/hooks (common input field `cwd`: "Current working directory when the hook is invoked"; "`cwd` follows Claude … the new directory after Claude runs `cd`"; `${CLAUDE_PROJECT_DIR}` is "the project root where the session started"); https://git-scm.com/docs/git-rev-parse (`--show-toplevel`: "Show the (by default, absolute) path of the top-level directory of the working tree", read from the local `git rev-parse --help`).
- Hook source read: guardrails 1.2.2 `hooks/bash-guard.sh` `find_repo_cfg` — starts at `$PWD`, bounds the walk at `git rev-parse --show-toplevel`, falls back to `~/.claude/groundwork/guardrails.json`.
- Reproduction 2026-10-07: from `outer/.claude/tmp/inner/sub` (inner `git init`) `--show-toplevel` → `…/outer/.claude/tmp/inner`; from `outer/.claude/tmp` → `…/outer`; a linked worktree at `outer/.claude/tmp/wt` → `…/outer/.claude/tmp/wt`.
- https://code.claude.com/docs/en/tools-reference (Bash tool): a `cd` carries over only inside the project or an additional working directory; outside it resets with `Shell cwd was reset to <dir>`; `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1` makes every Bash command start in the project directory — added as Do-this step 2.
- The escalation itself is the queued field report (allowed at worktree root, escalated `rm_rf` from a nested clone's subdir). Confidence: **verified** (mechanism in docs + source + reproduction).

## Existing-layer check

Routed via `INDEX.md` → `wiki/platforms/index.md` (toolchains, tools) and `wiki/frontend/index.md` (no build-output/framework-tooling category; bundle-and-assets is about bundle size). `wiki_search` (k=5) per candidate trigger:
- Insight 1 top-5: backend-common-change-impact-compiler-as-call-site-inventory (×2 chunks), testing-quality-value-preserving-refactor-assertions, debugging-signals-stack-traces, platforms-tools-version-keyed-artifact-cache — none about framework build output paths.
- Insight 2 top-5: security-secrets-secrets-in-code, platforms-tools-deny-rules-under-bypassed-permissions, testing-data-testcontainers-python-community-namespace, backend-common-change-impact-compiler-as-call-site-inventory, qa-process-scope-purity-checks — none about a build rewriting a tracked config.
- Insight 3 top-5: platforms-tools-harness-mediated-tool-results, qa-process-scope-purity-checks (×2), platforms-filesystems-paths-case-and-line-endings, backend-common-llm-project-local-layer-over-shared-guidance — none about hook config discovery vs the shell directory.
- Repo grep: `turbopack|next.js|nextjs|tsconfig` hits only compiler-as-call-site-inventory, backend/index, secrets-in-code (unrelated mentions); `show-toplevel|nested clone|guardrails` hits agent-orchestration pages about brief writing and run state, not config discovery.

Pages read: platforms-toolchains-regeneration-silently-drops-hand-edited-state, platforms-tools-deny-rules-under-bypassed-permissions, testing-quality-checks-that-cannot-pass, platforms-shells-command-text-inspected-before-execution, infrastructure-agent-orchestration-worktree-isolated-workers

Adversarial review (fresh-context `feature-dev:code-reviewer`, no shell, re-fetched every cited doc) before commit — findings and what changed:
- Unsupported: `distDir` row, the mandatory-option list, "not configurable", `git diff --exit-code` guard, `.gitignore` "untracks", cd-reset row, submodule row → each now cites source code / docs / a scratch-repo check, or is reworded (`git rm --cached`; submodule marked not reproduced).
- Wrong in a common case: page 2 said a non-root toplevel means the policy was never loaded — false for a worktree/clone of the same project with a tracked policy file. Scoped the trigger and step 4 to a nested repo without the file; edge row rewritten.
- Wording: hook start directory is "the shell directory the previous call left behind"; `CLAUDE_PROJECT_DIR` quoted from the docs.
- All quoted phrases were confirmed faithful; format (frontmatter, positive form, ≤120 lines) passed.

Outcome: no duplicate, no conflicting directive → 2 new pages.
- Created `platforms-toolchains-nextjs-16-build-output-and-tsconfig-rewrite` (insights 1+2: same tool, same "what does `next build` write" trigger family; two "When this applies" bullets).
- Created `platforms-tools-hook-config-lookup-from-shell-cwd` (insight 3).
- Back-links added: regeneration-silently-drops-hand-edited-state → nextjs page; deny-rules-under-bypassed-permissions → hook-config page.
- Back-links deferred (forward `related:` only) because an open PR rewrites that file's `related:` line: checks-that-cannot-pass (#223), command-text-inspected-before-execution (#230), harness-mediated-tool-results (#223), worktree-isolated-workers (#223), flag-availability-at-the-execution-site (#244), portable-shell-scripts (#223).
- Lint: `node scripts/wiki-structure-checks.js wiki/` → `pages: 361, indexes: 13, findings: 0`; `node scripts/wiki-lint-prohibitions.js wiki/` → `violations: 0`. Known-bad arm: same structure check on a scratch copy with a fabricated related id → rc 3, `bad-related: … resolves to no page`.

## Open-PR check

Listed 20 open `knowledge/*` heads (#223, #225–#231, #233–#239, #241, #244, #249, #253, #254) and diffed each against `origin/main` under `wiki/` for `turbopack|next.js|nextjs|tsconfig|show-toplevel|nested clone|nested git|guardrails|hook.*(config|cwd)|starting directory`. Hits: #254 (session-completion-gates row mentions `cwd` + tmux session name — worker identification, not config discovery), #244 (tsconfig `paths` alias vs Node `exports` — module resolution), #233 (TypeScript 6 `types` default — not Next build rewrites). Adjacent but distinct: #235 adds `unmatched-glob-in-a-command-argument` (zsh NOMATCH on a glob the program matches itself — the new page only cites the symptom and does not restate that guidance; not linked because the id is not on main yet) and #223 adds `hook-input-fields-from-the-reference` (hook stdin field names, not config discovery).

Verdicts: insight 1 → **new**; insight 2 → **new**; insight 3 → **new**.

## Routing decision

- Insights 1+2 → `platforms/toolchains/nextjs-16-build-output-and-tsconfig-rewrite.md`. platforms/toolchains already holds "generator rewrites a tracked file" and "version-dependent tool behavior" pages; frontend's categories cover UI code, not what a framework build writes to disk. No new category.
- Insight 3 → `platforms/tools/hook-config-lookup-from-shell-cwd.md`. The queued domain hint was infrastructure/agent-orchestration, but the mechanism applies to any Claude Code session under a cwd-scoped hook, orchestrated or not; platforms/tools already holds the harness/hook pages (deny-rules-under-bypassed-permissions, harness-mediated-tool-results). No new category.

## Local-layer candidates

All 24 `plan-gap` rows are per-task design decisions that name one repository's own files, modules and conventions — excluded from this PR. Run wiki-ingest inside that project if any should persist:
- linkly, task t189 (14 rows: `f68a1de9cb55da66`, `ca6074ccf20b52ce`, `30ef5a67fdc20ae6`, `ff2818c4c12a9039`, `b1330715aaa59008`, `797cbdc6cd089be0`, `5c402b4b5f5ef523`, `b26bda08f4c7bf18`, `2145b5849260e272`, `9a6fec94ecc06f9d`, `0b04e848c404d49a`, `2e1b7c241919e43e`, `7fcdf73748dac079`, `d5bea8aa3c9701a5` — deploy_gen module layout, `--set` option channel, capability→service mapping, YAML escaping, DNS-1035 names, goldens) → `wiki-local/infrastructure/deploy/compose-and-k8s-generators.md` — run wiki-ingest inside that project.
- linkly, task t192 (8 rows: `2c338f7472d6cca6`, `2138692f31f68a45`, `ce4b609e9fc14a83`, `d92d4cd64d7e65dd`, `e8f481402bb4b4fb`, `6700e0327e928b26`, `2252032edcc09dab`, `9df8879ea515ed17` — secret-file trailing newline, SecretProvider SPI, opener diagnostics, bookkeeping) → `wiki-local/security/secrets/secret-provider-spi.md` — run wiki-ingest inside that project.
- Next.js 16 invitation scaffold project, task t1 (2 rows: `61e0efcc16733efe`, `1d79a3953022f952` — Tailwind v4 `@theme inline` token mapping, dev-only preview route; the row does not name the repository) → `wiki-local/frontend/design/tailwind-v4-token-mapping.md` — run wiki-ingest inside that project.
