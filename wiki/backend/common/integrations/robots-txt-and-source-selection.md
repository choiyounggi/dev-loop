---
id: backend-common-integrations-robots-txt-and-source-selection
domain: backend
category: integrations
applies_to: [general]
confidence: verified
sources:
  - https://www.rfc-editor.org/rfc/rfc9309.html
  - https://docs.aiohttp.org/en/stable/client_reference.html
last_verified: 2026-08-04
related: [backend-common-integrations-externally-owned-defaults, backend-common-reliability-timeouts-and-retries]
---

# Choosing a Source to Crawl by Reading robots.txt

## When this applies

You are picking which site to fetch a published dataset from (notices, listings,
filings, prices) and are reading its `/robots.txt` to decide whether your client
may crawl it. Also when a file you read as a blanket refusal contains a
`Disallow: /`, or when the file did not return 200.

## Do this

1. **Select the group whose product token matches your client, then obey only
   that group.** RFC 9309: "Crawlers MUST use case-insensitive matching to find
   the group that matches the product token and then obey the rules of the
   group"; the `*` group applies only "If no matching group exists". When several
   groups match your token, "the matching groups' rules MUST be combined into one
   group".
2. **Attribute every `Disallow: /` you see to the group it sits under before
   drawing a conclusion.** A file can leave `User-agent: *` open to everything
   except a few admin paths while giving named crawlers a full block. Read the
   file as a list of groups, not as a list of rules.
3. **Look up your own User-Agent string in the file.** The product token "should
   appear as a substring in the crawler's user-agent header", so a client running
   on its library's default UA carries that library's name as a token. Set an
   explicit User-Agent that identifies you and a contact, then search the file for
   that token as well as for your HTTP library's name.
4. **Branch on the response status, not just the body:**

| robots.txt response | Do |
|---------------------|-----|
| 2xx with a parseable body | Follow the rules of your matching group |
| 3xx | Follow up to five consecutive redirects; past five, treat the file as unavailable |
| 4xx (404, 410, and the rest) | Treat the file as unavailable — the crawler "MAY access any resources on the server" |
| 5xx, connection or DNS failure | Assume complete disallow while the failure persists |
| 5xx continuing past 30 days | Treat as unavailable (4xx handling) |

5. **When your matching group disallows the path, enumerate the other publishers
   of the same records before concluding the data is unreachable.** A source
   organization and the portal that republishes its records are separate
   authorities, so each serves its own robots.txt and the two can differ. Fetch
   the portal's file, match your token against it, and compare record identity
   (same notice id, same fields) before substituting one source for the other.
6. **Apply the most-specific-match rule inside the chosen group**: "The most
   specific match is the match that has the most octets", and an `allow` that ties
   a `disallow` wins.
7. **Re-fetch robots.txt at least daily.** Crawlers "SHOULD NOT use the cached
   version for more than 24 hours", so a long-running collector re-reads before
   each run rather than pinning a value read at deployment.
8. **Settle the terms-of-service and licensing question separately.** robots.txt
   states crawler access rules; record which document grants you the right to
   store and redistribute the content, and cite it next to the source config.

## Edge cases

| Case | Then |
|------|------|
| The subdomain differs from the marketing site (`apply.`, `housing.`, `open.`) | Fetch each host's own robots.txt — the file is per-authority (scheme, host, port), so a sibling host's rules say nothing about this one |
| Your matching group is a named block and the `*` group is open | Follow your named group; the specific match is what RFC 9309 requires you to obey |
| The site publishes an official API or bulk download for the same records | Take that path and record it in the source config; it removes the crawl question entirely |
| The permitted portal renders the table server-side with a stable detail id | Key your stored records on that id, so re-collection is idempotent rather than position-based |
| robots.txt is unreachable intermittently | Hold the previous rules and retry with backoff ([backend-common-reliability-timeouts-and-retries]); treat a sustained failure as complete disallow |
| The permitted portal's default is one your repo does not own (host, path, id scheme) | Add a startup check that the source still resolves and still returns the expected shape ([backend-common-integrations-externally-owned-defaults]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude "this site blocks crawling" from a `Disallow: /` seen anywhere in the file | Find the group your product token matches and read that group's rules | The blanket block frequently belongs to named AI/library crawler groups while `User-agent: *` is open except for a handful of admin paths |
| Ship a collector on its HTTP library's default User-Agent | Set an explicit UA naming your crawler and a contact, then check that token against the file | Sites publish groups naming library tokens; the library default can place you in a fully disallowed group you never looked for |
| Treat a 404 or 410 on robots.txt as a refusal | Treat 4xx as unavailable and proceed under the site's other terms | RFC 9309 assigns "MAY access any resources" to unavailable status; 5xx is the status that means complete disallow |
| Give up on a dataset because the originating agency's site restricts your token | Check the portals that republish the same records and compare record identity | Republishing portals exist to distribute the records and commonly permit what the origin restricts |

## Sources

- https://www.rfc-editor.org/rfc/rfc9309.html — group selection ("Crawlers MUST use case-insensitive matching to find the group that matches the product token and then obey the rules of the group"; `*` only "If no matching group exists"; "If there is more than one group matching the user-agent, the matching groups' rules MUST be combined into one group"); the product token contains "only uppercase and lowercase letters ('a-z' and 'A-Z'), underscores ('_'), and hyphens ('-')" and "should appear as a substring in the crawler's user-agent header"; access results ("If a server status code indicates that the robots.txt file is unavailable to the crawler, then the crawler MAY access any resources on the server"; unreachable "means the robots.txt file is undefined and the crawler MUST assume complete disallow"; five-redirect limit; 30-day rule); "The most specific match found MUST be used. The most specific match is the match that has the most octets"; "Crawlers SHOULD NOT use the cached version for more than 24 hours"
- https://docs.aiohttp.org/en/stable/client_reference.html — aiohttp autogenerates a `User-Agent` header when none is passed, so a client that sets no UA advertises the library name; `headers` on `ClientSession` sets an explicit one
- Live observation 2026-08-04 (Korean public-housing notices, fetched directly): `www.i-sh.co.kr/robots.txt` gives `User-agent: *` a path list only (`/admin`, `/cert`, `/upload`, `/gcms/brd`, per-district board paths) and reserves `Disallow: /` for named groups — `GPTBot`, `ChatGPT-User`, `facebookexternalhit`, `BaiDuSpider`, `MJ12bot`, `OAI-SearchBot`, `PerplexityBot`, `Google-Extended`, `ClaudeBot`, `Claude-SearchBot`, `meta-externalAgent`, `Applebot-Extended`, `CCBot`, `aiohttp`, `DuckDuckBot`. `housing.seoul.go.kr/robots.txt` is `User-agent: * / Allow: /` and republishes the same notices with a server-rendered table and a stable detail id; `apply.gh.or.kr/robots.txt` is `User-agent: * / Allow: /*`; `www.gh.or.kr/robots.txt` returns HTTP 410, which RFC 9309 classifies as unavailable rather than as a refusal
