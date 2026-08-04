# Knowledge flush — 3 insight(s): 2 ingested, 1 held back

Drained 3 pending candidates from `~/.dev-loop/queue`. Two were verified and
merged into existing `platforms` pages; one (MLIR IRDL) is verified-but-niche and
held back from this general wiki with a recommendation (see Routing decision).

## Verified best-practice

### 1. Homebrew keg-only formulae are installed but off `PATH` → `verified`
- **Claim:** On macOS, `which <tool>` / `command -v <tool>` reporting not-found
  does **not** mean the tool is absent. Homebrew keg-only formulae (llvm, curl,
  openjdk, node@N, libpq, ruby) are installed into the Cellar but deliberately not
  symlinked onto `PATH`. Check the package manager's record before concluding
  absence.
- **Sources checked:** https://docs.brew.sh/FAQ ("What does keg-only mean?" —
  "installed only into the Cellar and is not linked into the default prefix");
  `brew info llvm` output ("llvm is keg-only, which means it was not symlinked
  into /opt/homebrew").
- **How verified (reproduced on this machine, 2026-08-04):** `which mlir-opt` →
  "mlir-opt not found" (exit 1) and `command -v mlir-opt` → not found, **while**
  `brew list --versions llvm` → `llvm 22.1.8` and
  `/opt/homebrew/opt/llvm/bin/mlir-opt --version` → "Homebrew LLVM version
  22.1.8". This is the exact incident from the queue (issue #7 deferred on a stale
  `which` check though LLVM 22.1.8 was installed).
- **Confidence: verified** (official doc + local reproduction).

### 2. Bash double-quote strips the backslash only before five chars → `verified`
- **Claim:** Inside a double-quoted bash string, the backslash retains special
  meaning only before `$`, backtick, `"`, `\`, or newline. So a regex embedded in
  a double-quoted string has `"\$"` collapse to a bare `$` (a regex end-of-line
  anchor) before the tool ever sees it, while `"\d"` keeps its backslash. Miscopy
  the pattern as `$` or `\\$` and the EOL match silently changes.
- **Sources checked:**
  https://www.gnu.org/software/bash/manual/html_node/Double-Quotes.html — the
  backslash "retains its special meaning only when followed by one of" `$`,
  backtick, `"`, `\`, or newline (page fetched and the sentence confirmed present
  2026-08-04).
- **How verified (reproduced 2026-08-04):** `od -c` on the guardrails-style
  pattern `"(sh|bash)([[:space:]]|-|<|\$)"` shows the byte reaching grep is a bare
  `$` (backslash stripped); `echo 'curl http://x | sh' | grep -E "$pat"` matches
  `sh` at end-of-line, confirming `$` acts as the EOL anchor. Matches the queue
  incident (why `curl … | sh` with no trailing char matches the bash-guard rule).
- **Confidence: verified** (official doc + local reproduction).

### 3. MLIR IRDL region ops fail verification without a borrowed terminator → `field-tested`
- **Claim:** An MLIR op with a region defined declaratively via IRDL (LLVM 22)
  fails block verification ("block with no terminator") because IRDL cannot
  declare a terminator op or attach `NoTerminator`/set `RegionKind` on
  user-defined ops. Either embed a borrowed terminator
  (`omp.terminator`/`llvm.unreachable`) or model the nesting with flat marker ops
  carrying a `children` id-list attribute.
- **Sources checked:** https://mlir.llvm.org/docs/LangRef/ (SSACFG regions require
  a terminator; a single-block region may opt out only via `NoTerminator` **on the
  enclosing op**); https://mlir.llvm.org/docs/Dialects/IRDL/ (`irdl.dialect`
  itself carries `NoTerminator`, but the op-definition surface exposes no way to
  attach that trait or set `RegionKind` on the ops you define). The mechanics are
  doc-corroborated; the specific IRDL limitation is not stated as such in the docs.
- **How verified:** contributor measured it with `mlir-opt 22.1.8` (region op →
  "block with no terminator"; only `omp.terminator`/`llvm.unreachable` verified
  inside a generic IRDL region; flat marker ops round-tripped cleanly). Not
  re-reproduced here (no dialect fixture on hand).
- **Confidence: field-tested** — measured in production, mechanism doc-backed, but
  the IRDL-can't-set-it limitation has no official-doc statement.

## Existing-layer check

- **Insight 1 → `wiki/platforms/environment/path-resolution.md` (merge, not new).**
  Read the full page. Its "load when" line already owns "'command not found'
  though the tool is installed"; it already had a brew-shadowing row and a
  `which`→`type`/`command -v` Instead-of row. **Gap:** none of those cover the
  keg-only case where even `command -v`/`type` correctly report not-found because
  the binary is genuinely unlinked (absence-on-PATH ≠ not-installed). Merged one
  `Edge cases` row + one `Instead of` row + one source; no duplication, no
  conflict. Related links already point to `toolchains/version-management` and
  `processes/background-services` (both relevant, left as-is).
- **Insight 3 → `wiki/platforms/shells/portable-shell-scripts.md` (merge, not new).**
  Read the full page plus the adjacent
  `shells/command-text-inspected-before-execution.md` (the candidate arose in a
  guardrails PreToolUse hook, which that page owns). That page is about a *gate
  reading command text*; this lesson is about the *shell mangling an embedded
  regex* — a quoting-semantics fact, so it belongs on portable-shell-scripts (the
  quoting page), which the two pages already cross-link via `related:`. The page's
  "Do this #2" says "quote every expansion" but nowhere states the double-quote
  backslash-stripping rule. Merged one `Edge cases` row + one `Instead of` row +
  one source; no duplication, no conflict.
- **Insight 2 (MLIR IRDL):** no domain owns compiler/dialect internals. Closest
  seeded categories (`platforms/toolchains` = version pinning; `infrastructure`
  = CI/CD) genuinely do not cover "how MLIR's region verifier interacts with
  IRDL-defined ops." No merge target exists.

## Routing decision

- **Insight 1 → `platforms/environment/path-resolution`** (merged). The harvested
  `domain: infrastructure` hint was wrong — this is a PATH-resolution symptom, not
  a CI/CD/build concern. No new category.
- **Insight 3 → `platforms/shells/portable-shell-scripts`** (merged). The harvested
  `domain: security` hint was incidental (the bug surfaced in a guardrails hook);
  the reusable lesson is bash double-quote semantics, owned by `platforms/shells`.
  No new category.
- **Insight 2 → held back (no ingest).** Verified-as-field-tested and genuinely
  correct, but it is single-repo compiler-internals with no home in the current 10
  general SWE domains. Ingesting it would mean creating a `compilers`/`mlir` domain
  for one insight loadable by exactly one repo — which the wiki's own philosophy
  (one case per page, cross-repo reusability) argues against. **Recommendation:**
  keep it in the owning repo's own docs (e.g. a dialect NOTES file), or, if you
  want the wiki to carry dialect-authoring knowledge, say so and I will open a
  dedicated `compilers` domain in a follow-up. Logged as a `gap` entry in `log.md`.
  All 3 candidates are retired from the active queue so auto-flush will not re-run
  them; the MLIR row is preserved in `.processed.jsonl` (status `deferred-out-of-scope`).
