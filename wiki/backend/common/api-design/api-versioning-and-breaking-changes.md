---
id: backend-common-api-design-api-versioning-and-breaking-changes
domain: backend
category: api-design
applies_to: [general]
confidence: verified
sources:
  - https://docs.stripe.com/api/versioning
  - https://docs.stripe.com/upgrades
  - https://datatracker.ietf.org/doc/html/rfc8594
last_verified: 2026-08-17
related: [backend-common-change-impact-call-site-enumeration]
---

# Versioning a Public API and Rolling Out Breaking Changes

## When this applies

An API has external callers you do not control (public API, mobile app in the
field, third-party integration) and you need to change its contract — add,
remove, rename, or retype a field or endpoint. Unlike
[backend-common-change-impact-call-site-enumeration] (internal callers you can
find and fix in the same change), an external caller cannot be enumerated or
force-updated, so the contract itself must carry the compatibility guarantee.

## Do this

| Change | Classification | Do |
|--------|-----------------|----|
| Add a new optional request parameter | Backward-compatible | Ship on the current version; no version bump needed |
| Add a new field to a response | Backward-compatible | Ship on the current version — callers must ignore unknown response fields (design new clients to tolerate unfamiliar fields from day one, not retrofit tolerance later) |
| Add a new endpoint or resource | Backward-compatible | Ship on the current version |
| Add a new event/webhook type | Backward-compatible | Ship on the current version — document that webhook consumers must not fail on an unrecognized event type |
| Remove or rename a field/endpoint; change a field's type or meaning; change validation to reject previously-valid input | Breaking | Requires a new API version; existing callers keep the old behavior until they explicitly opt in |
| Reordering fields in a response, or changing the length/format of opaque strings (IDs, error message text) | Backward-compatible | Ship on the current version — callers must not parse opaque strings positionally or assume a fixed length |

## Deciding how to version

| Choice | Do |
|--------|----|
| How clients select a version | Pick one mechanism and use it consistently: a request header (e.g. `Stripe-Version`) or a date/number embedded in the URL path. A header keeps the URL stable across versions; a path segment makes the version visible in logs/caches without inspecting headers |
| What a "version" identifies | A single version stamps the whole API's behavior for that request — not one flag per field. Stripe stamps every monthly release with the major version's name so a caller pinned to a version only ever receives backward-compatible additions until it explicitly upgrades |
| Deprecating an old version | Announce the deprecation and give a lead time before removal; send the `Sunset` HTTP header (RFC 8594) with the retirement date on responses from the version being retired, so client tooling can detect it without reading changelogs |

## Edge cases

| Case | Then |
|------|------|
| A field's value looks unchanged but the semantics changed (e.g. a status enum gains a new state the old client didn't expect) | Treat as breaking — the type is unchanged but the client's exhaustive switch/if-chain silently mishandles the new value; document new enum values as an explicit compatibility risk even though they are structurally additive |
| A caller needs to test a new version before committing | Support a rollback window (Stripe allows 72 hours) or a per-request version override, so an early adopter can revert without a second deployment |
| An internal caller and an external caller share the same endpoint | Version for the external caller's guarantee; the internal caller can be migrated directly at the call site instead ([backend-common-change-impact-call-site-enumeration]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Change a field's type/meaning on the existing version because "no one should be relying on that" | Ship the change under a new version and deprecate the old one with a `Sunset` date | You cannot enumerate external callers the way you can grep internal call sites — an assumption about who depends on a field is unverifiable |
| Remove an old API version the moment the new one ships | Keep both live through a deprecation window and signal it via the `Sunset` header | Callers need time to detect and act on the deprecation signal before the version actually stops responding |

## Sources

- https://docs.stripe.com/api/versioning — date-based versions, per-SDK version pinning, monthly vs major releases
- https://docs.stripe.com/upgrades — explicit backward-compatible change list, 72-hour rollback window
- https://datatracker.ietf.org/doc/html/rfc8594 — `Sunset` HTTP header field for signaling upcoming retirement
