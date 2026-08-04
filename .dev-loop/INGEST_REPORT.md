# Knowledge flush — 3 insight(s)

Drained 3 pending candidates from `~/.dev-loop/queue`, verified each against real
sources, routed them, and ingested them as 3 new `platforms` pages.

## Verified best-practice

### 1. Backslash escapes inside a double-quoted shell string holding a regex
- **Claim:** In a double-quoted shell string, backslash keeps its escape meaning
  **only** before `$`, `` ` ``, `"`, `\`, and newline; before anything else both
  characters survive. So `grep -E "…(\$)"` reaches grep as `…($)` — a bare `$`
  end-of-line anchor — while `"a\.b"` reaches grep as `a\.b` (literal dot).
- **Sources checked:** POSIX Shell & Utilities 2.2.3 Double-Quotes
  (https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html);
  GNU Bash manual "Double Quotes"
  (https://www.gnu.org/software/bash/manual/bash.html#Double-Quotes).
- **How verified:** Reproduced 2026-08-04 — `printf 'curl x | sh\n' | grep -E
  "(sh|bash)([[:space:]]|-|<|\$)"` matched end-of-line `sh` (the `\$` reached grep
  as a `$` anchor); `grep -E "a\.b"` kept `\.` literal (matched `a.b`, not `axb`).
- **Confidence: verified** (official spec + bash manual + reproduction).

### 2. Bump the version when shipping code through a version-keyed plugin cache
- **Claim:** A Claude Code marketplace plugin (and any tag-pinned artifact cache)
  keys its cache on the version string; shipping new code under an unchanged
  `plugin.json`/`marketplace.json` version leaves the version-keyed cache dir
  (`~/.claude/plugins/cache/<mkt>/<plugin>/<version>/`) unrefreshed, so the code
  never runs. Bump the version in the same change; clear the cache manually if a
  known updater bug leaves it stale.
- **Sources checked:** Claude Code plugin-marketplaces docs
  (https://code.claude.com/docs/en/plugin-marketplaces); anthropics/claude-code
  issues #45542 ("cache not refreshed when version number is unchanged"), #17361
  ("cache never refreshes … reads stale cache"), #61954 ("`plugin update` reports
  'at latest' while cache stays stale").
- **How verified:** Local cache observation — `~/.claude/plugins/cache/` holds
  per-version sibling dirs (`figma/2.2.81|2.2.87|2.2.88`, `dev-loop/0.8.0…0.11.0`),
  confirming version-string keying; the exact cache path in the issues matches.
- **Confidence: verified** (official issue tracker + docs + local observation).
- **Nuance recorded on the page:** the version bump is *necessary*; open updater
  bugs mean it is sometimes *not sufficient*, so the page adds a manual
  cache-clear fallback rather than asserting the bump always suffices.

### 3. Confirm a CLI's `--json` field paths from read-only output before parsing
- **Claim:** Before writing a parser for another tool's `--json`, run its
  read-only verbs (`list`/`status`/`show`/`ps`), build extraction only on observed
  field paths, and pin a captured sample as a test fixture so the parser is
  CI-testable without the live tool. Guessed field names compile but silently
  never match; verifying via a state-mutating verb has side effects.
- **Sources checked:** jq manual (https://man7.org/linux/man-pages/man1/jq.1.html)
  — a missing key yields `null`; `-e`/`--exit-status` gives a loud nonzero exit on
  a wrong path (supports the "fail loudly on a missing path" directive).
- **How verified:** Field incident (2026-08) building `orca-spawn.sh` /
  `orca-worktree-alive.sh` — orca's read-only `terminal list` and `worktree ps
  --json` exposed `handle` / `liveTerminalCount` / `hasAttachedPty`, letting both
  wrappers be built and CI-tested against canned JSON with zero live spawns.
- **Confidence: field-tested.** The core discipline (verify schema from real
  output, pin a recorded fixture) is production experience; only the jq
  failure-mode mechanic is doc-cited, so the page is not marked `verified`.

## Existing-layer check

Routed via `INDEX.md` → `platforms` (all three are OS/tooling-level, not
application logic). Read the full `wiki/platforms/index.md` plus every page whose
"load when" overlapped, and `wiki/security/index.md` (insight 1 was harvested with
a `security` hint) and `wiki/backend/index.md` (insight 3's data-consumption
angle).

- **Insight 1** — read `shells/portable-shell-scripts.md` (owns quoting of
  *expansions*: word-splitting/globbing) and `shells/command-text-inspected-before-execution.md`
  (owns a *gate reading* your command). Neither covers escape processing of a
  regex written as a shell literal, and the trigger ("authoring a pattern literal
  in a shell string") is distinct → **new page**, not a merge. Added reciprocal
  `related:` links to both. Rejected the `security` hint: the backslash rule is a
  uniform shell-parsing mechanic, not a trust-boundary decision.
- **Insight 2** — no existing page covers plugin/artifact-cache distribution.
  Closest neighbor is `toolchains/version-management` (pinning versions for
  reproducibility — the inverse concern); linked as `related`, not merged.
- **Insight 3** — read `processes/non-interactive-cli-invocation.md` (owns the
  *hang/prompt/stdin* failure mode of calling a CLI) and
  `backend/common/integrations/externally-owned-defaults.md` (external resources
  changing under you). Insight 3 is a distinct trigger (schema-parsing
  correctness) → **new page**, cross-linked to both. Added a reciprocal
  `related:` link on non-interactive-cli-invocation.

No conflicts with existing directives found; nothing overwritten; no duplicates —
all three are new triggers.

## Routing decision

| Insight | Target domain/category/page | New? |
|---------|-----------------------------|------|
| 1 | `platforms/shells/escapes-in-shell-string-literals.md` | new page (existing category) |
| 2 | `platforms/tools/version-keyed-artifact-cache.md` | new page (existing category `tools`) |
| 3 | `platforms/processes/parsing-cli-structured-output.md` | new page (existing category) |

No new categories were created — `shells`, `tools`, and `processes` already exist
under `platforms` and each cleanly owns its insight. `wiki/platforms/index.md`
gained one "load when" row per page; `log.md` has the dated ingest entry.
Lint checks pass: all three bodies ≤120 lines (61/59/54), no banned vague
qualifiers, every `related:` id resolves.
