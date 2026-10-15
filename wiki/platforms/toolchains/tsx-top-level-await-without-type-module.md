---
id: platforms-toolchains-tsx-top-level-await-without-type-module
domain: platforms
category: toolchains
applies_to: [typescript, nodejs, tsx]
confidence: verified
sources:
  - https://esbuild.github.io/content-types/#javascript
  - https://nodejs.org/api/typescript.html
  - https://github.com/privatenumber/tsx/blob/master/docs/typescript.md
  - https://github.com/privatenumber/tsx/issues/488
  - https://nodejs.org/api/packages.html#type
last_verified: 2026-10-15
related: [platforms-toolchains-typescript-6-global-types, platforms-processes-sentinel-driven-repl-payloads, platforms-toolchains-self-import-inside-a-workspace-package, platforms-shells-portable-shell-scripts]
---

# Top-Level `await` in a tsx Script Inside a Package Without `"type": "module"`

## When this applies

You run a one-off or helper TypeScript script with `tsx` (`tsx file.ts`,
`pnpm exec tsx`, `npx tsx`) that uses `await` at module top level, and the
package's `package.json` has no `"type"` field (or `"type": "commonjs"`). The run
stops with `ERROR: Top-level await is currently not supported with the "cjs"
output format` although the file type-checks and the tsconfig says
`"module": "esnext"`.

## Do this

tsx compiles each file with esbuild in the module format Node would give that
file: `.mts` is always ESM, `.cts` is always CommonJS, and `.ts` follows the
nearest `package.json` `"type"` (no field means CommonJS). esbuild refuses
top-level `await` when the output format is `cjs`, so the script fails at the
transform step, before any line runs. Pick the fix by what the file must stay:

| Case | Do |
|------|----|
| The script is yours and standalone (a seed, a probe, a migration helper) | Save it as `.mts`. It then compiles as ESM, and extension-less relative imports of the project's `.ts` modules (`import { x } from '../src/x'`) still resolve under tsx |
| The file must keep its `.ts` name (other files import it, a script runner lists it) | Wrap the body: `async function main() { … }` then `main().catch((e) => { console.error(e); process.exit(1) })` |
| The file must run unchanged and the project's `package.json` must stay as it is (a scratch folder, a script someone handed you) | Put a `package.json` containing only `{"type":"module"}` in the script's own folder. Node uses the first `package.json` it finds walking up, so that folder and its subfolders become ESM and the parent project stays as it was. Extension-less imports of the parent project's `.ts` modules still resolve under tsx. Use this row only when no `.js`/`.ts` file in that folder uses `require()`, `module.exports`, `__dirname` or `__filename` (in ESM they are undefined); otherwise use the `.mts` row |
| The whole package is meant to be ESM | Add `"type": "module"` to `package.json`; every `.ts` then compiles as ESM, and a file that must stay CommonJS is renamed `.cts` |

After the change, run the script once and read its own output line; a
`tsconfig.json` edit alone does not change the result (see Edge cases).

## Edge cases

| Case | Then |
|------|------|
| `tsconfig.json` has `"module": "esnext"` / `"moduleResolution": "bundler"` | Irrelevant to this decision — the format comes from the extension and `package.json` `"type"`, not from tsconfig; the reproduction below failed with exactly those settings |
| The error names a file under `node_modules` (a dependency with top-level `await`) | The dependency's ESM entry was reached from a CommonJS file; load it from an ESM file (`.mts`, or `"type": "module"`) — see tsx issue #552 for the shape of this failure |
| The stack trace points at `esbuild/lib/main.js` although you never invoked esbuild | Expected: tsx bundles esbuild as its transformer; the message is esbuild's, the cause is the module format above |
| A caller captures the script's output through a pipe (`tsx s.ts \| tail -1 > cookie.txt`) | The transform fails before any line runs, so stdout is empty and the error is on stderr; the caller gets an empty file while the pipe reports `tail`'s exit 0. Check the producer's own exit status as `platforms-shells-portable-shell-scripts` describes |
| You need top-level `await` inside a REPL payload or `node -i` driver rather than a script | Different mechanism; see `platforms-processes-sentinel-driven-repl-payloads` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `"module": "esnext"` to `tsconfig.json` to "enable ESM" for the script | Rename to `.mts` or set `package.json` `"type"` | tsconfig does not pick the runtime module format |
| Replace `await` with `.then()` chains to dodge the error | Wrap in `async function main()` | Same effect, and the body keeps `await` readability |
| Set `"type": "module"` on a package full of `require()` calls to run one script | Rename only that script to `.mts` | The field flips every `.ts`/`.js` in the package to ESM at once |

## Sources

- https://esbuild.github.io/content-types/#javascript — JavaScript caveats: "while transforming code containing top-level await is supported, bundling code containing top-level await is only supported when the output format is set to esm"; the error text `Top-level await is currently not supported with the "cjs" output format` is esbuild's
- https://nodejs.org/api/typescript.html — "Determining module system": `.mts` files "will always be run as ES modules, similar to `.mjs` files"; `.cts` "will always be run as CommonJS modules"; `.ts` files follow the `package.json` `"type"` field, and without `"type": "module"` they are CommonJS
- https://github.com/privatenumber/tsx/blob/master/docs/typescript.md — "Compiler limitations": "tsx uses esbuild to compile TypeScript and ESM, so it shares some of the same limitations", pointing at esbuild's JavaScript caveats
- https://github.com/privatenumber/tsx/issues/488 — the same error reported against tsx; the maintainer's answer points to the README and esbuild's JavaScript caveats rather than a tsx fix
- https://nodejs.org/api/packages.html#type — "The nearest parent package.json is defined as the first package.json found when searching in the current folder, that folder's parent, and so on up until a node_modules folder or the volume root is reached"
- Reproduction 2026-10-15 (tsx 4.23.15, Node 26.7.0): in a project whose `package.json` has no `"type"`, `scratch/tla.ts` (top-level `await` plus `import { two } from '../src/helper'`) exited 1 with the esbuild error; after adding `scratch/package.json` = `{"type":"module"}` the unchanged file printed `TLA_OK 2` (exit 0), whether run from the project root or from `scratch/`; a top-level-`await` file in `scratch/sub/` also ran, while a `scratch/` file calling `require('node:path')` exited 1 with `ReferenceError: require is not defined in ES module scope` and `typeof __dirname` printed `undefined`. Piped as `tsx s.ts 2>err.log | tail -1 > cookie.txt`, the failing script left `pipestatus` `1 0`, a 0-byte `cookie.txt`, and the error only in `err.log`
- Reproduction 2026-10-12 (tsx 4.23.15, Node 26.7.0, `package.json` without `"type"`, tsconfig `"module": "esnext"`): a two-line `tla.ts` with `const v = await Promise.resolve(2)` exited 1 with the esbuild error; the identical text saved as `tla.mts` printed `TLA_OK 2` (exit 0); the body wrapped in `async function main()` in a `.ts` file printed `MAIN_OK 3` (exit 0). A sibling field case on the same day: a `.mts` helper imported a `src/` module by extension-less relative path and ran
