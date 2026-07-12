---
name: knowledge-flush
effort: high
argument-hint: "[optional: filters]"
description: Drain queued ★ Insight candidates (harvested from your sessions) into the wiki as a reviewed PR. For each candidate it researches and verifies the best-practice against real sources, checks existing wiki layers for duplicates and links, decides the target layer/category (or justifies a new one), runs wiki-ingest, then opens ONE PR per flush for you to review and merge/reject. Never auto-merges. Use when asked to "flush knowledge", "process the insight queue", "ingest what I learned", or "/dev-loop:knowledge-flush".
---

# knowledge-flush — queued insights → verified wiki PR

Turn the `★ Insight` candidates harvested from your sessions into a wiki
contribution, **PR-only** — you (the repo owner) review each PR and merge or
reject it. This skill NEVER auto-merges and NEVER pushes to `main`.

The queue lives at `~/.dev-loop/queue/*.jsonl` (written by the Stop hook). Each
row is a candidate: `trigger, directive, why, evidence, domain, tags, content`.

## Non-negotiable order (a PreToolUse gate enforces it)

`hooks/pre-flush-pr-gate.sh` blocks `gh pr create` on a knowledge branch unless
an `INGEST_REPORT.md` with three filled sections exists. So do the work first:

1. **Prepare a writable checkout** of the dev-loop repo (never edit the installed
   plugin dir — it is read-only and untracked):
   ```sh
   REPO="$HOME/.dev-loop/repo"
   if [ -d "$REPO/.git" ]; then
     git -C "$REPO" fetch origin && git -C "$REPO" checkout main && git -C "$REPO" reset --hard origin/main
   else
     mkdir -p "$HOME/.dev-loop"
     git clone https://github.com/choiyounggi/dev-loop.git "$REPO"
   fi
   # Commit under THIS user's own identity — each contributor's PR carries their
   # own account; the owner reviews and approves/rejects. Do NOT hardcode an
   # identity, and NEVER commit as an assistant or add a Co-Authored-By trailer.
   # Inherit the user's global git identity (fall back to their gh login only if
   # git has none configured):
   if [ -z "$(git -C "$REPO" config user.email)" ]; then
     GH_USER="$(gh api user -q .login 2>/dev/null)"
     [ -n "$GH_USER" ] && git -C "$REPO" config user.name "$GH_USER" \
       && git -C "$REPO" config user.email "${GH_USER}@users.noreply.github.com"
   fi
   # Branch names carry the contributor so PRs are attributable at a glance:
   WHO="$(git -C "$REPO" config user.name | tr ' ' '-' | tr -cd 'A-Za-z0-9-')"
   BR="knowledge/${WHO:-anon}-$(date +%Y%m%d-%H%M%S)"
   git -C "$REPO" checkout -b "$BR"
   ```
   Read/write the wiki inside `$REPO` (its `INDEX.md`, `wiki/`, `templates/`,
   `AGENTS.md`), NOT `${CLAUDE_PLUGIN_ROOT}`. The push + PR use the ambient `gh`
   auth, so the PR is opened by whichever account this user is logged in as.

2. **For each queued candidate, run the pre-PR pipeline** (this is the whole point
   — a raw harvested block is a *candidate*, not vetted knowledge):

   a. **Research & verify the best-practice.** Do a real search — official docs,
      primary sources, reputable references (use WebSearch / context7 / the
      relevant framework docs). Confirm the directive is actually correct, not
      just plausibly asserted in the session. Capture checkable citations.
      - Verified against official docs or a reproducible check → `confidence: verified`.
      - Only production experience, no external source → `confidence: field-tested`.
      - Cannot substantiate → either drop the candidate or keep it
        `confidence: unverified` and say so loudly in the report. **Never
        fabricate or approximate a URL.**

   b. **Existing-layer check (dedup + links).** Route to the domain via
      `INDEX.md`, then read that domain's `index.md` and every page whose
      "load when" overlaps. Determine: is this already covered (→ merge/append,
      don't duplicate)? Does it conflict with an existing directive (→ flag,
      don't overwrite)? Which existing pages should it `related:`-link to?

   c. **Routing decision.** State the target `domain/category` and page. If no
      category fits, decide whether to add one (and justify why the existing
      categories genuinely don't cover it) or place it under the closest fit.

   d. **Ingest.** Run the **`wiki-ingest`** skill with the decisions from a–c:
      merge-before-create, positive-guidance form, sourced frontmatter, ≤120
      body lines, and update the domain `index.md` + `log.md`.

3. **Write `INGEST_REPORT.md`** at `$REPO/.dev-loop/INGEST_REPORT.md` (a separate
   step BEFORE the PR command — the gate evaluates the file before the command
   runs, so it cannot be a heredoc inside the `gh pr create` line). Required
   sections, each with real content:

   ```markdown
   # Knowledge flush — <N> insight(s)

   ## Verified best-practice
   For each insight: the claim, the sources you checked (real URLs/docs), how you
   verified it, and the resulting confidence (verified / field-tested / unverified).

   ## Existing-layer check
   Pages you read, overlaps found, what you merged vs. created new, conflicts
   flagged, and related-links added.

   ## Routing decision
   Target domain/category/page for each insight; any new category + why existing
   ones didn't fit.
   ```

4. **Commit + PR (no auto-merge).**
   ```sh
   git -C "$REPO" add wiki/ INDEX.md log.md .dev-loop/INGEST_REPORT.md
   git -C "$REPO" commit -m "knowledge: ingest <N> verified insight(s)"
   git -C "$REPO" push -u origin "$BR"
   gh pr create --repo choiyounggi/dev-loop --base main --head "$BR" \
     --title "knowledge: <short summary>" \
     --body-file "$REPO/.dev-loop/INGEST_REPORT.md" \
     --label dev-loop:knowledge
   ```
   Do NOT `gh pr merge`. The owner reviews open `dev-loop:knowledge` PRs and
   merges or rejects each one.

5. **Retire processed candidates.** Move the flushed rows out of the active queue
   (e.g. append them to `~/.dev-loop/queue/.processed.jsonl` and rewrite the
   session file without them) so the next flush doesn't re-ingest them.

## Guardrails
- PR-only. Never auto-merge, never push to `main`, never force-push `main`.
- Commit under the **user's own ambient git/gh identity** — never hardcode an
  account, never commit as an assistant, never add a `Co-Authored-By` trailer.
- A candidate you cannot verify does not get quietly upgraded to `verified`.
- If the queue is empty, say so and stop — do not open an empty PR.
- One PR per flush (batched), so review stays a single pass.

## Triggering — manual and automatic
- **Manual:** invoke this skill (`/dev-loop:knowledge-flush`) any time; it drains
  the shared queue (`~/.dev-loop/queue/`, keyed off `$HOME` so it spans sessions).
- **Automatic:** the Stop hook `hooks/auto-flush.sh` fires this same pipeline in a
  detached headless `claude` run when the queue crosses a threshold and the
  rate-limit window has elapsed — so PRs appear without you running anything. It
  is guarded (rate-limited, batched, recursion-safe) and opens the same reviewed,
  gated PR. Disable with `DEV_LOOP_AUTOFLUSH=0`. See that hook for the knobs.
