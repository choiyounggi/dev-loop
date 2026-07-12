---
name: wiki-query
effort: medium
argument-hint: "[your question]"
description: Answer a development question from the wiki with citations, loading only the pages whose triggers match. If the answer required synthesis across multiple pages and the question is likely to recur, file the synthesis back as a new page so knowledge compounds.
---

# Query

> **In the dev-loop plugin.** Resolve `INDEX.md` and `wiki/<...>.md` paths against
> **`${CLAUDE_PLUGIN_ROOT}/`** (the installed plugin root), not the working dir.

Input: a question or an active task that needs guidance.

## Steps

1. **Route, don't scan.** Follow the routing protocol in `AGENTS.md`:
   `INDEX.md` → domain `index.md` → load only pages whose "When this applies"
   matches. Never bulk-load a domain.

2. **Answer from pages, cite pages.** Compose the answer from the loaded pages'
   directives and edge-case tables. Cite each page id you used. Where a page cites
   external sources, surface them.

3. **Say what the wiki doesn't know.** If no page matches, say so explicitly and
   answer from general knowledge clearly labeled as *not wiki-backed*. Do not blend
   wiki-backed and unbacked claims without labels.

4. **Compound.** If the answer required synthesizing 2+ pages or filled a gap, and
   the question is one that will recur, run `skills/wiki-ingest/SKILL.md` on the synthesis
   (the answer's evidence chain is its source list). One-off trivia does not get a page.

5. **Log gaps.** If the wiki had no answer, append
   `## [YYYY-MM-DD] gap | <question>` to `log.md` so lint can propose research.
