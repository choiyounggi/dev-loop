---
id: security-agent-exposure-command-guard-exemption-matching
domain: security
category: agent-exposure
applies_to: [general, hooks, shell]
confidence: verified
sources:
  - https://docs.python.org/3/library/shlex.html#shlex.split
  - https://docs.python.org/3/library/re.html#re.fullmatch
last_verified: 2026-10-23
related: [platforms-shells-command-text-inspected-before-execution, security-input-validation-at-trust-boundaries]
---

# Exempting One Command Shape from a Guard That Reads Command Text

## When this applies

A guard (an agent `PreToolUse` hook, a CI policy step, a shell wrapper) inspects a
command string with a regex to block a class of commands — say `gh api … -X POST`
to pull-request endpoints — and you are adding an exception that lets one shape
through ("posting a review comment to `/pulls/<n>/comments` is allowed").

## Do this

1. **Parse the command into tokens with a shell-aware splitter** (`shlex.split`)
   instead of matching the raw string or a whole command segment.
2. **Identify the one token the exemption is about** — for `gh api`, the first
   non-option argument after `api` — using the tool's own option table, read from
   its `--help`:

| Option kind | `gh api` options | Skip |
|-------------|------------------|------|
| Takes a value | `--cache`, `-F/--field`, `-H/--header`, `--hostname`, `--input`, `-q/--jq`, `-X/--method`, `-p/--preview`, `-f/--raw-field`, `-t/--template` | The option and the next token; one token for `--opt=value` and attached short forms (`-XPOST`) |
| Boolean | `-i/--include`, `--paginate`, `--silent`, `--slurp`, `--verbose` | The option only |
| Anything else | — | Stop: an option the table does not know makes the command **not exempt** |

3. **Test the exemption with a full match on that token alone**
   (`re.fullmatch(r'repos/[^/]+/[^/]+/pulls/\d+/comments', endpoint)`), and reject
   it when any path segment is `..` or the token contains a percent-encoded dot
   (`%2e`) — `repos/../r/pulls/1/comments` passes the full match otherwise.
4. **Keep a bypass test set next to the guard** and run it on every change:

| Command | Exempt? |
|---------|---------|
| `gh api repos/o/r/pulls/1/comments -X POST -f body=x` | Yes — the real shape |
| `gh api -XPOST --method=POST repos/o/r/pulls/1/comments -f body=x` | Yes — attached and `=` option forms |
| `gh api repos/o/r/pulls -X POST -f title=/pulls/1/comments` | No — the exempt text sits in a field value |
| `gh api repos/o/r/pulls -X POST --jq '/pulls/1/comments'` | No — the exempt text sits in an option argument |
| `gh api -t repos/o/r/pulls/1/comments repos/o/r/pulls -X POST` | No — a value of a value-taking option the guard must skip (same for `-p`) |
| `gh api repos/../r/pulls/1/comments -X POST` | No — a `..` segment that the full match alone accepts |
| `gh api --frobnicate repos/o/r/pulls/1/comments -X POST` | No — an option missing from the table |

## Edge cases

| Case | Then |
|------|------|
| The command has several segments (`a && b`, `;`, `\|`) | Split into segments first and evaluate every segment; one exempt segment must not exempt its neighbours |
| The endpoint is built from a variable (`"$EP"`) | The guard sees unexpanded text — treat an unresolvable endpoint as not exempt ([platforms-shells-command-text-inspected-before-execution]) |
| `shlex.split` raises on unbalanced quotes | Fail closed: block, with a message naming the parse failure |
| The tool accepts the endpoint as an option (`--url=…`) | Extend step 2 to read that option's value as the endpoint, and add its bypass rows |
| The tool's version adds options | Re-read `--help` when the tool is upgraded; an option added upstream is "unknown" to the guard, which keeps it not exempt until the table is updated |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `if EXEMPT.search(segment): allow` | Full-match the extracted endpoint token | A substring search grants the exemption to any command that mentions the exempt text anywhere, including in data |
| Test the exemption only with the command it was written for | Run the bypass rows above as fixtures | The legitimate command passes under both designs; only the hostile rows tell them apart |

## Sources

- https://docs.python.org/3/library/shlex.html#shlex.split — "Split the string s using shell-like syntax"
- https://docs.python.org/3/library/re.html#re.fullmatch — "If the whole string matches the regular expression pattern, return a corresponding Match"
- `gh api --help` (gh 2.87.3) — the FLAGS list behind the option table in step 2; `-t`/`--template` and `-p`/`--preview` take a value
- Reproduction 2026-10-23 (Python 3, gh 2.87.3): over the seven commands in the bypass table, a `re.search` exemption allowed all seven. A tokenizer that skipped values only for `-f`, `--jq` and `-X` allowed the `-t`, `..` and unknown-option rows as well as both real shapes. The step-2 option table with `..` rejection allowed only the two real shapes. gh accepted `-t <path-like value>` and `-p <path-like value>` before the endpoint and sent the request to the endpoint, not to the value
- Field case 2026-10 (an agent hook gating `gh api` writes): an adversarial review reproduced `gh api …/pulls -X POST -f title=/pulls/1/comments` passing the first version of the exemption; after switching to token full-match, five bypass cases were blocked and the hook's 86-case suite passed
