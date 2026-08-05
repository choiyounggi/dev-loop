---
id: platforms-shells-env-var-off-switches
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html
last_verified: 2026-08-05
related: [platforms-shells-portable-shell-scripts, infrastructure-config-environment-config, platforms-environment-path-resolution]
---

# Turning a Script's Behavior Off Through an Environment Variable

## When this applies

You are disabling part of a shell script from the outside — `FEATURE= script.sh`,
`CHECK="" ./run` — or you are writing the script that reads such a switch. Also
when a feature you believe you turned off keeps running, with no error and no
message naming the switch.

## Do this

1. **Read the script before choosing the value it gets.** Which expansion it
   uses decides whether an empty string means anything:

| Script reads | `VAR` unset | `VAR=` (empty) | `VAR=x` |
|--------------|-------------|----------------|---------|
| `${VAR:-default}` | `default` | `default` — the empty value is discarded | `x` |
| `${VAR-default}` | `default` | empty — the empty value is honoured | `x` |

2. **When the script uses `${VAR:-default}` and you cannot change it, pass a
   value that fails the script's own validation** rather than an empty one.
   A sentinel path is the reliable form when the default is a command name:
   `WATCH_TMUX=/nonexistent-disable ./watch.sh` makes the script's
   `command -v "$TMUX_BIN"` fail and take its already-written disabled path.
3. **When you own the script, express the intent in the expansion.** Use
   `${VAR-default}` (no colon) for a switch whose empty value means "off", and
   keep `${VAR:-default}` for a value that must never be empty.
4. **Give a disable switch its own explicit test** so the intent is readable and
   an empty value is unambiguous:

   ```sh
   case "${FEATURE_ENABLED:-1}" in
     0|off|false) enabled=0 ;;
     *)           enabled=1 ;;
   esac
   ```

5. **Log which branch was taken** — one line naming the switch and the resolved
   value. A switch that silently does nothing is indistinguishable from a switch
   that does not exist.

## Edge cases

| Case | Then |
|------|------|
| The script runs under `set -u` | `${VAR-default}` and `${VAR:-default}` both supply a value, so neither trips `set -u`; a bare `$VAR` does |
| The switch selects a binary and the sentinel path might exist | Point at a path under a directory you control and confirm it is absent (`command -v` / `test -x`) before relying on it |
| Passing a sentinel makes the script fail loudly instead of disabling | The script has no disabled path — add one, or skip the whole invocation from the caller |
| The value comes from a `.env` file or CI variable UI | Empty and unset are frequently indistinguishable there (many loaders export the key with an empty value); use an explicit sentinel value such as `off`, never blank |
| A long-lived service reads the switch | Config-shaped switches for a service belong in its validated config schema — [infrastructure-config-environment-config] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Disable a feature by exporting `VAR=` | Read the script's expansion first, then pass an empty value only if it uses `${VAR-…}`; otherwise pass a sentinel the script rejects | `${VAR:-default}` substitutes the default for unset **and** null, so the empty value is discarded and the feature stays on |
| Write `${VAR:-default}` for every option in a script | Use `${VAR-default}` where an empty value is a meaningful choice | The colon form makes "explicitly blank" unreachable from the caller |
| Conclude the switch does not exist when the feature keeps running | Grep the script for the variable and read the expansion form | A feature still running with the switch set is being overridden by the script's own default, which the expansion form shows |

## Sources

- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html — Parameter Expansion: "use of the <colon> in the format shall result in a test for a parameter that is unset or null; omission of the <colon> shall result in a test for a parameter that is only unset"
- Field reproduction 2026-08-05 (zsh/bash, macOS): with `V=""`, `${V:-def}` → `def` and `${V-def}` → empty; with `V` unset both → `def`. Origin case: `WATCH_TMUX=` failed to disable a liveness check whose script read `TMUX_BIN="${WATCH_TMUX:-tmux}"`, so the check kept running and aborted the run on stale tmux sessions; `WATCH_TMUX=/nonexistent-tmux-disable` took the intended `command -v` failure path
