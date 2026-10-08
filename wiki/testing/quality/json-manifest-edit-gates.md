---
id: testing-quality-json-manifest-edit-gates
domain: testing
category: quality
applies_to: [json, git, jq]
confidence: verified
sources:
  - https://www.rfc-editor.org/rfc/rfc8259#section-4
  - https://git-scm.com/docs/git-diff
  - https://jqlang.org/manual/
  - https://git-scm.com/docs/gitrevisions
  - "Local reproduction 2026-10-08 (git 2.50.1, jq 1.7.1): append-last vs insert-first line counts, a known-bad edit with the same count, and the parsed-document gate on one good and three bad edits"
  - "Second reproduction 2026-10-08 (jq 1.7.1, monorepo layout): the gate from a package directory, a first dependency, a wrong version, a JSONC file through --argjson"
  - "Field case 2026-10-07 (a dev-loop task adding one dependency to package.json): the plan expected 2 changed lines, git diff showed 3"
last_verified: 2026-10-08
related: [testing-quality-unchanged-function-gates, testing-quality-checks-that-cannot-pass, platforms-toolchains-regeneration-silently-drops-hand-edited-state]
---

# Gating a One-Key Edit to a JSON Manifest

## When this applies

A plan, review, or done-gate must prove that an edit to a JSON file
(`package.json`, `composer.json`, a JSON config) added exactly the intended key
and changed nothing else, and the gate you are writing or reviewing counts diff
lines against an expected number: `git diff | grep -c '^[+-] '`,
`git diff --numstat`, or `--stat`.

## Do this

1. **Compare the parsed documents, not the diff's line count.** Parse the base
   and working-tree versions and assert all facts at once: the added keys are
   exactly the intended key, it carries the intended value, and every other
   value is equal.

```sh
base="$(git show HEAD:./package.json)"      # <base-ref>:./<path> when the base is not HEAD
jq -n -e --argjson a "$base" --argjson b "$(cat package.json)" --arg k zod --arg v 4.6.5 '
  ($a.dependencies // {}) as $ad | ($b.dependencies // {}) as $bd
  | (($bd | keys) - ($ad | keys)) == [$k]
  and $bd[$k] == $v
  and ($bd | del(.[$k])) == $ad
  and ($b | del(.dependencies)) == ($a | del(.dependencies))'
```

   `-e` makes the result the exit status: `true` exits 0, `false` exits 1.
   The `./` in `HEAD:./package.json` resolves the path from the current
   directory, like `cat package.json`; a bare `HEAD:package.json` is
   repo-root-relative. `// {}` lets the gate pass the first dependency a
   manifest gets.

2. **When the gate has to stay line-based** (the runner has no JSON tool, or a
   reviewer reads the diff), restrict it to the manifest path
   (`git diff -U0 -- package.json`) and assert the exact set of changed lines.
   Derive that set from where the key lands:

| Where the new key lands | Changed lines in `git diff` | `--numstat` |
|-------------------------|-----------------------------|-------------|
| Before an existing key of the same object | 1: `+` the new key | `1 0` |
| After the last key | 3: `-` the previous key, `+` the previous key with a `,`, `+` the new key | `2 1` |

   The second row is fixed by JSON's grammar: members are separated by commas
   and no comma may follow the last one, so appending a member rewrites the
   line before it, and a rewritten line counts once as removed and once as
   added.

3. **Run the gate on the real change and on a known-bad copy before adopting
   it.** The known-bad copy adds the intended key and also changes one
   neighbour value. The parsed check must exit 1 on it. A line count cannot
   catch it: the known-bad copy has the same 3 changed lines as a correct
   append ([testing-quality-checks-that-cannot-pass]).

## Edge cases

| Case | Then |
|------|------|
| The same change also rewrites a lockfile (`pnpm-lock.yaml`, `package-lock.json`) | Pass the manifest path to every diff (`git diff -- package.json`); a whole-tree count mixes the lockfile's lines into the number |
| The file is JSON with comments (JSONC) | The step-1 gate stops with "invalid JSON text passed to --argjson" (exit 2), a failure unrelated to the edit; load it with a JSONC-aware parser, or use the exact line set from step 2 |
| The base is a branch point or tag, not `HEAD` | Name it in `git show <base>:./<path>`; gating against `HEAD` after a commit compares the change with itself |
| The gate runs from a package directory of a monorepo (`apps/web`) | Keep the `./`: from `apps/web`, `git show HEAD:package.json` returned the root manifest and the gate compared two different files |
| The intended edit changes an existing value instead of adding a key | Assert `$b.<path> == <new value>` plus equality of the document with that path deleted on both sides; the key-set test in step 1 sees no added key |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Gate "one key added" on `git diff \| grep -c '^[+-] '` = 2 | Compare the parsed documents (step 1) | Appending after the last key rewrites the previous line, so a correct edit shows 3; inserting before an existing key shows 1 |
| Fix a red count gate by changing the expected number to 3 | Replace the count with the parsed check | 3 holds only when the key lands last, and the known-bad neighbour edit also shows 3, so the gate would pass it |

## Sources

- https://www.rfc-editor.org/rfc/rfc8259#section-4 — "object = begin-object [ member *( value-separator member ) ] end-object"; "A single comma separates a value from a following name." The grammar has no trailing separator, so an appended member adds a comma to the member before it
- https://git-scm.com/docs/git-diff — `--numstat` "shows number of added and deleted lines"; unified-format prefixes `-` (in A, removed in B) and `+` (added to B), so one rewritten line is counted on both sides
- https://jqlang.org/manual/ — `-e`/`--exit-status` "Sets the exit status of jq to 0 if the last output value was neither `false` nor `null`" (1 for `false`/`null`); `--argjson` passes a JSON-encoded value as a variable; `keys` returns an object's keys in an array
- Local reproduction 2026-10-08 (git 2.50.1, jq 1.7.1, scratch repo, `dependencies: {next, react}`): appending `"zod"` after `react` gave `grep -c '^[+-] '` = 3 and `--numstat` `2 1`; inserting `"axios"` before `next` gave 1 and `1 0`; appending `"zod"` while also changing `react` to `19.2.0` gave 3 again. The step-1 gate printed `true` (exit 0) on the correct append and `false` (exit 1) on the neighbour change, on a missing key, and on an extra top-level key. `jq` on a file with a `//` comment exited 5 with a parse error
- Second reproduction 2026-10-08 (jq 1.7.1, a repo with a root `package.json` and `apps/web/package.json`): the step-1 gate as written above, run from `apps/web`, exited 0 on a correct `zod` add and 1 on a neighbour change, a wrong version, an extra top-level key and no change; it exited 0 on a first dependency in a manifest with no `dependencies`, where the earlier form without `// {}` stopped with "null (null) has no keys" (exit 5). From `apps/web`, `git show HEAD:package.json` printed the root manifest and `HEAD:./package.json` the package's. A JSONC file passed through `--argjson` exited 2 with "invalid JSON text passed to --argjson"
- https://git-scm.com/docs/gitrevisions — `<rev>:<path>`: "A path starting with ./ or ../ is relative to the current working directory."
- Field case 2026-10-07 (a dev-loop task adding `"zod": "4.6.5"` as the last dependency of a Next.js project's `package.json`): the planned gate expected 2 changed lines; `git diff --stat` showed `3 ++-`, the previous dependency line rewritten with a trailing comma
