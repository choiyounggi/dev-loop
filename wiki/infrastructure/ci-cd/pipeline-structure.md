---
id: infrastructure-ci-cd-pipeline-structure
domain: infrastructure
category: ci-cd
applies_to: [general]
confidence: field-tested
sources:
  - https://12factor.net/build-release-run
  - https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows
last_verified: 2026-07-10
related: [infrastructure-containers-image-builds, infrastructure-ci-cd-secrets-handling]
---

# Ordering and Structuring CI Pipeline Stages

## When this applies

Creating a CI pipeline, restructuring an existing one, or diagnosing CI that is
slow, unreliable, or reports failures too late; deciding where a new check
belongs in the pipeline.

## Do this

1. Order stages fastest-failing first, so most defects are reported within minutes:

| Position | Stage | Reason for position |
|----------|-------|---------------------|
| 1 | Lint + typecheck | Seconds to run; catches the largest share of trivial failures |
| 2 | Unit tests | Fast, no external services needed |
| 3 | Build (artifact/image) | Produces the one artifact later stages consume |
| 4 | Integration tests | Need running services and the built artifact |
| 5 | E2E / acceptance | Slowest, most environment-dependent |

2. Fail fast: stop the pipeline at the first failing stage. Run stages with no
   data dependency on each other (lint and unit tests) in parallel.
3. Make every step reproducible locally: put the command in a repo script
   (Makefile target, package script) and have both CI and developers invoke that
   same script. A step that only runs in CI costs one commit-push-wait cycle per
   debugging attempt.
4. Pin toolchain versions (runtime, package manager, build tools) in version
   files the pipeline reads (`.nvmrc`, `.tool-versions`, pinned image tags) —
   floating versions make builds fail on tool releases unrelated to any code change.
5. Cache dependencies keyed by the lockfile hash, so the cache invalidates
   exactly when dependencies change. Cache the directory the tool's caching docs
   name — when the tool advises against caching the install directory
   (node_modules-style), cache the package cache instead.
6. Build the deployable artifact once, in one stage; every later stage and
   environment promotes that exact artifact (immutable tagging:
   [infrastructure-containers-image-builds]).
7. When a step fails intermittently with no code change, treat it like a flaky
   test: quarantine it out of the merge-blocking path and fix the root cause
   (flaky-test workflow: testing domain, wiki/testing/).

## Edge cases

| Case | Then |
|------|------|
| Monorepo pipeline runs everything on every change | Filter stages by affected paths/packages per PR; run the unfiltered pipeline on the main branch |
| Integration/e2e stage needs the built artifact | Pass the stage-3 artifact forward (artifact store or registry); do not rebuild inside the test stage |
| Cache restore takes longer than a clean install | Measure both paths; drop the cache when restore is the slower one |
| Full e2e suite too slow to run per PR | Run a smoke subset per PR; full suite on the main-branch or merge-queue pipeline |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add automatic retries to a flaky step and move on | Quarantine the step from the blocking path and fix the root cause | Blanket retries hide real defects and permanently inflate pipeline time |
| Rebuild the artifact for each environment (stg build, prd build) | Build once, promote the same artifact through environments | Per-environment rebuilds break "what you tested is what you ship" |
| Write a CI-only shell blob inline in pipeline YAML | Move the command into a repo script that CI calls | Inline steps cannot be reproduced or debugged locally |

## Sources

- https://12factor.net/build-release-run — build once; releases are immutable and promoted, not rebuilt
- https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows — dependency cache keys derived from lockfile hash
