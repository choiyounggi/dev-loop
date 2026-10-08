---
id: backend-node-runtime-env-files-with-process-loadenvfile
domain: backend
category: runtime
applies_to: [nodejs]
confidence: verified
sources:
  - https://nodejs.org/docs/latest-v24.x/api/process.html#processloadenvfilepath
  - https://nodejs.org/docs/latest-v22.x/api/process.html#processloadenvfilepath
  - https://nodejs.org/docs/latest-v20.x/api/process.html#processloadenvfilepath
  - https://nodejs.org/docs/latest-v24.x/api/cli.html#--env-filefile
  - https://nodejs.org/docs/latest-v24.x/api/cli.html#--env-file-if-existsfile
  - https://nodejs.org/docs/latest-v24.x/api/util.html#utilparseenvcontent
  - https://github.com/nodejs/node/blob/7514ef8caff3feea55c60d628e003ccbda850485/src/node_dotenv.cc
  - https://github.com/nodejs/node/blob/v20.12.0/src/node_dotenv.cc
  - https://github.com/nodejs/node/blob/7514ef8caff3feea55c60d628e003ccbda850485/test/parallel/test-process-load-env-file.js
  - "Local reproduction 2026-10-08 (Node v26.7.0): layering order for the function and for repeated flags, shell precedence and two ways past it, literal `$` text, `\\n` in double quotes, NODE_OPTIONS through each path, a missing file and a relative path run from another directory"
last_verified: 2026-10-08
related: [infrastructure-config-environment-config, backend-common-orm-prisma-7-config-env-and-generated-client, security-secrets-secrets-in-code]
---

# Loading .env Files with process.loadEnvFile

## When this applies

Node code loads `.env`-style files with `process.loadEnvFile(path)` instead of the
`dotenv` package: layering `.env.local` over `.env`, a file that may be missing,
a `${OTHER}` or `cost$5` value arriving literally, a shell-set variable the file
does not replace, or `NODE_OPTIONS` in the file having no effect.

## Do this

`process.loadEnvFile` and the `--env-file` flags parse the same format but layer
differently; the rows below name which one they are about.

| Case | Do |
|------|----|
| The file may be absent (`.env.local` on a fresh clone) | Guard the call: `if (fs.existsSync(p)) process.loadEnvFile(p)`; a missing file throws `ENOENT`. The flag form `--env-file-if-exists=<file>` (v22.9.0+) skips a missing file |
| Two files are layered with `process.loadEnvFile` | Load the higher-priority file (`.env.local`) first. The function sets a variable only when it is absent from `process.env`, so the first value wins — including a value the shell set |
| Two files are layered with repeated flags (`--env-file=.env --env-file=.env.local`) | Put the higher-priority file last: "Subsequent files override pre-existing variables defined in previous files"; the shell still wins over both |
| A file value must replace a value the shell already set | Run `delete process.env.NAME` before `process.loadEnvFile(p)`, or read the file with `util.parseEnv(fs.readFileSync(p, 'utf8'))` and assign the names you need from the result |
| A value refers to another variable (`A=${B}-x`, `P=cost$5`) | Write the final text in the file, or build the value in code; the parser keeps `$` text literally and expands only `\n` inside double quotes (Node 20.12's parser also expands `\r`) |
| The path is relative (the default is `'./.env'`) | Build an absolute path from the module's own directory when the process can start elsewhere; a relative path resolves from `process.cwd()`, and an exists-guard then skips the file without an error |
| The file sets `NODE_OPTIONS` | Load that file with `--env-file`, which applies it, or set it in the launcher; `process.loadEnvFile` puts it in `process.env` with no effect on the running process |

## Edge cases

| Case | Then |
|------|------|
| Node older than 20.12.0 (or 21.0–21.6) | `process.loadEnvFile` does not exist; use the `dotenv` package |
| Node 20.x, 22.x before 22.21.0, 24.x before 24.10.0 | The API is marked experimental there (20.x: "Stability: 1.1 - Active development"); it is stable from 22.21.0 and 24.10.0 — pin the Node version the project tests on |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `${OTHER}` references in a file loaded with `process.loadEnvFile` | Write resolved values, or compose them in code after loading | The parser stores `${OTHER}` as literal text |
| Call `process.loadEnvFile('.env')` and then `('.env.local')` to let local values win | Load `.env.local` first | The function never overwrites, so the second file cannot replace the first file's values |
| Load the file and then read `process.env.NAME` expecting the file's value over the shell's | `delete process.env.NAME` before loading, or assign from `util.parseEnv` | After loading, `process.env.NAME` still holds the shell's value, and the function keeps no copy of the file's |

## Sources

- https://nodejs.org/docs/latest-v24.x/api/process.html#processloadenvfilepath — "Added in: v21.7.0, v20.12.0"; "v24.10.0 This API is no longer experimental."; `path` "Default: './.env'"; "Loads the .env file into process.env. Usage of NODE_OPTIONS in the .env file will not have any effect on Node.js."
- https://nodejs.org/docs/latest-v22.x/api/process.html#processloadenvfilepath — "v22.21.0 This API is no longer experimental."
- https://nodejs.org/docs/latest-v20.x/api/process.html#processloadenvfilepath — "Added in: v20.12.0", "Stability: 1.1 - Active development"
- https://nodejs.org/docs/latest-v24.x/api/cli.html#--env-filefile — "You can pass multiple --env-file arguments. Subsequent files override pre-existing variables defined in previous files."; "The environment variables which configure Node.js, such as NODE_OPTIONS, are parsed and applied. If the same variable is defined in the environment and in the file, the value from the environment takes precedence."; "An error is thrown if the file does not exist."
- https://nodejs.org/docs/latest-v24.x/api/cli.html#--env-file-if-existsfile — "Added in: v22.9.0"; "Behavior is the same as --env-file, but an error is not thrown if the file does not exist."
- https://nodejs.org/docs/latest-v24.x/api/util.html#utilparseenvcontent — `util.parseEnv(content)`, "Added in: v21.7.0, v20.12.0", `content` "The raw contents of a .env file", returns an object
- https://github.com/nodejs/node/blob/7514ef8caff3feea55c60d628e003ccbda850485/src/node_dotenv.cc — lines 74-75 look the name up and set it only `if (!existing.has_value())`; line 228 "Expand new line if \n it's inside double quotes" is the only expansion; Node v20.12.0's `src/node_dotenv.cc` (lines 124-125) also turns the two characters `\r` into a carriage return
- https://github.com/nodejs/node/blob/7514ef8caff3feea55c60d628e003ccbda850485/test/parallel/test-process-load-env-file.js — lines 47-50 "should throw when file does not exist" with `{ code: 'ENOENT', syscall: 'open' }`
- Local reproduction 2026-10-08 (Node v26.7.0): `process.loadEnvFile` of `a.env` then `b.env` kept `a.env`'s `K`, the reverse order kept `b.env`'s; `--env-file=b.env --env-file=a.env` gave `a.env`'s `K` and the reverse gave `b.env`'s; `K=from-shell` survived the function, while `delete process.env.K` before loading, or assigning from `util.parseEnv`, gave the file's value; `BAZ=${BAR}-suffix` and `QUX=cost$5` arrived unchanged; `"x\ny"` became two lines; `NODE_OPTIONS=--max-old-space-size=123` in a file cut the heap limit to 219 MB through `--env-file` and left it at 4192 MB through `process.loadEnvFile`; `process.loadEnvFile('.env.rel')` threw `ENOENT` from a subdirectory and loaded from the file's own directory
