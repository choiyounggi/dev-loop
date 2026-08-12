# Knowledge flush — 4 insight(s)

Queue drained: `~/.dev-loop/queue/` held 4 pending rows across 3 session files.
Result: 2 new pages, 1 merge into an existing page, 1 candidate corrected and
folded (its asserted directive did not survive verification).

## Verified best-practice

### 1. A plugin-bundled MCP server missing from `/mcp` is a registration fault first

**Claim.** When a Claude Code plugin's MCP server does not appear in `/mcp`, run
`/reload-plugins` before editing any configuration; MCP servers are connected at
the point the plugin layer loads, so a session that predates the install/edit
does not know the server.

**Sources checked.**
- https://code.claude.com/docs/en/plugins-reference — "Changes you make to a
  skill's `SKILL.md` take effect immediately in the current session. Changes to
  the plugin's other components, such as `hooks/`, `.mcp.json`, `agents/`, and
  `output-styles/`, do not. Run `/reload-plugins` or restart Claude Code to pick
  those up." Also: "When a plugin updates mid-session, hook commands, monitors,
  MCP servers, and LSP servers keep using the previous version's path."
- https://code.claude.com/docs/en/mcp — "At session startup, Claude Code connects
  the servers for enabled plugins automatically"; "If you enable or disable a
  plugin during a session, run `/reload-plugins` to connect or disconnect its MCP
  servers."

**How verified.** Both quotes read from the live official docs this session. The
session's own reproduction matches: `lnpl-mcp` 0.3.0 was installed, registered in
`enabledPlugins`, and answered `initialize` correctly when run by hand, yet was
absent from `/mcp` until `/reload-plugins`, which exposed its tools immediately.

**Confidence: verified.**

Sub-claim — **both `.mcp.json` shapes load** (a bare map of server names, and the
documented `{"mcpServers": {...}}` wrapper), so the shape is a poor first
suspect. The docs show only the wrapper; the bare map was verified by direct
observation rather than documentation: in this machine's plugin cache,
`context7` and `playwright` ship a bare map while `claude-mem`, `figma`, and
`atlassian` ship the wrapper, and servers of **both** shapes are live in this
session (their tools are callable as
`mcp__plugin_context7_context7__*` / `mcp__plugin_figma_figma__*`).
**Confidence: verified** (reproducible check, not doc-stated).

### 2. `.mcp.json` `env` — the queued directive did NOT verify; corrected before ingest

**Queued claim.** "Do not relay a variable the user already exports through
`env`; a stdio server is a child process, so it inherits the parent environment —
use `env` only to inject values the plugin alone knows."

**What the sources say.**
- https://github.com/modelcontextprotocol/typescript-sdk/issues/216 — the
  reference stdio client's `getDefaultEnvironment()` returns only
  `DEFAULT_INHERITED_ENV_VARS` (`HOME`, `LOGNAME`, `PATH`, `SHELL`, `TERM`,
  `USER` on POSIX) when `env` is absent, and a supplied `env` **replaces** rather
  than extends that set. An arbitrary exported variable such as `LNPL_IMPL` is
  not inherited by default in that implementation.
- https://code.claude.com/docs/en/mcp — states only that plugin servers get
  "access to the same environment variables as manually configured servers"; it
  does not document full parent-environment inheritance.

**Why the session's evidence does not carry it.** The cited measurement
(`cwd=/` + `export LNPL_IMPL` → correct `serverInfo`) was a **manual shell run**
of the server. That demonstrates shell-to-child inheritance, not what the harness
passes when it spawns the server. The claim is therefore **not substantiated**
and was **not ingested as a directive**.

**What was ingested instead — verified.** From
https://code.claude.com/docs/en/mcp: "If a referenced environment variable isn't
set and has no default value, the config still loads: Claude Code reports a
missing-variable warning for that server in `claude mcp list` output and uses the
unexpanded `${VAR}` text as-is." So the real hazard is the opposite of the
queued one: an unset `${VAR}` is delivered to the server as the literal string
`${VAR}` rather than failing loudly. The page's directive is to keep the `env`
entry with a `:-` default (or assert the value inside the server at startup).
**Confidence: verified.**

### 3. A send wrapper's success word is not proof the prompt was submitted

**Claim.** Treat a tmux send helper's exit 0 / "delivered" as "the keys reached
the pane"; confirm submission by reading the pane (empty input line + the
target's working indicator), and press Enter as its own key event when a
`[Pasted text #N]` placeholder is still in the buffer.

