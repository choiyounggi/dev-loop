---
id: backend-common-integrations-cutting-scraped-text-at-a-noise-marker
domain: backend
category: integrations
applies_to: [general]
confidence: field-tested
sources:
  - https://doi.org/10.13053/cys-22-2-2959
  - "Field measurement 2026-10-10 (scraper over a company-review site's interview, review and benefits list pages)"
last_verified: 2026-10-11
related: [backend-common-integrations-contact-details-from-scraped-pages]
---

# Cutting Scraped Page Text at a Noise Marker

## When this applies

Post-processing a scraped page's text (markdown or plain text from a scraper or a
main-content extractor) by cutting it at a phrase that starts a noise block —
"recommended", "related posts", "learn more about this company", an ad heading — or
reviewing such a cut; the trimmed text is much shorter than the page yet still reads
like a complete page.

## Do this

1. **Find where the content ends before choosing a cut point.** Pick an item anchor:
   a string every content item carries once (a per-item "Report" label, a review date
   line, a rating line). Find its last occurrence, and cut at the first noise marker
   after it:

| Case | Do |
|------|----|
| A noise marker occurs after the last item anchor | Cut at the first such occurrence |
| Noise markers occur only before the last item anchor | Keep the text uncut; each of them opens a block placed between items |
| The page has no item anchor (zero items, or the layout changed) | Keep the text uncut and record the page as unanchored |

2. **Prove the cut kept every item.** Count the item anchors before and after the cut;
   when the counts differ, keep the uncut text and log the page.

## Edge cases

| Case | Then |
|------|------|
| One site has several list page types (reviews, interviews, benefits) | Choose the item anchor per page type and run the count check on each type; in the field case all three types interleaved blocks between items |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Cut at the first occurrence of the marker (`text.indexOf(marker)`) | Cut at the first marker after the last item anchor | Sites place ad and recommendation blocks between items; a first-occurrence cut drops every item after the first block |
| Judge the cleanup by reading a trimmed page | Compare item-anchor counts before and after the cut on every page | A page cut from 4,103 to 542 characters read like a normal short page |

## Sources

- https://doi.org/10.13053/cys-22-2-2959 — Viveros-Jiménez et al., "Improving the Boilerpipe Algorithm for Boilerplate Removal in News Articles Using HTML Tree Structure", Computación y Sistemas 22(2), 2018 (full text on SciELO): "Non-relevant content could be placed everywhere in the structure of the document (even in the middle of the text)". It supports the premise that noise is not confined to a page's tail; the cut rule and the count check on this page are field practice, hence `field-tested`
- Field measurement 2026-10-10 (a scraper over a Korean company-review site, JobPlanet): on an interview list page the "learn more about this company" block began at character 300 of the 4,103-character text and four interview reviews followed it; the stored result of the first-occurrence cut was 542 characters long and held none of those reviews (the session recorded the offset and the stored length, not the step between them). On a review list page a "popular community posts" block began at character 1,358 while the per-review "Report" label kept appearing up to character 4,114; the benefits page showed the same interleaving
