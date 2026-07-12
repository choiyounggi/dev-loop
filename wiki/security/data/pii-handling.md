---
id: security-data-pii-handling
domain: security
category: data
applies_to: [general]
confidence: verified
sources:
  - https://gdpr-info.eu/art-5-gdpr/
  - https://gdpr-info.eu/art-17-gdpr/
  - https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
last_verified: 2026-07-10
related: [databases-schema-design-soft-delete]
---

# Handling Personal Data (PII) in a Feature

## When this applies

A feature stores or processes personal data — emails, names, phones, addresses,
government ids — or you are reviewing a log, analytics, export, or URL path
that can carry it.

## Do this

1. **Collect the minimum that serves the feature** (data minimization, GDPR
   Art. 5). A field you don't store cannot leak and never needs erasure.
2. **Classify at design time**: mark which columns are PII where the schema lives
   (column comment or data catalog), so every later log/export/analytics change
   can check the classification instead of guessing.
3. Keep PII out of side channels:

| Path | Do |
|------|----|
| Logs | Mask/redact at the logger layer (one central serializer/filter), not at each call site — one miss at a call site is a leak; the central filter catches new code too. Pipeline mechanics: wiki/infrastructure/ (observability) |
| URLs (query/path) | Carry PII in the request body or a header — URLs persist in access logs, browser history, and referrer headers |
| Analytics events | Exclude PII by default; include a field only when a documented contract requires it, checked against the classification |

4. **Encryption**: in transit always (TLS). At rest: full-disk/database-level
   encryption as the baseline for all PII; column-level (application-layer)
   encryption additionally for high-sensitivity fields — government ids,
   financial and health data.
5. **Retention is designed with the table**: every PII table/column gets a
   retention rule and a scheduled deletion job. Soft delete does not satisfy
   erasure (GDPR Art. 17) — hard-delete or anonymize, per the GDPR edge row in
   [databases-schema-design-soft-delete].
6. **Test fixtures and staging use synthetic data.** When realistic shape/volume
   is required, build a masking + subsetting pipeline from prod; raw prod copies
   stay in prod.

## Edge cases

| Case | Then |
|------|------|
| Deleted PII persists in backups | Bound it: the backup retention window is part of your erasure window — document that erasure completes when the last backup containing the row expires |
| Erasure request, but the row anchors legal/financial records | Anonymize instead of delete: null or hash the PII columns, keep the transactional facts — the record survives, the person is no longer identifiable |
| Analytics needs per-user deduplication | Use an opaque pseudonymous id whose mapping lives in one access-controlled table — never the email/phone itself |
| Derived stores built from PII (search indexes, caches, ML features, exports) | Register them under the same classification and wire them into the deletion job — erasure covers derived copies, not just the source row |
| PII inside error reports / crash dumps sent to third-party tools | Apply the same logger-layer scrubbing to the error-reporting SDK's payload hooks before sending |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Copy prod data to staging for realistic testing | Masked subset pipeline or synthetic factories | Staging has weaker access control; every copy is another breach surface and erasure target |
| Log full request/response bodies while debugging | Log ids and non-PII fields; look up details in the DB during investigation | Bodies carry emails/addresses into log retention and third-party log tooling |
| Satisfy an erasure request with `deleted_at` | Hard-delete or anonymize via the retention job | Soft-deleted PII is still stored personal data ([databases-schema-design-soft-delete]) |

## Sources

- https://gdpr-info.eu/art-5-gdpr/ — data minimization and storage limitation principles
- https://gdpr-info.eu/art-17-gdpr/ — right to erasure; erasure must actually remove personal data
- https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html — exclude/mask sensitive data in logs at the framework level
