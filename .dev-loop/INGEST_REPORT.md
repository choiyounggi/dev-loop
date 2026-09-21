# Knowledge flush — 5 insight(s)

Claimed queue ids: `44e28bb8c99c1d0c`, `f2d90d5048826870`, `fb7d73874bac6eaa`,
`5f3e5eb58ec373e4`, `6e83a02b449a8dff`. All five are plan-gap rows emitted by
`skills/wiki-plan/scripts/emit-gaps.sh` — decisions a wiki-plan marked
`[no-wiki]`. Result: 1 new page (4 rows merged into it), 1 row dropped.

## Verified best-practice

**Candidates `f2d90d5048826870`, `fb7d73874bac6eaa`, `5f3e5eb58ec373e4`, `6e83a02b449a8dff`
(all t3-status, issue #195)** — the four rows are facets of one reusable lesson:
how to change a cited knowledge/decision record that turned out wrong.

| Claim | Source checked | How verified |
|-------|----------------|--------------|
| Keep the reversed record, mark it superseded, reference the replacement | https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions | Live-fetched 2026-09-17; quote: "If a decision is reversed, we will keep the old one around, but mark it as superseded. (It's still relevant to know that it *was* the decision, but is *no longer* the decision.)" and "may be marked as 'deprecated' or 'superseded' with a reference to its replacement" |
| Amend-in-place vs. stand-alone successor is a real, named distinction | https://www.rfc-editor.org/rfc/rfc2223.txt §12 | Raw text read with curl; *Updates* = supplement that "cannot stand on its own", *Obsoletes* = "can be used alone, without reference to the older document" |
| Status is an optional field whose value carries the successor | https://adr.github.io/madr/ | Live-fetched; template status values `proposed / rejected / accepted / deprecated / … / superseded by ADR-0123`, marked "These are optional elements" |
| Validity status lives apart from the document's content and can change later | https://www.rfc-editor.org/faq/ | Raw page read with curl; "the status of an RFC can change", published on the info page and a status-changes list |

Correction made during verification: the candidates' evidence cited a Stack
Overflow answer for the Obsoletes/Updates semantics, and a first fetch of
RFC 7322 §4.1.4 returned a summary that *added* definitions the RFC does not
contain. Reading the raw RFC 7322 text showed §4.1.4 only gives the header
format; the definitions are in RFC 2223 §12, which is what the page cites.
The candidates' secondary sources (ctaverna.github.io, docsio.co, the
runenwerk issue) were not needed and are not cited.

Directive 7 of the page (log the transition under the existing `revise`-class
verb) has no external source; it is stated conditionally ("when nothing parses
the verb set mechanically") and rests on the field context of issue #195.
Confidence: **verified** (directives 1–6 are backed by the primary sources above).

**Candidate `44e28bb8c99c1d0c` (t1-reviewer, README agents-tree line)** — not a
best-practice claim. It is a one-repo scope ruling ("add one README line, leave
README.ko.md and the sibling reviewer lines alone"). No transferable trigger or
directive; nothing to verify. **Dropped.**

## Existing-layer check

Routed via `INDEX.md` → qa (document deliverables / document-verification), and
cross-checked infrastructure (agent-orchestration, where the gap-queue page
lives) and backend (api-versioning, the nearest "deprecation" page).

Pages read: qa-document-verification-retiring-a-provisional-marker, infrastructure-agent-orchestration-escape-hatch-uses-as-a-knowledge-gap-signal, qa-document-verification-spec-document-gates, backend-common-api-design-api-versioning-and-breaking-changes

- `grep -rli "supersed|ADR|architecture decision" wiki/` → 4 hits, none about
  the lifecycle of a record: retiring-a-provisional-marker covers removing
  `[추정]`/TBD markers inside one document; escape-hatch-uses covers emitting
  gap rows; the other two only mention the word.
- `grep '^status:'` over the wiki → 0 pages; AGENTS.md has no lifecycle field
  (issue #195 is what introduces it). No existing directive conflicts.
- Result: **new page** `wiki/qa/document-verification/superseding-a-knowledge-record.md`
  (72 body lines). The four t3-status rows were merged into it rather than
  ingested as four pages: supersede-vs-overwrite (D8) → Do-this 1–3, status vs.
  confidence (D9) → Do-this 5, absent-means-active template line (D14) →
  Do-this 6, `revise` verb (D7) → Do-this 7.
- Related links added both ways: retiring-a-provisional-marker,
  spec-document-gates, escape-hatch-uses-as-a-knowledge-gap-signal.
- `wiki/qa/index.md` document-verification table +1 row; `log.md` +1 ingest entry.
- Checks after the edit: `node scripts/wiki-structure-checks.js wiki` →
  279 pages / 13 indexes / 0 findings; `node scripts/wiki-lint-prohibitions.js wiki`
  → directives 75, violations 0 (bats pin unchanged at 75);
  wiki-structure-checks / wiki-lint-prohibitions / wiki-lint-model-era bats → 0 failures.

## Open-PR check

Open `knowledge/*` heads listed 2026-09-17: #205, #191, #190, #189, #188, #187,
#186, #185, #183, #182, #181, #180, #179. Each head was fetched and
`git diff origin/main origin/<head> -- wiki/` grepped for
`supersed|superseded_by|status: retired|decision record|obsoletes` → 0 added
lines on every head. Nearest neighbour: #186's
`model-coupled-guidance-aging-detector` — it detects pages that may have aged;
it says nothing about what to do with a refuted record, so no overlap.

| Candidate | Verdict |
|-----------|---------|
| `f2d90d5048826870` (log verb for supersede/retire) | new |
| `fb7d73874bac6eaa` (ingest third case: page wrong as a whole) | new |
| `5f3e5eb58ec373e4` (status vs. confidence) | new |
| `6e83a02b449a8dff` (template optional status lines) | new |
| `44e28bb8c99c1d0c` (README agents-tree line) | drop — not generalizable (not a pending duplicate) |

Note for the reviewer: issue #195 (t3-status) will itself add `status` /
`superseded_by` to AGENTS.md. This page is the general practice behind that
schema, written so it stays correct whether or not #195 has landed.

## Routing decision

- 4 t3-status rows → `qa / document-verification /
  superseding-a-knowledge-record` (new page, existing category). The category
  already owns ADR/RFC/spec document lifecycle pages
  (retiring-a-provisional-marker, editing-a-gated-document), so no new
  category was needed.
- 1 t1-reviewer row → no page (dropped).
