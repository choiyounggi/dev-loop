---
id: infrastructure-agent-orchestration-verify-command-in-a-worker-brief
domain: infrastructure
category: agent-orchestration
applies_to: [general, python, node]
confidence: verified
sources:
  - https://docs.python.org/3/library/venv.html
  - https://docs.python.org/3/library/unittest.html
last_verified: 2026-09-03
related: [platforms-environment-path-resolution, platforms-toolchains-version-management, platforms-toolchains-compiler-sysroot-on-macos, qa-process-completion-claims, testing-quality-tests-that-cannot-fail, infrastructure-agent-orchestration-worktree-isolated-workers]
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

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `python3 -m unittest … must pass` | Write the venv path plus the baseline `Ran N … failures=M` line | Bare names resolve per session; "pass" has no meaning on a non-green baseline |
| Let the worker measure the baseline itself | Measure it on the base branch with the same command and put it in the brief | A baseline measured on the worker's changed tree is the thing in question |
| Accept "the failures are environmental" from the worker's report | Diff its totals and ids against the brief's baseline | Import errors and regressions both read as "environment" in a self-report |

## Sources

- https://docs.python.org/3/library/venv.html — activation "will prepend that directory to your PATH"; "You don't specifically need to activate a virtual environment, as you can just specify the full path to that environment's Python interpreter when invoking Python"
- https://docs.python.org/3/library/unittest.html — the text runner's `Ran N tests in …` summary followed by `OK` or `FAILED (failures=M, errors=E)`; reproduced 2026-09-03 with a 3-test case: `Ran 3 tests … FAILED (failures=1, errors=1)`
- Field measurement 2026-08-31 (linkly, one worktree): `python3 -m unittest` → Ran 3532, failures=15, errors=18; `.venv/bin/python -m unittest` → Ran 3549, failures=1. All 33 extra failures were `ModuleNotFoundError: jsonschema` and a missing MLIR toolchain, both named by the repo's `scripts/dev_doctor.sh`; the repo's own baseline was one failure, so "must pass" could never have been met
