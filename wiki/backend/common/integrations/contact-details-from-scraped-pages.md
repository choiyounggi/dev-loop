---
id: backend-common-integrations-contact-details-from-scraped-pages
domain: backend
category: integrations
applies_to: [general, firecrawl]
confidence: verified
sources:
  - https://docs.firecrawl.dev/api-reference/endpoint/scrape
last_verified: 2026-09-06
related: [backend-common-integrations-robots-txt-and-source-selection, backend-common-reliability-timeouts-and-retries]
---

# Collecting Phone Numbers and Addresses From Company Sites With a Main-Content Scraper

## When this applies

Extracting contact details (phone, address, messenger handle) from company
websites through a scraping API or library that offers a "main content only"
mode (Firecrawl `onlyMainContent`, readability-style extractors); such a run
returns clean text with few or no phone numbers; deciding whether to add a
JavaScript-rendering fallback.

## Do this

1. **Turn the main-content filter off for contact extraction.** Sites put
   contact details in the header bar, the footer, and floating widgets —
   exactly the regions a main-content filter is defined to remove. Firecrawl's
   `onlyMainContent` defaults to `true` and "excludes headers, navs, footers";
   set it to `false` (or list `header`, `footer`, `aside` and the theme's
   wrapper selectors in `includeTags`) so the extractor sees the regions where
   the numbers live.
2. **Extract from the raw HTML's link targets before any text heuristic.**
   Request the HTML format alongside markdown and read `href` values:

| Link | Yields |
|------|--------|
| `tel:+84…` | The canonical phone number, already normalized by the site |
| `https://zalo.me/…`, `https://wa.me/…`, `viber://…` | Messenger handles that are the primary contact on many SME sites |
| `mailto:` | Email without a regex over rendered text |

   Fall back to a regex over the full-page text only for sites with no such
   links.
3. **Treat JavaScript rendering as the last fallback.** Measure before adding
   it: fetch the static HTML and the rendered DOM for a sample of target sites
   and diff the numbers found. Add rendering only for the sites where the diff
   is non-empty.

## Edge cases

| Case | Then |
|------|------|
| The number appears only as an image or CSS-obfuscated spans | Neither mode returns it as text; record the site as "contact by image" and stop, rather than adding OCR to the pipeline for one site |
| The footer holds several numbers (branches, departments) | Keep all, labeled by the nearest heading or `aria-label`; a "first number wins" rule picks the fax line |
| `includeTags` is used instead of `onlyMainContent: false` | Include the wrapper elements the theme actually uses (`#footer`, `.topbar`) — a site that renders its footer as a `<div>` is not matched by the `footer` tag alone |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Scrape in the default main-content mode and regex the markdown for phone numbers | Disable the main-content filter and read `tel:`/messenger hrefs from the HTML first | The default mode removes the header and footer where the numbers sit |
| Add headless rendering because the static fetch found no number | Diff static vs rendered on a sample first | In the measured sample no site injected a number by JavaScript alone; the missing numbers were in the filtered-out regions |

## Sources

- https://docs.firecrawl.dev/api-reference/endpoint/scrape — `onlyMainContent` (default `true`): "Only return the main content of the page excluding headers, navs, footers, etc. This is a deterministic HTML-level filter applied before markdown is generated"; `includeTags` / `excludeTags`: "Tags to include in the output" / "Tags to exclude from the output"
- Field measurement 2026-09-04 (30 Vietnamese company websites, static HTML vs rendered DOM): 16/30 sites carried their phone number only outside the main content (header, footer, floating widget); 22/30 exposed it as a `tel:` link; 0/30 gained a number after JavaScript rendering that the static HTML lacked
