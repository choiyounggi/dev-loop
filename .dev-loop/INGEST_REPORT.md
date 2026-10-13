# Knowledge flush — 4 insight(s)

Six claimed queue rows became **4 new pages, 0 merges, 0 drops, 2 local-layer rows**:
- A dead first DNS server that adds about 5 s to every outbound call (`debugging/network`).
- A Claude Code plugin whose npm dependencies are missing after an update (`platforms/tools`).
- Done criteria that a task split assigns to the wrong piece (`infrastructure/agent-orchestration`).
- `reader.cancel()` on a Node-stream request body that never settles (`backend/node/async`).

Claimed rows (run `20261010-221818-2974`):
- `3be5bdead3f07fb5`: DNS
- `b4f831f51faf06b7`: plugin dependencies
- `3c75059217baccb5`: split-task DoD
- `3cf7069fd51c2a57`: request-body reader cancel
- `a525cd52ad3a644e`, `ac0e8ad633885234`: linkly plan-gaps rows → local layer (see last section)

The first three were drafted by run `20261010-021344-36918`, which stopped before its review and PR. This run kept that work (main had not moved: merge base `f7c865c` = `origin/main`), re-checked the plugin docs claim, added the fourth page, and ran the review.

The four ingested candidates are general. None names one repository's own files or conventions.

## Verified best-practice

### 1. `3be5bdead3f07fb5` → `debugging-network-unresponsive-first-nameserver` — **verified**

**Claim.** When every outbound call from one host is about 5 s slow, or a client with a 5 s timeout fails while curl slowly succeeds:
1. Split the request's time with `curl -w` (`time_namelookup`).
2. Probe each `/etc/resolv.conf` nameserver on its own.

The glibc resolver waits `timeout` (default 5 s) on an unresponsive first server before it tries the next one.

**Sources checked:**
- resolv.conf(5): https://man7.org/linux/man-pages/man5/resolv.conf.5.html
  - Servers are queried "in the order listed".
  - `timeout` defaults to RES_TIMEOUT (5); `attempts` defaults to 2.
  - Also covers `rotate` and `RES_OPTIONS`.
- curl `--write-out` timing variables: https://curl.se/docs/manpage.html
- libcurl timeouts, which explain why curl succeeds where a 5 s client fails:
  - https://curl.se/libcurl/c/CURLOPT_CONNECTTIMEOUT.html: the connection phase includes DNS; default 300 s.
  - https://curl.se/libcurl/c/CURLOPT_TIMEOUT.html: default 0, meaning it never times out.
- Node: https://nodejs.org/api/dns.html
  - `dns.lookup()` is `getaddrinfo(3)` and follows `resolv.conf`.
  - `dns.resolve*()` sends its own DNS queries over the network.
- systemd-resolved(8): https://man7.org/linux/man-pages/man8/systemd-resolved.service.8.html
  - The stub is `127.0.0.53`; the real servers are in `/run/systemd/resolve/resolv.conf`.
  - resolved stays on one server until it sees an error.
- NetworkManager:
  - https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html: `rc-manager` writes the file.
  - https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html: `ipv4.ignore-auto-dns`.
  - https://networkmanager.dev/docs/api/latest/nmcli.html: `device reapply`.
- musl: https://wiki.musl-libc.org/functional-differences-from-glibc.html
  - musl queries every listed server in parallel, so the cause does not apply there.
  - Added as an edge-case row.

**How it was verified.** Reproduced in throwaway containers and on the macOS host, using the TEST-NET-1 address `192.0.2.1` as the dead server:

```
glibc (node:22-bookworm-slim, --dns 192.0.2.1 --dns 1.1.1.1): dns.lookup 5031 ms; fetch(AbortSignal.timeout(4000)) → TimeoutError at 4007 ms
  + options timeout:1                                         : dns.lookup 1021 ms
  control (--dns 1.1.1.1)                                     : dns.lookup 12 ms; fetch 200 in 596 ms
musl (python:3-alpine, same server order)                     : getaddrinfo 54 ms vs 55 ms control
dig @192.0.2.1 example.com +time=2 +tries=1 → "connection timed out; no servers could be reached" (2 s); live server → NOERROR, 5 ms
Node Resolver({timeout:2000,tries:1}) single-server probe → 192.0.2.1 ETIMEOUT 2995 ms; 1.1.1.1 ok 5 ms
```

