---
id: frontend-rendering-request-time-data-in-a-nextjs-page
domain: frontend
category: rendering
applies_to: [nextjs]
confidence: verified
sources:
  - https://nextjs.org/docs/app/glossary
  - https://nextjs.org/docs/app/guides/caching-without-cache-components
  - https://nextjs.org/docs/app/api-reference/functions/connection
  - https://nextjs.org/docs/app/guides/migrating-to-cache-components
  - https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config
  - "next@16.3.8 bundled docs, node_modules/next/dist/docs/ (io.md, cacheLife.md, building.md, 08-caching.md, unstable_noStore.md)"
  - "Local builds 2026-10-11 (next 16.3.8, react 19.3.0, DATABASE_URL unset)"
last_verified: 2026-10-11
related: [backend-common-orm-prisma-7-config-env-and-generated-client]
---

# Reading a Database in a Next.js Page Without Prerendering It at Build

## When this applies

A Next.js App Router page or layout reads a database or another non-`fetch` source
(a Prisma or `pg` call) with no request-time API (`cookies()`, `headers()`,
`searchParams`); `next build` fails with `Error occurred prerendering page` where
the database URL is unset (CI, image builds), or the page serves build-time data.

## Do this

1. **Mark the read as request-time, by the app's caching mode:**

| `next.config` | Do | Route line in `next build` |
|---|---|---|
| `cacheComponents` not set | `await connection()` from `next/server` as the first statement of the page, or `export const dynamic = 'force-dynamic'` | `ƒ /` — Dynamic, "Server-rendered on demand for each request" |
| `cacheComponents: true` | Remove any `dynamic` export (it fails the build). Render the reading component inside `<Suspense>` and call `await io()` (from `next/cache`, 16.3.0 and later) before the read; call `await connection()` there instead only when rendering must wait for a real user request, because it also blocks prefetches | `◐ /` — Partial Prerender: a static shell, the read streamed at request time |

2. **Keep module scope free of code that throws without the environment.** The
   build evaluates the page module at "Collecting page data" to read its route
   config, `force-dynamic` included; construct clients and check variables
   inside the function that runs per request.
3. **Confirm in the route table of `next build`:** the route shows `ƒ` or `◐`. A
   route shown as `○` was prerendered and carries the data read at build time.

Measured on next 16.3.8 with `DATABASE_URL` unset and a page whose data function
throws when it is missing:

| Page | Exit | Result |
|---|---|---|
| No route config | 1 | `Error occurred prerendering page "/"` at "Generating static pages" |
| `dynamic = 'force-dynamic'` | 0 | `┌ ƒ /` |
| `await connection()` first | 0 | `┌ ƒ /` |
| `force-dynamic` plus a module-scope `throw` | 1 | `Error: Failed to collect configuration for /` at "Collecting page data" |
| `cacheComponents: true` plus `force-dynamic` | 1 | ``Route segment config "dynamic" is not compatible with `nextConfig.cacheComponents`. Please remove it.`` |
| `cacheComponents: true`, `<Suspense>` child calling `await io()` before the read | 0 | `┌ ◐ /` |
| `cacheComponents: true`, `<Suspense>` child calling `await connection()` before the read | 0 | `┌ ◐ /` |
| `cacheComponents: true`, `<Suspense>` child, no `io()`, the read throws before awaiting I/O | 1 | The prerender error of the first row |
| `cacheComponents: true`, page unchanged | 1 | The prerender error of the first row |

## Edge cases

