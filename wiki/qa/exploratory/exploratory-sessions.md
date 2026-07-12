---
id: qa-exploratory-exploratory-sessions
domain: qa
category: exploratory
applies_to: [general]
confidence: field-tested
sources:
  - https://www.satisfice.com/download/session-based-test-management
  - https://developsense.com/blog/2009/08/testing-vs-checking
last_verified: 2026-07-10
related: [qa-bug-reports-reproducible-reports, qa-process-release-gates]
---

# Running a Chartered Exploratory Testing Session

## When this applies

A new feature needs testing beyond its scripted checks, or you have test time
available and want maximum new information per hour spent.

## Do this

Exploratory testing is simultaneous learning, test design, and execution —
it finds what scripted checks were never written to look for. Structure it,
or it degrades into unaccountable clicking:

1. **Write a charter before starting**, in the form:
   `Explore <target> with <resources/constraints> to discover <information sought>`
   — e.g. "Explore checkout with a migrated legacy account to discover
   pricing/display failures."
2. **Timebox 60–90 minutes per charter, one charter at a time.** When you
   find a promising thread outside the charter, note it as a candidate
   charter and stay on mission; chase it in its own session.
3. **Generate test ideas from heuristics**, not habit:

| Heuristic | Try |
|-----------|-----|
| Boundaries and extremes | Empty input, maximum length, unicode/emoji, a huge paste, 0 and negative numbers |
| Interruptions | Refresh mid-flow, back button, double-click submit, go offline mid-request, let the session expire mid-form |
| State transitions | Do X before its prerequisite, after completion, twice in a row; skip a step; arrive via deep link |
| Role/permission variations | Repeat the flow as each role; hit the URL of a permitted action from an unpermitted role |
| Data variations | Existing vs freshly created account; migrated vs newly created data; record at its lifecycle edges (just created, archived, soft-deleted) |

4. **Log as you go**: what you tried, what surprised you, bugs found. A
   surprise that is not a bug is still a finding — it marks where the model
   in your head and the product disagree.
5. **Produce three outputs** at session end: (a) session notes, (b) bug
   reports filed per [qa-bug-reports-reproducible-reports], (c) a list of
   coverage gaps worth automating — hand these to the automated-test backlog
   (wiki/testing/) as candidates.

## Edge cases

| Case | Then |
|------|------|
| A bug found mid-session eats the timebox | Capture the reproduction immediately (that evidence is perishable), file it, and end the session honestly short — note the charter as partially explored, don't stretch the box |
| Feature too large for one charter | Split by risk into multiple charters and run the riskiest first; a charter that needs "and" twice is two charters |
| No requirements exist to judge expected behavior against | Charter the session to discover and document actual behavior; file surprises as questions to the owner, not as bugs |
| Time available but no new feature | Charter around recent-change hot spots and the least-recently-explored critical flow ([qa-process-regression-scope] adjacency records point to recurring breakage) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| "Click around" the feature unstructured | Write a charter and run a timeboxed, logged session | Unlogged exploration finds bugs you can't re-find, covers what you already believed, and leaves no record of what was and wasn't examined |
| Treat exploratory testing as optional polish after checks pass | Schedule it as its own gate layer for feature releases | Scripted checks only verify anticipated behavior; the unanticipated failures are exactly what exploration exists to find |
| Keep the notes in your head until the end of the day | Log during the session | Reproduction details decay within hours; a bug you can't re-find is a report nobody can act on |

## Sources

- https://www.satisfice.com/download/session-based-test-management — chartered, timeboxed, logged sessions (Bach & Bach, SBTM)
- https://developsense.com/blog/2009/08/testing-vs-checking — exploration finds what scripted checks cannot (Bolton)
- Elisabeth Hendrickson, *Explore It!* (Pragmatic Bookshelf, 2013) — charter template "Explore… with… to discover…"
