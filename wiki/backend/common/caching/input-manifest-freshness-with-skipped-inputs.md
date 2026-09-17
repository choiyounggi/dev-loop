---
id: backend-common-caching-input-manifest-freshness-with-skipped-inputs
domain: backend
category: caching
applies_to: [general]
confidence: verified
sources:
  - https://github.com/tirth8205/code-review-graph/issues/944
  - https://aws.amazon.com/builders-library/caching-challenges-and-strategies/
last_verified: 2026-09-17
related: [backend-common-caching-invalidation-and-stampede, platforms-tools-version-keyed-artifact-cache]
---

# Freshness of a Derived Index Judged by an Input-Hash Manifest When Some Inputs Are Skipped

## When this applies

A derived artifact (search index, code graph, compiled bundle, embedding store)
decides "am I fresh?" by comparing a stored manifest — a map of input path →
content hash, or a version marker — against the current input set, and the
builder can skip an input it cannot process (parse error, unreadable file,
missing required field). Also when such an index rebuilds on every session or
every hook run although each build exits 0.

## Do this

1. **Treat the manifest as the cache key of the whole input directory, and the
   output table as the list of what was usable.** They answer different
   questions, so they are filled from different sets:

| Record | Filled from | A skipped input is |
|--------|-------------|--------------------|
| Manifest (freshness key) | Every input the freshness check enumerates | **Present**, with its current hash |
| Output table (rows, nodes, embeddings) | Inputs that processed successfully | Absent |

2. **Derive both sides of the comparison from one enumeration function.** The
   check is `manifest.inputs == current_inputs()`; the builder writes
   `manifest.inputs` from the same `current_inputs()` result it iterated, and
   skipping happens after the hash is recorded. A key filled only from
   successes makes the comparison permanently unequal while one bad input
   exists.
3. **Retry a skipped input when its hash changes** (or the builder's version
   does — see Edge cases). The recorded hash is what makes this work: an edit
   to the bad file changes its hash, the manifest differs, and the next
   incremental pass re-attempts exactly that file. An unchanged bad file costs
   nothing.
4. **Report the skip where a human reads it** — a `skipped` list inside the
   manifest or a status line — because after step 1 the index is `fresh` and a
   rebuild loop no longer advertises the bad input.
5. **Prove it with a settle test.** Fixture: one valid input plus one the
   builder skips. Assert build exits 0, status reads fresh **immediately after
   the build**, an incremental pass leaves it fresh, and the manifest carries
   the skipped input's hash. Negative control: repair the skipped file and
   require status to turn stale and the repaired input to appear in the table.

## Edge cases

| Case | Then |
|------|------|
| Freshness is a single version marker rather than a per-input map, and the builder withholds the marker when any input failed | Same loop in another shape: one persistently failing file turns every incremental update into a full rebuild. Record the marker and track the failed inputs individually so only those are retried |
| A background hook (session start, file watcher) triggers the rebuild | The loop is invisible: each build "succeeds", so no error log records it. Look for it in build counts or timing — run the status command straight after a successful build and require `fresh` |
| The skip reason is transient (file locked, read raced a writer) | Hash-keyed retry never re-attempts an unchanged file. Record the skip reason and re-attempt transient classes on the next pass; keep hash-keyed retry for content failures (parse, schema) |
| The skipped input was previously indexed and then became unparseable | Remove its stale rows from the output table in the same pass that records the new hash, so the table does not serve content the manifest no longer vouches for |
| The builder is upgraded and can now process an input it used to skip | The input's hash is unchanged, so hash-keyed retry alone leaves it out of the table permanently. Key the retry on (input hash, builder version), or re-attempt every recorded skip once after a builder version change |
| The failing dependency is a remote call rather than a local file | Same principle as negative caching — store the failure with its own shorter TTL rather than re-asking on every request ([backend-common-caching-invalidation-and-stampede] rule 6) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build the manifest from the rows you inserted (`{p: sha for p in indexed}`) | Build it from the enumerated inputs, then drop the unprocessable ones from the table only | A success-only key can never equal the current input set while a bad input exists, so status reads stale straight after a successful build |
| Withhold the freshness marker whenever any input failed, so the failure gets retried | Record the marker plus the failed inputs' hashes; retry those on change | Withholding converts one bad file into a full rebuild on every trigger, with no error anywhere because each rebuild succeeds |
| Conclude the cache works because `--build` exits 0 and queries return results | Run the status check immediately after the build and require `fresh` | Exit 0 and a populated table are both true inside the rebuild loop |

## Sources

- https://github.com/tirth8205/code-review-graph/issues/944 — "A persistently failing file makes every incremental update a full rebuild": the builder refuses to record its identity version when any file failed to parse, so "**every** incremental update becomes a full rebuild, indefinitely … it is silent apart from an INFO log"; proposed direction: "Record the version and track the specific failed files, so only those are retried rather than rebuilding everything"
- https://aws.amazon.com/builders-library/caching-challenges-and-strategies/ — negative caching: "cache the error response (that is, we use a 'negative cache') using a different TTL than positive cache entries"; "Don't cause or amplify an outage by repeatedly asking for the same downstream resource and discarding the error responses" — the remote-call form of recording a failed input
- Reproduction 2026-09-17 (Python 3, two-file fixture: one valid input, one without its header; three simulated sessions that rebuild when status is stale): a manifest filled from processed inputs only gave `builds over 3 sessions: 3 | final status: stale`; filling it from all enumerated inputs gave `builds: 1 | final status: fresh`, with an identical output table (`['good.md']`) in both runs
- Reported field measurement 2026-09-17 (dev-loop wiki index builder, SQLite index plus `manifest.json`; reported by the originating session, corroborated here by reading its code and test, not re-executed): with one valid page and one page lacking frontmatter, `--build` exited 0 and `--status` printed `incremental` instead of `fresh`, and again after `--incremental`. Recording the skipped page's sha256 in the manifest settled it to `fresh`; the regression test asserts the manifest holds the skipped page's hash, status stays `fresh` across an incremental pass, and repairing the page turns it stale again