**Sources checked.**
- https://man7.org/linux/man-pages/man3/termios.3.html and
  https://man7.org/linux/man-pages/man1/tmux.1.html — already cited by the target
  page for the underlying mechanism (the tty echoes independently of the
  program's `read()`; `send-keys`/`capture-pane` report nothing about
  consumption).
- https://en.wikipedia.org/wiki/Bracketed-paste — already cited by
  `platforms-processes-non-interactive-cli-invocation` for why a pasted block's
  embedded newline is not a submit.

**How verified.** Reproduced this session across 3 tmux worker sessions:
`send-prompt.sh` returned 0/"delivered" for two workers whose panes both sat at
`❯ [Pasted text #3]`/`#4` unsubmitted, while the run that returned "queued" and
whose follow-up `wait` reported pick-up had genuinely submitted. `Enter` sent as
a separate key event started both stuck workers immediately.

**Confidence: verified** (mechanism doc-backed; the harness-specific exit-code
semantics field-reproduced this session).

### 4. After an auth cutover, a session key with readers and zero writers is the missed route

**Claim.** Having replaced an authentication mechanism, grep the retired session
key across the codebase and compare read sites to write sites. A key that is
still read but no longer written marks the route the migration missed; the old
gate's "empty config → allow" fallback makes it pass in development and refuse
everyone in production.

**Sources checked.**
- https://github.com/OWASP/ASVS/blob/master/4.0/en/0x12-V4-Access-Control.md —
  V4.1.5: "Verify that access controls fail securely including when an exception
  occurs."
- https://cwe.mitre.org/data/definitions/561.html — CWE-561 Dead Code: "The
  product contains dead code, which can never be executed … The surrounding code
  makes it impossible for a section of code to ever be executed." A gate reading
  a key no writer sets can only take its own default branch.
- https://cwe.mitre.org/data/definitions/1188.html — "Initialization of a
  Resource with an Insecure Default": "the default is not secure."
- https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
  — session claims are trustworthy only where the application still writes them.

**How verified.** All four source texts fetched and quoted this session. The
field incident is reproducible in its own repo: in `chungyak-alimi`,
`/notice/{no}` gated on `session["authed"]` with no code setting it; with
`WEB_USER` unset the suite was green, and the reproduction test failed
(303 ≠ 200) only when parameterized with `WEB_USER=admin`.

**Confidence: verified** (principle doc-backed by ASVS/CWE; the read/write census
technique field-tested, with the failing-then-passing test as evidence).

## Existing-layer check

Routed via `INDEX.md` → the domain indexes for `platforms`, `infrastructure`, and
`security`, then opened every page whose "load when" overlapped.

Pages read: platforms-processes-non-interactive-cli-invocation, infrastructure-agent-orchestration-pane-delivery-confirmation, security-authn-session-vs-token, platforms-tools-version-keyed-artifact-cache

| Candidate | Overlap found | Outcome |
|-----------|---------------|---------|
| 1 — MCP server absent from `/mcp` | No page covers plugin MCP registration. `platforms-tools-version-keyed-artifact-cache` is the nearest neighbour (a plugin update that keeps running old code) but its trigger is a stale version-keyed cache directory, not a server that never registered. Grep for `mcp` across `wiki/` hit only `backend/common/llm/context-window-budget` and `infrastructure/ci-cd/secrets-handling`, neither about server config | **New page**, cross-linked to the cache page in both directions |
| 2 — `.mcp.json` `env` | Same trigger family as candidate 1 (a plugin MCP server that does not work) | **Folded into the candidate-1 page** as two edge-case rows + one Instead-of row, with the unverified inheritance directive replaced by the sourced expansion behaviour. No second page — one case per page |
| 3 — send helper "delivered" ≠ submitted | **Already covered.** `infrastructure-agent-orchestration-pane-delivery-confirmation` owns the case (tty echo ≠ consumption; the evidence-strength table; "send the body and the submit key as separate calls"), and `platforms-processes-non-interactive-cli-invocation` already carries the `[Pasted text #1]` bracketed-paste edge case and its sources | **Merged, not created** — the genuinely new increment is the *wrapper's own exit code/status word* as false evidence, plus the queued-then-picked-up pair as a positive confirmation. Added 1 Instead-of row, 2 edge-case rows, 1 field-observation source; `last_verified` bumped to 2026-08-12 |
| 4 — retired auth gate | `security-authn-session-vs-token` is a mechanism-**choice** page (session vs JWT, revocation cost) and says nothing about a cutover's leftovers; `security-authz-resource-level-checks` covers per-resource authorization, not gate retirement | **New page**, cross-linked to both (`session-vs-token` given the reverse link) |

