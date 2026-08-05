# Knowledge flush — 3 insight(s)

Three `★ Insight` candidates drained from `~/.dev-loop/queue`. Each was
researched, verified, deduped against existing pages, and **merged into an
existing page** (merge-before-create — no new pages, no new categories).

## Verified best-practice

### 1. Homebrew keg-only formulae are installed but deliberately off PATH
- **Claim:** `which <tool>` / `command -v <tool>` returning "not found" on macOS
  does **not** mean the toolchain is absent — Homebrew keg-only formulae (llvm,
  openssl, curl, node@N, libpq) are built into the Cellar but not symlinked into
  the prefix, so they are off PATH by design. Check the keg directly
  (`/opt/homebrew/opt/<formula>/bin/`, `brew info <formula>`) before deferring.
- **Sources checked:** <https://docs.brew.sh/FAQ> — verbatim: "the formula is
  installed only into the Cellar and is not linked into the default prefix …
  most tools will not find it"; "You can see why a formula was installed as
  keg-only, and instructions for including it in your `PATH`, by running
  `brew info <formula>`." The active version stays reachable at
  `$(brew --prefix)/opt/<formula>/bin` regardless of version.
- **How verified:** official Homebrew docs + the field reproduction on record
  (`which mlir-opt` → not found, while `/opt/homebrew/opt/llvm/bin/mlir-opt
  --version` → LLVM 22.1.8).
- **Confidence: verified.**

### 2. tmux/REPL prompt injection stalls on bracketed paste; submit is a separate keystroke
- **Claim:** injecting a long/multiline prompt into an interactive REPL (tmux
  `send-keys -l`, `expect`, a PTY) and seeing it stall as a collapsed paste
  (`❯ [Pasted text #1]`) means the REPL captured it as one **bracketed-paste**
  block; the embedded newline is not treated as submit, so a **separate** Enter
  (a couple seconds later) is required — or clear with `C-u` and re-inject.
- **Sources checked:** <https://en.wikipedia.org/wiki/Bracketed-paste> — the
  terminal wraps a paste in `ESC[200~`/`ESC[201~` so the application treats it as
  one block and does not act on embedded control characters (newlines) as
  keypresses. Corroborated by <https://github.com/anthropics/claude-code/issues/43169>
  (tmux multi-line paste under `extended-keys-format csi-u`).
- **How verified:** the bracketed-paste mechanism is doc-verified; the specific
  Claude-CLI "first Enter confirms the paste, second Enter submits" behavior is
  the session's own reproduction (three orchestration sessions all stalled at
  `[Pasted text #1]` until a second Enter flipped them to `esc to interrupt`).
- **Confidence: field-tested** (mechanism doc-verified; the CLI submit specifics
  are production observation, not an official CLI doc).

### 3. A "pure" function's test is not dependency-free if its module runs I/O at import
- **Claim:** importing a module to unit-test a pure function within it runs the
  module's import-time side effects (module-scope `init_db()`, a top-level DB/HTTP
  client), so the test is really integration. A function-level
  `@pytest.mark.skipif` cannot prevent it, because skipif is evaluated at
  collection **after** the test module (and its top-level imports) has been
  imported. Gate at module load (`pytest.importorskip`, `pytest.skip(...,
  allow_module_level=True)`) or move the function to a side-effect-free module.
- **Sources checked:** <https://docs.pytest.org/en/stable/how-to/skipping.html> —
  skipif's condition "is evaluated at collection time"; skip an entire module at
  import with `pytest.skip(reason, allow_module_level=True)`; use
  `pytest.importorskip` at module level for a missing import.
- **How verified:** official pytest docs for the timing/mechanism + the field
  case (`src/web/app.py` calling `init_db()` at import, forcing Postgres onto a
  `from app import _polygon_centroid` unit test).
- **Confidence: verified.**

## Existing-layer check

Pages read for overlap in each target domain/category before editing:

- **path-resolution** (`platforms/environment`): its "When this applies" already
  owns "command not found though the tool is installed" and its "Instead of"
  already steers `which` → `command -v`/`type`. The keg-only case **extends** it
  with a mechanism neither the page nor `command -v` covers (the binary is off
  PATH by design, so `command -v` also misses it). **Merged** a "Do this" row, an
  "Instead of" row, a source, and a "When this applies" clause — no new page.
  Also read `toolchains/version-management` (owns version-manager shims, a
  different off-PATH mechanism — left untouched, no conflict).
- **non-interactive-cli-invocation** (`platforms/processes`): the page owns
  "automating a prompt-capable CLI (agent CLI) from a harness." The bracketed-paste
  stall is a distinct failure mode within that theme (driving the *interactive*
  REPL rather than `-p`). **Merged** an Edge-cases row, a source+field-context
  bullet, and a "When this applies" clause. No conflict with its stdin-detach
  guidance (orthogonal: that is fd 0 for `-p` calls; this is paste framing for
  keystroke injection).
- **test-level-choice** (`testing/strategy`): its Edge-cases already has "logic
  worth unit-testing is buried inside a controller/handler that needs the
  framework to run → extract it." The import-side-effect case is the same family
  (buried-in-a-module-that-needs-I/O) with a pytest-specific skipif twist.
  **Merged** two Edge-cases rows + one "Instead of" row + a source. Also read
  `testing/data/test-data-and-isolation` (owns runtime state leak, not import
  time) — no duplication; added a reciprocal `related:` link (it already linked
  back to test-level-choice).

Conflicts flagged: none. Related links added: test-level-choice ↔
test-data-and-isolation (reciprocal now complete).

## Routing decision

| Insight | Target domain/category/page | Notes |
|---------|-----------------------------|-------|
| 1. keg-only off PATH | `platforms/environment/path-resolution.md` | Harvested hint said `infrastructure`; **re-routed** — the wiki has a dedicated PATH page and the insight is a PATH-resolution fact, not a CI/CD or deploy concern |
| 2. bracketed-paste REPL injection | `platforms/processes/non-interactive-cli-invocation.md` | Matches harvested `platforms`; merged as an edge case of automating a prompt-capable CLI |
| 3. import-time side effects vs unit test | `testing/strategy/test-level-choice.md` | Matches harvested `testing`; chosen over `testing/data/test-data-and-isolation` because the resolution is a *level/structure* decision (extract to a side-effect-free module / recognize it as integration), extending the page's existing "extract buried logic" edge case |

No new categories created — every insight merged into an existing page under an
existing category. Domain `index.md` load-when lines for all three pages were
extended so the new cases are routable, and `log.md` records the ingest.
