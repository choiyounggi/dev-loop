---
name: wiki-ingest
description: Add new knowledge to the wiki — a lesson learned, an edge case hit in production, a documented best practice, or a source document. Routes it to the right domain/category, merges into existing pages before creating new ones, and enforces sourcing and positive-guidance rules.
---

# Ingest

> **In the dev-loop plugin.** The wiki lives at the plugin root. When you run this
> skill by hand for reference, read paths (`INDEX.md`, `wiki/`, `templates/`,
> `AGENTS.md`) against **`${CLAUDE_PLUGIN_ROOT}/`**. When this skill is driven by
> **`knowledge-flush`** to open a PR, that skill first prepares a **writable git
> checkout of the dev-loop repo** and passes you its path as `<wiki_root>` — do all
> reading and writing there (never edit the installed plugin dir, which is
> read-only and untracked). `knowledge-flush` handles the branch/commit/PR after
> you finish; your job is only the routed, sourced edit + plumbing update.

Input: one unit of knowledge. Either a source (doc, article, post-mortem, benchmark)
or a distilled lesson ("we hit X; doing Y fixed it because Z").

## Steps

1. **Extract the case.** State the knowledge as: *trigger situation → directive →
   why → evidence*. If you cannot fill "trigger situation" precisely, stop: ask the
   contributor what situation makes this advice apply. Knowledge without a trigger
   cannot be routed and pollutes context.

2. **Convert prohibitions.** If the input arrives as "never do X" / "avoid X",
   rewrite it as the replacement action: "when <situation that tempts X>, do Y".
   Keep the prohibition only as an `Instead of` row paired with Y.

3. **Route.** Match the case to a domain via `INDEX.md`, then to a category via the
   domain `index.md`. If no category fits, create one (update the domain index) —
   but first re-check that an existing category doesn't already cover it under a
   different name.

4. **Merge before creating.** Read every existing page in the target category whose
   "load when" line overlaps the new case.
   - Same trigger, same directive → add the new source / edge case to that page.
   - Same trigger, conflicting directive → do NOT overwrite. Add the conflict to the
     page under `Edge cases` if it is condition-dependent, or flag it in `log.md` as
     `contradiction` for the owner to resolve.
   - New trigger → create a new page from `templates/page.md`.

5. **Source it.** Fill `sources:` with real, checkable citations. Do not invent or
   approximate URLs — an unverifiable citation is worse than none. If the only
   evidence is experience, set `confidence: field-tested` and describe the context
   in the page body. If there is no evidence yet, set `confidence: unverified`.

6. **Respect the format.** Template sections, ≤120 body lines, decision tables for
   branches, no vague qualifiers in directives (see `AGENTS.md`).

7. **Update the plumbing.** Domain `index.md` gets the page with an accurate
   "load when" line. `log.md` gets `## [YYYY-MM-DD] ingest | <page id> — <one line>`.
   Add `related:` links both ways for genuinely adjacent pages.

8. **Report.** List pages created/updated, conflicts flagged, and anything left
   `unverified` that needs evidence.
