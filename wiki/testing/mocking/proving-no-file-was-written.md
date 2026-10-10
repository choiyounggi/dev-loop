---
id: testing-mocking-proving-no-file-was-written
domain: testing
category: mocking
applies_to: [vitest, nodejs]
confidence: verified
sources:
  - https://vitest.dev/guide/mocking/modules
  - https://vitest.dev/guide/mocking/file-system
  - https://nodejs.org/api/fs.html
  - "Local reproduction 2026-10-11 (Vitest 5.0.3, Node 26.7.0, memfs 4.80.0)"
last_verified: 2026-10-11
related: [testing-mocking-what-to-mock, testing-quality-tests-that-cannot-fail]
---

# Proving a Test Run Wrote No File When `node:fs` Is Mocked

## When this applies

A Vitest suite claims the code under test writes nothing to disk (a privacy or
no-persistence guarantee) by mocking `node:fs`, typically with a factory that spreads
`importOriginal()` and replaces the writer functions, then asserts those mocks were
never called; or you are reviewing such a suite.

## Do this

1. **Assert on the directory, not on the mocks.** Run the code with every path it
   writes to (working directory, data directory, temp directory) pointed at a fresh
   empty directory, and assert `fs.readdirSync(dir)` is still empty afterwards. This
   check has no import form or API to miss: it failed for all six channels in the
   table below with no mock in place.
2. **When the suite has to mock the module** (to record calls, or to keep writes off
   the disk), close the three gaps a spread factory leaves:

| Gap | Do |
|-----|----|
| `import fs from 'node:fs'` reads the module's `default` export, and `...(await importOriginal())` copies the real one | Build the mocked object, set `mocked.default = mocked`, and return it, in the `node:fs` factory and in the `node:fs/promises` factory |
| `node:fs/promises` is its own module specifier (at runtime the same object as `fs.promises`) | Give it its own `vi.mock('node:fs/promises', …)` |
| Writes reach the disk through more than `writeFile`/`appendFile` | Also replace `promises.writeFile`/`appendFile`/`open`, `open`/`openSync`, `write`/`writeSync`, `createWriteStream` and `copyFile`/`copyFileSync` |

   The Vitest docs' alternative closes the same gaps: `__mocks__/fs.cjs` exporting
   memfs's `fs`, `__mocks__/fs/promises.cjs` exporting `fs.promises`, plus both
   `vi.mock('node:fs')` and `vi.mock('node:fs/promises')`; then assert that memfs's
   `vol` holds no file.
3. **Prove every write channel with a mutant that really writes.** For each channel
   the code could use, write a mutant that writes through it and require the suite to
   go red; a channel whose mutant stays green is a hole in the mock.

Measured with one function per channel (Vitest 5.0.3, Node 26.7.0). "missed" means
the suite stayed green while a real file landed; "caught" means a mock recorded the
call or memfs received the write with no real file, or the empty-directory assertion
failed:

| Channel in the code under test | Spread + writer functions | + top-level keys widened | + `default` set | memfs `__mocks__` | Empty-directory check, no mock |
|---|---|---|---|---|---|
| (a) `fs.promises.writeFile`, `import fs from 'node:fs'` | missed | missed | caught | caught | caught |
| (b) `writeFile` imported from `node:fs/promises` | missed | caught | caught | caught | caught |
| (c) `(await fsp.open(p, 'w')).writeFile(…)` | missed | caught | caught | caught | caught |
| (d) `fs.openSync` + `fs.writeSync`, default import | missed | missed | caught | caught | caught |
| (e) `fs.createWriteStream(p).end(…)`, default import | missed | missed | caught | caught | caught |
| (f) `fs.copyFileSync`, default import | missed | missed | caught | caught | caught |

## Edge cases

| Case | Then |
|------|------|
| The code under test uses only named or namespace imports today | Set `default` anyway; the first `import fs from 'node:fs'` added later reaches the real module through the spread copy, and the suite stays green |
| The test itself needs the real disk (creating fixtures, inspecting the target directory) | Use `await vi.importActual('node:fs')` for those calls; under the memfs setup every `node:fs` import in the test's module graph, helpers included, resolves to memfs |
| The memfs setup mocks `node:fs` but not `node:fs/promises` | Channels (b) and (c) wrote real files in the reproduction; add the second `vi.mock` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Spread `importOriginal()`, replace `writeFile`/`writeFileSync`/`appendFile*`, and assert they were not called | Assert an empty target directory, or close the three gaps in directive 2 | That mock missed all six channels while the suite stayed green |
| Widen the factory with more top-level keys (`promises`, `openSync`, `createWriteStream`) | Also set `mocked.default = mocked` | Code using the default import kept writing through four of six channels |

## Sources

- https://vitest.dev/guide/mocking/modules — "The factory method accepts an importOriginal function that will execute the original module and return its module object"
- https://vitest.dev/guide/mocking/file-system — "Vitest doesn't provide any file system mocking API out of the box"; "we recommend using memfs to do that for you"; "To automatically redirect every fs call to memfs, you can create __mocks__/fs.cjs and __mocks__/fs/promises.cjs files at the root of your project"; the example test calls both `vi.mock('node:fs')` and `vi.mock('node:fs/promises')`
- https://nodejs.org/api/fs.html — Promises API history: "The API is accessible via require('fs').promises only" (v10.1.0), "Exposed as require('fs/promises')" (v14.0.0); "The fs/promises API provides asynchronous file system methods that return promises". On Node 26.7.0, `require('node:fs').promises === require('node:fs/promises')` printed `true`
- Local reproduction 2026-10-11 (Vitest 5.0.3, Node 26.7.0, memfs 4.80.0; one exported function per channel, each writing into its own directory): the full table above. Spread-only and widened suites together reported `Tests 8 failed | 10 passed (18)` alongside the empty-directory suite, with real files left for every "missed" cell; the `default` variant reported `Tests 6 passed (6)` both for "real directory stays empty" and for "each channel's mock recorded one call", and its control without `mocked.default = mocked` reported `Tests 4 failed | 2 passed (6)` with real files for (a), (d), (e), (f); the memfs suite reported `Tests 6 passed (6)` with every write in `vol`, and its control without `vi.mock('node:fs/promises')` reported `Tests 2 failed | 4 passed (6)` with real files for (b) and (c)
- Field origin 2026-10-10 (a privacy suite in a Next.js project, task t6b): mutants writing through `(await import('node:fs')).promises.writeFile` and `fsp.open(…).writeFile` left 54- and 34-byte files in the working directory under the first suite and failed after the mock was widened; the reproduction above adds the default-import channels that widening alone does not reach
