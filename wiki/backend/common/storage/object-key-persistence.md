---
id: backend-common-storage-object-key-persistence
domain: backend
category: storage
applies_to: [aws-s3, aws-sdk-js-v2, aws-sdk-js-v3]
confidence: verified
sources:
  - https://docs.aws.amazon.com/AmazonS3/latest/API/API_CompleteMultipartUpload.html
  - https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3/ManagedUpload.html
  - https://github.com/aws/aws-sdk-js/blob/master/lib/s3/managed_upload.js
  - https://github.com/aws/aws-sdk-js/issues/1158
  - https://github.com/aws/aws-sdk-js-v3/issues/5656
last_verified: 2026-07-30
related: [backend-common-api-design-idempotency, backend-node-boundaries-runtime-validation]
---

# Persisting the Result of an Object-Storage Upload

## When this applies

You are writing the result of a managed/multipart object-storage upload
(`s3.upload()`, `@aws-sdk/lib-storage` `Upload`, an equivalent transfer manager)
into a database column, a message, or any store read back later — and you are
choosing which response field to persist.

## Do this

1. **Persist the raw object key (`Key`) plus the bucket, and derive URLs at read
   time.** `Key` is the field the service documents as "the object key of the
   newly created object" and is what every later call (`GetObject`,
   `getSignedUrl`, `HeadObject`, delete) takes as input.
2. **Treat `Location` as display-only.** Its encoding and host are not a
   documented contract, and the value comes from a different producer on each
   upload path:

| Upload path | Taken when | Who produces `Location` | Observed form |
|-------------|------------|-------------------------|---------------|
| Single part (`PutObject`) | Body ≤ the managed uploader's part size — 5 MiB (5,242,880 B) by default in aws-sdk-js | The SDK, joining `protocol + host + httpRequest.path` | Path-style percent-encoding: space → `%20` |
| Multipart (`CompleteMultipartUpload`) | Body over that threshold | The S3 response, passed through after the SDK rewrites `%2F` back to `/` | Service encoding with only slashes repaired: space → `+` survives |

3. **Build the read path from `Key`.** Sign or fetch with the stored key exactly
   as stored; apply no decode step. A stored key needs no repair, so no decode
   rule has to be guessed later.
4. **When a column already holds URLs, migrate by extracting the key** — reverse
   both encodings by upload size, verify each candidate with `HeadObject`, and
   write `Key` back. Add the `Key` column before the code switch so old and new
   rows are both readable ([backend-common-api-design-idempotency] for the
   backfill's retry behavior).

## Edge cases

| Case | Then |
|------|------|
| A CDN or custom domain fronts the bucket | Store `Key` and compose `cdnBase + encodeURI(key)` at read time; in aws-sdk-js-v3 the multipart path returns the origin host in `Location` while the single-part path returns the custom domain (issue #5656) |
| The key contains `+` as a literal character | Storing `Key` keeps it literal; a URL round-trip cannot distinguish it from an encoded space, which is why the encoded form is not a safe identifier |
| A bug report says "only large files 404" | Read it as the single-part/multipart split, not as intermittency: the threshold is a deterministic byte boundary, so reproduce at part-size ± 1 byte |
| Only `Location` was ever stored and the objects must be found now | Try both decodings per row (`+` → space and `+` literal), confirm with `HeadObject`, and record which rows stayed ambiguous |
| `partSize` is configured above the default | The boundary moves to that value; read it from the uploader config rather than assuming 5 MiB |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Save `uploadRes.Location` as the object's identifier | Save `uploadRes.Key` (with `Bucket`) and build URLs on read | `Location` is produced by two different code paths with two different encodings, so one column ends up holding both |
| Add a `decodeURIComponent` on read to fix the broken rows | Store the raw key so the read path needs no decode | Standard URL decoding leaves `+` as a literal, so it repairs the single-part rows and leaves the multipart rows 404-ing |
| Chase the mismatch as a nondeterministic uploader bug | Compare file sizes against the uploader's part size and reproduce at the boundary | The behaviour is decided by one byte-size comparison; naming it "intermittent" sends the fix to the upload layer instead of the persistence layer |
| Normalize the encoding inside the upload wrapper | Change what the caller persists | The wrapper cannot fix rows already written, and the service keeps returning its own `Location` regardless |

## Sources

- https://docs.aws.amazon.com/AmazonS3/latest/API/API_CompleteMultipartUpload.html — response elements: `Key` is "the object key of the newly created object"; `Location` is documented only as "the URI that identifies the newly created object", with no encoding guarantee
- https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3/ManagedUpload.html — callback data carries `Location`, `ETag`, `Bucket`, `Key`; `AWS.S3.ManagedUpload.minPartSize = 1024 * 1024 * 5` and the default `partSize` is 5 MB
- https://github.com/aws/aws-sdk-js/blob/master/lib/s3/managed_upload.js — `finishSinglePart` builds `data.Location` from `endpoint.protocol + '//' + endpoint.host + httpReq.path` and sets `data.Key` from `params.Key`; `finishMultiPart` takes the service's `Location` and applies only `.replace(/%2F/g, '/')`
- https://github.com/aws/aws-sdk-js/issues/1158 — reported inconsistency: multipart returns `…/stream-uploads%2Fkokoko.gif` where single-part returns `…/stream-uploads/kokoko.gif`; `Key` is identical in both responses
- https://github.com/aws/aws-sdk-js-v3/issues/5656 — same split in v3 `lib-storage`: `__uploadUsingPut` constructs `Location` client-side, `CompleteMultipartUploadCommand` does not
