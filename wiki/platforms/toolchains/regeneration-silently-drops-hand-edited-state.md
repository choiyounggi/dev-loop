---
id: platforms-toolchains-regeneration-silently-drops-hand-edited-state
domain: platforms
category: toolchains
applies_to: [xcodegen, ios, general]
confidence: verified
sources:
  - https://github.com/yonaskolb/XcodeGen
  - https://github.com/yonaskolb/XcodeGen/blob/master/Docs/FAQ.md
  - https://github.com/yonaskolb/XcodeGen/issues/515
  - https://github.com/yonaskolb/XcodeGen/issues/572
last_verified: 2026-09-08
related: [platforms-toolchains-environment-resync-removes-undeclared-packages, platforms-toolchains-version-management]
---

# Regenerating a Generator-Owned Project File That Is Also Hand-Edited

## When this applies

A code-generation tool writes a file the repository also commits (XcodeGen's
`.xcodeproj` from `project.yml`, or a similar codegen-plus-hand-edit setup) and
that committed file has also been edited outside the generator's spec — a target
or scheme added through the Xcode GUI, a manual patch to generated code. You are
about to run the regenerate command to make one small, unrelated change.

## Do this

1. Treat the spec (`project.yml`) as authoritative only for what it declares. The
   generator performs a full regeneration, so anything present in the committed
   output but absent from the spec has no representation there and is deleted,
   not merged, on the next run. Confirmed on XcodeGen: a scheme created via the
   Xcode GUI defaults to shared, and "if a user forgets to uncheck that when
   creating a custom scheme, their schemes will be overwritten the next time
   they generate" (issue #515); a second report independently confirms "running
   xcodegen will overwrite that xcscheme file" (issue #572).
2. Right after running the regenerate command, check the delta before accepting
   it: `git diff --stat <generated-file-path>`. A nonzero deletion count on a run
   meant to add one key is the signal that the spec is missing something the
   committed file carried — targets, schemes, or build settings added outside it.
3. When there is a loss, `git checkout -- <generated-file-path>` to discard the
   regenerated file, then re-apply only the specific change you wanted (hand-edit
   the one key, or first add the missing target/scheme to the spec and regenerate
   again) so the regeneration lands on a spec that actually has parity with what
   is committed.
4. Close the gap at the source rather than repeatedly discarding regen output:
   add any GUI-created target/scheme to `project.yml` so it becomes declared and
   survives regeneration. XcodeGen's own FAQ frames a committed `.xcodeproj`
   alongside `project.yml` as a "halfway step" — the fully supported path is
   gitignoring the generated file entirely, which removes this failure mode by
   removing the possibility of a hand-edit existing outside the spec.

## Edge cases

| Case | Then |
|------|------|
| Diff shows only additions/reorderings you expect, nothing removed | Regeneration is safe to accept as-is |
| The lost state is small and easy to redeclare (one scheme, one target) | Add it to the spec, regenerate again, confirm the diff is now clean, then commit |
| The repo already gitignores the generated project file | This failure mode does not apply — nothing hand-edited exists to lose; skip the diff-before-accept step |
| A CI job runs the generator on every push | The same undeclared-state loss happens silently there too; add a `git diff --stat` check as a CI gate, not only a local habit |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run the regenerate command and commit whatever it produces | `git diff --stat` the regenerated file first, and `git checkout` it back if targets/schemes were deleted | The generator treats its spec as the sole source of truth; anything committed but undeclared is deleted, and the build still succeeds so the loss surfaces later, in CI |
| Assume the spec already describes everything in the committed generated file | Diff the two after any GUI/manual change and update the spec before the next regeneration | The spec does not absorb out-of-band edits automatically; it only ever reflects what was written into it |

## Sources

- https://github.com/yonaskolb/XcodeGen — "Generate projects on demand and remove your `.xcodeproj` from git, which means no more merge conflicts!"; `xcodegen generate` "will look for a project spec in the current directory called `project.yml`"
- https://github.com/yonaskolb/XcodeGen/blob/master/Docs/FAQ.md — "Can I still check in my project — Absolutely... But you can also check it in as a halfway step"
- https://github.com/yonaskolb/XcodeGen/issues/515 — GUI-created shared schemes "will be overwritten the next time they generate"
- https://github.com/yonaskolb/XcodeGen/issues/572 — "running xcodegen will overwrite that xcscheme file"
- Field reproduction (an iOS repo with committed `.xcodeproj` + `project.yml`, xcodegen 2.45.4, 2026-09): regenerating to add one localhost ATS exception deleted 118 pbxproj lines including the test target's `PBXNativeTarget` and the shared `.xcscheme` file; `git status`/`git diff --stat` surfaced it before commit
