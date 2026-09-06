---
id: infrastructure-ci-cd-unparseable-workflow-file
domain: infrastructure
category: ci-cd
applies_to: [github-actions, yaml]
confidence: verified
sources:
  - https://yaml.org/spec/1.2.2/#812-literal-style
  - https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions
  - https://cli.github.com/manual/gh_workflow_run
  - https://github.com/rhysd/actionlint
  - https://github.com/choiyounggi/groundwork/pull/16
last_verified: 2026-09-06
related: [infrastructure-ci-cd-pipeline-structure, infrastructure-ci-cd-workflow-authored-pull-requests, platforms-shells-portable-shell-scripts]
---

# A Workflow File That Stops Parsing Registers No Triggers

## When this applies

A GitHub Actions workflow was added or edited and its `schedule` or
`workflow_dispatch` never fires; `gh workflow run` answers
`Workflow does not have 'workflow_dispatch' trigger`; the Actions tab or
`gh workflow list` shows the file's path (`.github/workflows/x.yml`) where the
`name:` should be. Also when writing a multi-line string (commit message, PR
body) inside a `run: |` block.

## Do this

1. **Read a path shown in place of the name as "this file did not parse."**
   GitHub displays the file path when it has no `name` to show; a file whose
   YAML breaks before `on:` is read has no name and no triggers, and the
   listing still says `active`. No failed run exists to open — the listing is
   the only signal.
2. **Keep every line of a block scalar inside its indentation.** A literal
   block (`run: |`) ends at the first line indented less than the block; a
   line starting at column 0 (the second paragraph of a commit message, a
   Markdown heading) ends the `run` value and the parser reads the rest as
   mapping keys. Write multi-line text so no line can start at column 0:

| You need | Write |
|----------|-------|
| A commit message with a body | One `-m` per paragraph: `git commit -m "title" -m "body"` |
| A PR body of several paragraphs | One `printf '%s\n\n' "..."` per paragraph into `"$RUNNER_TEMP/body.md"`, then `gh pr create --body-file "$RUNNER_TEMP/body.md"` |
| A heredoc inside `run:` | Indent the heredoc body and its terminator to the block's indentation (use `<<-` only with tab indentation), or move the text into a repo file the step reads |

3. **Parse the workflow before it ships.** Run `actionlint` (workflow-syntax
   check plus shellcheck on each `run:` block) locally or as the first CI step;
   at minimum load the YAML (`ruby -ryaml -e 'YAML.load_file(ARGV[0])' f.yml`)
   and run `bash -n` on each extracted `run:` body. A parse failure then fails
   a commit instead of silently disabling the schedule.
4. **After a fix, confirm registration from the listing, not from the diff:**
   `gh workflow list` shows the `name:` again and `gh workflow run <name>`
   accepts the dispatch.

## Edge cases

| Case | Then |
|------|------|
| The file parsed before the edit and only the schedule stopped | The edit added the column-0 line; `git log -p` on the file and look for a line inside a block scalar with less indentation than the block |
| The YAML loads locally but GitHub still lists the path | The file has no `name:` at all — the documented display for a nameless workflow, not a parse failure; add `name:` |
| A `run:` line begins with `#` at column 0 | It is a YAML comment ending the scalar, not a shell comment — indent it |
| `gh workflow run` answers 422 on a file that carries `workflow_dispatch:` in its text | The trigger is not registered because the file did not parse; fix parsing first — the trigger text being present is not evidence it is registered |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Put a multi-paragraph commit message or PR body literally inside `run: \|` | Split it into `-m` flags, or `printf` lines into a file passed with `--body-file` | The next paragraph at column 0 ends the block scalar and breaks the file |
| Debug a silent schedule by re-reading the cron expression | Check `gh workflow list` for a path shown in place of the name | A cron cannot run when the file has no registered triggers, whatever the expression says |
| Treat a green "workflow file updated" commit as proof the workflow runs | Dispatch it once (`gh workflow run`) and check that a run appears | Registration is the only observable; the commit proves nothing about parsing |

## Sources

- https://yaml.org/spec/1.2.2/#812-literal-style — "A block style construct is terminated when encountering a line which is less indented than the construct"
- https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions — "If you omit `name`, GitHub displays the workflow file path relative to the root of the repository"
- https://cli.github.com/manual/gh_workflow_run — "The given workflow file must support an `on.workflow_dispatch` trigger in order to be run in this way"
- https://github.com/rhysd/actionlint — syntax check for workflow files following the workflow syntax; shellcheck and pyflakes integrations for scripts at `run:`
- Local reproduction 2026-09-06 (macOS system Ruby 2.6 / Psych): a `run: |` block whose `git commit -m "…` message continued at column 0 failed `YAML.load_file` with `could not find expected ':' while scanning a simple key at line 13 column 1`; the same message split into two `-m` flags parsed and kept `name`
- https://github.com/choiyounggi/groundwork/pull/16 — field reproduction 2026-08-25, "sync-dev-loop-pin.yml never registered — column-0 line broke the YAML": before the fix `gh workflow run` returned `HTTP 422: Workflow does not have 'workflow_dispatch' trigger` and `gh workflow list` showed `.github/workflows/sync-dev-loop-pin.yml` as `active`; after it the workflow listed as `sync dev-loop pin` and dispatched (the listing/registration behavior is observed, not documented)
