---
id: infrastructure-containers-postgres-18-image-data-volume
domain: infrastructure
category: containers
applies_to: [docker, postgresql]
confidence: verified
sources:
  - https://github.com/docker-library/postgres/blob/e00e1bd34ec5c8a8e7ad89b273b3d42efaf6d5bc/18/alpine3.24/Dockerfile
  - https://github.com/docker-library/postgres/blob/e00e1bd34ec5c8a8e7ad89b273b3d42efaf6d5bc/18/alpine3.24/docker-entrypoint.sh
  - https://hub.docker.com/_/postgres
  - https://github.com/docker-library/docs/blob/master/postgres/content.md
  - https://github.com/docker-library/postgres/pull/1259
  - https://github.com/docker-library/postgres/commit/5ec89312491bdaa2c42377a65ec0af2ecb774480
  - https://github.com/docker-library/postgres/commit/3b6b5fca9ca40c84b77540fc605ea8e8353b13b2
  - https://github.com/docker-library/postgres/issues/37
  - https://www.postgresql.org/docs/current/runtime-config-file-locations.html
  - https://www.postgresql.org/docs/current/upgrading.html
  - https://www.postgresql.org/docs/current/pgupgrade.html
  - https://github.com/docker/docs/issues/23789
last_verified: 2026-10-08
related: [infrastructure-containers-published-ports-bind-all-interfaces, infrastructure-containers-image-builds, infrastructure-data-backup-and-restore]
---

# Data Volume Path for the Official Postgres Image 18 and Newer

## When this applies

A Compose file, `docker run` or Kubernetes manifest mounts storage for the official
`postgres` image at tag 18+, or moves a volume from tag 17 or lower to 18; a guide's
`-v pgdata:/var/lib/postgresql/data` fails on 18; the container exits on start with
`Error: in 18+, these Docker images are configured to store database data in a format which is compatible with "pg_ctlcluster"`.

## Do this

Read the image's major version first, then pick the mount target from this table:

