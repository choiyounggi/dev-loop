---
id: infrastructure-containers-image-builds
domain: infrastructure
category: containers
applies_to: [docker, general]
confidence: verified
sources:
  - https://docs.docker.com/build/building/best-practices/
  - https://docs.docker.com/build/building/secrets/
last_verified: 2026-07-10
related: [infrastructure-ci-cd-pipeline-structure, infrastructure-ci-cd-secrets-handling]
---

# Structuring Container Image Builds

## When this applies

Writing or reviewing a Dockerfile; images rebuild everything on small code
changes, build slowly, or are too large; choosing an image tagging scheme.

## Do this

1. Order layers by change frequency, least-changing first — the cache survives
   down to the first changed layer:

| Layer order | Content |
|-------------|---------|
| 1 | Base image, pinned |
| 2 | OS/system packages |
| 3 | Dependency manifests + lockfile only (e.g. `COPY package.json package-lock.json ./`) |
| 4 | Dependency install, deterministic from the lockfile (`npm ci`-style, not floating resolve) |
| 5 | Source code |
| 6 | Build/compile step |

   A source-only change then reuses cached layers 1–4. Copying source before the
   install invalidates the dependency layer on every commit.
2. Use multi-stage builds: a build stage carries compilers and toolchain; the
   final stage starts from a minimal runtime base and `COPY --from=build` only
   the runtime artifacts. Ships a smaller image with no build tools in production.
3. Pin the base image to a digest (`@sha256:...`) or a specific version tag.
   A floating `latest` changes the build result with no code change.
4. Create a non-root user and switch to it with `USER` before the entrypoint.
5. One process per container; supervisors and sidecars belong to the orchestrator.
6. Add a `.dockerignore` excluding `.git`, build output dirs, local dependency
   dirs, and env/secret files — smaller build context and no secrets copied into layers.
7. Tag each release immutably with the git SHA; never overwrite an existing
   release tag. Moving alias tags (`latest`, env names) are pointers only —
   deploys reference the SHA tag. This implements build-once/promote
   ([infrastructure-ci-cd-pipeline-structure]).

## Edge cases

| Case | Then |
|------|------|
| Build needs a private dependency (registry token, SSH key) | BuildKit `RUN --mount=type=secret` (or `--mount=type=ssh`), never `ARG`/`ENV` — those persist in image history ([infrastructure-ci-cd-secrets-handling]) |
| Pinned base image needs security patches | Pinning shifts updating to you: bump the digest on a schedule via automated PRs, rebuilding through CI |
| App must serve a port below 1024 as non-root | Bind a high port in the container; map the privileged port at the orchestrator or load balancer |
| Minimal runtime base lacks CA certs or timezone data | Install exactly those packages in the final stage — not the whole build toolchain |
| Same source must build identical images on different machines | Deterministic installs (lockfile), pinned base digest, and no build steps that fetch unpinned resources at build time |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `COPY . .` before the dependency install | Copy manifests + lockfile, install, then copy source | Every commit otherwise invalidates the dependency cache |
| `FROM x:latest` | Pin a digest or specific version tag | Builds change without a code change; not reproducible |
| Pass a build-time token via `ARG` | `--mount=type=secret` | ARG/ENV values persist in image history |
| Retag/overwrite an existing release tag | New SHA tag; move only alias tags | Immutable tags keep what-ran identifiable and rollback possible |

## Sources

- https://docs.docker.com/build/building/best-practices/ — cache/layer ordering, multi-stage builds, digest pinning, non-root USER, .dockerignore, one concern per container
- https://docs.docker.com/build/building/secrets/ — secret mounts; build args persist in the final image
