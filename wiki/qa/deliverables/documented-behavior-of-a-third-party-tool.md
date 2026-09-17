---
id: qa-deliverables-documented-behavior-of-a-third-party-tool
domain: qa
category: deliverables
applies_to: [general]
confidence: verified
sources:
  - https://diataxis.fr/reference/
  - https://google.github.io/styleguide/docguide/best_practices.html
  - https://google.github.io/eng-practices/review/reviewer/looking-for.html
last_verified: 2026-09-17
related: [qa-deliverables-exclusivity-and-absence-claims, qa-deliverables-quantitative-claims-in-a-published-document, backend-common-integrations-externally-owned-defaults, platforms-toolchains-flag-availability-at-the-execution-site]
---

# A Sentence in Your Docs Stating What a Third-Party Tool Does

## When this applies

An operator-facing document you own — a skill, runbook, README, setup guide — states
a side effect of a tool your repository does not own ("`<tool> hook install` also
adds `out/` to `.git/info/exclude`", "the installer writes a `.gitignore` entry",
"the CLI creates the config directory") and the sentence cites nothing. Also when
reviewing such a sentence, and when the sentence arrived through an issue, a plan, or
a worker brief rather than from the tool.

## Do this

1. **Locate the tool's source as installed where the document's reader will run
   it, and grep it for the claimed effect before approving the sentence:**

| Where the tool lives | Find its source with |
|----------------------|----------------------|
| pipx / pip package | `pipx list` or `pip show -f <pkg>`, then grep the module that implements the subcommand |
| npm / bun package | `npm ls -g --parseable <pkg>`, then grep `node_modules/<pkg>` |
| Homebrew formula or a binary only | `<tool> --help` and `--version`, then the upstream repository at the tag `--version` prints |
| A script vendored in your own repo | grep the script — the one case the document can quote by path |

   Grep for the object the sentence names (`exclude`, `gitignore`, the output
   directory) and read every hit; a guard that only *tests* for the directory is
   not code that writes the entry.
2. **Attribute each effect to the component that produces it.** When two
   installers run in one step (the tool's own and your wrapper), write which one
   does what: "`graph-hooks.sh install` adds `graphify-out/` to `.git/info/exclude`;
   graphify's own installer does not". Reference material is "neutral description"
   whose purpose is "to describe, as succinctly as possible, and in an orderly
   way" — a merged "both also …" describes neither component.
3. **Record the version and the check next to the sentence or in the PR**:
   "verified against graphifyy 0.4.23 `hooks.py` — `grep -E 'exclude|gitignore'`
   returns only the `graphify-out` existence guard". The claim is true for that
   version; the recorded check is what the next editor re-runs when the pin moves.
4. **When the claim came from an issue, plan, or brief, treat it as unverified
   input, not as a decision already made.** The plan's author read the same issue
   text, so conformance to the plan reproduces the error. Run the sentence through
   the execution-environment check the review already applies to new CLI flags
   ([platforms-toolchains-flag-availability-at-the-execution-site]): confirm the
   behavior exists in the version present where the code runs.
5. **Link instead of restating where the tool documents the effect itself.**
   Google's docs guidance for shared technology is "Link to it instead" — point at
   the tool's own doc or source path, and keep in your document only the parts your
   wrapper adds.

## Edge cases

| Case | Then |
|------|------|
| The tool's behavior differs between the version on your machine and the version the reader installs | State the version the sentence was checked against; a behavior claim without a version is a claim about a moving target ([qa-deliverables-exclusivity-and-absence-claims]) |
| The effect exists but is conditional (only with a flag, only on first run) | Write the condition into the sentence; "also adds X" without its predicate reads as unconditional |
| The tool is closed-source or its source is unavailable | Reproduce the effect in a scratch repository (`git init`, run the installer, inspect `.git/info/exclude`) and cite that run with its version |
| A test in your repo asserts the sentence's wording (a bats gate on the `.gitignore` phrase) | Reword within the gate's anchor or update the gate in the same commit ([qa-document-verification-editing-a-gated-document]) |
| The sentence tells the reader to leave something alone because the tool "already does it" | Verify first, then keep the instruction only with the component that makes it true — when the tool does not do it, the reader is left with a broken state and an instruction not to repair it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Approve "both installers also add X" because the plan said so | Grep the installed tool's source for X and attribute the effect per component | The plan copied the issue; neither read the tool |
| Describe the combined outcome of your wrapper plus the tool as the tool's behavior | Name which component does what | A reader who runs only one of them sees a different outcome and concludes the tool is broken |
| Cite the tool's README for a side effect | Cite the source line (or a reproduced run) at the installed version | A README describes intent across versions; the installed module is what runs |

## Sources

- https://diataxis.fr/reference/ — reference material demands "accuracy, precision, completeness and clarity"; "The only purpose of a reference guide is to describe, as succinctly as possible, and in an orderly way"; the imperative is "neutral description"
- https://google.github.io/styleguide/docguide/best_practices.html — on a common technology or process: "Link to it instead."; "Dead docs are bad. They misinform"
- https://google.github.io/eng-practices/review/reviewer/looking-for.html — a reviewer checks that a change altering how users build, test, interact with, or release code "also updates associated documentation"
- Reproduction 2026-09-17 (graphifyy 0.4.23, pipx venv `site-packages/graphify/hooks.py`, 220 lines): `grep -nE 'exclude|gitignore|graphify-out' hooks.py` returns only lines 91–92, the hook script's `if [ ! -d "graphify-out" ]` existence guard; the module installs `post-commit` and `post-checkout` hooks and writes nothing to `.git/info/exclude` or `.gitignore`. dev-loop's own `scripts/graph-hooks.sh` is the component that appends `graphify-out/` to `$(git rev-parse --git-path info/exclude)`
- Field evidence 2026-09-17 (dev-loop, task t7-graph-setup, review round 1 finding F1): the skill sentence "Both also add `graphify-out/` to `.git/info/exclude`" was carried from the issue text through the plan into the worker's draft; plan conformance passed. The execution-environment lens grepped the installed tool's source, found no such handling, and the sentence was reworded to attribute the exclude entry to `graph-hooks.sh install` alone
