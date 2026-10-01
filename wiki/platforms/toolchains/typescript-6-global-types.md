---
id: platforms-toolchains-typescript-6-global-types
domain: platforms
category: toolchains
applies_to: [typescript]
confidence: verified
sources:
  - https://devblogs.microsoft.com/typescript/announcing-typescript-6-0/
  - https://www.typescriptlang.org/tsconfig/#types
last_verified: 2026-10-01
related: [platforms-toolchains-version-management, platforms-toolchains-flag-availability-at-the-execution-site, backend-node-boundaries-runtime-validation]
---

# Global Type Packages After the TypeScript 6 `types` Default Change

## When this applies

A project on TypeScript 6.0 or later — a new scaffold (an Expo/React Native app,
a Vite app, a Node service) or an upgrade from 5.x — fails `tsc` with
`Cannot find name 'describe'`, `'expect'`, `'process'`, `'Buffer'`, `'fs'`, or
`'Bun'` although the matching `@types/*`
package is installed. Also when you are writing a `tsconfig.json` for a
TypeScript 6 project and deciding whether `compilerOptions.types` is needed.

## Do this

1. **Read the installed compiler version first**: `npx tsc --version`. The
   behavior below starts at 6.0; on 5.9 and earlier the same error means the
   package is missing ([platforms-toolchains-flag-availability-at-the-execution-site]).

2. **List every global-affecting type package in `compilerOptions.types`.**
   TypeScript 6.0 changed the default of `types` from "every package under
   `node_modules/@types`" to `[]`. Globals such as `describe`, `process`, or
   `Buffer` now load only from packages named there.

   ```json
   { "compilerOptions": { "types": ["node", "jest"] } }
   ```

3. **Declare each listed package as a direct devDependency** of the package
   whose tsconfig names it. A `types` entry resolves by package name; relying on
   a hoisted transitive copy breaks under a strict installer (pnpm) or when the
   parent dependency drops it.

4. **Verify by typecheck, not by editor state**: run `tsc --noEmit` and require
   zero "Cannot find name" errors; an editor may still hold the old program.

| Globals you use | `types` entry |
|-----------------|---------------|
| `process`, `Buffer`, `node:` built-in modules as ambient globals | `"node"` |
| `describe` / `it` / `expect` from Jest | `"jest"` |
| Mocha globals | `"mocha"` |
| Vitest with `globals: true` | `"vitest/globals"` |
| Bun globals | `"bun"` |

## Edge cases

| Case | Then |
|------|------|
| A monorepo where each package has its own tsconfig | Set `types` per package (or in the shared base each extends); a test-only tsconfig lists the runner's types, the build tsconfig omits them so test globals stay out of shipped code |
| You need the pre-6.0 behavior while migrating | Set `"types": ["*"]` — the release notes give this as the opt-in to load everything — and replace it with an explicit list once the build is green |
| The type package is imported explicitly (`import { describe } from 'vitest'`, `import fs from 'node:fs'`) | No `types` entry is needed for that import to resolve; `types` governs only automatic global inclusion |
| The tsconfig `extends` a framework base (`expo/tsconfig.base`, `@tsconfig/node22`) | Print the effective config with `tsc --showConfig` and read its `types` value before and after your edit; list every entry you need in the file that sets it |
| The error names a runner you do not use | The message lists candidates (`@types/jest` or `@types/mocha`); install and list only the runner the project runs |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Reinstall `@types/jest` because "Cannot find name 'describe'" | Add `"jest"` to `compilerOptions.types` | The package is present; TypeScript 6 no longer includes it automatically |
| Add `/// <reference types="jest" />` to every test file | One `types` entry in the tsconfig the tests compile under | A per-file directive repeats in every file and is missed in the next new one |
| Pin TypeScript back to 5.9 to make the scaffold typecheck | List the types and stay on the scaffold's version | The framework template and its type packages are tested against the version it ships |

## Sources

- https://devblogs.microsoft.com/typescript/announcing-typescript-6-0/ — section "`types` now defaults to `[]`": "In TypeScript 6.0, the default `types` value will be `[]` (an empty array)"; previously TypeScript "would also include all packages in `node_modules/@types` by default"; the new diagnostics read "Cannot find name 'describe'. Do you need to install type definitions for a test runner? Try `npm i --save-dev @types/jest` or `npm i --save-dev @types/mocha` and then add 'jest' or 'mocha' to the types field in your tsconfig"; `"types": ["*"]` restores the 5.9 behavior
- https://www.typescriptlang.org/tsconfig/#types — "By default `types` is set to `[]`. For versions below TypeScript 6.0, by default all _visible_ \"`@types`\" packages are included in your compilation"; "If `types` is specified, only packages listed will be included in the global scope"; the option "does not affect how `@types/*` are included in your application code" via imports
- Field reproduction 2026-09-29 (an Expo SDK 57 app, `typescript` 6.0.3, `@types/jest` installed): `tsc --noEmit` reported TS2593 on every test file; adding `"types": ["jest", "node"]` to `compilerOptions` cleared them with no other change
