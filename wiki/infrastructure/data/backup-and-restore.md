---
id: infrastructure-data-backup-and-restore
domain: infrastructure
category: data
applies_to: [general]
confidence: field-tested
sources:
  - https://sre.google/sre-book/data-integrity/
  - https://docs.aws.amazon.com/prescriptive-guidance/latest/backup-recovery/design.html
  - https://www.postgresql.org/docs/current/continuous-archiving.html
last_verified: 2026-07-10
related: [infrastructure-observability-alerting, infrastructure-ci-cd-secrets-handling]
---

# Backups That Restore — Data-Loss Readiness for a Datastore

## When this applies

Setting up backups for a datastore; auditing existing backups; planning for
data-loss scenarios: accidental deletion, corruption, a bad migration,
ransomware/account compromise, or region loss.

## Do this

1. Define RPO and RTO per datastore BEFORE choosing tooling — they are the
   requirements the tooling must meet:
   - RPO (acceptable data-loss window) drives backup frequency and whether
     you need WAL/binlog archiving for point-in-time recovery (PITR).
   - RTO (acceptable downtime) drives the restore mechanism and is the
     pass/fail target for restore drills.
2. Cover each threat explicitly — one snapshot schedule does not cover them all:

| Threat | Protection |
|--------|-----------|
| Operator error / bad migration (the most common data loss) | PITR (WAL/binlog archiving) that can reach a moment BEFORE the mistake; retention longer than your worst-case time-to-notice |
| Infrastructure loss (disk, AZ, region) | Offsite/cross-region backup copies |
| Ransomware / account compromise | At least one copy immutable or offline, stored under a separate account with separate credentials — an account that can delete prd data can delete every backup reachable with the same credentials (credential separation: [infrastructure-ci-cd-secrets-handling]) |

3. A backup you have not restored is a hope, not a backup. Run restore
   drills at a fixed cadence: restore into a scratch environment, verify data
   integrity (row counts, spot checks, application boots against it), and
   record the wall-clock time against RTO.
4. Monitor backup jobs like production: alert on failure AND on absence
   ("no successful backup within its window") — a silently stopped backup
   cron is the classic discovery-during-restore disaster. Absence alerting:
   [infrastructure-observability-alerting].
5. Back up the restore KNOWLEDGE too: a runbook with the exact restore
   commands, executed during each drill by someone other than its author.
6. Scope the backup set beyond the application datastore: include the config
   and state needed to rebuild the system around it — schema migrations,
   infrastructure definitions, restore credentials' location.
7. Replication is NOT backup. A replica replicates the DELETE and the
   corruption within seconds — replicas serve availability, backups serve
   history. Keep both; they answer different failures.

## Edge cases

| Case | Then |
|------|------|
| HA replicas exist and backups are questioned as redundant | Keep both: replication answers "a node died", backup answers "the data was wrong or deleted" |
| Managed datastore with provider-run snapshots | Provider snapshots cover infrastructure loss only; verify the PITR window covers your RPO, add the immutable/offline copy, and drill the restore yourself — the drill obligation does not transfer to the provider |
| Drill restore time exceeds RTO | Change the mechanism (warm standby, more frequent base backups, faster storage) or get the RTO renegotiated with its owner — record whichever happened |
| Datastore too large for a full-restore drill every cycle | Drill a full restore at a fixed lower cadence and a subset/single-table restore every cycle; the full path must still be exercised on the calendar, not "eventually" |
| Data deleted by an application bug discovered weeks later | This is the retention case: keep PITR/backup retention longer than worst-case time-to-notice, and verify the oldest retained backup still restores |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Call "we have daily snapshots" the whole strategy | State RPO/RTO per datastore, drill restores on a cadence, alert on backup absence, keep one immutable copy | Snapshots without a restore proof fail exactly at discovery time, and daily granularity may miss the stated RPO |
| Count replicas/HA as the backup | Replicas for availability; PITR-capable backups for history | Replication propagates deletion and corruption to every replica within seconds |
| Store backups under the same account/credentials as prd | Separate account and credentials for backup storage, with delete protection or immutability | A prd compromise otherwise deletes the backups in the same session |
| Keep restore steps in the author's head | Written runbook, executed by a non-author during each drill | The author is the person guaranteed to be unavailable during some incident |

## Sources

- https://sre.google/sre-book/data-integrity/ — "no one wants backups; they want restores"; recovery must be continuously tested; replication/redundancy is not recoverability; defense in depth across failure modes
- https://docs.aws.amazon.com/prescriptive-guidance/latest/backup-recovery/design.html — RPO/RTO as the requirements that backup and recovery design must meet
- https://www.postgresql.org/docs/current/continuous-archiving.html — WAL archiving and point-in-time recovery to an arbitrary moment
