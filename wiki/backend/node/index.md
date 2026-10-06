# backend/node — Stack Subtree Index

Route here for: Node.js/TypeScript stack-specific backend concerns. Language-agnostic
principles → wiki/backend/common/.

Match your situation to a "load when" line; load only matching pages. When a common
page and a node page both apply, load both — common owns the principle, these pages
own the Node mechanics.

## runtime

| Page | Load when |
|------|-----------|
| [event-loop-blocking](runtime/event-loop-blocking.md) | A Node service's requests ALL slow down together under specific inputs; p99 spikes when a CPU-bound feature runs (big JSON, crypto, compression, regex); writing/reviewing handler code with heavy synchronous work (`*Sync` APIs, large parse/stringify, CPU loops, user-input regex/ReDoS); choosing worker_threads vs main loop; setting up event-loop delay monitoring |
| [graceful-shutdown](runtime/graceful-shutdown.md) | Deploys/scale-downs drop in-flight requests or clients see connection resets on restart; writing/reviewing SIGTERM handling under an orchestrator (K8s, ECS, systemd, pm2); ordering server.close/readiness/pool close; sizing a force-exit timer against the grace period; deciding what uncaughtException/unhandledRejection handlers do at process level |
| [import-cycle-under-decorator-di](runtime/import-cycle-under-decorator-di.md) | Adding an import of a helper/constant/class into a NestJS (or `emitDecoratorMetadata` DI) TypeScript file whose target already imports it back, directly or through a barrel `index.ts`; boot fails with `Nest can't resolve dependencies of the X (?) … index [n] … appears to be undefined at runtime` (tsc) or `ReferenceError: Cannot access 'X' before initialization` (SWC) while typecheck and unit tests pass; the app boots only after reordering imports in `app.module.ts`; choosing between moving a helper out and `forwardRef()`; adding a root-module compile spec or a `madge --circular` CI check (type-only imports skipped) |

## async

| Page | Load when |
|------|-----------|
| [promise-error-handling](async/promise-error-handling.md) | unhandledRejection crashes/warnings in logs; errors vanishing from async flows; an async function called without await inside a handler; choosing between Promise.all / allSettled / any / race for parallel work; racing a timeout that must actually cancel the loser; deciding `return promise` vs `return await promise` in a try block |

## boundaries

| Page | Load when |
|------|-----------|
| [runtime-validation](boundaries/runtime-validation.md) | Typing request bodies/query params/env vars/third-party responses/queue messages in a TypeScript service; an `as` cast on external data; runtime shape errors deep inside code that compiled fine; choosing where schema parse lives (handler, startup config, consumer) and where static types alone suffice |
