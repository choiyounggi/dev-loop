---
id: qa-document-verification-sweeping-pre-gate-citations-for-fabrication
domain: qa
category: document-verification
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/choiyounggi/dev-loop/issues/156
last_verified: 2026-09-08
related: [qa-document-verification-spec-document-gates, qa-document-verification-editing-a-gated-document, qa-process-defect-class-resweep-after-review, qa-deliverables-quantitative-claims-in-a-published-document]
---

# Retroactively Sweeping a Pre-Gate Corpus When a Citation-Verification Gate Lands

## When this applies

A knowledge base or wiki marks entries `confidence: verified` based on
citations the author added at write time (docs, URLs, quoted text), and you
are introducing — or just introduced — an automated citation-verification
gate: one that fetches every cited source and checks the page's claims
against it. Deciding whether that gate applies only to future edits or also
sweeps the corpus written before it existed.

## Do this

1. **Run the new gate over the full pre-gate corpus once, in addition to
   future diffs.** Enumerate every page carrying the confidence level the gate
   guards (`verified`), fetch every cited URL for each, and compare. Pre-gate
   entries were verified only by the author's own session — nothing else ever
   checked them, so a defect there stays invisible under a `verified` label
   until something re-reads the source.
2. **Treat quotation marks as a verbatim guarantee.** Any text inside quote
   marks attributed to a source must match the fetched source's text exactly,
   not "convey the same idea." A close paraphrase inside quote marks is a
   defect: the marks are the reader's signal that no interpretation happened.
3. **Classify each finding by its specific breakage kind** — the fixes differ:

| Case | Do |
|------|----|
| Quoted text is not present verbatim in the fetched source | Blocker: replace with the source's actual wording, or drop the quote marks and restate as paraphrase — then re-check the underlying claim still holds without the quote |
| Cited source fetches fine but discusses a different subject than the sentence claims (an arXiv ID names a different paper; an OWASP page never covers the cited topic) | Blocker: find the correct source or delete the claim; a "roughly related" citation is removed, not kept |
| Numeric or identifier citation (arXiv ID, issue number, version number) not traceable to any fetched source | Blocker: treat as suspected fabrication — remove or replace it |
| Link 404s, but the content exists at a different path, branch, or commit | Blocker: replace with a pinned working link (commit SHA or default-branch path) — a re-guessed URL is the next auditor's dead link |
| Source is unreachable from the auditing environment (403/429, JS-rendered, paywalled) after one retry | Advisory only: mark "unverifiable from CI"; unreachability itself is not a content defect |
| A claim's only real support is internal/session-only evidence, and the cited external doc does not establish it | Downgrade the page's `confidence` to `field-tested` and keep the claim — field evidence still supports it |

4. **Report the breakdown by kind, not a single defect count.** A "33
   blocker-level citation defects" headline can quietly include categories
   that are not citation defects at all (frontmatter formatting bugs,
   internal count mismatches within a page) — state each category's count
   separately so the citation-specific total is not inflated by unrelated
   lint failures found in the same pass.
5. **Parallelize the sweep by domain or category chunk** when the corpus is
   large enough that serial fetching is impractical, and record the actual
   agent count and fetch count achieved — that is the evidence the next
   auditor uses to estimate cost before starting their own sweep.

## Edge cases

| Case | Then |
|------|------|
| The page's confidence was already `field-tested`, not `verified` | Still fetch its cited URLs if any exist and flag fabricated/dead ones — a lower confidence tier does not exempt a page from having its citations exist |
| A citation was correct when written but the source has since changed (a doc page moved a claim to a different section) | Blocker under "stale claim," logged separately from fabrication — the citation was true once, so the fix is re-pointing it, not removing it |
| Two independent pages cite the same broken source | Fix both in the same pass; recording only the first-found instance leaves the second silently wrong after the sweep closes |
| The gate itself cannot tell fabrication from an unreachable-but-real source | Retry once, then record as advisory "unverifiable" rather than auto-classifying the uncertain fetch as a blocker — matching the fail-closed-on-missing-anchor principle in [qa-document-verification-spec-document-gates] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Apply a new citation-verification gate only to future PRs going forward | Also run it once over the full pre-gate corpus | Nothing else ever checked the old entries, so a pre-gate defect stays invisible under a `verified` label indefinitely |
| Accept a quote because the cited source is topically related | Fetch the exact source and compare the quoted phrase against it character-for-character | Topical relation is not verbatim truth — a citation can be a real, fetchable, wrong document, and the mismatch is invisible without a fetch |
| Publish one combined "N citation defects" count that mixes fabrication with formatting bugs found in the same pass | Report counts per defect kind (fabricated quote / wrong source / dead link / stale claim / non-citation lint) | Each kind has a different fix and urgency, and a combined count overstates how many are true citation-content defects |

## Sources

- https://github.com/choiyounggi/dev-loop/issues/156 — wiki-wide retroactive audit: 8 parallel agents, ~440 URL fetches, 270/270 pages covered, 33 blockers on 24 pages (about 25 of them citation/sourcing defects — fabricated quotes, wrong-paper citations, dead links, unsupportable `verified` labels — the remainder frontmatter and internal-consistency bugs found in the same pass); the issue's verdict rule: a failed fetch gets one retry then becomes an advisory "unverifiable", never a guessed verdict