| Case | Do |
|------|----|
| New container, image 18 or newer | Mount the volume at `/var/lib/postgresql` (`pgdata:/var/lib/postgresql`). The image sets `PGDATA=/var/lib/postgresql/18/docker` and declares `VOLUME /var/lib/postgresql` |
| Image 17 or lower | Mount at `/var/lib/postgresql/data`; with the default `PGDATA`, a mount at `/var/lib/postgresql` does not persist the data when the container is re-created. Setting `PGDATA=/var/lib/postgresql/17/docker` with the mount at `/var/lib/postgresql` opts such an image into the 18 layout |
| The mount target is `/var/lib/postgresql/data` and the image is 18 or newer | Move the mount to `/var/lib/postgresql`. With the default `PGDATA` and an empty data directory, images built from 2025-10-15 (Debian) and 2026-04-21 (Alpine) on list the old path as an unused mount, print the error above and exit with status 1. Older 18 images start without an error and write into the image's own anonymous volume, leaving yours unused |
| A volume holds an older major's data and the tag moves to 18 | Upgrade before the tag change: dump with `pg_dumpall` and restore into a new volume, or run `pg_upgrade` with both majors' binaries (docker-library/postgres#37). Then mount the new volume at `/var/lib/postgresql` |

## Edge cases

| Case | Then |
|------|------|
| A guide, blog post or older docs example shows `/var/lib/postgresql/data` | Check which major it was written for; Docker's own docs carried the old path for 18 (docker/docs#23789) |
| An 18 container started without the error | Confirm the data lands on your volume: `docker inspect -f '{{json .Mounts}}' <container>` lists it at `/var/lib/postgresql`, and `SHOW data_directory;` names a path under that mount |
| The manifest sets `PGDATA` explicitly | The entrypoint's old-path check runs only for the default `PGDATA` (`/var/lib/postgresql/<major>/docker`); mount a path that contains the `PGDATA` you set |
| Later majors (19+) | `PGDATA` is `/var/lib/postgresql/<major>/docker`; the volume still belongs at `/var/lib/postgresql` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Copy `-v pgdata:/var/lib/postgresql/data` from a pre-18 guide onto an 18 image | Mount `pgdata:/var/lib/postgresql` | The 18 image keeps its data in `/var/lib/postgresql/18/docker`; current builds refuse to start with the old mount and an empty data directory, and older builds silently write to an anonymous volume |
| Bump only the tag on a volume that holds 17's data | Dump and restore, or run `pg_upgrade`, then remount | File-system-level copies do not carry across majors; the 18 entrypoint finds the old data and exits with status 1 |

## Sources

- https://github.com/docker-library/postgres/blob/e00e1bd34ec5c8a8e7ad89b273b3d42efaf6d5bc/18/alpine3.24/Dockerfile — the commit that builds `18.6-alpine`, lines 202-205: "# NOTE: in 18+, PGDATA has changed to match the pg_ctlcluster standard directory structure, and the VOLUME has moved from /var/lib/postgresql/data to /var/lib/postgresql", `ENV PGDATA /var/lib/postgresql/18/docker`, `VOLUME /var/lib/postgresql`
- https://github.com/docker-library/postgres/blob/e00e1bd34ec5c8a8e7ad89b273b3d42efaf6d5bc/18/alpine3.24/docker-entrypoint.sh — lines 244-264: only when `PGDATA` is the default `/var/lib/postgresql/$PG_MAJOR/docker`, a `PG_VERSION` under `/var/lib/postgresql`, `/var/lib/postgresql/data` or another major's `docker` directory, or (with no such data) a mount point at `/var/lib/postgresql/data`, is recorded as old; lines 140-166 then print "Error: in 18+, these Docker images are configured to store database data in a format which is compatible with "pg_ctlcluster"", name "pg_upgrade" ("which requires both versions"), suggest "a single mount at /var/lib/postgresql", and `exit 1`
- https://hub.docker.com/_/postgres (source text: https://github.com/docker-library/docs/blob/master/postgres/content.md) — "The defined `VOLUME` was changed in 18 and above to `/var/lib/postgresql`. Mounts and volumes should be targeted at the updated location."; "For 18 it is `/var/lib/postgresql/18/docker`. Later versions will replace `18` with their respective major version"; "(for PostgreSQL 17 and below) Mount the data volume at `/var/lib/postgresql/data` and not at `/var/lib/postgresql` because mounts at the latter path WILL NOT PERSIST database data when the container is re-created"
- https://github.com/docker-library/postgres/pull/1259 — the change: "This also changes the `VOLUME` to `/var/lib/postgresql`"
- https://github.com/docker-library/postgres/commit/5ec89312491bdaa2c42377a65ec0af2ecb774480 (2025-10-15) "Remove intentionally-breaking "data" symlink and add better detection", and https://github.com/docker-library/postgres/commit/3b6b5fca9ca40c84b77540fc605ea8e8353b13b2 (2026-04-21) "Fix Alpine missing `/var/lib/postgresql/data` mounts" — the dates from which an unused old-path mount is detected
- Hub docs (same `content.md`) — "Users who wish to opt-in to this change on older releases can do so by setting `PGDATA` explicitly (`--env PGDATA=/var/lib/postgresql/17/docker --volume some-postgres:/var/lib/postgresql`)"
- https://www.postgresql.org/docs/current/runtime-config-file-locations.html — `data_directory`: "Specifies the directory to use for data storage."
- https://github.com/docker-library/postgres/issues/37 — "Upgrading between major versions?", the image's issue on cross-major upgrades
- https://www.postgresql.org/docs/current/upgrading.html — moving data from one major version to another needs "a logical backup tool like pg_dumpall; file system level backup methods will not work"
- https://www.postgresql.org/docs/current/pgupgrade.html — "pg_upgrade requires the specification of the old and new cluster's data and executable (bin) directories"
- https://github.com/docker/docs/issues/23789 — "Wrong volume path for running the Postgres container"
