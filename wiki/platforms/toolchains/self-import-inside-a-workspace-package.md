---
id: platforms-toolchains-self-import-inside-a-workspace-package
domain: platforms
category: toolchains
applies_to: [nodejs, typescript, pnpm, npm, yarn]
confidence: verified
sources:
  - https://nodejs.org/api/packages.html#self-referencing-a-package-using-its-name
last_verified: 2026-10-06
related: [platforms-toolchains-flag-availability-at-the-execution-site, backend-common-change-impact-call-site-enumeration]
---

# Importing a Sibling Module Inside a Workspace Package

## When this applies

You are adding or moving a module into a JS/TS package that other packages in the
same monorepo consume by name (`@org/shared`), and the new module or its test must
import another module of that same package. You must choose between the package's
own name (`from '@org/shared'`) and a relative path (`from './research'`).

## Do this

| Case | Do |
|------|----|
| A module or test inside the package imports something defined in the same package | Import it by relative path (`'./research'`), in the same specifier style the package's other source files use (extensionless or `.js`) |
| Code in a *different* workspace package imports it | Import by the package name (`'@org/shared'`); that is what the package's `"exports"` map is for |
| You moved a module into the package and its old importers live in other packages | Change only those importers' specifier to the package name, and confirm the moved names are re-exported from the entry the `"exports"` map points at |

The mechanism (Node docs): a package's own name resolves from inside the package
only when `package.json` has `"exports"`, and then only to what `"exports"` lists.
When `"exports"` points at a build entry (`./dist/index.js`), a self-import inside
the source reaches the **built** copy, not the file next to it. Observed in one
pnpm + vitest package (field evidence below):

- before the first build, `dist/` does not exist → the import fails to resolve;
- under a test runner or watch mode, `dist/` holds the previous build → the test
  exercises stale code;
- the entry (`index`) re-exports the module doing the import → a cycle through the
  barrel.

Whether the name resolves at all also depends on the package manager linking the
package where its own files can see it; the relative path avoids that question.

## Edge cases

| Case | Then |
|------|------|
| The package's `"exports"` points at source (`./src/index.ts`) or uses a `development`/`source` condition the test runner selects | The stale-`dist/` failure does not occur; still import by relative path, because a self-import through the barrel re-enters the entry module that re-exports the importer |
| The package has no `"exports"` field | Self-reference by name is not available (Node docs); the import either fails or resolves through some other path (a hoisted copy, a tsconfig `paths` alias) — use the relative path |
| A tsconfig `paths` alias maps the package name to `src/` | The type checker follows the alias while Node at run time ignores tsconfig and follows `"exports"`, so the two can reach different files. Use the relative path so both resolve the same file |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `from '@org/shared'` inside `packages/shared/src/*` because consumers use that name | Use the relative path the package's other source files use | The name resolves through `"exports"`: when that points at `dist/`, the build output is absent before a build and stale during tests; when it points at source, the import re-enters the barrel that re-exports the importer |
| Leave a re-export shim at the module's old path after moving it into the shared package | Repoint every importer to the package name and delete the old file in the same change | Two import paths for the same names let new code pick either; the shim hides importers you did not move |

## Sources

- https://nodejs.org/api/packages.html#self-referencing-a-package-using-its-name — "Within a package, the values defined in the package's `package.json` `"exports"` field can be referenced via the package's name"; "Self-referencing is available only if `package.json` has `"exports"`"; "Self-referencing will allow importing only what that `"exports"` (in the `package.json`) allows"
- Field evidence 2026-10-06 (a pnpm monorepo, plan t1 moving a helper module into the shared package): the plan rejected a self-import by package name inside the package because it resolves to the package's own `dist/` — absent before the first build, stale during `vitest` — and used `'./research'` like every other file in `packages/shared/src/`
