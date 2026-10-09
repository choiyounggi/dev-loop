# Knowledge flush — 3 insight(s)

3 new pages, 5 back-links, 0 dropped, 0 folded. Queue rows: `0340c831f8181183`, `68be9b82b3aef477`, `e6863821c35717ab`.

## Verified best-practice

### 1. Test a CI workflow's `run:` step by executing it — `verified`
**Claim:** a test that checks substrings in the workflow YAML still passes after a guarded line moves outside its `if`. Instead, extract the step's script with a YAML parser and run it with the runner's own shell command. Point `GITHUB_OUTPUT` at a temp file, run one input per branch, and assert on the exact output.

**Sources checked (downloaded and grepped):**
- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell gives the commands the runner uses: `bash -e {0}` when `shell:` is unset, `bash --noprofile --norc -eo pipefail {0}` for `shell: bash`, `sh -e {0}` for `sh`, and `pwsh -command ". '{0}'"` on Windows. It also says the runner "executes a temporary file".
- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#setting-an-output-parameter gives the `name=value` form and the multi-line delimiter form.
- https://docs.github.com/en/actions/concepts/security/script-injections says `${{ }}` is "evaluated and then substituted" before the shell runs.
- https://docs.github.com/en/actions/reference/security/secure-use#use-an-intermediate-environment-variable gives the `env:` form for passing values into inline scripts.

**How verified:**
- Reproduction on 2026-10-06 (bash 5.3, Ruby `YAML.load_file`): the substring check passed on both the correct workflow and the moved-line mutant. The executed step produced exactly one tag line on the correct workflow, and an extra `…:v1.2.3-rc` alias line on the mutant.
- Field evidence from the candidate: 14/14 text tests stayed green under the mutant, while the executing tests killed it and 2 other mutants.

### 2. Per-call effort for a Claude Code subagent needs one agent file per level — `verified`
**Claim:** the Agent tool takes a per-call `model` but has no `effort` parameter. Effort comes only from agent (or skill) frontmatter. So per-call effort means a base file plus generated variants, with a `--check` drift gate.

**Sources checked (downloaded `.md` and grepped):**
- https://code.claude.com/docs/en/sub-agents#supported-frontmatter-fields describes the `effort` field.
- https://code.claude.com/docs/en/sub-agents#choose-a-model gives the model order: per-invocation `model`, then frontmatter, then `CLAUDE_CODE_SUBAGENT_MODEL`. It also covers `_FORCE` and the `/tasks` effort display (v2.1.242+).
- https://code.claude.com/docs/en/model-config#adjust-effort-level says frontmatter effort overrides "the session level but not the environment variable". It also covers the `maxEffortLevel` cap and the fall-back for unsupported levels.

**How verified:**
- The Agent tool's input schema was read in this session; it has no effort field.
- One inference is labelled in the page's Sources: that frontmatter overrides `--effort` comes from model-config listing `--effort` as setting the session level. It was not measured separately.

**Edge case added:** a parent session started with `CLAUDE_CODE_EFFORT_LEVEL` forces that level on every subagent variant.

### 3. Uploading through a dynamically created file input in headless Chromium — `verified`
**Claim:** headless Chromium cancels the native file chooser immediately. A picker that resolves on whichever of `change` or `cancel` fires first, as expo-document-picker on web does, therefore reports "canceled". The fix is to intercept the chooser before the click.

**Sources checked:**
- `expo-document-picker/src/ExpoDocumentPicker.web.ts` on `main` (read): it listens for `change` and `cancel`, then calls `input.dispatchEvent(new MouseEvent('click'))`.
- Chromium `content/public/browser/web_contents_delegate.cc`: the default `RunFileChooser` is `listener->FileSelectionCanceled();`.
- Chromium `headless/lib/browser/headless_web_contents_impl.cc` has no `RunFileChooser` override.
- CDP `Page.pdl` and `DOM.pdl` define `setInterceptFileChooserDialog`, `fileChooserOpened.backendNodeId` and `setFileInputFiles`.
- Playwright docs/src/input.md says to call `waitForEvent('filechooser')` before the click for inputs created on the fly.
- Puppeteer's `page.waitForFileChooser` docs.
- The DOM spec's canceled-flag algorithm and its `EventInit.cancelable = false` default.
- MDN on the `cancel` event.

**How verified:** measured on 2026-10-06 with Playwright 1.58.2 and Chromium 145.0.7632.6, in both the headless shell and full headless mode:
- A naive click resolved `canceled: true`.
- `waitForEvent('filechooser')` delivered the file, and so did a `dispatchEvent` wrapper.
- A capture-phase `preventDefault()` did **not** deliver the file. The constructed click has `cancelable: false`, so `defaultPrevented` stayed `false`.
- When the picker calls `input.click()` instead, the click is cancelable: `preventDefault()` delivered the file and the wrapper did not.
- Field evidence from the candidate: 0 requests before the change, and a multipart request returning 200 after.