**Changes from the candidate:**
- The field evidence's real router address is not reproduced on the page.
- Added edge-case rows for systemd-resolved, macOS, musl, `rotate`, and hosts without `dig`.

### 2. `b4f831f51faf06b7` → `platforms-tools-plugin-dependencies-after-an-update` — **verified, directive refined**

**Candidate directive.** After a plugin update, check `node_modules` in the `installPath` that `installed_plugins.json` records. Give such plugins a `SessionStart` self-install for when `node_modules` is missing.

**What the docs say** (https://code.claude.com/docs/en/plugins/loading):
- Claude Code already installs a plugin's Node.js dependencies into every new version directory.
- It does so only when the plugin root has `package.json` **and** a supported lockfile:
  - `package-lock.json` or `npm-shrinkwrap.json` (lockfile v2 or v3), or
  - a text `bun.lock`.
- The "packages … not installed" note in `claude plugin list` also requires a lockfile.
- Orphaned version directories are removed 14 days after their `.orphaned_at` marker.

**Fallbacks and related limits:**
- The documented fallback is a `SessionStart` install into `${CLAUDE_PLUGIN_DATA}` (https://code.claude.com/docs/en/plugins/components).
- `${CLAUDE_PLUGIN_DATA}` is kept across updates (https://code.claude.com/docs/en/plugins/manifest-reference).
- The two failure notes are explained at https://code.claude.com/docs/en/plugins/troubleshooting.
- ESM `import` ignores `NODE_PATH` (https://nodejs.org/api/esm.html).

**How it was verified** (local, Claude Code 2.1.295, plugin auto-velog):

```
installed_plugins.json: installPath …/auto-velog/0.2.2
0.2.0, 0.2.1: package-lock.json + node_modules/playwright, both with .orphaned_at; lockfile mtime 38 h / 9 min after the
              directory's other files → a hand-run npm install, not a shipped lockfile
0.2.2: package.json only — no lockfile, no node_modules
upstream (GitHub API): 0 commits ever touched package-lock.json; .gitignore has listed it since the first commit (aa17934)
claude plugin list: auto-velog 0.2.2 "✔ enabled", no dependency note
import.meta.resolve('playwright'): from 0.2.1/scripts → its own node_modules; from 0.2.2/scripts → ERR_MODULE_NOT_FOUND
Node 26.7.0: .mjs import + NODE_PATH → ERR_MODULE_NOT_FOUND; CJS require + NODE_PATH → loads; symlinked node_modules → import loads
```

**Resulting directive:**
- Commit the lockfile so the built-in install runs on every install, update and new machine.
- Keep the `${CLAUDE_PLUGIN_DATA}` hook for what that install cannot provide.

The candidate's mechanism holds: each update is a fresh version directory, `node_modules` is not in the source, and old directories hide the gap. Its fix is kept as the fallback rather than the first step.

### 3. `3c75059217baccb5` → `infrastructure-agent-orchestration-done-criteria-in-a-split-task-piece` — **field-tested**

**Claim.** When adopting one piece of a split task whose DoD was rewritten at split time:
- Map each DoD item to the task and test in your own piece before coding.
- An item proven only in a sibling piece is a contradiction to report first.

**Sources:**
- https://www.anthropic.com/engineering/multi-agent-research-system: each subagent needs "clear task boundaries"; "Without detailed task descriptions, agents duplicate work, leave gaps, or fail to find necessary information".
- https://en.wikipedia.org/wiki/Traceability_matrix: correlates requirements with test cases; "Zero values indicate that no relationship exists".

**Why field-tested, not verified.** The sources support the technique: trace each requirement to the test that proves it, and keep clear boundaries between delegated pieces. The specific failure mode rests on one field case (split piece t6, recorded by the originating session): a split-time DoD restated into function names gave one piece an outcome its sibling's plan proves.

**Also checked.** The "Splitting a task mid-run" section of dev-loop's `skills/orchestrate/SKILL.md` judges a split only by overlap in each piece's `files` and `outputs`. It says nothing about dividing the DoD between pieces, which is the gap this page fills. The skill itself is not changed in this PR.

### 4. `3cf7069fd51c2a57` → `backend-node-async-request-body-reader-cancel` — **verified**

**Claim.** When a handler races `reader.read()` on a Node-stream-backed `Request` body (Next.js Node runtime) against a deadline, call `reader.cancel().catch(() => {})` without awaiting it and run cleanup at once. `await reader.cancel()` can wait until Node's `requestTimeout` on a client that sends nothing.

**Sources checked:**
- https://streams.spec.whatwg.org/#readable-stream-cancel — cancel closes the stream, then waits on the source's cancel algorithm.
- https://streams.spec.whatwg.org/#readable-stream-from-iterable — `ReadableStream.from` cancel calls the iterator's `return()` and waits for it.
- https://github.com/nodejs/undici/blob/main/lib/web/fetch/body.js — an async-iterable body becomes `ReadableStream.from(object)` (read at lines 219–240 of the fetched file).
- https://github.com/nodejs/node/blob/main/lib/internal/streams/readable.js — the readable async iterator: "Requests received while another is outstanding are queued and processed in order."
- https://nodejs.org/api/http.html#serverrequesttimeout — default `300000` (anchor and value confirmed in the page and in `doc/api/http.md`).
- Next.js 16.3.8 `dist/server/web/spec-extension/adapters/next-request.js` `fromNodeNextRequest`: `body = request.body` (the Node `IncomingMessage`) is passed to `new Request`.

**How it was verified** (Node v26.7.0, local script):

```
Request(body: PassThrough): cancel STILL PENDING after 3000 ms; read resolved done=true
Readable.toWeb(PassThrough): cancel resolved in 1 ms; read resolved done=true
new ReadableStream({}) fake: cancel resolved in 1 ms; read resolved done=true
```

**Changes from the candidate:** added that the pending `read()` itself resolves `{done: true}` (only the cancel promise hangs), and that `Readable.toWeb` does not hang. The real-session field numbers (311 s, 4 stalled POSTs) stay as a field case.

## Existing-layer check

Pages read: platforms-processes-non-interactive-cli-invocation, backend-common-reliability-timeouts-and-retries, backend-java-kotlin-coroutines-dispatchers-and-blocking, backend-common-llm-self-hosted-model-load-latency, platforms-tools-version-keyed-artifact-cache, platforms-tools-plugin-mcp-server-registration, platforms-toolchains-agent-files-written-by-next-dev, infrastructure-agent-orchestration-gate-evidence-exit-code-class, platforms-toolchains-native-addon-binary-missing-after-bun-install, infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan, infrastructure-agent-orchestration-worker-reported-plan-contradiction, infrastructure-agent-orchestration-inbound-validation-ownership-in-task-decomposition, infrastructure-agent-orchestration-verify-command-in-a-worker-brief, infrastructure-agent-orchestration-unattended-worker-questions, testing-quality-cross-task-stub-assertions, qa-document-verification-superseding-a-knowledge-record, databases-query-optimization-repeated-sublinks-in-a-pulled-up-derived-table, backend-node-async-promise-error-handling, backend-node-async-request-body-reader-cancel, backend-java-jpa-raw-jdbc-inside-a-jpa-transaction, testing-async-teardown-after-aborted-tasks

**Method:**
1. Read `INDEX.md`, then the domain indexes for debugging, platforms and infrastructure.
2. Ran `grep -rli` over all 426 pages on `origin/main` for each candidate's key terms:
   - DNS: `resolv.conf`, `nameserver`, `namelookup`, `getaddrinfo`
   - Plugin: `CLAUDE_PLUGIN_DATA`, `installed_plugins`, `installPath`, `ERR_MODULE_NOT_FOUND`
   - Split DoD: `DoD`, `definition of done`, `split`, `traceab`
3. Ran `wiki_search` (k=5) with each trigger sentence, then read "When this applies" on every hit page.

| Candidate | wiki_search top 5 (score) | Overlap verdict |
|---|---|---|
| DNS | non-interactive-cli-invocation ×2 (0.763, 0.753), timeouts-and-retries (0.746), coroutines-dispatchers-and-blocking (0.745), self-hosted-model-load-latency (0.745) | No page covers resolver delay; the grep found zero pages for any of the DNS terms → **new page** |
| Plugin deps | agent-files-written-by-next-dev ×2 (0.793, 0.763), gate-evidence-exit-code-class ×2 (0.773, 0.762), plugin-mcp-server-registration (0.753) | Closest is version-keyed-artifact-cache, which covers the publisher side (unchanged version → stale cache). It says nothing about the dependencies of a correctly bumped version → **new page**, linked both ways |
| Split DoD | checkable-claims-in-an-adopted-plan ×2 (0.697, 0.694), cross-task-stub-assertions (0.694), superseding-a-knowledge-record (0.692), repeated-sublinks-in-a-pulled-up-derived-table (0.689) | checkable-claims covers numbers, symbol contracts and dependency tables in an adopted plan, not DoD ownership across split pieces. It already has 124 body lines, over the 120 limit, so merging in was not an option → **new page**, linked both ways |
| Reader cancel | raw-jdbc-inside-a-jpa-transaction (0.786), promise-error-handling ×2 (0.781, 0.774), teardown-after-aborted-tasks ×2 (0.761, 0.750) | promise-error-handling owns "race a deadline, abort the loser" but not a cancel that itself never settles; teardown-after-aborted-tasks is the tokio analogue (cancel returns before it completes); raw-jdbc is a Spring transaction timeout, unrelated. `grep -rliE "reader\.cancel\|getReader\|ReadableStream\|requestTimeout\|duplex"` over `wiki/` hit 14 pages, none on stream cancel → **new page** |

**Conflicts:** none. No new directive contradicts an existing one.

**Related links added both ways:**
- DNS page ↔ backend-common-reliability-timeouts-and-retries.
- Plugin page ↔ version-keyed-artifact-cache, plugin-mcp-server-registration, native-addon-binary-missing-after-bun-install.
- Split-DoD page ↔ checkable-claims-in-an-adopted-plan, worker-reported-plan-contradiction, inbound-validation-ownership-in-task-decomposition, verify-command-in-a-worker-brief.
- Reader-cancel page ↔ backend-node-async-promise-error-handling, testing-async-teardown-after-aborted-tasks; one way → backend-common-reliability-timeouts-and-retries.

The split-DoD page also links one way to unattended-worker-questions, the channel it reports through. checkable-claims links to that page the same way.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` returned one open head: **#265** `knowledge/choiyounggi-20261009-222812`. It covers wrapped grep, review diff base, frontmatter quotes, GITHUB_TOKEN chaining and blind LLM judges.

`git diff origin/main...origin/knowledge/choiyounggi-20261009-222812 -- wiki/ INDEX.md` touches 22 files. A scan for every candidate's key terms found no overlapping trigger:

| Candidate | Overlapping open head | Verdict |
|---|---|---|
| `3be5bdead3f07fb5` DNS | none | **new** |
| `b4f831f51faf06b7` plugin deps | none | **new** |
| `3c75059217baccb5` split DoD | none | **new** |
| `3cf7069fd51c2a57` reader cancel | none — `git diff origin/main...origin/knowledge/choiyounggi-20261009-222812 -- wiki/` has 0 lines matching `reader\.cancel\|getReader\|ReadableStream\|requestTimeout\|duplex` (positive control `GITHUB_TOKEN`: 17) | **new** |

**Merge note.** Measured with `git merge-tree --write-tree <this branch> origin/knowledge/choiyounggi-20261009-222812` (merge base `d04462f`). Whichever PR merges second sees two conflicts:
- `log.md`: both PRs append at the end. Keep both blocks.
- `.dev-loop/INGEST_REPORT.md`: every flush rewrites it. Keep the later PR's report.

`wiki/infrastructure/index.md` and `wiki/platforms/index.md` merge automatically, and no wiki page conflicts. The root `INDEX.md` is unchanged here because #265 rewrites the qa and platforms rows on either side of the debugging row.

## Routing decision

| Candidate | Target page | Why |
|---|---|---|
| DNS | `wiki/debugging/network/unresponsive-first-nameserver.md` | The directive is diagnosis: split the timing, then find the dead server. `debugging/network` already exists (epipe-write-ordering). Fix guidance stays short, per the debugging domain's "fix → owning domain" rule. The root debugging row ("Diagnosing a failure") already routes here |
| Plugin deps | `wiki/platforms/tools/plugin-dependencies-after-an-update.md` | The other Claude Code plugin pages already live here (version-keyed-artifact-cache, plugin-mcp-server-registration) |
| Split DoD | `wiki/infrastructure/agent-orchestration/done-criteria-in-a-split-task-piece.md` | Sibling of checkable-claims-in-an-adopted-plan and worker-reported-plan-contradiction. The root row "multi-agent orchestration" routes here |
| Reader cancel | `wiki/backend/node/async/request-body-reader-cancel.md` | The mechanism is Node's (undici body + readable iterator), so `backend/node`, not `common`; `async` already holds the deadline-race page it extends. Next.js is one caller, not the owner |

No new category. Each domain `index.md` gained one row.

## Independent review

A fresh-context adversarial reviewer (read-only, `git status --porcelain` empty afterwards) checked commit `8d8e603`:
- 19 load-bearing claims across the 4 pages fetched against their cited sources: 19 CONFIRMED, 0 WRONG, 0 UNSUPPORTED. This includes an independent run of the reader-cancel reproduction (`cancel STILL PENDING after 3000 ms; read resolved done=true`) and the Next.js 16.3.8 `fromNodeNextRequest` source (`body = request.body`).
- Plumbing: 11/11 `related:` ids resolve, 20/20 `Pages read:` ids resolve, 10/10 claimed back-links present, 4 index rows present.
- Format: body lines 77 / 74 / 64 / 59; all template sections; no vague words in directives.

Findings and resolutions:

| Finding | Resolution |
|---|---|
| high: this section still held the placeholder | Filled with this review |
| low: the two man7.org URLs on the DNS page time out (reviewer and this run both got `curl: (28)`, HTTP 000); DNS resolves | Content re-checked on the Debian copies, both HTTP 200: `manpages.debian.org/bookworm/manpages/resolv.conf.5.en.html` ("the default is RES_TIMEOUT (currently 5)") and `.../systemd-resolved.service.8.en.html` (stub on 127.0.0.53, `/run/systemd/resolve/resolv.conf`). man7.org stays the cited canonical URL; the timeout looks like a site/network outage, not a moved page |

Merge note re-measured after the fourth page: `git merge-tree --write-tree --name-only HEAD origin/knowledge/choiyounggi-20261009-222812` still lists only `.dev-loop/INGEST_REPORT.md` and `log.md` as conflicts.

## Local-layer candidates

Two rows from `plan-gaps.jsonl`, project `linkly` (planning task t1-password-union). Both directives name linkly's compiler internals (`lower.py`, `scope.resolve_field`, `scope.network_bindings`, RFC-0053), so they would be wrong in another codebase. Excluded from this PR and retired from the queue:

| Row | Decision it records | Target |
|---|---|---|
| `a525cd52ad3a644e` | Semantics of the shared Password-family judgement (`_password_family_declarations`) | `wiki-local/backend/compiler/password-family-declarations.md` in linkly — run wiki-ingest inside that project |
| `ac0e8ad633885234` | Where the `with` check runs | `wiki-local/backend/compiler/with-check-placement.md` in linkly — run wiki-ingest inside that project |

The four ingested candidates hold outside the projects they came from:
- the DNS case: a home server
- the plugin case: the auto-velog plugin
- the split-DoD case: one piece of an orchestrated run
- the reader-cancel case: a Next.js app's upload route
