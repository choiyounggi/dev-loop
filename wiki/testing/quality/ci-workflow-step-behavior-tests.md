---
id: testing-quality-ci-workflow-step-behavior-tests
domain: testing
category: quality
applies_to: [github-actions]
confidence: verified
sources:
  - https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell
  - https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#setting-an-output-parameter
  - https://docs.github.com/en/actions/concepts/security/script-injections
  - https://docs.github.com/en/actions/reference/security/secure-use#use-an-intermediate-environment-variable
last_verified: 2026-10-06
related:
  [
    testing-quality-source-text-wiring-assertions,
    testing-quality-behavior-not-implementation,
    testing-quality-tests-that-cannot-fail,
    infrastructure-ci-cd-pipeline-structure,
    infrastructure-ci-cd-unparseable-workflow-file,
  ]
---

# Testing the Logic Inside a CI Workflow's `run:` Step

## When this applies

A test guards a GitHub Actions workflow's inline shell step — tag computation, a
release guard, an output it writes to `$GITHUB_OUTPUT` — by checking that certain
substrings exist in the YAML (a guard condition and the line it guards). You are
writing such a test, or one is green and you must judge whether it would catch a
broken step.

## Do this

1. **Execute the step's script; assert on what it emits.** Substring checks pass
   for any arrangement of the text: moving the guarded line outside its `if`
   keeps both substrings present and the test green while the behaviour is gone.
   In the test:
   - parse the workflow with a YAML parser and select the step by `id` (or
     `name`) — the parser returns the `run:` block with its indentation removed;
   - write an empty file in the test's temp dir and pass its path as
     `GITHUB_OUTPUT` (and `GITHUB_ENV` / `GITHUB_STEP_SUMMARY` when the step
     writes them);
   - set every env var the step reads, one run per input class;
   - assert on the exact contents of the output file (`name=value` lines, or the
     `name<<DELIM … DELIM` block for multi-line values).
2. **Run the script with the runner's command line for the step's `shell:`**:

| Step's `shell:` | Run the extracted script with |
|-----------------|-------------------------------|
| absent (Linux/macOS runner default) | `bash -e <file>` |
| `bash` | `bash --noprofile --norc -eo pipefail <file>` |
| `sh` | `sh -e <file>` |
| a custom template such as `bash {0}` | that template with `{0}` replaced by the script file |

   Running it under your own shell's defaults changes the result: without
   `pipefail` a failing producer in a pipe exits 0, and an interactive profile
   adds functions and aliases the runner does not have.
3. **Pick one input per branch of the script.** For a tag step: a release tag,
   a pre-release tag (`-rc`), and the input that takes any extra branch
   (lowercasing, alias cut). Assert the full output for each, so an extra line
   and a missing line both fail.
4. **Prove each test by mutation**: move the guarded line out of its guard,
   drop a transform, change the cut, and require a named test to go red for each
   ([testing-quality-tests-that-cannot-fail]).

## Edge cases

| Case | Then |
|------|------|
| The script contains `${{ … }}` expressions | The runner substitutes them into the text before the shell runs. Move each one into the step's `env:` and read `"$VAR"` in the script — GitHub's own guidance against script injection — so the test sets an env var instead of templating source text |
| The step runs long enough to deserve its own file | Move it to a repo script the workflow calls ([infrastructure-ci-cd-pipeline-structure]) and test that script directly; keep one test that the workflow still calls it |
| The step calls a network tool or another action's output | Put a stub executable first on `PATH` for the network tool, and set the upstream `steps.<id>.outputs.*` value through `env:` as above |
| The workflow edit can break YAML parsing itself | Keep the parse as the test's first assertion — a workflow that does not parse never runs on GitHub ([infrastructure-ci-cd-unparseable-workflow-file]) |
| The step runs on a Windows runner (default `pwsh`) | The table covers Linux/macOS shells only; run the script with `pwsh -command ". '<file>.ps1'"` and write outputs with `$env:GITHUB_OUTPUT`, per the same reference pages |
| The step's job uses `defaults.run.shell` | Read the shell from the job's or workflow's `defaults` when the step has no `shell:` of its own |
| A test that reads the YAML as text must stay (it checks a trigger or permission key, not logic) | Assert the parsed key, not a substring; the parsed value fails on a misplaced key that a substring still finds |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert `grep -F 'if [[ "$TAG" != *-* ]]'` and the guarded `echo` both occur in the file | Run the extracted script with a pre-release `TAG` and assert the alias line is absent from `$GITHUB_OUTPUT` | Both substrings survive the guarded line moving outside the `if` |
| Point `GITHUB_OUTPUT` at `/dev/stdout` and match the combined stdout | Point it at a temp file and assert on that file alone | Stdout also carries the script's own `echo` lines, so an assertion on it cannot tell an output from a log line |
| Run the extracted script with plain `bash -c` | Use the runner's command for that `shell:` (step 2) | `-e`/`pipefail` decide whether a failing command stops the step |

## Sources

- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell — the "Command run internally" column: unspecified shell → `bash -e {0}`, `shell: bash` → `bash --noprofile --norc -eo pipefail {0}`, `sh` → `sh -e {0}`; the runner "executes a temporary file that contains the commands specified in the `run` keyword"
- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#setting-an-output-parameter — `echo "{name}={value}" >> "$GITHUB_OUTPUT"` and the multi-line delimiter form
- https://docs.github.com/en/actions/concepts/security/script-injections — "Before the shell script is run, the expressions inside `${{ }}` are evaluated and then substituted with the resulting values"
- https://docs.github.com/en/actions/reference/security/secure-use#use-an-intermediate-environment-variable — the env-var form for inline scripts
- Field measurement 2026-10-05 (a container-publish workflow): moving `echo "${image}:${xy}"` outside `if [[ "$TAG" != *-* ]]` left 14/14 substring tests green; after adding execution tests the same mutant failed the pre-release test, and two more mutants (no lowercasing, wrong alias cut) failed their own tests
- Reproduction 2026-10-06 (bash 5.3, Ruby `YAML.load_file` to extract the step): on the correct workflow and on the moved-line mutant the substring check passed both times; the executed step with `TAG=v1.2.3-rc.1` produced exactly `ghcr.io/acme/app:v1.2.3-rc.1` on the correct workflow and an extra `…:v1.2.3-rc` line on the mutant