Conflicts flagged: none — nothing in the merged layer contradicts these
directives. The only correction is internal to this flush (candidate 2's queued
directive, handled above and recorded in `log.md`).

Related-links added: `platforms-tools-plugin-mcp-server-registration` ↔
`platforms-tools-version-keyed-artifact-cache` (both directions);
`security-authn-retiring-a-replaced-auth-gate` ↔ `security-authn-session-vs-token`
(both directions); one-way to `platforms-tools-harness-mediated-tool-results`,
`infrastructure-config-environment-config`, and
`security-authz-resource-level-checks`.

## Open-PR check

Listed with
`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` —
21 open `knowledge/*` heads: #79, #78, #76, #74, #73, #72, #69, #68, #66, #64,
#62, #61, #58, #57, #56, #55, #52, #51, #50, #49, #47.

Enumerated every `wiki/` path each of the 21 heads touches and filtered for the
three candidate areas (MCP/plugin, security/authn, tmux pane + `processes/`).
Overlapping paths, and what each in-flight change actually does:

| Open head | Overlapping path | Their change | Effect on this flush |
|-----------|------------------|--------------|----------------------|
| #51 | `pane-delivery-confirmation.md` | Adds pane **binding** rows (binding a new unit to a pane whose worker just reported done; failed-bind stage taxonomy) | Different case — no content overlap with candidate 3. Both edit the file, so the owner will resolve a `last_verified` line conflict |
| #64 | `pane-delivery-confirmation.md` | `related:` line only | No overlap |
| #57, #66 | `non-interactive-cli-invocation.md` | `related:` line only | No overlap |
| #56, #62, #76 | other `platforms/processes/` pages | Unrelated triggers (stderr diagnostics, background services, cloud CLI bounds, CLI JSON parsing) | No overlap |
| #51 | `wiki/security/index.md`, `security/data/commit-identity-in-public-repos.md` | A different security page + its index row | No overlap with `security/authn/` |

No open head touches plugin/MCP configuration or `security/authn/` at all.

**Per-candidate verdict:**

| Candidate | Verdict |
|-----------|---------|
| 1 — MCP server absent from `/mcp` | **new** — no open PR carries it |
| 2 — `.mcp.json` `env` | **new**, ingested as part of candidate 1's page (corrected form) |
| 3 — send helper "delivered" ≠ submitted | **new** relative to the open PRs (none carries this content), but merged into the existing merged-main page rather than given its own — the existing-layer check, not the open-PR check, is what bounded it |
| 4 — retired auth gate | **new** — no open PR touches `security/authn/` |

No sibling duplicate PR opened; nothing folded onto another branch; nothing
dropped as a pending duplicate.

## Routing decision

| Insight | Target | New category? |
|---------|--------|---------------|
| 1 + 2 (MCP server registration and `env` expansion) | `platforms` / `tools` / **new page** `plugin-mcp-server-registration.md` (`platforms-tools-plugin-mcp-server-registration`) | No. `platforms` owns "commands inspected before execution / toolchain and harness behaviour", and its `tools` category already holds the sibling harness cases (`version-keyed-artifact-cache`, `harness-mediated-tool-results`). Not `infrastructure/config` — the case is a harness's plugin-loading lifecycle, not per-environment application config |
| 3 (send helper's success word) | `infrastructure` / `agent-orchestration` / **merged into** `pane-delivery-confirmation.md` | No — merge-before-create; the page's trigger already names deciding "whether the input was consumed" |
| 4 (retired auth gate) | `security` / `authn` / **new page** `retiring-a-replaced-auth-gate.md` (`security-authn-retiring-a-replaced-auth-gate`) | No. `security/authn` already owns mechanism choice and password storage; gate retirement is the same category's cutover case. Not `security/authz` — the missed check is authentication state, not per-resource permission |

The harvested `domain:` hints were followed for all four (`platforms`,
`platforms`, `infrastructure`, `security`).

Plumbing updated: `wiki/platforms/index.md` and `wiki/security/index.md` each get
the new page with a "load when" line enumerating its distinct uses; `log.md` has
the dated `ingest` entry, including the candidate-2 correction. Both new pages
are within the 120-line body limit (61 and 67 lines); every `related:` id
resolves to an existing page.
