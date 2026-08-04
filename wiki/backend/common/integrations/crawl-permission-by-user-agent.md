---
id: backend-common-integrations-crawl-permission-by-user-agent
domain: backend
category: integrations
applies_to: [general]
confidence: verified
sources:
  - https://www.rfc-editor.org/rfc/rfc9309.html
  - https://www.i-sh.co.kr/robots.txt
  - https://housing.seoul.go.kr/robots.txt
  - https://apply.gh.or.kr/robots.txt
last_verified: 2026-08-04
related: [backend-common-integrations-externally-owned-defaults, backend-common-reliability-timeouts-and-retries]
---

# Deciding Whether robots.txt Permits the Crawler You Are About to Write

## When this applies

You are about to fetch a site's pages programmatically and are reading its
`robots.txt` to decide whether that is permitted; or you are choosing among
several sites that publish the same records; or a `Disallow: /` in a target's
`robots.txt` is about to end the project.

## Do this

1. **Attribute every rule to its `User-agent` group before drawing any
   conclusion.** A `robots.txt` is a sequence of groups, not a flat list. A
   crawler matches the group whose product token equals its own (case-insensitive);
   only when no group matches its token does it obey the `*` group (RFC 9309
   §2.2.1). A `Disallow: /` sitting under `User-agent: GPTBot` constrains GPTBot
   and says nothing about your crawler.
2. **Resolve the group against the User-Agent you will actually send.** HTTP
   client library names appear as product tokens in real files, so an unset UA can
   put you in a blanket-denied group that a named UA would never match.
3. **Decide from the response status, not the body:**

| robots.txt response | Then |
|---------------------|------|
| 2xx with a parseable body | Follow the matching group's rules (§2.3.1.1) |
| 3xx, resolving within five hops | Fetch, parse, and apply the rules in the context of the original authority (§2.3.1.2) |
| 4xx — including 404 and 410, whatever the body renders as | The file is *unavailable*: the crawler MAY access any resource on the server (§2.3.1.3) |
| 5xx | The file is *undefined*: assume complete disallow (§2.3.1.4). After a long outage (the RFC's example is 30 days) treat it as unavailable or keep using a cached copy |

4. **When the group that matches you really is `Disallow: /`, enumerate other
   publishers of the same records before concluding the data is unreachable.**
   Public-sector notices are routinely republished by a parent authority or an
   umbrella portal whose `robots.txt` is permissive, and the republished page is
   often the easier target (server-rendered tables, stable per-record ids).
5. **Store the decision with the scraper**: the `robots.txt` URL, the fetch date,
   the group your UA matched, and the verbatim rules of that group. Re-fetch
   rather than trusting a cached copy older than 24 hours (§2.5).

## Edge cases

| Case | Then |
|------|------|
| `robots.txt` returns an HTML error page | The status code decides, not the rendered body — a styled "410 Gone" page is a 4xx *unavailable*, not a disallow |
| More than one group matches your product token | Combine the matching groups' rules into one group and parse that (§2.2.1) |
| The file names your HTTP client's default UA (`aiohttp`, `python-requests`, `curl`) with `Disallow: /` | You are in that group until you set a UA; pick a UA that identifies your crawler and re-resolve which group applies |
| The permissive republisher carries the same records but different field names | Treat it as a distinct external source and validate its shape at the boundary rather than assuming parity with the origin site |
| `robots.txt` permits the path | It settles crawler policy only; site terms of service, personal-data rules, and request-rate courtesy are separate controls that still apply |
| The permissive source is a default you did not choose (an inherited config or a teammate's constant) | Re-verify it still resolves the way the code assumes ([backend-common-integrations-externally-owned-defaults]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude "scraping is blocked" from a `Disallow: /` seen anywhere in the file | Find the `User-agent` line that opens that group and check whether it matches your product token | Most `Disallow: /` lines in the wild sit in named-bot groups; a crawler that matches no named group falls through to `*` |
| Read `robots.txt` in a browser and judge by what renders | Record the HTTP status code and the raw body | 4xx and 5xx have opposite normative meanings, and both can render as readable HTML |
| Ship a scraper with whatever UA the HTTP library defaults to | Set an explicit UA and re-check which group it matches | Client library tokens appear in real `robots.txt` files, so the default UA can select a denied group |
| Drop a data source because the issuing agency's site denies your crawler | Check the parent authority's or umbrella portal's site for the same records | Agency sites and the portals that republish them are separate authorities with independently authored `robots.txt` |

## Sources

- https://www.rfc-editor.org/rfc/rfc9309.html — §2.2.1: "Crawlers MUST use case-insensitive matching to find the group that matches the product token"; "If there is more than one group matching the user-agent, the matching groups' rules MUST be combined into one group"; "If no matching group exists, crawlers MUST obey the group with a user-agent line with the \"*\" value, if present". §2.3.1.1–2.3.1.4: successful access, five-redirect rule, 4xx "the crawler MAY access any resources on the server", 5xx "the robots.txt file is undefined and the crawler MUST assume complete disallow" with the ~30-day relaxation. §2.5: "Crawlers SHOULD NOT use the cached version for more than 24 hours"
- https://www.i-sh.co.kr/robots.txt — fetched 2026-08-04, HTTP 200, 64 lines: the `User-agent: *` group disallows only specific path prefixes (`/admin`, `/upload`, `/gcms/brd`, …) and carries **no** blanket `Disallow: /`; the thirteen `Disallow: /` lines each belong to a named group (`GPTBot`, `ChatGPT-User`, `facebookexternalhit`, `BaiDuSpider`, `MJ12bot`, `OAI-SearchBot`, `PerplexityBot`, `Google-Extended`, `ClaudeBot`, `Claude-SearchBot`, `meta-externalAgent`, `Applebot-Extended`, `CCBot`, `aiohttp`, `DuckDuckBot`) — the `aiohttp` entry is a client-library default UA
- https://housing.seoul.go.kr/robots.txt — fetched 2026-08-04, HTTP 200 `text/plain`: `User-agent: *` / `Allow: /` — the umbrella portal republishing the same housing notices is permissive where a per-agency site need not be
- https://apply.gh.or.kr/robots.txt — fetched 2026-08-04, HTTP 200 `text/plain`: `User-agent: *` / `Allow: /*`, while `https://www.gh.or.kr/robots.txt` returns HTTP 410 with an HTML body — i.e. *unavailable* under §2.3.1.3, not a disallow
