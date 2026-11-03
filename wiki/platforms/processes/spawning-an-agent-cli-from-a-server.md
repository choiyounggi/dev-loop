---
id: platforms-processes-spawning-an-agent-cli-from-a-server
domain: platforms
category: processes
applies_to: [nodejs, claude-code]
confidence: verified
sources:
  - https://code.claude.com/docs/en/env-vars.md
  - https://code.claude.com/docs/en/memory.md
  - https://nodejs.org/api/child_process.html
  - https://code.claude.com/docs/en/hooks
  - https://code.claude.com/docs/en/settings
  - https://code.claude.com/docs/en/llm-gateway-connect
  - https://code.claude.com/docs/en/plugin-hints
  - "Local reproduction 2026-10-11 (Claude Code 2.1.296, macOS): claude -p under env -i with PATH, HOME and the three switches, from a directory outside every git work tree"
  - "Field origin 2026-10 (linkly-invitation task t6c planning; recorded by the originating session): a repository-internal cwd keyed auto memory on the repository; PATH + HOME measured as enough for the subscription login"
  - "Field case 2026-11-03 (Claude Code 2.1.317, proxy-router work): six-turn stream-json child logged six Stop events; --settings env reached a probe Stop hook; a capture proxy upstream at api.anthropic.com got 401 under a gateway bearer token and 200 once chained to ANTHROPIC_BASE_URL"
last_verified: 2026-11-03
verified_model: claude-opus-5-5
related: [platforms-processes-non-interactive-cli-invocation, platforms-processes-parsing-cli-structured-output, platforms-processes-background-services, infrastructure-ci-cd-secrets-handling, platforms-toolchains-agent-files-written-by-next-dev, platforms-shells-env-var-off-switches, platforms-tools-per-call-subagent-effort]
---

# Spawning an Agent CLI From a Server Process

## When this applies

A long-running server (a web request handler, a job worker), a script, or
another Claude Code session spawns Claude Code (`claude -p …`) or a similar
agent CLI as a child process, and you are choosing the child's environment,
working directory and settings. Also when such a child billed an API key
instead of the subscription it was meant to use, pulled a repository's
`CLAUDE.md`/`AGENTS.md` or memory into a request's context, wrote memory under
the server's own repository, ran the user's side-effect hooks on every turn,
or got a 401 through a capture proxy.

## Do this

1. **Build the child environment as an allow-list, not a filtered copy.**
   Node's `spawn` default is `env: process.env`, which hands the child every
   server secret. Pass exactly: `PATH` and `HOME` copied from the parent (each
   only when it is a non-empty string), plus
   `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`, `CLAUDE_CODE_DISABLE_CLAUDE_MDS=1` and
   `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`. Measured: that set alone
   logged in through the subscription (`apiKeySource` `none` in the `init`
   event) and answered.

| Variable | In the child env | Why |
|----------|------------------|-----|
| `PATH` | Yes, copied | `spawn` looks the command up in `options.env.PATH`; without it Unix falls back to `/usr/bin:/bin`, which holds no `claude` |
| `HOME` | Yes, copied | Locates the credentials and the `~/.claude` directory the login lives in |
| `ANTHROPIC_API_KEY` | Only when that key is the intended account | In `-p` mode "the key is always used when present", replacing the subscription with no prompt |
| `CLAUDE_CODE_DISABLE_CLAUDE_MDS=1` | Yes | Prevents "loading any CLAUDE.md memory files into context, including user, project, and auto memory files" |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` | Yes | The child neither creates nor loads auto memory files |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` | Yes | Turns off auto-updates, telemetry, error reporting and similar background calls in an unattended child |
| `CLAUDE_CONFIG_DIR` | Only when the host keeps its credentials outside `~/.claude` | Without it such a child cannot log in and fails as unavailable, which is the safe failure |
| `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` | Both together, only when the parent reaches Claude through an LLM gateway | The token is the gateway's bearer credential; sent anywhere but that base URL it is rejected with 401 |
| `CLAUDECODE`, `CLAUDE_CODE_CHILD_SESSION`, other parent `CLAUDE_CODE_*` | No, unless the test is about that variable | A Claude Code session sets the first two in every Bash-tool and hook command it runs; the child then behaves as a nested session, not as a standalone run |
| `DATABASE_URL`, session secrets, `NEXT_PUBLIC_*`, `TMPDIR`, `LANG` | No | Nothing in the child reads them; a deny-list misses the next secret someone adds |

