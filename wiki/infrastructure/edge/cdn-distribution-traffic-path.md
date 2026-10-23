---
id: infrastructure-edge-cdn-distribution-traffic-path
domain: infrastructure
category: edge
applies_to: [aws, cloudfront, waf, general]
confidence: verified
sources:
  - https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistValuesGeneral.html
  - https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/restrict-access-to-load-balancer.html
  - https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/CNAMEs.html
  - https://docs.aws.amazon.com/vpc/latest/userguide/aws-ip-ranges.html
last_verified: 2026-10-23
related: [security-api-exposure-exposing-an-origin-http-api]
---

# Which CDN Distribution Actually Carries a Hostname's Traffic

## When this applies

An audit finding, alert, or ticket names CDN distributions by id (CloudFront `E…`)
and you must act on them — attach or change a WAF web ACL, cache policy, or
header policy — while the owning account/environment is unknown, or several
distributions look alike in the console ("all three have WAF attached").

## Do this

1. **Find the owner by listing, not by guessing.** Run the distribution list in
   every candidate account/profile in parallel and match the id
   (`aws cloudfront list-distributions --query "DistributionList.Items[?Id=='E…']"`).
   Record per distribution: account, `Enabled`, aliases (CNAMEs), origin domain,
   attached web ACL.
2. **Measure the path for each alias the distribution claims.** Configuration
   says what *could* serve traffic; DNS and the response say what *does*:

   ```sh
   dig +short app.example.com
   curl -sS -o /dev/null -D - -w 'remote_ip=%{remote_ip}\n' https://app.example.com/ \
     | grep -iE '^(via|x-amz-cf-pop|x-cache)|remote_ip'
   ```

3. **Classify, then act only on the distributions that carry traffic.**

| Observation | The distribution is | Do |
|-------------|---------------------|----|
| `Via: … .cloudfront.net (CloudFront)` and an `X-Amz-Cf-Pop` header (resolved IP in `ip-ranges.json` service `CLOUDFRONT`), **and** this distribution holds the most specific alias matching the hostname across every distribution you listed | On the path | Apply the change here; it governs real traffic. The headers alone prove only that *some* CloudFront distribution answered |
| No CloudFront headers; resolved IP belongs to the origin (load balancer, instance) | Bypassed — DNS points at the origin | A WAF on this distribution filters nothing. Fix the DNS or restrict the origin; changing the distribution alone changes no traffic |
| `Enabled` is `false` | Disabled — "CloudFront doesn't accept any end-user requests" for it | Record it as an orphan; exclude it from traffic-facing changes and decide separately whether to delete it |
| No alias, only the `*.cloudfront.net` domain | Reachable only by that domain | Search code/config for the `d….cloudfront.net` host before deciding it is unused |

4. **Report each distribution with its measured class**, not as a group. Three
   distributions with identical settings can be one live path, one bypassed
   path, and one disabled orphan.

## Edge cases

| Case | Then |
|------|------|
| The origin is an internet-facing load balancer that is also reachable directly | The edge WAF is bypassable even for the live distribution; AWS's mitigation is a secret custom header that the load balancer requires (or a VPC origin) — route that fix to [security-api-exposure-exposing-an-origin-http-api] |
| A wildcard alias (`*.example.com`) on one distribution and a specific alias (`app.example.com`) on another | CloudFront serves the request from the distribution with the more specific match "regardless of the distribution that the DNS record points to" — classify by the alias match, not by the CNAME target |
| The hostname resolves through a CNAME chain or a third-party DNS/CDN | Follow the chain to the last answer before classifying; the final address decides the path |
| Split-horizon DNS (corporate resolver vs public) | Resolve from the client population that matters (public resolver for public traffic) and note which resolver you used |
| The account cannot be determined from any profile you hold | Stop at the measured class and hand the id plus the measurement to the account owner; do not apply changes from a guessed account |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Apply one WAF/cache change to every distribution "in front of" a service | Classify each by DNS + response headers first | A bypassed or disabled distribution makes the change a no-op that reads as protection |
| Conclude "protected" because a web ACL is attached | Confirm the hostname's traffic passes that distribution | The ACL only inspects requests that reach CloudFront |

## Sources

- https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistValuesGeneral.html — Distribution state: "Whenever a distribution is disabled, CloudFront doesn't accept any end-user requests that use the domain name associated with that distribution"
- https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/restrict-access-to-load-balancer.html — mitigations "to prevent users from directly accessing an Application Load Balancer, and allow access only through CloudFront": a custom HTTP header CloudFront adds, which the load balancer requires; APIs reached through the load balancer directly "bypass CloudFront"
- https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/CNAMEs.html — "If you have overlapping alternate domain names in two distributions, CloudFront sends the request to the distribution with the more specific name match, regardless of the distribution that the DNS record points to"
- https://docs.aws.amazon.com/vpc/latest/userguide/aws-ip-ranges.html — published `ip-ranges.json`; on 2026-10-23 it listed 214 prefixes with service `CLOUDFRONT`
- Header check 2026-10-23: `curl -sI https://d1.awsstatic.com/` returned `Via: 1.1 <id>.cloudfront.net (CloudFront)`, `X-Cache: Hit from cloudfront`, `X-Amz-Cf-Pop: ICN80-P2`
- Field case 2026-10 (AWS audit of three distributions with web ACLs): one disabled distribution's hostname resolved to an `ap-southeast-1` load balancer address and returned no CloudFront headers, while the other two returned `X-Amz-Cf-Pop: ICN57-P6` / `ICN53-P1`; the planned change was needed on two of the three
