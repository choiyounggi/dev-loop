---
id: platforms-shells-unset-versus-empty-parameters
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html
last_verified: 2026-08-05
related: [platforms-shells-portable-shell-scripts, platforms-environment-path-resolution]
---

# Turning a Shell Feature Off With an Environment Variable

## When this applies

You are disabling a script's optional behavior by setting its environment
variable to the empty string (`FEATURE= ./script.sh`), and the feature keeps
running; or you are writing a script whose optional inputs must be
overridable to "off"; or you are reviewing a script that reads its knobs with
`${VAR:-default}`.

## Do this

1. **Read the script's expansion form before choosing how to pass the value.**
   The colon decides what counts as "not supplied": "use of the `<colon>` in the
   format shall result in a test for a parameter that is unset or null; omission
   of the `<colon>` shall result in a test for a parameter that is only unset."

| Script reads | `VAR` unset | `VAR=` (empty) | `VAR=value` |
|--------------|-------------|----------------|-------------|
| `${VAR:-default}` | `default` | `default` — the empty value is discarded | `value` |
| `${VAR-default}` | `default` | empty string — the caller's "off" is honored | `value` |

2. **When you can edit the script, express "optional, and empty means off" as
   `${VAR-default}`** (no colon), and document that the empty string is a
   meaningful value.
3. **When the script is not yours to change and reads `${VAR:-default}`, pass a
   value that fails the script's own validation instead of an empty one.** The
   disable path then runs for the reason the script already understands:

| The script's check | Value that reaches the disable path |
|--------------------|-------------------------------------|
| `command -v "$BIN"` before using it | An absolute path that does not exist: `WATCH_TMUX=/nonexistent-tmux` |
| `[ -f "$FILE" ]` / `[ -d "$DIR" ]` | A path under a directory you control that you do not create |
| A numeric threshold compared with `-gt` | A value the comparison rejects (`0`, or a bound the code treats as never-reached) |

4. **Confirm which branch ran, from the script's own output or state** — an
   exported variable proves only what you passed, not what the script resolved.
5. **Under `set -u`, keep expanding optional variables with an explicit default**
   (`"${OPT-}"` for empty-means-off, `"${OPT:-}"` when empty and unset are the
   same thing) so the reference itself does not abort the script.

## Edge cases

| Case | Then |
|------|------|
| The script must distinguish "unset", "empty", and "set to a value" | Test presence separately: `if [ -n "${VAR+set}" ]` is true for both unset-vs-set forms including empty, then branch on `[ -z "$VAR" ]` |
| The knob is consumed by a program, not the shell (`docker run -e`, systemd `Environment=`) | The same colon rule applies only inside the shell; for a program, check whether its own parser treats empty as absent, and prefer unsetting the variable entirely |
| The value is a binary path used elsewhere in the script too | A nonexistent path can reach a second call site that does not guard with `command -v` — read every use of the variable before choosing this route |
| Another shell runs the script (zsh vs bash vs dash) | The colon rule is POSIX and identical across them — measured below; no per-shell workaround is needed |
| The script assigns the knob with `${VAR:=default}` | The colon rule is the same, and the assignment persists for the rest of the script — passing empty leaves `default` in the environment of every child process too |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pass `FEATURE=` to turn a feature off | Read the script's expansion form first; pass a value its own validation rejects, or fix the script to `${FEATURE-default}` | `${FEATURE:-default}` substitutes the default for an empty value, so the feature stays on and the run looks like the flag was ignored |
| Write `${OPT:-default}` for a knob whose empty value means "off" | Write `${OPT-default}` | The colon form makes the empty string unreachable, so callers have no way to express "off" |
| Conclude the variable "was not picked up" when the feature keeps running | Print the resolved value inside the script (or trace with `set -x`) and compare it with what you passed | The variable was received; the expansion replaced it — the symptom of substitution and of a missing variable are identical from outside |

## Sources

- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html — Parameter Expansion: "use of the `<colon>` in the format shall result in a test for a parameter that is unset or null; omission of the `<colon>` shall result in a test for a parameter that is only unset"; `${parameter:-[word]}` Use Default Values: "If parameter is unset or null, the expansion of word … shall be substituted"

## Field context

Measured 2026-08-05 on macOS across bash 3.2, `/bin/sh`, and zsh: with `VAR=`
(empty), `${VAR:-tmux}` expanded to `tmux` in all three shells while
`${VAR-tmux}` expanded to the empty string in all three. Originally observed in
`dev-loop`'s `watch-status.sh`, where `WATCH_TMUX=` intended to disable the tmux
liveness check but `TMUX_BIN="${WATCH_TMUX:-tmux}"` restored `tmux`; the check
then read a previous orchestration's dead session as a dead worker and aborted
with exit 3. `WATCH_TMUX=/nonexistent-tmux-disable` failed the script's
`command -v` guard and reached the disable path — reproduced above:
`command -v "${WATCH_TMUX:-tmux}"` succeeds for the empty value and fails for the
nonexistent path.
