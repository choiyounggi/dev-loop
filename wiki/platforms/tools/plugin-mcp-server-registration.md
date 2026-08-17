---
id: platforms-tools-plugin-mcp-server-registration
domain: platforms
category: tools
applies_to: [claude-code]
confidence: verified
sources:
  - https://code.claude.com/docs/en/plugins-reference
  - https://code.claude.com/docs/en/mcp
  - https://github.com/modelcontextprotocol/typescript-sdk/issues/216
last_verified: 2026-08-12
related: [platforms-tools-version-keyed-artifact-cache, platforms-tools-harness-mediated-tool-results, infrastructure-config-environment-config]
---

# A Plugin-Bundled MCP Server That Does Not Appear in the Harness

## When this applies

You installed or edited a Claude Code plugin that bundles an MCP server and the
server is absent from `/mcp`, or its tools are not callable — while the plugin's
skills and commands work. Also when you are about to change that plugin's
`.mcp.json` shape, `command`/`args`, or `env` to make it appear.

## Do this

1. **Reload the plugin layer before editing any config.** Run `/reload-plugins`,
   then re-open `/mcp`. A plugin's MCP servers are connected at session startup
   for plugins that were already enabled; a plugin enabled, installed, or updated
   mid-session keeps the session's previous plugin state until you reload.
2. **When it is still absent after a reload, read the harness's own report before
   changing the file**: `claude mcp list` names the per-server failure detail and
   any missing-variable warning, and `claude --debug` prints server
   initialization errors.
3. **Run the installed copy by hand as the third step**, from the same working
   directory the session uses, and feed it one `initialize` request on stdin. A
   valid `serverInfo` response separates "the server is broken" from "the harness
   never started it".
4. **Compare against a working sibling's file, not against your memory of the
   schema**: `find ~/.claude/plugins/cache -maxdepth 4 -name .mcp.json`.

Order the hypotheses by what each one explains:

| Observation | Conclusion |
|-------------|------------|
| Server absent from `/mcp`, plugin's skills present, session predates the install/edit | The session holds the pre-change plugin state — reload |
| Server listed in `/mcp` with a failure status | The spawn or handshake failed — take the detail from `claude mcp list` / `claude --debug` |
| Server absent after a reload and a manual run answers `initialize` correctly | The config is not being read as you think — compare shape and placeholder expansion against a working sibling |
| Tools present but named unexpectedly | Plugin server tools are `mcp__plugin_<plugin>_<server>__<tool>`; search by that form before concluding they are missing |

## Edge cases

| Case | Then |
|------|------|
| The file is a bare map of server names, with no `"mcpServers"` wrapper | Both shapes load. The documented form wraps entries in `"mcpServers"`, and installed plugins ship both — treat the shape as an unlikely cause and keep looking |
| You relay a value the user already exports, as `"env": {"VAR": "${VAR}"}` | Give it a default (`${VAR:-<value>}`) or assert on the value inside the server at startup: with no default and the variable unset, the config still loads and the server receives the literal text `${VAR}`, warning only in `claude mcp list` |
| You are tempted to drop `env` and let the child inherit the variable from your shell | Keep the entry (with a default) unless you have confirmed the inheritance for your harness version — the MCP reference stdio client passes only a fixed allowlist (`HOME`, `PATH`, `SHELL`, `TERM`, `USER`, `LOGNAME`) to the child when `env` is absent |
| The plugin was updated mid-session | Hooks, MCP servers, and LSP servers keep the previous version's `${CLAUDE_PLUGIN_ROOT}` path until `/reload-plugins`; monitors need a session restart ([platforms-tools-version-keyed-artifact-cache] owns the stale-cache case) |
| Only the plugin's slash commands are missing after a reload | The reload connects MCP servers but has not always rebuilt the command index — restart the session for commands specifically |
| The server writes logs to stdout | The harness reads stdout as protocol frames and disconnects the server, counting it as a crash — send logs to stderr |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rewrite `.mcp.json` into the other shape because the server is missing | Run `/reload-plugins` first, then `claude mcp list` | Both shapes are accepted, so a shape edit that "fixes" it was really the reload; the true cause survives to the next install |
| Conclude the server is broken because `/mcp` does not list it | Run the installed copy by hand and feed it one `initialize` | A server that answers `initialize` was never started by the harness — that is a registration fault, not a server fault |
| Add `env` entries for variables your shell already exports, to be safe | Add them with `:-` defaults, or read the value inside the server and fail loudly when it is absent | An unexpanded `${VAR}` is delivered as literal text rather than rejected, so the server starts with a wrong value instead of not starting |

## Sources

- https://code.claude.com/docs/en/plugins-reference — "Changes you make to a skill's `SKILL.md` take effect immediately in the current session. Changes to the plugin's other components, such as `hooks/`, `.mcp.json`, `agents/`, and `output-styles/`, do not. Run `/reload-plugins` or restart Claude Code to pick those up"; "When a plugin updates mid-session, hook commands, monitors, MCP servers, and LSP servers keep using the previous version's path. Run `/reload-plugins` to switch hooks, MCP servers, and LSP servers to the new path; monitors require a session restart"; troubleshooting for a server whose tools do not appear ("Check the MCP server logs: `claude --debug` shows initialization errors", "Test the server manually outside of Claude Code"); stdout is read as protocol messages and non-protocol output disconnects the server
- https://code.claude.com/docs/en/mcp — "At session startup, Claude Code connects the servers for enabled plugins automatically"; "If you enable or disable a plugin during a session, run `/reload-plugins` to connect or disconnect its MCP servers"; expansion of `${VAR}` / `${VAR:-default}` in `command`, `args`, `env`, `url`, `headers`; "If a referenced environment variable isn't set and has no default value, the config still loads: Claude Code reports a missing-variable warning for that server in `claude mcp list` output and uses the unexpanded `${VAR}` text as-is"; plugin tool naming `mcp__plugin_<plugin-name>_<server-name>__<tool-name>`; `claude mcp get <name>` shows an `Issue:` line for a failed server
- https://github.com/modelcontextprotocol/typescript-sdk/issues/216 — the reference stdio client's `getDefaultEnvironment()` returns only `DEFAULT_INHERITED_ENV_VARS` (`HOME`, `LOGNAME`, `PATH`, `SHELL`, `TERM`, `USER` on POSIX) and a supplied `env` replaces rather than extends it; an arbitrary exported variable is not inherited by default
- Field reproduction 2026-08-12 (`lnpl-mcp` 0.3.0, macOS): install, `enabledPlugins` registration, and a manual run of the installed server (correct `serverInfo`) were all healthy while `/mcp` did not list the server; `/reload-plugins` exposed its two tools immediately. Control: in the same cache, `context7` and `playwright` ship a bare map and `claude-mem`, `figma`, and `atlassian` ship the `"mcpServers"` wrapper, and servers of both shapes were live in that session
