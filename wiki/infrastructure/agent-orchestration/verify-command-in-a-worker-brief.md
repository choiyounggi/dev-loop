---
id: infrastructure-agent-orchestration-verify-command-in-a-worker-brief
domain: infrastructure
category: agent-orchestration
applies_to: [general, python, node]
confidence: verified
sources:
  - https://docs.python.org/3/library/venv.html
  - https://docs.python.org/3/library/unittest.html
  - https://vitest.dev/guide/filtering
  - https://git-scm.com/docs/githooks
  - https://git-scm.com/docs/gitrepository-layout
  - "Local reproduction 2026-10-11 (Vitest 5.0.3, zsh 5.9, GNU bash 5.3.15): literal, escaped and pattern forms of route-group and dynamic-segment test paths"
last_verified: 2026-10-24
related: [platforms-environment-path-resolution, platforms-toolchains-version-management, platforms-toolchains-compiler-sysroot-on-macos, qa-process-completion-claims, testing-quality-tests-that-cannot-fail, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-done-criteria-in-a-split-task-piece, testing-quality-checks-that-cannot-pass]
---

# The Test Command Written Into a Worker's Brief

## When this applies

You are writing the "run the suite and confirm it passes" line of a brief,
prompt, or done criterion for a subagent or worker session, and you are about to
write it as a bare interpreter name (`python3 -m unittest`, `pytest`, `node`) plus
"must pass". Also when a worker reports a wall of import failures as
"pre-existing environment problems".

## Do this

1. **Write the interpreter by path, not by name.** In a repo with a project
   virtual environment, a bare `python3` resolves through the caller's `PATH`; a
   session that never activated the venv gets the system interpreter and fails
   on every import the venv provides. Activation only prepends the venv's `bin`
   to `PATH`, and the venv docs state the interpreter can be invoked by its full
   path without activation — the path form behaves the same in every session:

| Bare form | Path form |
|-----------|-----------|
| `python3 -m unittest discover` | `.venv/bin/python -m unittest discover` (or `uv run python -m unittest discover`) |
| `pytest` | `.venv/bin/python -m pytest` |
| `node script.js` in a version-managed repo | the managed binary by path, or explicit manager init first ([platforms-toolchains-version-management]) |

2. **Name every environment the command needs on the same line** — `PATH`
   prefixes for keg-only tools, `CPATH`/`SDKROOT` for compiled extensions —
   because the worker's shell is not yours ([platforms-environment-path-resolution],
   [platforms-toolchains-compiler-sysroot-on-macos]).

3. **Run that exact command on the base branch first and paste its summary
   line into the brief as the expected result.** "Must pass" is false for a repo
   whose baseline is not green, and it cannot separate the worker's regression
   from a pre-existing failure. Write the numbers and the failing ids:

```
Verify:   .venv/bin/python -m unittest discover -s tests
Baseline: main @ <sha> → Ran 3549 tests … FAILED (failures=1); the failure is tests/x_test.py::test_y (pre-existing)
Done:     Ran ≥ 3549, failures ≤ 1, and the only failure is that same test id
```

4. **Make the total part of the criterion.** A worker that breaks an import
   sees fewer tests and a green-looking run; the `Ran N` against the baseline N
   is what catches it ([testing-quality-tests-that-cannot-fail],
   [qa-process-completion-claims]).

## Edge cases

