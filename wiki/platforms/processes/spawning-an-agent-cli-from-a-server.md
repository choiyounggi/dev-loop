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
  - "Local reproduction 2026-10-11 (Claude Code 2.1.296, macOS): claude -p under env -i with PATH, HOME and the three switches, from a directory outside every git work tree"
  - "Field origin 2026-10 (linkly-invitation task t6c planning; recorded by the originating session): a repository-internal cwd keyed auto memory on the repository; PATH + HOME measured as enough for the subscription login"
last_verified: 2026-10-11
verified_model: claude-fable-5-1
related: [platforms-processes-non-interactive-cli-invocation, platforms-processes-parsing-cli-structured-output, platforms-processes-background-services, infrastructure-ci-cd-secrets-handling, platforms-toolchains-agent-files-written-by-next-dev]
---

# Spawning an Agent CLI From a Server Process

## When this applies

A long-running server (a web request handler, a job worker) spawns Claude Code
(`claude -p …`) or a similar agent CLI as a child process, and you are choosing
the child's environment and working directory. Also when such a child billed an
API key instead of the subscription it was meant to use, pulled a repository's
`CLAUDE.md`/`AGENTS.md` or memory into a request's context, or wrote memory
under the server's own repository.

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

## Edge cases

| Case | Then |
|------|------|
| The server runs under launchd/systemd with a minimal `PATH` | Write the `PATH` the child needs explicitly instead of copying the parent's ([platforms-processes-background-services]) |
| The child could not be started (`spawn` emits `error`: `ENOENT`, `EACCES`, a missing `cwd`) | Report that as the CLI being unavailable, distinct from a run that started and failed; the `error` event fires when "The process could not be spawned" |
| A dev server writes `AGENTS.md`/`CLAUDE.md` into the repository ([platforms-toolchains-agent-files-written-by-next-dev]) | A child run from inside the repository loads them; the cache-directory cwd keeps them out |
| You need the key, not the subscription (CI, a service account) | Put `ANTHROPIC_API_KEY` in the allow-list on purpose; in `-p` mode it is used whenever present |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `spawn('claude', args, { env: { ...process.env } })` and delete the secrets you know of | Pass the allow-list from step 1 | Every variable not named is one the child never sees; a deny-list leaks the next secret added to the server |
| Spawn with the server's own `cwd` | Spawn from the per-app cache directory (step 2) | The repository's instruction files and its memory key on that cwd |
| Rely on the switches alone, or on the cwd alone | Use both (step 3) | Each covers a path the other leaves open |

## Sources

- https://code.claude.com/docs/en/env-vars.md — `ANTHROPIC_API_KEY`: "When set, this key is used instead of your Claude Pro, Max, Team, or Enterprise subscription even if you are logged in. In non-interactive mode (`-p`), the key is always used when present"; `CLAUDE_CODE_DISABLE_AUTO_MEMORY`: "Set to `1` to disable auto memory … When disabled, Claude does not create or load auto memory files"; `CLAUDE_CODE_DISABLE_CLAUDE_MDS`: "Set to `1` to prevent loading any CLAUDE.md memory files into context, including user, project, and auto memory files"; `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: "disable nonessential network traffic: auto-updates, telemetry, error reporting, …"; `CLAUDE_CONFIG_DIR` is a path variable that takes an absolute path
- https://code.claude.com/docs/en/memory.md — "Claude Code loads `CLAUDE.md` and `CLAUDE.local.md` from your current working directory and every directory above it"; `AGENTS.md`: "At session start: every `AGENTS.md` and `.claude/AGENTS.md` in your working directory and the directories above it"; "Each project gets its own memory directory at `~/.claude/projects/<project>/memory/`. The `<project>` path is derived from the git repository, so all worktrees and subdirectories within the same repo share one auto memory directory. Outside a git repo, the project root is used instead"
- https://nodejs.org/api/child_process.html — `options.env`: "Environment key-value pairs. Default: `process.env`"; "The command lookup is performed using the `options.env.PATH` environment variable if `env` is in the `options` object … If `options.env` is set without `PATH`, lookup on Unix is performed on a default search path search of `/usr/bin:/bin`"; `cwd`: "If given, but the path does not exist, the child process emits an `ENOENT` error and exits immediately"; "The `'error'` event is emitted whenever: The process could not be spawned …"
- Local reproduction 2026-10-11 (Claude Code 2.1.296 on macOS): `env -i PATH=… HOME=… CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 claude -p "Reply with exactly one word: pong" --output-format stream-json --verbose --max-turns 1 </dev/null`, run from `~/.dev-loop/scratch/…/claude-cwd` (no git repository above it), exited 0 with result `pong`; the `init` event read `cwd` = that directory, `apiKeySource` `none`, 70 tools; usage 2 input + 10,327 cache-read + 23,375 cache-creation tokens; a `~/.claude/projects/` entry named after the cache directory held the transcript
- Field origin 2026-10 (linkly-invitation task t6c planning; recorded by the originating session): with a cwd inside the repository, a probe's `memory_paths.auto` was the repository's project directory; PATH + HOME were measured as sufficient for the subscription login; no `CLAUDE.md` or `AGENTS.md` existed in the ten directories from the cache directory up to `/`