2. **Run the child from a directory outside every git work tree, created
   before each spawn** (`mkdirSync(dir, { recursive: true, mode: 0o700 })`; a
   missing `cwd` makes the child emit `ENOENT`): a per-app cache directory such
   as `~/Library/Caches/<app>/claude-cwd` (macOS) or `~/.cache/<app>/claude-cwd`.
   Claude Code loads `CLAUDE.md` "from your current working directory and every
   directory above it", reads `AGENTS.md` from the same directories, and keys
   memory and transcripts on the project, "derived from the git repository, so
   all worktrees and subdirectories within the same repo share one auto memory
   directory. Outside a git repo, the project root is used instead". Measured:
   from the cache directory the `init` event's `cwd` was that directory and the
   transcript landed under a `projects/` entry named after it, not the repo.
3. **Keep both the cwd and the switches.** The cwd keeps repository files out
   of the child even when a switch is dropped; the switches cover `CLAUDE.md`
   files above the cache directory (`~`, `~/Library`) and the user-level
   `~/.claude/CLAUDE.md`, which loads in every session.
4. **Smoke-test the context once per deploy.** Run one trivial prompt with
   `--output-format stream-json --verbose`, assert that the `system`/`init`
   event's `cwd` is the cache directory and `apiKeySource` is the account you
   intend, and record the result's input tokens (cache reads included) as the
   baseline; a later jump means instructions or memory leaked into the child.
   Detach stdin and bound the call per
   [platforms-processes-non-interactive-cli-invocation]; parse the events per
   [platforms-processes-parsing-cli-structured-output].
5. **When the child inherits the user's hooks, turn off the ones with outside
   effects through `--settings`.** A child that keeps `HOME` loads the user's
   `settings.json`, and its `Stop` hooks fire every time Claude finishes a
   response — once per turn, so a multi-turn `--input-format stream-json`
   child runs an auto-publish or auto-PR hook after every turn. Pass the
   hooks' own off switches as
   `--settings '{"env":{"<SWITCH>":"0"}}'`: `--settings` ranks above user,
   project and local settings, its `env` reaches the hook processes, and the
   rest of the user's environment stays as it is.

| Need | Do |
|------|----|
| No hook may run in the child | `--settings '{"disableAllHooks": true}'` |
| Keep the user's hooks, silence the side-effect ones | `--settings '{"env":{…off switches…}}'`; confirm with a probe hook that logs the variable once |

## Edge cases

| Case | Then |
|------|------|
| The server runs under launchd/systemd with a minimal `PATH` | Write the `PATH` the child needs explicitly instead of copying the parent's ([platforms-processes-background-services]) |
| The child could not be started (`spawn` emits `error`: `ENOENT`, `EACCES`, a missing `cwd`) | Report that as the CLI being unavailable, distinct from a run that started and failed; the `error` event fires when "The process could not be spawned" |
| A dev server writes `AGENTS.md`/`CLAUDE.md` into the repository ([platforms-toolchains-agent-files-written-by-next-dev]) | A child run from inside the repository loads them; the cache-directory cwd keeps them out |
| You need the key, not the subscription (CI, a service account) | Put `ANTHROPIC_API_KEY` in the allow-list on purpose; in `-p` mode it is used whenever present |
| You export a hook's off switch in the shell and the hook still runs | The user's `settings.json` `env` block sets the same variable and overwrites the shell export; pass the switch through `--settings` (step 5) |
| You put a capture proxy between the child and the API while the parent uses a gateway | Set the proxy's upstream to the parent's `ANTHROPIC_BASE_URL` and point the child's `ANTHROPIC_BASE_URL` at the proxy; with a gateway configured, a 401's text comes from whichever server got the token, and `/login` does not fix it |
| You spawn the child from inside a Claude Code session to observe or test its behaviour (session saving, subagent model, permission mode) | Start it under the step-1 allow-list (`env -i …`) and record any parent variable you deliberately keep beside the result. Observed 2026-11-03: a child left with the parent's environment saved no session transcript (cause not isolated) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `spawn('claude', args, { env: { ...process.env } })` and delete the secrets you know of | Pass the allow-list from step 1 | Every variable not named is one the child never sees; a deny-list leaks the next secret added to the server |
| Spawn with the server's own `cwd` | Spawn from the per-app cache directory (step 2) | The repository's instruction files and its memory key on that cwd |
| Rely on the switches alone, or on the cwd alone | Use both (step 3) | Each covers a path the other leaves open |
| Hardcode `https://api.anthropic.com` as a capture proxy's upstream | Chain the proxy to the parent's `ANTHROPIC_BASE_URL` | The inherited `ANTHROPIC_AUTH_TOKEN` is valid only at that gateway |

## Sources