| Case | Then |
|------|------|
| A `<Suspense>`-wrapped read with no `io()` | It runs during the prerender until it awaits real I/O: a read that awaits a query first leaves a hole (`◐ /`, measured with a 50 ms timer before the read), and a read that throws first — a client that checks a missing `DATABASE_URL` — fails the build (measured); put `await io()` before it |
| Existing code calls `unstable_noStore()` | Replace it with `await connection()` (the docs deprecated it for `connection` in v15); under Cache Components use step 1's `io()` |
| A read whose result can be shared across requests (the same rows for every visitor) | Under Cache Components, mark the reading function `"use cache"` and set its lifetime with `cacheLife` (`import { cacheLife } from 'next/cache'`); a read that needs fresh data on every request stays on step 1, as the docs exclude `"use cache"` for it |
| nextjs.org and the installed version disagree | Read `node_modules/next/dist/docs/`; on 2026-10-11 nextjs.org served 16.4.0 text for several of these pages while the bundled 16.3.8 copy differed |
| The build machine has the real database URL | The unmarked page builds, and prerendering runs the query at build time and serves that result; step 1 still applies for per-request data |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Set a placeholder `DATABASE_URL` so `next build` passes | Mark the read as request-time (step 1) | Prerendering runs the query at build and serves its result |
| Keep `export const dynamic = 'force-dynamic'` after enabling Cache Components | Use `<Suspense>` plus `await io()` | The build fails on the `dynamic` export (measured) |

## Sources

- https://nextjs.org/docs/app/glossary (bundled `01-app/04-glossary.md:177`) — prerendering: "The result is HTML and RSC Payload, which can be cached and served from a CDN. Prerendering is the default for components that don't use Request-time APIs."
- https://nextjs.org/docs/app/guides/caching-without-cache-components (bundled `01-app/02-guides/caching-without-cache-components.md:97`) — "`'force-dynamic'`: Force dynamic rendering, which will result in routes being rendered for each user at request time."
- https://nextjs.org/docs/app/api-reference/functions/connection (bundled `01-app/03-api-reference/04-functions/connection.md:6, 82`) — "The `connection()` function allows you to indicate rendering should wait for an incoming user request before continuing."; "`connection` replaces `unstable_noStore`"
- bundled `01-app/03-api-reference/04-functions/io.md:83, 87, 109` — "The data comes from an awaited `fetch` or async database query wrapped in `<Suspense>`. The `await` is the suspension point."; `connection()` "stays suspended until a full user navigation reaches the server, so it also blocks prefetches"; "Prefer `io()` over `connection()`, and reach for `connection()` only when you need to wait for a real user request."; "`v16.3.0` | `io` added."
- https://nextjs.org/docs/app/guides/migrating-to-cache-components (bundled `01-app/02-guides/migrating-to-cache-components.md:76`) — "After enabling the flag, route segments that still export `dynamic`, `revalidate`, or `fetchCache` will error."
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config (bundled `02-route-segment-config/index.md`, Version History) — "`v16.0.0` | `dynamic`, `dynamicParams`, `revalidate`, and `fetchCache` removed when Cache Components is enabled."
- bundled `01-app/02-guides/building.md:59, 61` — route legend: `◐` "Partial Prerender | Static shell served immediately. Dynamic content streams in at request time."; `ƒ` "Dynamic | Server-rendered on demand for each request."
- bundled `01-app/01-getting-started/08-caching.md:99` and `01-app/03-api-reference/04-functions/cacheLife.md:73` — "For components that fetch data from an asynchronous source such as an API, a database, or any other async operation, and require fresh data on every request, do not use `"use cache"`."; `import { cacheLife } from 'next/cache'`
- bundled `01-app/03-api-reference/04-functions/unstable_noStore.md:7, 46` — "In version 15, we recommend using `connection` instead of `unstable_noStore`."; "`v15.0.0` | `unstable_noStore` deprecated for `connection`."
- Local builds 2026-10-11 (next 16.3.8, react 19.3.0, Turbopack; `env -u DATABASE_URL npx next build`, one directory per variant): the measured table above — the `io()` row and the no-`io()` throwing row in one run, the other seven rows in two separate runs; a `<Suspense>` child awaiting a 50 ms timer before the read, with no `io()`, built with `┌ ◐ /`
- Field origin 2026-10-10 (linkly-invitation t5 plan, the decision for `/`; recorded by the planning session): a static page failed `next build` with `ConfigError: DATABASE_URL is not set`
