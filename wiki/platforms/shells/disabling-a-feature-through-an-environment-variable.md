---
id: platforms-shells-disabling-a-feature-through-an-environment-variable
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
  - https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
last_verified: 2026-08-05
related: [platforms-shells-portable-shell-scripts, platforms-environment-path-resolution, platforms-processes-non-interactive-cli-invocation]
---

# Turning a Shell Script's Feature Off Through an Environment Variable

## When this applies

You are invoking a shell script (hook, CI step, watcher, wrapper) and want to
disable one of its behaviors by setting an environment variable — written
`VAR= script.sh` or `export VAR=""` — and the script reads that variable with
`${VAR:-default}`. Also applies when writing the script that must honour such an
override.

## Do this

1. Read the script's expansion form first; it decides what an empty value means:

| The script reads | Passing `VAR=""` yields | Passing `VAR` unset yields |
|------------------|-------------------------|----------------------------|
| `${VAR:-default}` | `default` — the empty value is discarded, the feature stays on | `default` |
| `${VAR-default}` | the empty string — the override is honoured | `default` |
| `${VAR:=default}` | `default`, and `VAR` is assigned it | `default`, assigned |
| `${VAR:+alt}` | empty | empty |

2. Act on the form you found:

| Case | Do |
|------|----|
| Script reads `${VAR:-default}` and you cannot edit it | Pass a **non-empty value the script's own validation rejects**, so the feature takes its disabled branch: `WATCH_TMUX=/nonexistent-disable` makes the script's `command -v "$TMUX_BIN"` fail |
| Script reads `${VAR:-default}` and you can edit it | Change it to `${VAR-default}` so an explicitly empty value survives, and document that empty means off |
| You are writing the script and want a clean off-switch | Read a dedicated flag with an explicit compare (`[ "${FEATURE_ENABLED:-1}" = "0" ]`), not the presence or emptiness of a path/config variable |
| The disabled branch must be observable | Have the script log which branch it took, so the caller can confirm the feature is off instead of inferring it |

3. **Confirm the feature is off by its effect, not by the variable you set.** Run the
   script once with the override and check the behaviour it gates (no tmux query, no
   network call, the log line for the disabled branch). Setting the variable and
   seeing the script exit 0 proves nothing.

## Edge cases

| Case | Then |
|------|------|
| The script runs under `set -u` | `${VAR-default}` still expands safely because a default is supplied; a bare `$VAR` aborts. Keep the default form when converting away from the colon |
| The sentinel value flows into a command line rather than a lookup | Pick a sentinel that fails safely: an absolute path that cannot exist, never a name that could resolve on some machine ([platforms-environment-path-resolution]) |
| The script exports the variable onward to child processes | The sentinel reaches the children too — check no child interprets it as a real path before choosing it |
| `VAR=` is written as a prefix assignment (`VAR= ./script.sh`) | The variable is set-and-null for that command only, which is exactly the case `${VAR:-default}` discards; the prefix form does not change the outcome |
| The variable holds a command plus flags | Splitting differs between bash and zsh — keep only the binary path in the variable ([platforms-shells-portable-shell-scripts]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pass `VAR=` to turn a feature off | Read the script's expansion form, then pass a rejected sentinel or switch the script to `${VAR-default}` | With `${VAR:-default}` an empty value is replaced by the default, so the feature stays on and the run continues under a false assumption |
| Assume the override worked because the command started | Verify the gated behaviour did not happen | The default silently reinstated the feature; the failure appears later as an unrelated error |
| Add `if [ -z "$VAR" ]` checks around an existing `${VAR:-default}` | Change the expansion to `${VAR-default}` at the single read site | Two places now decide the same thing and drift apart |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — "use of the <colon> in the format shall result in a test for a parameter that is unset or null; omission of the <colon> shall result in a test for a parameter that is only unset" (2.6.2 Parameter Expansion)
- https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html — "Omitting the colon results in a test only for a parameter that is unset"
- Reproduced 2026-08-05 (`bash`): with `v=""`, `${v:-tmux}` → `tmux` while `${v-tmux}` → empty; with `v` unset both → `tmux`
