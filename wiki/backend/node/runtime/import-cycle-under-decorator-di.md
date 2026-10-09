---
id: backend-node-runtime-import-cycle-under-decorator-di
domain: backend
category: runtime
applies_to: [nestjs, typescript]
confidence: verified
sources:
  - https://docs.nestjs.com/faq/common-errors
  - https://docs.nestjs.com/fundamentals/circular-dependency
  - https://www.typescriptlang.org/docs/handbook/decorators.html
  - https://github.com/pahen/madge
last_verified: 2026-10-06
related: [testing-strategy-import-time-side-effects, backend-node-boundaries-runtime-validation]
---

# A File-Level Import Cycle Under NestJS Decorator DI

## When this applies

In a NestJS (or any decorator-metadata DI) TypeScript service, you are adding an
import of a value — a helper function, a constant, a class — from file B into
file A while B already imports A, directly or through a barrel `index.ts`. The
common shape: a pure helper exported from `resume.service.ts`, imported by
`research.service.ts`, which `ResumeService` injects. Also when boot fails while
typecheck and unit tests pass, with `Nest can't resolve dependencies of the X (?)
… index [n] … appears to be undefined at runtime` (tsc output) or
`ReferenceError: Cannot access 'X' before initialization` (SWC output).

## Do this

1. **Find the cycle before changing code**: `npx madge --circular --extensions ts src`
   exits 1 and prints the chain (`research.service.ts > resume.service.ts`) when
   a cycle exists, 0 when none does. Add a `.madgerc` with
   `{"detectiveOptions": {"ts": {"skipTypeImports": true}}}` so a cycle made only
   of `import type` lines (erased at compile time) is not reported.
2. **Fix it by case:**

| Case | Do |
|------|----|
| A plain helper or constant lives in a service/module file and another file in the cycle imports it | Move it into its own file that imports no provider, module, or barrel file from the project; import it from both sides (the Nest FAQ: "move the constants to a separate file") |
| A barrel `index.ts` closes the cycle | Import the concrete file path; Nest's guide asks you not to import a barrel from a file inside the barrel's own directory |
| Two providers inject each other in their constructors (a provider cycle, not a file cycle) | Follow Nest's circular-dependency guide: wrap both the modules **and** the providers with `forwardRef()` |
| No cycle exists and the injected class is imported with `import type` | Use a value import; with a type-only import tsc records `Function` in the metadata instead of the class |

3. **Gate it**: keep one spec whose first project import is `AppModule` and that
   compiles it (`Test.createTestingModule({ imports: [AppModule] }).compile()`,
   with `.overrideProvider(...)` for providers that open connections), and run
   the step-1 madge command in CI.

**Mechanism (tsc, CommonJS output).** With `emitDecoratorMetadata`, tsc emits the
constructor's parameter types as a `__metadata("design:paramtypes",
[research_service_1.ResearchService])` call that runs when the class definition
runs. Inside a cycle, the file evaluated second runs while the first file's
exports are still unset, so the recorded type is `undefined` and Nest cannot
resolve that index. Which file is "second" depends on which one the entry point
loads first. SWC emits `typeof X === "undefined" ? Object : X` behind an export
getter instead, and the same cycle throws the `ReferenceError` above during load.

## Edge cases

| Case | Then |
|------|------|
| The error text suggests `import type` but no `import type` exists for that class | Run the step-1 cycle check; the same message covers any dependency that is `undefined` at decoration time |
| Swapping two import lines in `app.module.ts` makes the app boot | Still apply the step-2 fix — an import sorter, an auto-import, or a new entry point changes the load order and the failure returns |
| Every isolated unit test of each service passes | Expected: each spec loads a different file first. Only a spec that imports `AppModule` before any other project file reproduces the entry point's order (step 3) |
| The helper is needed by many services | Put the helpers in one or more files that import no provider, module, or barrel file from the project; such a file cannot be part of a cycle |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `@Inject(forwardRef(() => X))` to silence a cycle created by a helper import | Move the helper out (step 2, first row) | `forwardRef` defers only that one injection; the file cycle stays, and any other value read at load time (a base class, a constant) is still `undefined` |
| Trust `tsc --noEmit` and per-service unit tests as proof the module graph boots | Run the root-module spec from step 3 | Typecheck sees types, not evaluation order; the failure exists only in the order the real entry point loads files |

## Sources

- https://docs.nestjs.com/faq/common-errors — "If the dependency at the reported index resolves to `undefined` or `Object` at runtime, the error message omits the token name"; cause 1 "A circular file import … the providers don't depend on each other in their constructors; two files end up importing each other … If you use barrel files, make sure your barrel imports don't create such circular imports"; "from TypeScript files that depend on each other for constants … move the constants to a separate file … make sure that both the modules **and** the providers are wrapped with `forwardRef()`"
- https://docs.nestjs.com/fundamentals/circular-dependency — "A circular dependency can also be caused by using "barrel files" (`index.ts` files) to group imports"; "The order of instantiation is indeterminate"
- https://www.typescriptlang.org/docs/handbook/decorators.html — Metadata section: with `emitDecoratorMetadata` the compiler emits `Reflect.metadata("design:…", …)` decorator calls on the class
- https://github.com/pahen/madge — `--circular`; README `.madgerc` example with `"detectiveOptions": {"ts": {"skipTypeImports": true}}`
- Reproduction 2026-10-06 (`@nestjs/core` 11.2.7, TypeScript 5.9.3, `@swc/core` 1.x, Node 26.7.0, CommonJS). Files: `resume.service.ts` exports `isProfileEmpty` and `ResumeService(research: ResearchService)`; `research.service.ts` imports `isProfileEmpty` from it; `app.module.ts` imports `research.service` first. tsc: `tsc --noEmit` rc=0, a direct `ResearchService` call worked, boot printed `design:paramtypes [ undefined ]` and `Nest can't resolve dependencies of the ResumeService (?) … index [0]`. SWC: `resume.service.ts` compiled to `_ts_metadata("design:paramtypes", [typeof _researchservice.ResearchService === "undefined" ? Object : _researchservice.ResearchService])` with `ResearchService` exported through an `Object.defineProperty(exports, …, { get })` getter, and boot threw `ReferenceError: Cannot access 'ResearchService' before initialization`. Importing `resume.service` first in `app.module.ts` booted under tsc; moving `isProfileEmpty` to `is-profile-empty.ts` booted in both orders. `madge --circular` exited 1 on the cyclic tree and 0 on the fixed tree; a two-file cycle of `import type` lines was reported without `skipTypeImports` and passed with it, while the real cycle was still reported. An `import type` injected class compiled to `__metadata("design:paramtypes", [Function])`
- Field evidence 2026-10-06 (a NestJS API): the same helper move fixed an `app.module.spec` failure and every e2e suite failing at boot (372 unit, 122 e2e green afterwards)
