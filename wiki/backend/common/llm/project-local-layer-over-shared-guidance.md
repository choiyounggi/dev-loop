---
id: backend-common-llm-project-local-layer-over-shared-guidance
domain: backend
category: llm
applies_to: [general]
confidence: field-tested
sources:
  - https://developers.openai.com/codex/guides/agents-md
  - https://git-scm.com/docs/git-config
  - https://spec.editorconfig.org/
last_verified: 2026-09-17
related: [backend-common-llm-binding-instructions-for-agents, backend-common-llm-progressive-disclosure-artifacts, infrastructure-config-environment-config]
---

# Adding a Project-Local Layer Over Shared Agent Guidance

## When this applies

A shared, versioned body of agent guidance (a bundled wiki, a plugin's rule
set, global instructions) serves many repositories, and one repository needs
entries that apply only to it. You are deciding where that project layer lives,
how a consumer finds it, and which layer applies when both match the same
trigger.

## Do this

1. **Give the local layer one fixed, conventional path under the project root
   and commit it with the project.** Every consumer — router, linter, gate,
   test — derives the path by the same rule with nothing to resolve. Git
   (`$GIT_DIR/config`), EditorConfig (`.editorconfig`) and Codex (`AGENTS.md`
   per directory) all locate their project layer by fixed name.

2. **Resolve a same-trigger match as: local directives apply, shared entries
   stay loaded for what the local entry does not cover.** Read the shared layer
   first and the local layer last, so the local value is the one in effect for
   each key both define. All three tools above implement this order.

3. **Decide the tie by layer, then by specificity.** A local edge-case row
   overrides a shared general rule; within one layer, keep the existing
   most-specific-match rule.

4. **Make the local entry a delta.** It states what differs in this project and
   leaves the rest to the shared entry, so a shared-layer update still reaches
   the project for everything the delta does not name.

| Case | Do |
|------|----|
| Only the shared layer matches | Apply it unchanged |
| Only the local layer matches | Apply it; no shared lookup is required |
| Both match, directives agree | Apply both; the local entry adds project detail |
| Both match, directives disagree | Apply the local directive for the disagreeing point and the shared entry for every other point |

## Edge cases

| Case | Then |
|------|------|
| The path rule would read an environment variable set by the agent harness | Derive the root from the script's own location or an argument instead: a harness variable present in hook processes can be unset in the agent's shell commands and in the test runner, so production takes a fallback branch the tests never ran |
| The natural home is a tool-state directory that is git-ignored | Place the layer outside it; committing one subdirectory of an ignored tree needs a split ignore pattern that contradicts the "this directory is workspace state" rule readers rely on |
| A local entry fully replaces the shared one for this project | Say so in the local entry's first line; Codex models this as a separate `AGENTS.override.md` that is used instead of `AGENTS.md` at that level |
| The project has nested sub-projects | Closer layers win: Codex concatenates "from the root down", EditorConfig reads the closer file last |
| A local entry would be correct in any repository | It belongs in the shared layer; move it upstream and delete the local copy |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add a config key or env var that relocates the local layer | Fix the path by convention | Each knob is a resolution step every gate, linter and router must reproduce identically; one that skips it reads a different layer |
| Load only the local entry when both layers match | Load both, local last | The project never restated the shared coverage, so dropping the shared entry drops guidance nobody decided to remove |
| Resolve local-vs-shared ties by specificity alone | Layer first, specificity second | Two equally specific entries in different layers stay undecided under a specificity-only rule |

## Sources

- https://developers.openai.com/codex/guides/agents-md — "By layering global guidance with project-specific overrides…"; "Codex concatenates files from the root down, joining them with blank lines. Files closer to your current directory override earlier guidance because they appear later in the combined prompt."; `AGENTS.override.md` is checked before `AGENTS.md` and "Codex includes at most one file per directory" (page text read 2026-09-17)
- https://git-scm.com/docs/git-config — system, global, then repository files: "The files are read in the order given above, with last value found taking precedence over values read earlier."
- https://spec.editorconfig.org/ — "If multiple EditorConfig files have matching sections, the pairs from the closer EditorConfig file are read last, so pairs in closer files take precedence."
- Field context 2026-09-17 (`dev-loop` t4-local-layer plan, decisions D1 and D5): a fixed `wiki-local/` under the project root was chosen over a tools-config path knob, a git-ignored state directory, and a `CLAUDE_PROJECT_DIR` read (unset in agent Bash commands and in bats); precedence chosen as local-wins-with-shared-retained over specificity-only and local-only loading. Confidence is `field-tested` because rule 1's no-knob stance, rule 4 and the env-var and ignored-directory rows rest on this planning context alone; the precedence directives (rules 2–3, the decision table, the nested and override rows) are additionally confirmed by the three tool documents above
