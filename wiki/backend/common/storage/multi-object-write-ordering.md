---
id: backend-common-storage-multi-object-write-ordering
domain: backend
category: storage
applies_to: [general, aws-s3]
confidence: verified
sources:
  - https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html
  - https://man7.org/linux/man-pages/man2/rename.2.html
last_verified: 2026-08-14
related: [backend-common-storage-object-key-persistence, backend-common-jobs-idempotent-handlers, backend-common-concurrency-distributed-locks]
---

# Writing Two or More Objects With No Transaction Around Them

## When this applies

A change writes two or more related objects (files, blobs, S3 keys) with no
transaction wrapping the writes — a payload plus its checksum/manifest, a data file
plus an index entry, a new version plus the pointer that marks it current. Also when
reviewing such a diff: ask what a concurrent reader sees between the two writes, and
what a crash between them leaves behind.

## Do this

Object storage gives per-key atomicity only: S3 offers "strong read-after-write
consistency for PUT and DELETE requests," but "updates are key-based... there is no
way to make atomic updates across keys" (AWS S3 docs) — every row below is a way to
make a reader's observable state single-key despite that.

| Case | Reader outcome it guarantees |
|------|-------------------------------|
| Write-then-publish via a pointer flipped last | Write both objects under new/unpublished names first, then atomically flip a single pointer (a `rename(2)` on the filesystem, or a single-key overwrite PUT) to the version that's complete. `rename()` "will be atomically replaced, so that there is no point at which another process... will find it missing" (POSIX/Linux `rename(2)`) — readers see either the fully-old or fully-new pair, never a mix |
| Writing the dependent object first | Write the object nothing else references yet (the checksum, the index entry) before the object readers actually discover (the payload, the listing). A reader that finds the referencing object can assume its dependency already exists; one that finds only the dependency has evidence of an in-progress write, not corruption |
| A single object carrying both payload and checksum | Fold the pair into one PUT (checksum in metadata/header, or in the same body) so there is only one key and S3's per-key read-after-write consistency is the whole guarantee — no ordering decision left to get wrong |
| Serialising the writers | When neither object can safely be ordered relative to the other (both are independently discoverable, both are mutated in place), make writers mutually exclusive instead of ordering their writes — [backend-common-concurrency-distributed-locks] owns the owner-token/TTL/fencing mechanics |

## Edge cases

| Case | Then |
|------|------|
| Crash in the gap between the two writes | With write-then-publish, a crash before the pointer flip leaves only unpublished/orphaned objects — no reader ever observed them, so the fix is a cleanup sweep for orphans, not a data-consistency incident. Without a pointer scheme, a crash between the two writes leaves a **permanent** half-state; nothing re-runs it unless something else does (see retries, below) |
| A fail-closed reader vs a fail-open reader hits the half-state | Fail-closed (verify the checksum/companion object exists before trusting the payload) turns a partial write into a visible outage for every request in the gap; fail-open (serve the payload regardless) turns it into silently unverified/corrupt data reaching a caller. Choose per how expensive each direction is — and state the choice in the page/runbook, since the two failure modes are opposite in cost |
| A retry re-runs the pair | Re-running the same two writes must be idempotent: writing the dependent object first is naturally repeatable, but a retry after a *partial* prior attempt (dependent object written, payload write crashed) must still converge — dedupe by a deterministic key derived from the job/request, the same shape as queue-consumer idempotency ([backend-common-jobs-idempotent-handlers]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write the payload, then write its checksum as a second, independent step | Write the checksum (or the dependent object) first, or flip a single pointer last | A reader racing the two writes should never be able to see the referencing object before its dependency exists |
| Rely on "the writes usually land together" | Pick one row above and name the reader guarantee it gives | "Usually" is exactly the gap a concurrent reader or a crash finds |
| Reach for a distributed lock as the default fix | Reach for ordering (pointer-flip, dependent-first, single-object) first; lock only when neither object can be safely ordered | Ordering has no lock-store dependency and no TTL/fencing to get wrong; a lock is the fallback, not the default |

## Sources

- https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html#ConsistencyModel — "Amazon S3 provides strong read-after-write consistency for PUT and DELETE requests of objects... in all AWS Regions"; and "Updates are key-based. There is no way to make atomic updates across keys" — the per-key guarantee this page's patterns build on, and the exact gap they close
- https://man7.org/linux/man-pages/man2/rename.2.html — "If newpath already exists, it will be atomically replaced, so that there is no point at which another process attempting to access newpath will find it missing" — the atomic-pointer-flip mechanism for the filesystem variant
