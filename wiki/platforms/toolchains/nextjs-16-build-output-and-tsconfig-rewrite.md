---
id: platforms-toolchains-nextjs-16-build-output-and-tsconfig-rewrite
domain: platforms
category: toolchains
applies_to: [nextjs, typescript]
confidence: verified
sources:
  - https://nextjs.org/blog/next-16
  - https://nextjs.org/docs/app/api-reference/config/typescript
  - https://raw.githubusercontent.com/vercel/next.js/v16.3.8/packages/create-next-app/templates/app/ts/tsconfig.json
  - https://raw.githubusercontent.com/vercel/next.js/v16.3.8/packages/next/src/lib/typescript/writeConfigurationDefaults.ts
  - https://nextjs.org/docs/app/api-reference/config/next-config-js/distDir
last_verified: 2026-10-07
related: [testing-quality-checks-that-cannot-pass, platforms-toolchains-regeneration-silently-drops-hand-edited-state, platforms-shells-portable-shell-scripts, platforms-toolchains-flag-availability-at-the-execution-site]
---

# Next.js 16 Build Output Paths and the tsconfig the Build Rewrites

## When this applies

- You write or review a verify command, CI step, or plan check that reads the
  built CSS of a Next.js 16+ app ("is utility X in the bundle", "no hex colors
  in the output").
- You pin an exact `tsconfig.json` for a Next.js 16 project in a plan, template,
  or scaffold, and later builds should leave the tracked file unchanged.

## Do this

1. **Locate built CSS by searching, then prove the search matched.** Run
   `find .next/static -name '*.css'` and fail the check when it prints nothing.
   After that, grep inside the files it listed. The path depends on the bundler:

   | Build command (Next 16.3.8) | CSS written to |
   |-----------------------------|----------------|
   | `next build` (Turbopack, the default) | `.next/static/chunks/<hash>.css` |
   | `next build --webpack` | `.next/static/css/<hash>.css` |

   `find` works for both. A webpack-era literal glob (`.next/static/css/*.css`)
   matches nothing under Turbopack. zsh then aborts the command with
   `no matches found` (rc 1), so the check can never pass. bash passes the
   pattern through unexpanded, and grep exits 2 with `No such file or directory`.

2. **Pin the tsconfig that `next build` produces, not a hand-written one.** Run
   one `next build` in a scratch copy, then commit the file exactly as Next left it.
   Next 16's build prints "mandatory changes" and always forces `jsx` to
   `react-jsx`. It also sets `esModuleInterop`, `resolveJsonModule` and
   `isolatedModules` to `true`, unless an option you already chose implies them
   (see Edge cases). Finally it appends `.next/types/**/*.ts` and
   `.next/dev/types/**/*.ts` to `include`, re-serializing the whole file. Once
   these values are in place, the next build leaves the file byte-identical.
   The `create-next-app@16.3.8` templates ship these same values, so copying the
   template's file also works.

3. **Guard the pin in CI.** After `next build`, run
   `git ls-files --error-unmatch tsconfig.json && git diff --exit-code tsconfig.json`.
   A non-zero exit means the committed file has drifted from what the installed
   Next version requires. The `ls-files` half matters because `git diff --exit-code` exits 0
   for an untracked file.

## Edge cases

| Case | Then |
|------|------|
| `next.config` sets `distDir` | The build writes to `<distDir>` instead of `.next`, so search under `<distDir>/static`. The `include` globs Next appends also start with `<distDir>` (they come from `getTypeDefinitionGlobPatterns(distDir)`) |
| `module` is `preserve` (TypeScript ≥5.4), or `verbatimModuleSyntax` is `true` | Next skips `esModuleInterop`/`resolveJsonModule` under `preserve`, and skips `isolatedModules` under `verbatimModuleSyntax`. Pin exactly the set the scratch build leaves |
| The project builds with `--webpack` (custom webpack config) | The same `find` search still finds the files (they are under `static/css/`); keep the "matched at least one file" check |
| You need `.next/dev/types` in `include` but only run `next build` | Keep it anyway. Next 16 gives `next dev` and `next build` separate output directories, and the build adds the dev path too. Removing it makes the next build re-add it |
| You deliberately keep `"jsx": "preserve"` | Next 16.3.8 lists `jsx: react-jsx` as a required option with no alternative value, so every build overwrites `preserve`. Pin `react-jsx` |
| `next-env.d.ts` shows up in the diff | Next regenerates it on every dev, build, or typegen run. Add it to `.gitignore`; if it is already tracked, also run `git rm --cached next-env.d.ts`. Keep it in `include` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Grep `.next/static/css/*.css` as copied from a Next ≤15 recipe | `find .next/static -name '*.css'`, assert ≥1 hit, then grep the hits | Turbopack writes CSS chunks into `static/chunks/`; the old path never exists |
| Hand-write a minimal tsconfig with `jsx: preserve` in a scaffold plan | Commit the file a scratch `next build` produced | Every build in every worktree rewrites the hand-written file and dirties the tree |

## Sources

- https://nextjs.org/blog/next-16 — Turbopack is "the default bundler for all
  apps; opt out with `next build --webpack`". `next dev` and `next build` "now use separate
  output directories". Build banner `▲ Next.js 16 (Turbopack)`.
- https://nextjs.org/docs/app/api-reference/config/typescript — `next dev` and
  `next build` "add a `tsconfig.json` file with the recommended config
  options". `next-env.d.ts` is regenerated, belongs in `.gitignore`, and must stay in
  `include`. `.next/types/**/*.ts` belongs in `include`.
- next v16.3.8 `packages/next/src/lib/typescript/writeConfigurationDefaults.ts`: `jsx`
  has `value: 'react-jsx'` with reason "next.js uses the React automatic runtime".
  `esModuleInterop`/`resolveJsonModule` are omitted when `module` is `preserve` on TypeScript ≥5.4.
  `isolatedModules` is omitted when `verbatimModuleSyntax` is `true`. The include globs
  are `getTypeDefinitionGlobPatterns(distDir)`.
- https://nextjs.org/docs/app/api-reference/config/next-config-js/distDir — "if
  you run `next build` Next.js will use `build` instead of the default `.next` folder".
- create-next-app v16.3.8 `templates/app/ts/tsconfig.json` (and `app-tw`): has
  `"jsx": "react-jsx"`, and `include` lists `.next/types/**/*.ts` and
  `.next/dev/types/**/*.ts` (fetched 2026-10-07).
- Local reproduction 2026-10-07 with next@16.3.8, a minimal App Router app, and one CSS import:
  - Default build: `find .next/static -name '*.css'` → `.next/static/chunks/1bb-rre_qc00j.css`, and `ls -d .next/static/css` → No such file or directory.
  - `next build --webpack`: banner `▲ Next.js 16.3.8 (webpack)`, CSS at `.next/static/css/095cf7daa880d79a.css`.
  - zsh `grep -l x .next/static/css/*.css` with no such files: `no matches found`, rc 1. In `/bin/bash` the same command gave `grep: .next/static/css/*.css: No such file or directory`, rc 2.
  - tsconfig: the first build printed "jsx was set to react-jsx (next.js uses the React automatic runtime)" and "include was updated to add '.next/dev/types/**/*.ts'". The sha256 was identical after the second build.
  - git (scratch repo): `git diff --exit-code tsconfig.json` on an untracked file returned rc 0, and `git ls-files --error-unmatch` returned rc 1. On a tracked, modified file `git diff --exit-code` returned rc 1.
