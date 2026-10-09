---
id: backend-node-boundaries-nestjs-multer-upload-errors
domain: backend
category: boundaries
applies_to: [nestjs, express, multer]
confidence: verified
sources:
  - https://github.com/nestjs/nest/blob/master/packages/platform-express/multer/multer/multer.utils.ts
  - https://github.com/nestjs/nest/blob/master/packages/platform-express/multer/interceptors/file.interceptor.ts
  - https://github.com/nestjs/docs.nestjs.com/blob/master/content/http/file-upload.md
  - https://docs.nestjs.com/exception-filters
last_verified: 2026-10-01
related: [backend-node-boundaries-runtime-validation, backend-common-errors-exception-handling, testing-quality-tests-that-cannot-fail]
---

# Custom Error Bodies for Upload Failures in a NestJS Multer Route

## When this applies

A NestJS route on `@nestjs/platform-express` uses `FileInterceptor`,
`FilesInterceptor`, `FileFieldsInterceptor`, or `AnyFilesInterceptor`, and the
API needs its own error body for upload failures — file too large, too many
files, an unexpected field, a malformed multipart body. Also when a
`@Catch(MulterError)` filter is registered and never runs.

## Do this

1. **Catch the HTTP exceptions the interceptor produces, not `MulterError`.**
   The interceptor runs multer inside a promise and passes every error through
   `transformException` before rejecting, so the filter chain receives an
   `HttpException` subclass.

| Multer / busboy failure | What the filter chain receives |
|-------------------------|--------------------------------|
| `LIMIT_FILE_SIZE` | `PayloadTooLargeException` (413), message = multer's message |
| `LIMIT_FILE_COUNT`, `LIMIT_FIELD_KEY`, `LIMIT_FIELD_VALUE`, `LIMIT_FIELD_COUNT`, `LIMIT_FIELD_NESTING`, `LIMIT_FIELD_ARRAY_INDEX`, `INVALID_FIELD_NAME`, `LIMIT_UNEXPECTED_FILE`, `LIMIT_PART_COUNT`, `MISSING_FIELD_NAME` | `BadRequestException` (400), message = `"<multer message> - <field>"` when multer set `field` |
| Busboy: multipart boundary not found, malformed part header, unexpected end of form / file | `BadRequestException` (400); the three non-boundary messages are prefixed `Multipart: ` |
| An error thrown by your own `fileFilter` or storage engine that is already an `HttpException` | Passed through unchanged |
| Any other error | Passed through unchanged — it reaches the default 500 path |

2. **Scope the filter to the upload route** with `@UseFilters(UploadErrorFilter)`
   on the handler, and declare `@Catch(PayloadTooLargeException, BadRequestException)`.
   A global `BadRequestException` filter would also rewrite validation-pipe
   errors on every other route.

3. **Reject a wrong file type from `fileFilter` with your own typed exception**
   (`cb(new UnsupportedMediaTypeException(...), false)`). It is an
   `HttpException`, so it passes through `transformException` untouched and the
   filter can branch on its class instead of parsing a message.

4. **Test through HTTP, one case per mapped status.** Send an oversized file and
   an unexpected field name through `supertest` against the real interceptor and
   assert status plus the custom body; a unit test that calls the filter with a
   hand-built `MulterError` proves a path production never takes
   ([testing-quality-tests-that-cannot-fail]).

## Edge cases

| Case | Then |
|------|------|
| The filter must tell "unexpected field" from another 400 on the same route (a `ParseFilePipe` or DTO failure) | Branch on the exception message's multer text and treat that as version-coupled: the source notes messages changed between releases ("Unexpected field" became "Unexpected file field"). Pin the expected text in the HTTP test so an upgrade reddens it |
| You need the original multer `code` | It is not carried on the transformed exception. Map status + message in the filter, or wrap multer yourself in a custom interceptor that attaches the code before rethrowing |
| The app runs on the `FastifyAdapter` (NestJS v12.1+ ships the same interceptors from `@nestjs/platform-fastify/multipart`, backed by `@fastify/multipart`) | The docs state those interceptors "fail with the same error responses"; the mapping table above was read from the Express package source, so keep the same HTTP-level tests (oversized file, unexpected field) on the Fastify route as the proof for your version |
| Size must be validated per field rather than per request | Keep a generous `limits.fileSize` as the hard stop and validate per-file size in a `ParseFilePipe` validator, which throws from the pipe stage with its own message |
| Global `MulterModule.register({ limits })` plus route-level `limits` | Current Nest merges `limits` key-by-key; assert the effective limit with an HTTP test on the installed version rather than assuming replace-or-merge |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Register `@Catch(MulterError)` to shape upload errors | `@Catch(PayloadTooLargeException, BadRequestException)` on the upload route | The interceptor converts the error before any filter sees it; a `MulterError` filter matches nothing |
| Unit-test the filter by constructing `new MulterError('LIMIT_FILE_SIZE')` | Post an oversized multipart body through the route | The hand-built input is a type the filter never receives at runtime |
| Register the upload filter globally | Route-scope it | Every unrelated 400 would take the upload error shape |

## Sources

- https://github.com/nestjs/nest/blob/master/packages/platform-express/multer/multer/multer.utils.ts — `transformException`: returns the error unchanged when it is falsy or `instanceof HttpException`; maps `LIMIT_FILE_SIZE` to `new PayloadTooLargeException(error.message)`, the other multer limit codes to `BadRequestException` (appending ` - ${error.field}` when present), busboy multipart errors to `BadRequestException`; source comment: "Multer identifies its errors by `code`, while the messages may change between releases (e.g. \"Unexpected field\" became \"Unexpected file field\")" (fetched 2026-10-01)
- https://github.com/nestjs/nest/blob/master/packages/platform-express/multer/interceptors/file.interceptor.ts — inside the interceptor's promise: `const error = transformException(err); return reject(error);`
- https://github.com/nestjs/docs.nestjs.com/blob/master/content/http/file-upload.md — "The `FileInterceptor()` decorator is exported from the `@nestjs/platform-express` package"; "Starting with NestJS v12.1, applications running on the `FastifyAdapter` … can handle file uploads with the same API, backed by the @fastify/multipart plugin instead of Multer"; the interceptors "take the same arguments and options, populate the request in the same way, and fail with the same error responses" (fetched 2026-10-01)
- https://docs.nestjs.com/exception-filters — "The `@Catch()` decorator accepts a single parameter or a comma-separated list, which lets you set up the filter for several types of exceptions at once"; `@UseFilters()` binds a filter to a method or controller
- Field evidence 2026-09-30 (a NestJS API, `@nestjs/platform-express` 12.1.1): a `@Catch(MulterError)` filter on a profile-upload route never fired; reading the installed `multer.utils.js` and `file.interceptor.js` showed the conversion, and the route-scoped HttpException filter produced the custom bodies
