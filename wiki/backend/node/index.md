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

## async

| Page | Load when |
|------|-----------|
| [promise-error-handling](async/promise-error-handling.md) | unhandledRejection crashes/warnings in logs; errors vanishing from async flows; an async function called without await inside a handler; choosing between Promise.all / allSettled / any / race for parallel work; racing a timeout that must actually cancel the loser; deciding `return promise` vs `return await promise` in a try block |

## boundaries

| Page | Load when |
|------|-----------|
| [runtime-validation](boundaries/runtime-validation.md) | Typing request bodies/query params/env vars/third-party responses/queue messages in a TypeScript service; an `as` cast on external data; runtime shape errors deep inside code that compiled fine; choosing where schema parse lives (handler, startup config, consumer) and where static types alone suffice |
