---
id: security-authz-resource-level-checks
domain: security
category: authz
applies_to: [general]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html
  - https://cheatsheetseries.owasp.org/cheatsheets/Insecure_Direct_Object_Reference_Prevention_Cheat_Sheet.html
  - https://owasp.org/Top10/A01_2021-Broken_Access_Control/
last_verified: 2026-07-10
related: [security-authn-session-vs-token, databases-schema-design-primary-key-choice]
---

# Authorizing Access to a Specific Resource (IDOR)

## When this applies

An endpoint reads or writes a resource identified by an id taken from the request
(path, query, or body), or you are designing permission checks. Authentication says
**who** the caller is; this page decides **whether this user may act on this
resource**.

## Do this

1. **Two gates, both required**: a role/permission check gates the **action**
   ("may this user delete listings?"); an ownership/tenancy check gates the
   **object** ("is listing 42 theirs?"). Passing one does not imply the other.
2. **Put the ownership check in the query itself** whenever the resource carries
   an owner/tenant column: `WHERE id = :id AND owner_id = :current_user` (or
   `tenant_id = :tenant`). Zero rows = denied. A predicate in the data access
   holds on every call path, including ones added later; a controller guard holds
   only where someone remembered it. (Tenant-key placement: the multi-tenant rows
   in [databases-schema-design-primary-key-choice].)
3. **Treat every client-supplied id as hostile until the ownership check passes.**
   Sequential integer ids make enumeration trivial — an attacker iterates
   `/orders/1..n` (exposure rows in [databases-schema-design-primary-key-choice]).
4. **Pick one not-found policy and apply it uniformly**: return 404 for resources
   the user must not learn exist. A mixed scheme (403 for others' resources, 404
   for missing) confirms existence by the difference.
5. **Bulk/batch endpoints check every item id**, not just the first; define the
   contract for partial failure (reject-all or per-item result) and enforce it.

## Edge cases

| Case | Then |
|------|------|
| Admin/support role must act on any resource | An explicit role branch inside the authz check, with an audit log entry — the check runs and records, rather than being skipped |
| Nested resource (`/projects/:pid/tasks/:tid`) | Verify the chain: task belongs to project AND project belongs to user. Checking only the leaf lets a caller swap in another project's id |
| Shared/collaborative resources | A membership lookup replaces `owner_id` equality — still inside the query (`JOIN`/`EXISTS` on the membership table) |
| Response embeds related objects (includes/expansions) | Authorization applies to every object serialized, not only the root — apply the same tenancy filter to each included collection |
| "Ids are unguessable UUIDs, so no check needed" | Unguessable is not authorized: ids leak through logs, referrers, exports, and shared links — run the ownership check regardless |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Hide buttons/routes in the UI as the authorization | Server-side check on every request; the UI is advisory | An attacker calls the API directly with any id |
| Rely on a controller-level "logged in + has role" guard alone | Add the per-resource ownership/tenancy predicate in the data access | The role gates the action; it says nothing about this object |
| Return 403 for others' resources and 404 for missing ones | One uniform 404 policy for both | Differential responses enumerate which ids exist |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html — enforce on every request, deny by default, least privilege
- https://cheatsheetseries.owasp.org/cheatsheets/Insecure_Direct_Object_Reference_Prevention_Cheat_Sheet.html — per-object access checks, id handling
- https://owasp.org/Top10/A01_2021-Broken_Access_Control/ — broken access control as the top web risk; IDOR patterns
