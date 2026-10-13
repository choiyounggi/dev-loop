# backend/node — Stack Subtree Index

Route here for: Node.js/TypeScript stack-specific backend concerns. Language-agnostic
principles → wiki/backend/common/.

Match your situation to a "load when" line; load only matching pages. When a common
page and a node page both apply, load both — common owns the principle, these pages
own the Node mechanics.

## runtime

| Page | Load when |
|------|-----------|
| [env-files-with-process-loadenvfile](runtime/env-files-with-process-loadenvfile.md) | Loading `.env`-style files from Node code with `process.loadEnvFile(path)` instead of `dotenv`: layering `.env.local` over `.env` (load order decides the winner); an optional file that may be missing throws `ENOENT`; a `${OTHER}` or `$` value arrives literally; a variable set in the shell is not replaced by the file; a relative env path run from another working directory; repeated `--env-file` flags layering the other way (the later file wins); `NODE_OPTIONS` in an env file having no effect through the function |
| [event-loop-blocking](runtime/event-loop-blocking.md) | A Node service's requests ALL slow down together under specific inputs; p99 spikes when a CPU-bound feature runs (big JSON, crypto, compression, regex); writing/reviewing handler code with heavy synchronous work (`*Sync` APIs, large parse/stringify, CPU loops, user-input regex/ReDoS); choosing worker_threads vs main loop; setting up event-loop delay monitoring |
| [graceful-shutdown](runtime/graceful-shutdown.md) | Deploys/scale-downs drop in-flight requests or clients see connection resets on restart; writing/reviewing SIGTERM handling under an orchestrator (K8s, ECS, systemd, pm2); ordering server.close/readiness/pool close; sizing a force-exit timer against the grace period; deciding what uncaughtException/unhandledRejection handlers do at process level |
| [import-cycle-under-decorator-di](runtime/import-cycle-under-decorator-di.md) | Adding an import of a helper/constant/class into a NestJS (or `emitDecoratorMetadata` DI) TypeScript file whose target already imports it back, directly or through a barrel `index.ts`; boot fails with `Nest can't resolve dependencies of the X (?) … index [n] … appears to be undefined at runtime` (tsc) or `ReferenceError: Cannot access 'X' before initialization` (SWC) while typecheck and unit tests pass; the app boots only after reordering imports in `app.module.ts`; choosing between moving a helper out and `forwardRef()`; adding a root-module compile spec or a `madge --circular` CI check (type-only imports skipped) |

## async

| Page | Load when |
|------|-----------|
| [promise-error-handling](async/promise-error-handling.md) | unhandledRejection crashes/warnings in logs; errors vanishing from async flows; an async function called without await inside a handler; choosing between Promise.all / allSettled / any / race for parallel work; racing a timeout that must actually cancel the loser; deciding `return promise` vs `return await promise` in a try block |
| [request-body-reader-cancel](async/request-body-reader-cancel.md) | Racing a deadline against `reader.read()` on a request body in a Node server (Next.js route handler in the Node runtime, or `new Request(url, { body: nodeReadable, duplex: 'half' })`) and cancelling the reader when the deadline wins; a slow-upload guard or in-flight cap whose slot is released only after ~300 s (Node `requestTimeout`); `await reader.cancel()` that never returns; a deadline test that passes with a `new ReadableStream({})` fake body |

## boundaries

| Page | Load when |
|------|-----------|
| [structured-output-schema-from-zod](boundaries/structured-output-schema-from-zod.md) | Sending a zod 4 schema as the JSON Schema of a Claude structured-output request (`output_config.format`) from TypeScript; choosing between `@anthropic-ai/sdk`'s `zodOutputFormat()` + `messages.parse()` and a hand call to `z.toJSONSchema`; picking the `io` mode (input mode drops `additionalProperties: false` and defaulted keys from `required`); a schema with `.transform()` that throws on conversion; a zod `enum`/`const`/`.min()`/`.max()` the SDK helper moves into `description`; a hand-converted schema that still carries `minimum`/`maxLength` limits the API rejects; a schema with many `.optional()` keys (24 optional parameters per request); storing or snapshotting the converted schema |
| [zod-4-checks-continue-after-a-failure](boundaries/zod-4-checks-continue-after-a-failure.md) | A zod 4 schema chains `.regex()`/`.min()`/other checks and then a `.refine()`/`.superRefine()` whose function throws or misjudges input the earlier check should have excluded (`BigInt`, `new URL`, `JSON.parse`) |
| [runtime-validation](boundaries/runtime-validation.md) | Typing request bodies/query params/env vars/third-party responses/queue messages in a TypeScript service; an `as` cast on external data; runtime shape errors deep inside code that compiled fine; choosing where schema parse lives (handler, startup config, consumer) and where static types alone suffice |
| [nestjs-multer-upload-errors](boundaries/nestjs-multer-upload-errors.md) | A NestJS `FileInterceptor`/`FilesInterceptor` route needs its own error body for upload failures (file too large, too many files, unexpected field, malformed multipart); a `@Catch(MulterError)` filter never runs; choosing which exception classes an upload filter catches and how to test it |
