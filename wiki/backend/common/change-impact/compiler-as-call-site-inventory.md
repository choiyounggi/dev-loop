---
id: backend-common-change-impact-compiler-as-call-site-inventory
domain: backend
category: change-impact
applies_to: [typescript]
confidence: verified
sources:
  - https://www.typescriptlang.org/docs/handbook/2/objects.html
  - https://www.typescriptlang.org/tsconfig/#include
  - https://www.typescriptlang.org/tsconfig/#exclude
  - https://www.typescriptlang.org/docs/handbook/type-checking-javascript-files.html
last_verified: 2026-08-27
related:
  [
    backend-common-change-impact-call-site-enumeration,
    backend-common-change-impact-cross-module-consumer-census,
    backend-common-integrations-consumer-required-fields,
    testing-quality-tests-that-cannot-fail,
    qa-process-completion-claims,
  ]
---

# Using the Type Checker as the Inventory of Sites That Build a Value

## When this applies

You are adding a required field to a type and relying on "make it required and
the compiler lists every site that must be updated" as the complete inventory —
or you enumerated those sites by grepping the **type's name** and are about to
publish the count in a plan, brief, or task breakdown.

Enumerating callers of a function whose signature changes →
[backend-common-change-impact-call-site-enumeration].

## Do this

1. **Enumerate construction sites from the compiler's error list, and use a
   grep only to cross-check it.** TypeScript types object literals from
   context, so a value of the type can be built with the type's name nowhere in
   the text — `dealViewer: { userId: ctx.user.userId }` constructs a `DealViewer`
   and contains no occurrence of `DealViewer`. A type-name grep counts the sites
   that *mention* the type; the sites that *build* it are a different set.

2. **Bound the claim to the files the compiler actually reads, and check that
   boundary before quoting the count.** The program is `files` ∪ `include` ∪
   everything reachable by import from them. A package whose `tsconfig.json`
   says `include: ["src/**/*"]` never type-checks its own `__tests__/`
   directory unless `src` imports it, so fixtures and expected-value literals
   there contribute **zero** errors and are missing from the inventory.

3. **Run the sweep per package in a monorepo and add the results up.** Each
   package carries its own `tsconfig.json`, so `include` differs between them;
   one root type-check reports only what the root project references.

4. **Cross-check with a grep on the *property name*, not the type name.**
   `grep -rn 'fieldName:'` reaches contextually-typed literals because the
   property is the text that is actually present. Reconcile the two lists and
   explain each difference:

| The site appears in | Read it as |
|---------------------|------------|
| Compiler errors and the property grep | Confirmed construction site |
| Compiler errors only | The literal spells the property differently (spread, computed key, helper) — read it and record the form |
| Property grep only | Outside the compiler's program — check that package's `include`, then treat it as a site the migration must handle by hand |
| Neither, but the value flows there at runtime | Built by a factory or spread from another object — enumerate that producer instead ([backend-common-integrations-consumer-required-fields]) |

5. **State the method next to the count.** "8 construction sites (tsc error
   list, `packages/*` each, cross-checked with `grep 'dealViewer:'`)" is
   checkable; a bare "8 sites" cannot be reviewed for the gaps above, and a
   count published into a brief is inherited by everyone working from it.

6. **Re-run the type-check after wiring and require zero errors, then run the
   tests.** Files outside the program fail only at runtime, so the test run is
   the second half of the inventory, not a formality.

## Edge cases

| Case | Then |
|------|------|
| The new field is optional | The compiler reports nothing at all — every site keeps compiling with the field absent. Make it required for the sweep, collect the list, then relax it if the design calls for optional ([testing-quality-tests-that-cannot-fail]) |
| A test directory is excluded from the package's `tsconfig` | Its sites surface as failing tests after wiring, or pass silently if nothing asserts the field — enumerate it by property grep and fix it in the same change |
| `exclude` lists the directory | `exclude` "only changes which files are included as a result of the `include` setting" — an excluded file still enters the program when an included file imports it, so the boundary is "in the program", not "in `include`" |
| The literal is built with a spread (`{ ...base, userId }`) | The excess/missing check applies to the spread result, but the property grep misses it — grep the base object's factory as the producer |
| The value is cast (`as DealViewer`) or typed `any` | The assertion suppresses the error, so the site is absent from the inventory while being a real construction site — grep the type name **as well**, which is where a type-name search does pay |
| The repo type-checks with `skipLibCheck` or has pre-existing errors | The new errors are not separable by eye — capture the error list before and after and diff them |
| Sites live in another repository or a published package | The compiler cannot see them at all; make the field optional at the boundary and version the change ([backend-common-change-impact-call-site-enumeration]) |
| The project uses `checkJs: false` with JavaScript callers | `.js` construction sites are unchecked — enumerate them by property grep only |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Report the number of construction sites from `grep "<TypeName>"` | Take the list from the compiler errors, cross-check with a property grep, and state the method | Contextually typed object literals build the type without naming it, so the grep and the truth are different sets — measured 3 vs 8 |
| Treat a clean `pnpm type-check` as proof every assembly site was updated | Confirm each package's `include` covers its tests, then run the tests too | A package excluding `__tests__/` contributes zero errors from files that still build the value |
| Add the field as optional to avoid breaking the build, then find the sites later | Make it required, collect the compiler's list, and decide optionality afterwards | An optional field produces no inventory at all; "later" has no signal to work from |
| Publish the count into worker briefs as soon as the grep returns | Publish the count with its method, after the compiler sweep | A wrong count in a brief is multiplied by the number of briefs, and each worker reads it as scope |

## Sources

- https://www.typescriptlang.org/docs/handbook/2/objects.html — excess property checking applies to fresh object literals assigned to a typed target; the checking follows from the **contextual type**, so it occurs on literals in which the type's name never appears (the basis for step 1)
- https://www.typescriptlang.org/tsconfig/#include — `include` "specifies an array of filenames or patterns to include in the program", defaulting to `**/*` when neither `files` nor `include` is set; the program is what `tsc` reads and therefore the limit of the inventory (step 2)
- https://www.typescriptlang.org/tsconfig/#exclude — "`exclude` *only* changes which files are included as a result of the `include` setting. A file specified by `exclude` can still become part of your codebase due to an `import` statement in your code" — the basis for the `exclude` edge-case row
- https://www.typescriptlang.org/docs/handbook/type-checking-javascript-files.html — `checkJs` governs whether `.js` files are checked, behind the JavaScript-callers row
- Field measurement 2026-08-24 (`rtb-unified`): a plan recorded "3 assembly sites" for `DealViewer` from `grep "DealViewer"`; the real count was 8, and the missing set included the production wiring `packages/orpc/src/routers/deal.ts:38`, `dealViewer: { userId: context.user.userId }`. The same error repeated for `ContractScopeActor`: 7 sites across 4 files by type-name grep versus roughly 22 across 11 files
- Field measurement 2026-08-25 (same repo): `packages/orpc/tsconfig.json` declares `include: ["src/**/*"]`. Making `DealViewer.firstTierScope` required produced 3 production and 13 api-test errors from `pnpm type-check`, and **zero** for `packages/orpc/__tests__/routers/deal.test.ts` — that file's 6 assembly and expectation sites appeared only as 6 failing tests once the router was wired