- https://code.claude.com/docs/en/env-vars.md — `ANTHROPIC_API_KEY`: "When set, this key is used instead of your Claude Pro, Max, Team, or Enterprise subscription even if you are logged in. In non-interactive mode (`-p`), the key is always used when present"; `CLAUDE_CODE_DISABLE_AUTO_MEMORY`: "Set to `1` to disable auto memory … When disabled, Claude does not create or load auto memory files"; `CLAUDE_CODE_DISABLE_CLAUDE_MDS`: "Set to `1` to prevent loading any CLAUDE.md memory files into context, including user, project, and auto memory files"; `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: "disable nonessential network traffic: auto-updates, telemetry, error reporting, …"; `CLAUDE_CONFIG_DIR` is a path variable that takes an absolute path
- https://code.claude.com/docs/en/memory.md — "Claude Code loads `CLAUDE.md` and `CLAUDE.local.md` from your current working directory and every directory above it"; `AGENTS.md`: "At session start: every `AGENTS.md` and `.claude/AGENTS.md` in your working directory and the directories above it"; "Each project gets its own memory directory at `~/.claude/projects/<project>/memory/`. The `<project>` path is derived from the git repository, so all worktrees and subdirectories within the same repo share one auto memory directory. Outside a git repo, the project root is used instead"
- https://nodejs.org/api/child_process.html — `options.env`: "Environment key-value pairs. Default: `process.env`"; "The command lookup is performed using the `options.env.PATH` environment variable if `env` is in the `options` object … If `options.env` is set without `PATH`, lookup on Unix is performed on a default search path search of `/usr/bin:/bin`"; `cwd`: "If given, but the path does not exist, the child process emits an `ENOENT` error and exits immediately"; "The `'error'` event is emitted whenever: The process could not be spawned …"
- Local reproduction 2026-10-11 (Claude Code 2.1.296 on macOS): `env -i PATH=… HOME=… CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 claude -p "Reply with exactly one word: pong" --output-format stream-json --verbose --max-turns 1 </dev/null`, run from `~/.dev-loop/scratch/…/claude-cwd` (no git repository above it), exited 0 with result `pong`; the `init` event read `cwd` = that directory, `apiKeySource` `none`, 70 tools; usage 2 input + 10,327 cache-read + 23,375 cache-creation tokens; a `~/.claude/projects/` entry named after the cache directory held the transcript
- https://code.claude.com/docs/en/hooks — the reference groups `UserPromptSubmit`, `Stop` and `StopFailure` as per-turn events; `Stop` runs "when the main Claude Code agent has finished responding" and has no matcher (search-result summary 2026-11-03; page not fetched)
- https://code.claude.com/docs/en/settings — precedence: managed, then command-line arguments (`--settings`, one session, no file written), then local, project, user; an `env` block in a settings file "overwrites the same variable exported in your shell" and applies to the subprocesses Claude Code starts; `--settings '{"disableAllHooks": true}'` turns hooks off for one run; exception: when the Claude Desktop app or a self-hosted runner starts the session, a settings `env` value is ignored for a variable the launch environment already sets (search-result summary 2026-11-03)
- https://code.claude.com/docs/en/llm-gateway-connect — `ANTHROPIC_BASE_URL` points Claude Code at the gateway and `ANTHROPIC_AUTH_TOKEN` is sent as `Authorization: Bearer`; "with a gateway configured, the text after a 401 comes from your gateway", and `/login` does not fix it (search-result summary 2026-11-03)
- https://code.claude.com/docs/en/plugin-hints — Claude Code sets `CLAUDECODE=1` in Bash-tool, PowerShell-tool and hook commands, and `CLAUDE_CODE_CHILD_SESSION=1` there on v2.1.172+ (search-result summary 2026-11-03)
- Field case 2026-11-03 (Claude Code 2.1.317, claude-proxy-router / claude-code-rea sessions): a six-turn `--input-format stream-json` child logged six `Stop` hook events; a probe `Stop` hook logged `AUTO_VELOG_AUTODRAFT=0 PROBE_X=from-settings` passed via `--settings`, and a hook switched on by the user's `settings.json` env stayed off; a capture proxy with upstream `api.anthropic.com` returned 401 `authentication_error` for the inherited gateway token and three 200s once its upstream was the parent's `ANTHROPIC_BASE_URL`; a child started with the parent's environment left no transcript under `~/.claude` (cause not isolated)
- Field origin 2026-10 (linkly-invitation task t6c planning; recorded by the originating session): with a cwd inside the repository, a probe's `memory_paths.auto` was the repository's project directory; PATH + HOME were measured as sufficient for the subscription login; no `CLAUDE.md` or `AGENTS.md` existed in the ten directories from the cache directory up to `/`
