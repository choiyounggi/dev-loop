---
id: backend-java-kotlin-ktlint-final-newline-from-editorconfig
domain: backend
category: kotlin
applies_to: [kotlin, ktlint, editorconfig]
confidence: verified
sources:
  - https://github.com/ktlint/ktlint/blob/1.8.0/ktlint-ruleset-standard/src/main/kotlin/com/pinterest/ktlint/ruleset/standard/rules/FinalNewlineRule.kt
  - https://github.com/ktlint/ktlint/blob/0.40.0/README.md
  - https://spec.editorconfig.org/
last_verified: 2026-10-23
related: []
---

# A ktlint End-of-File Newline Violation Decided by `.editorconfig`

## When this applies

ktlint (directly, or through a Gradle/Maven ktlint task) reports `Redundant newline
(\n) at the end of file` or `File must end with a newline (\n)` on files you
wrote or generated, and the usual habit — "every file ends with a newline" — does
not make it go away.

## Do this

1. **Read `insert_final_newline` in the `.editorconfig` that applies to the file**
   (the closest one, then parents up to `root = true`). ktlint's `final-newline`
   rule takes its direction from this property; its default is `true`.
2. **Match the file to the value:**

| `insert_final_newline` | ktlint reports | Make the file |
|------------------------|----------------|---------------|
| `true` or absent | `File must end with a newline (\n)` | End with exactly one `\n` |
| `false` | `Redundant newline (\n) at the end of file` | End with no trailing newline |

3. **Let the formatter apply it** — both messages are auto-correctable, so the
   project's ktlint format task (`ktlintFormat`, `ktlint -F`) fixes generated files
   in one pass. When a script writes the files, make it follow the property
   (`text.rstrip("\n")` for `false`, `text.rstrip("\n") + "\n"` for `true`).

## Edge cases

| Case | Then |
|------|------|
| Older ktlint documentation says `insert_final_newline = false` disables the rule | Current ktlint (checked at 1.8.0) enforces the opposite direction instead — "Redundant newline" — so treat `false` as "must not end with a newline" |
| Different directories carry different `.editorconfig` values | The closest file decides for each source file; compare against the section that matches the file's glob, not the repository root alone |
| Your editor re-adds the newline on save | The editor is applying its own default; install or enable its EditorConfig support so it reads the same property |
| An empty file | The rule does nothing for zero-length files; the EditorConfig spec also says editors must not add a newline to them |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add or remove trailing newlines by trial until the check passes | Read `insert_final_newline` and set every file to that value | The property fixes the direction; flipping by guess repeats the failure on the next generated file |
| Disable `final-newline` to unblock the build | Follow the repository's `.editorconfig` value | The value is a repository decision that the formatter already enforces consistently |

## Sources

- https://github.com/ktlint/ktlint/blob/1.8.0/ktlint-ruleset-standard/src/main/kotlin/com/pinterest/ktlint/ruleset/standard/rules/FinalNewlineRule.kt — rule `final-newline` reads `INSERT_FINAL_NEWLINE_PROPERTY`; when true and the file does not end in a newline it emits "File must end with a newline (\n)", when false and the last node is whitespace with a newline it emits "Redundant newline (\n) at the end of file"; both auto-correctable; zero-length files stop traversal. `InsertFinalNewLineEditorConfigProperty.kt` at the same tag sets `defaultValue = true`
- https://github.com/ktlint/ktlint/blob/0.40.0/README.md — the older wording, line 48: "set `insert_final_newline=false` in .editorconfig to disable" (id: `final-newline`), which the 1.8.0 rule above no longer matches
- https://spec.editorconfig.org/ — `insert_final_newline`: "Set to true ensure file ends with a newline when saving and false to ensure it doesn’t. Editors must not insert newlines in empty files"
- Field case 2026-10 (a Kotlin service built with Gradle): 12 newly added files all failed with "Redundant newline"; the repository's `.editorconfig` set `insert_final_newline = false`; ensuring a final newline kept the failures, stripping it made `ktlintCheck` exit 0
