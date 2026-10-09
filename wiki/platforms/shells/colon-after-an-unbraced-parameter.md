---
id: platforms-shells-colon-after-an-unbraced-parameter
domain: platforms
category: shells
applies_to: [zsh]
confidence: verified
sources:
  - https://zsh.sourceforge.io/Doc/Release/Expansion.html
  - https://zsh.sourceforge.io/Doc/Release/Options.html
last_verified: 2026-10-07
related: [platforms-shells-portable-shell-scripts, platforms-shells-unset-versus-empty-parameters, platforms-shells-escapes-in-shell-string-literals]
---

# A Colon Right After an Unbraced Parameter in zsh

## When this applies

A line that zsh runs — an interactive macOS terminal, a zsh-backed agent shell
tool, a `#!/bin/zsh` script, `zsh -c` — puts a colon straight after an unbraced
`$name`: a git refspec `"+refs/heads/$h:refs/remotes/origin/$h"`, an image tag
`"$img:latest"`, `"$svc:http"`. Also when such a string arrives shortened, with
letters missing after the value, or the line fails with `bad substitution`.

## Do this

1. **Brace every parameter that a colon follows: `"${h}:refs/remotes/origin/${h}"`.**
   In zsh, a colon after an unbraced name followed by a modifier letter (step 3)
   applies that history-style modifier, inside double quotes too, and the
   `:letter` disappears from the result. The braces end the name before the
   colon; bash and POSIX `sh` read the braced form the same way, so it is also
   the portable spelling.
2. **When a built string is wrong, print it in the shell that runs it** —
   `print -r -- "+refs/heads/$h:refs/…"` beside the braced form — before
   debugging the tool that received it. Every string built by the loop is wrong
   in the same way, so the downstream error reads as a remote or tool problem.
3. **Know which characters zsh consumes after `$name:`.** Measured with zsh 5.9
   in native mode, `v=dir/file.txt`, `"$v:X…"` against `"${v}:X…"`, with a
   non-modifier (`z`) and a modifier letter (`e h r t`) after `X`:

| After the colon | zsh applies | Result |
|-----------------|-------------|--------|
| `h`, `t`, `r`, `e` | head, tail, root, extension | `dirzz`, `file.txtzz`, `dir/filezz`, `txtzz`; `"$svc:http"` with `svc=api` → `.ttp` |
| `l`, `u` | lowercase, uppercase | `"$img:latest"` with `img=myapp` → `myappatest` |
| `a`, `A`, `P` | absolute or resolved path | `/<cwd>/dir/file.txtzz` |
| `c`, `q`, `Q`, `&` | command path, quoting, repeat last substitution | The `:c` (etc.) vanishes: `"$v:czz"` → `dir/file.txtzz` |
| `s` | substitution, with the next character as delimiter | `"$var:status"` with `var=data` → `dusta` (`s/a/us/`); `"$var:sort"` → `bad substitution`, status 1 |
| `f`, `g`, `w`, `F` (the manual adds `W`) | repeat, global, per-word prefixes for the modifier after them | Consumed when a modifier letter follows (`F` and `W` also before a delimiter: `"$v:F:2:h"` → `.`; `g` also before `&`): `"$src:feature/login"` with `src=topic` → `ature/login`, `"$svc:grpc"` → `apipc`; `"$img:focal"` stays unchanged |
| A digit, `/`, `$`, `-`, `.`, any letter not listed above | Nothing — the colon stays literal | `"$host:8080"`, `"$host:path"`, `"$a:$b"` unchanged |

## Edge cases