**Rewritten from the candidate:** the candidate's directive, "block the click event", is only half right. The page now splits the page-JS route by how the picker opens the input. The adversarial review caught this, and the measurement above confirmed it.

## Existing-layer check
Pages read: testing-quality-source-text-wiring-assertions, testing-quality-behavior-not-implementation, testing-e2e-e2e-stability, qa-document-verification-generated-reference-drift-gates

Indexes read: `INDEX.md`, `wiki/testing/index.md`, `wiki/platforms/index.md`, `wiki/infrastructure/index.md`, plus grep for agent/effort rows across the backend and qa indexes.

wiki_search, top 5 hits per candidate:
- **Candidate 1:** infrastructure-ci-cd-pipeline-structure, platforms-shells-portable-shell-scripts, infrastructure-ci-cd-changed-files-only-gates, debugging-methodology-reproduce-first, platforms-toolchains-version-management.
- **Candidate 2:** infrastructure-agent-orchestration-usage-limit-paused-workers (×2), backend-common-llm-context-window-budget, qa-process-agent-tool-parity-gate, qa-process-fresh-context-code-review.
- **Candidate 3:** qa-process-scope-purity-checks, debugging-methodology-reproduce-first, frontend-forms-dropzone-copy-without-drop-handlers, testing-quality-assertion-scanner-false-positive-on-unittest-convention, backend-common-storage-object-key-persistence.

**Overlaps:**
- Candidate 1 is closest to source-text-wiring-assertions. That page covers regex guards over application source where no seam exists; a workflow step does have an executable seam, so the trigger differs. That page is also at the 120-line body limit, so this is a new page that links to it.
- pipeline-structure's "move inline YAML into a repo script" is referenced as an edge-case row, not duplicated.
- Candidate 2 has no existing page on subagent effort. usage-limit-paused-workers covers the per-call `model` override only.
- Candidate 3 has no existing page on file choosers. e2e-stability covers selector and wait strategy.
- No conflicts flagged.

**Merged vs created:** 3 new pages, 0 merges.

**Related links added both ways:**
- source-text-wiring-assertions and unparseable-workflow-file ↔ the new ci-workflow page
- usage-limit-paused-workers and generated-reference-drift-gates ↔ per-call-subagent-effort
- e2e-stability ↔ dynamic-file-input page

## Open-PR check
I listed 15 open `knowledge/*` heads with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`: #223, #225, #226, #227, #228, #229, #230, #231, #233, #234, #235, #236, #237, #238, #239. For each head I ran `git diff origin/main...origin/<head> -- wiki/` and grepped it for the candidates' key terms (`GITHUB_OUTPUT`, `run:` script tests, `effort`, `subagent_type`, `document-picker`, `filechooser`, `setInputFiles`, `input.click`, `cancel event`). Every head had 0 hits. A control grep for `multer` on #233 returned 25, so the search was working.

None of the open heads touches the target files: `testing/quality/ci-workflow-*`, `platforms/tools/per-call-*` and `testing/e2e/*`.

Verdicts:
- Candidate 1: **new**
- Candidate 2: **new**
- Candidate 3: **new**

## Routing decision
| Candidate | Target |
|---|---|
| 1 | `wiki/testing/quality/ci-workflow-step-behavior-tests.md` — testing/quality. The artifact being changed is a test's assertion strategy, so testing owns it over infrastructure/ci-cd. |
| 2 | `wiki/platforms/tools/per-call-subagent-effort.md` — platforms/tools, next to the other Claude Code mechanics pages (deny rules, MCP registration, permission classifier). |
| 3 | `wiki/testing/e2e/dynamic-file-input-uploads-in-headless-chromium.md` — testing/e2e. |

No new categories were created.

## Local-layer candidates
none — all three are general. Candidate 2 came from the dev-loop repo's own tier profile work, but its directive holds for any Claude Code plugin or orchestrator.

## Review
11 files changed, so this got two fresh-context reviews:
- **General reviewer** (feature-dev:code-reviewer): PASS with 4 low-severity notes. Three are applied: the `--effort` inference is labelled, a Windows-runner row was added, and the chooser mechanism is now backed by a measurement. The fourth (full headless mode unknown) is now measured.
- **Adversarial reviewer:** FAIL on 1 high-severity finding. `preventDefault()` cannot cancel expo's constructed `new MouseEvent('click')`. This was reproduced in Chromium 145 and fixed by the page-JS row split above. Its other 5 attack items returned no finding.

Checks after the fixes:
- `node scripts/wiki-lint-prohibitions.js` reports `directives: 79`, `violations: 0`. The bats pin of 79 is unchanged.
- `bats` over `tests/wiki-structure-checks.bats`, `wiki-index.bats`, `wiki-lint-prohibitions.bats`, `wiki-lint-score.bats`, `wiki-lint-model-era.bats` and `wiki-contradiction.bats`: 113/113 ok.
- Body lines are 73, 61 and 71, all within the 120-line limit.