| Case | Then |
|------|------|
| The repo ships an environment doctor (`scripts/dev_doctor.sh`, `make check-env`) | Put it first on the verify line; when import failures are environmental it names the missing pieces, and the worker has nothing left to call pre-existing |
| The baseline has many failures | List them by test id; a bare `failures=15` lets a new failure hide inside the count |
| The worker reports "environment problem, failures are pre-existing" | Compare its `Ran N` and its failure ids with the baseline line; a mismatch in either is the worker's change, not the environment |
| The tests spawn subprocesses with `sys.executable` | The path form propagates the venv interpreter; a bare name resolves again in the child |
| No venv exists and the system interpreter is the intended one | Still write the path (`/usr/bin/python3`), so a later venv or a different `PATH` cannot change what the brief means |
| The task's deliverable is a new numbered/spec document (RFC, ADR) in a repo with doc-currency gates (a README-count test, a generated-reference `--check`) | Name those gate tests on the task's own verify line and include the files they read (README rows, the routes/registry constant) in the task's scope, not only at integration |
| The verify line passes Vitest a test file whose path holds `(`, `)`, `[` or `]` (a Next.js route group `src/app/(group)/page.test.tsx`, a dynamic segment `[slug]`) | Single-quote the path for the shell and leave it unescaped for Vitest: Vitest runs the files "whose path contains the given string", a plain substring, so `'src/app/(group)/page.test.tsx'` selects the file, while an escaped or pattern form (`\(group\)`, `layou[t]`, `.*`) selects nothing and exits 1 with "No test files found". Unquoted, zsh stops with "no matches found" and bash with a syntax error at `(`; bash also rewrites an unquoted `[slug]` to `src/app/s/…` when such a path exists |
| The brief tells a worker to skip local verification (CI judges) and push from a freshly created worktree | Have it read the repo's push hook first (`.husky/pre-push`, or the `core.hooksPath` directory) and install dependencies before the push (`pnpm install --frozen-lockfile`) even though it runs no checks itself. A linked worktree uses the common directory's hooks but gets no `node_modules`, so a hook that calls a repo tool dies (`tsx: command not found`) and git aborts the push. "No local verification" covers what the worker chooses to run, not what the repo enforces at push, so the fix is installing dependencies with the hook left on. Judge the push by git's own status (`set -o pipefail`, or `${PIPESTATUS[0]}`) — `git push … | tail; echo $?` prints `tail`'s 0 over a rejected push ([testing-quality-checks-that-cannot-pass]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `python3 -m unittest … must pass` | Write the venv path plus the baseline `Ran N … failures=M` line | Bare names resolve per session; "pass" has no meaning on a non-green baseline |
| Let the worker measure the baseline itself | Measure it on the base branch with the same command and put it in the brief | A baseline measured on the worker's changed tree is the thing in question |
| Accept "the failures are environmental" from the worker's report | Diff its totals and ids against the brief's baseline | Import errors and regressions both read as "environment" in a self-report |
| Scope a new-document task's brief to the document directory only, and check currency gates only at integration | Include the repo's README-count and generated-reference tests on that task's own verify line from the start | The gates fail deterministically at integration once every task lands; one in-task test run catches a missing registry entry before it costs a full rework round-trip |
| Regex-escape a route-group path on a Vitest verify line (`src/app/\(group\)/page.test.tsx`) | Single-quote the literal path | Vitest matches the filter as a substring, so the escaped text matches no file and the gate can never pass |

## Sources

- https://docs.python.org/3/library/venv.html — activation "will prepend that directory to your PATH"; "You don't specifically need to activate a virtual environment, as you can just specify the full path to that environment's Python interpreter when invoking Python"
- https://docs.python.org/3/library/unittest.html — the text runner's `Ran N tests in …` summary followed by `OK` or `FAILED (failures=M, errors=E)`; reproduced 2026-09-03 with a 3-test case: `Ran 3 tests … FAILED (failures=1, errors=1)`
- Field measurement 2026-08-31 (linkly, one worktree): `python3 -m unittest` → Ran 3532, failures=15, errors=18; `.venv/bin/python -m unittest` → Ran 3549, failures=1. All 33 extra failures were `ModuleNotFoundError: jsonschema` and a missing MLIR toolchain, both named by the repo's `scripts/dev_doctor.sh`; the repo's own baseline was one failure, so "must pass" could never have been met
- Field evidence 2026-08-29 (linkly, run `enf0829`): a task briefed to add RFC-0043 was scoped to its document directory only, with the currency gates left for integration; the integration suite failed 10 cases, 9 on `test_readme_currency` plus 1 on `test_plugin_references`, from one missing `RFC_ROUTES["0043"]` entry and its README rows. Fixed and re-run at 3374 tests OK; a verify line naming those two tests inside the doc task would have caught it before integration
- https://vitest.dev/guide/filtering — "Vitest will only run test files whose path contains the given string"; a `file:line` target "requires the full filename (relative or absolute)"
- Local reproduction 2026-10-11 (Vitest 5.0.3; zsh 5.9; GNU bash 5.3.15): `vitest run 'src/app/(group)/page.test.js'`, `'src/app/[slug]/page.test.js'`, `'(group)'`, `'app/(gr'` and `layout` each selected their file; `'src/app/\(group\)/page.test.js'`, `'src/app/layou[t].test.js'` and `'src/app/.*'` printed "No test files found, exiting with code 1". Unquoted, zsh printed `no matches found: src/app/(group)/page.test.js` (and the same for `[slug]`), bash printed ``syntax error near unexpected token `('`` and passed `src/app/[slug]/page.test.js` through unchanged until a `src/app/s/page.test.js` existed, then substituted that path
- Field origin 2026-10 (linkly-invitation task t5; recorded by the originating session): a plan's verify commands named route-group test files; `vitest run 'src/app/layou[t].test.tsx'` printing "No test files found" (exit 1) showed that the filter is not a regex before the commands were adopted
- https://git-scm.com/docs/githooks — pre-push: "If this hook exits with a non-zero status, `git` `push` will abort without pushing anything"; hooks live in `$GIT_DIR/hooks` "or `git config core.hooksPath`"
- https://git-scm.com/docs/gitrepository-layout — `hooks`: "This directory is ignored if $GIT_COMMON_DIR is set and \"$GIT_COMMON_DIR/hooks\" will be used instead" (linked worktrees share the main repository's hooks)
- Field observation (pnpm monorepo, husky pre-push running a code generator through `tsx`): the first push from a new worktree was rejected (`failed to push some refs`) while a piped `echo "RC=$?"` showed 0; `PIPESTATUS` exposed the failure; after `pnpm install --frozen-lockfile` (20 s) the hook ran 31 turbo tasks (8 m 39 s) and the push succeeded