| Case | Then |
|------|------|
| The line also runs in bash or `/bin/sh` | Both print the colon literally, so the defect shows only under zsh; reproduce with `zsh -fc '…'` before changing the tool or remote |
| The script runs under `emulate sh`, `emulate ksh`, or sets `KSH_ARRAYS` | The colon stays literal there (`KSH_ARRAYS` is on by default in sh and ksh emulation, and the unbraced-modifier rule applies only while it is off); brace anyway so the line is right in native zsh |
| Escaping the colon inside double quotes (`"$h\:refs"`) | zsh keeps the backslash (`knowledge/x\:refs`); brace the name |
| Closing and reopening the quotes (`"$h"":refs"`) | The colon stays literal, so the line works; use the braced form (`"${h}:refs"`) instead, because it keeps the string in one pair of quotes |
| A bracket follows the unbraced name (`"$svc[1]x"`) | The same rule makes zsh subscript it (`ax`); write `"${svc}[1]x"` when the bracket is text |
| A colon sits inside the braces as a POSIX operator (`${VAR:-default}`, `:=`, `:?`, `:+`) or right after the closing brace (`${VAR}:x`) | Leave it: both mean the same in every shell ([platforms-shells-unset-versus-empty-parameters]). A modifier inside the braces is zsh-only — `${v:h}` gives `dir` in zsh, `dir/file.txt` in bash and `/bin/sh`, `Bad substitution` in dash |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `"+refs/heads/$h:refs/remotes/origin/$h"` | Write `"+refs/heads/${h}:refs/remotes/origin/${h}"` | zsh applies `:r` and drops it, giving `…xefs/remotes/…`; bash keeps the colon — one line, two strings |
| Escape the colon with a backslash | Brace the parameter name | Inside double quotes zsh keeps the backslash in the result |
| Debug the remote or tool after every built name failed the same way | Print the built string in the shell that ran the line | The tool received a different string than the one written |

## Sources

- https://zsh.sourceforge.io/Doc/Release/Expansion.html — Parameter Expansion, `${name}`: "The braces are required if the expansion is to be followed by a letter, digit, or underscore that is not to be interpreted as part of name"; the exceptions, "which only apply if the option KSH_ARRAYS is not set, are a single subscript or any colon modifiers appearing after the name … all of which work with or without braces". Modifiers: "These modifiers also work on the result of filename generation and parameter expansion, except where noted"; the list includes `f` ("Repeats the immediately … following modifier"), `F:expr:`, `w` ("Makes the immediately following modifier work on each word"), `W:sep:`, and the `s` entry documents the `g` prefix
- https://zsh.sourceforge.io/Doc/Release/Options.html — `KSH_ARRAYS <K> <S>`; options "set by default only in csh, ksh, sh, or zsh emulations are marked <C>, <K>, <S>, <Z>"
- Local reproduction 2026-10-07 (macOS, zsh 5.9 arm64, `zsh -f`): with `h=knowledge/x`, `"+refs/heads/$h:refs/remotes/origin/$h"` printed `+refs/heads/knowledge/xefs/remotes/origin/knowledge/x` quoted and unquoted; the braced form printed the intended refspec; bash printed the colon. A probe over a–z, A–Z, 0–9 and `& / - . _ ~ % @ # =` with the follower `zz` found `a c e h l q r t u A P Q &` consumed, `s` failing with `no previous substitution`, and every other probed character literal; with the followers `e h r t`, `f g w F` were consumed too (`"$v:ge"` → `txt`); `"$v:F:2:h"` → `.`, `"$v:W:/:u"` → `DIR/FILE.TXT/FILE.TXT`, `"$v:g&x"` → `dir/file.txtx`; `${v:h}` gave `dir` in zsh, `dir/file.txt` in bash and `/bin/sh`, and `Bad substitution` in dash. Realistic strings: `"$svc:http"` → `.ttp`, `"$img:latest"` → `myappatest`, `"$var:status"` → `dusta`, `"$var:sort"` → `bad substitution` (status 1), `"$src:feature/login"` → `ature/login`, `"$svc:grpc"` → `apipc`, `"$img:focal"`, `"$host:8080"`, `"$host:path"` and `"$a:$b"` unchanged, `"$h\:refs"` → `knowledge/x\:refs`, `"$svc[1]x"` → `ax`. `setopt KSH_ARRAYS`, `emulate sh` and `emulate ksh` each kept the colon literal
- Field case 2026-10-07 (a zsh-backed agent shell tool refreshing open PR branches): a loop fetching `"+refs/heads/$h:refs/remotes/origin/$h"` produced `…efs/remotes/…` refspecs and failed for all 22 branches with `couldn't find remote ref`; the braced form printed in the same shell gave the intended refspec
