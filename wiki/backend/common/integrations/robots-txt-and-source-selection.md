---
id: backend-common-integrations-robots-txt-and-source-selection
domain: backend
category: integrations
applies_to: [general]
confidence: verified
sources:
  - https://www.rfc-editor.org/rfc/rfc9309.html
  - https://docs.aiohttp.org/en/stable/client_reference.html
  - https://www.i-sh.co.kr/robots.txt
  - https://housing.seoul.go.kr/robots.txt
  - https://apply.gh.or.kr/robots.txt
last_verified: 2026-08-05
related: [backend-common-integrations-externally-owned-defaults, backend-common-reliability-timeouts-and-retries, qa-environments-headless-browser-bot-blocking]
---

# Choosing a Source to Crawl by Reading robots.txt

## When this applies

You are picking which site to fetch a published dataset from (notices, listings,
filings, prices) and are reading its `/robots.txt` to decide whether your client
may crawl it. Also when a file you read as a blanket refusal contains a
`Disallow: /`, or when you are choosing among several sites that publish the same
records.

## Do this

1. **Attribute every rule to its `User-agent` group before drawing any
   conclusion.** A `robots.txt` is a sequence of groups, not a flat list. RFC
   9309 §2.2.1: "Crawlers MUST use case-insensitive matching to find the group
   that matches the product token"; only when no group matches its token does it
   obey the `*` group. A `Disallow: /` sitting under `User-agent: GPTBot`
   constrains GPTBot and says nothing about your crawler.

2. **Resolve your matching group by the User-Agent you will actually send.** HTTP
   client library names appear as product tokens in real files, so an unset UA can
   put you in a blanket-denied group that a named UA would never match.

3. **Branch on the response status, not just the body:**

| robots.txt response | Do |
|---------------------|-----|
| 2xx with a parseable body | Follow the rules of your matching group (RFC 9309 §2.3.1.1) |
| 3xx | Follow up to five consecutive redirects; past five, treat the file as unavailable (§2.3.1.2) |
| 4xx (404, 410, and the rest) | Treat the file as unavailable — the crawler "MAY access any resources on the server" (§2.3.1.3) |
| 5xx, connection or DNS failure | Assume complete disallow while the failure persists (§2.3.1.4) |
| 5xx continuing past ~30 days | Treat as unavailable (4xx handling) |

4. **When your matching group disallows the path, enumerate the other publishers
   of the same records before concluding the data is unreachable.** Public-sector
   notices are routinely republished by a parent authority or an umbrella portal
   whose `robots.txt` is permissive, and the republished page is often the easier
   target (server-rendered tables, stable per-record ids). The source organization
   and the portal that republishes its records are separate authorities with
   separate `robots.txt` files.

5. **Apply the most-specific-match rule inside the chosen group**: "The most
   specific match is the match that has the most octets", and an `allow` that ties
   a `disallow` wins (RFC 9309 §2.2.2).

6. **Re-fetch robots.txt at least daily.** Crawlers "SHOULD NOT use the cached
   version for more than 24 hours" (RFC 9309 §2.5), so a long-running collector
   re-reads before each run rather than pinning a value read at deployment.

7. **Settle the terms-of-service and licensing question separately.** robots.txt
   states crawler access rules; record which document grants you the right to
   store and redistribute the content, and cite it next to the source config.

## Edge cases

| Case | Then |
|------|------|
| The subdomain differs from the marketing site (`apply.`, `housing.`, `open.`) | Fetch each host's own robots.txt — the file is per-authority (scheme, host, port), so a sibling host's rules say nothing about this one |
| Your matching group is a named block and the `*` group is open | Follow your named group; the specific match is what RFC 9309 requires you to obey |
| More than one group matches your product token | Combine the matching groups' rules into one group and parse that (§2.2.1) |
| The site publishes an official API or bulk download for the same records | Take that path and record it in the source config; it removes the crawl question entirely |
| The permitted portal renders the table server-side with a stable detail id | Key your stored records on that id, so re-collection is idempotent rather than position-based |
| robots.txt is unreachable intermittently | Hold the previous rules and retry with backoff ([backend-common-reliability-timeouts-and-retries]); treat a sustained failure as complete disallow |
| The permitted portal's default is one your repo does not own (host, path, id scheme) | Add a startup check that the source still resolves and still returns the expected shape ([backend-common-integrations-externally-owned-defaults]) |
| `robots.txt` returns an HTML error page | The status code decides, not the rendered body — a styled "410 Gone" page is a 4xx *unavailable*, not a disallow |
| The permissive republisher carries the same records but different field names | Treat it as a distinct external source and validate its shape at the boundary rather than assuming parity with the origin site |
| `robots.txt` permits the path | It settles crawler policy only; site terms of service, personal-data rules, and request-rate courtesy are separate controls that still apply |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude "scraping is blocked" from a `Disallow: /` seen anywhere in the file | Find the `User-agent` line that opens that group and check whether it matches your product token | Most `Disallow: /` lines in the wild sit in named-bot groups; a crawler that matches no named group falls through to `*` |
| Read `robots.txt` in a browser and judge by what renders | Record the HTTP status code and the raw body | 4xx and 5xx have opposite normative meanings, and both can render as readable HTML |
| Ship a scraper with whatever UA the HTTP library defaults to | Set an explicit UA and re-check which group it matches | Client library tokens appear in real `robots.txt` files, so the default UA can select a denied group |
| Drop a data source because the issuing agency's site denies your crawler | Check the parent authority's or umbrella portal's site for the same records | Agency sites and the portals that republish them are separate authorities with independently authored `robots.txt` |

## Sources

- https://www.rfc-editor.org/rfc/rfc9309.html — §2.2.1: "Crawlers MUST use case-insensitive matching to find the group that matches the product token"; "If there is more than one group matching the user-agent, the matching groups' rules MUST be combined into one group"; "If no matching group exists, crawlers MUST obey the group with a user-agent line with the \"*\" value, if present". §2.2.2: most-specific-match rule. §2.3.1.1–2.3.1.4: successful access, five-redirect rule, 4xx "the crawler MAY access any resources on the server", 5xx "the robots.txt file is undefined and the crawler MUST assume complete disallow". §2.5: "Crawlers SHOULD NOT use the cached version for more than 24 hours"
- https://www.i-sh.co.kr/robots.txt — fetched 2026-08-05, HTTP 200, 64 lines: the `User-agent: *` group disallows only specific path prefixes and carries **no** blanket `Disallow: /`; the thirteen `Disallow: /` lines each belong to a named group (`GPTBot`, `ChatGPT-User`, `facebookexternalhit`, `aiohttp`, `DuckDuckBot`, etc.) — the `aiohttp` entry is a client-library default UA
- https://housing.seoul.go.kr/robots.txt — fetched 2026-08-05, HTTP 200: `User-agent: *` / `Allow: /` — the umbrella portal republishing housing notices is permissive where a per-agency site need not be
- https://apply.gh.or.kr/robots.txt — fetched 2026-08-05, HTTP 200: `User-agent: *` / `Allow: /*`, while the agency's main site returns HTTP 410 — i.e. *unavailable* under §2.3.1.3, not a disallow
