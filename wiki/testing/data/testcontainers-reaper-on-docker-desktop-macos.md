---
id: testing-data-testcontainers-reaper-on-docker-desktop-macos
domain: testing
category: data
applies_to: [testcontainers, python, docker-desktop, macos]
confidence: verified
sources:
  - https://github.com/testcontainers/testcontainers-python/blob/main/README.md
  - https://java.testcontainers.org/features/configuration/
  - https://golang.testcontainers.org/features/configuration/
  - https://golang.testcontainers.org/system_requirements/rancher/
  - https://docs.rancherdesktop.io/how-to-guides/using-testcontainers/
  - https://docs.docker.com/desktop/settings-and-maintenance/settings/
  - https://github.com/testcontainers/testcontainers-java/issues/8170
  - https://github.com/testcontainers/testcontainers-java/issues/7678
  - https://github.com/testcontainers/testcontainers-go/issues/399
last_verified: 2026-09-06
related: [testing-data-test-data-and-isolation, qa-environments-test-environment-parity, debugging-signals-reading-error-messages]
---

# Testcontainers' Reaper Cannot Mount the Docker Socket on Docker Desktop for macOS

## When this applies

A Testcontainers suite (testcontainers-python here; the Java and Go libraries
share the mechanism) on a macOS developer machine with Docker Desktop stops
before any test runs — `0 tests`, `errors=N` — with an error about mounting
`~/.docker/run/docker.sock` or `/host_mnt/Users/<you>/.docker/run/docker.sock`
(HTTP 500, `operation not supported`), while the identical suite is green on a
Linux CI runner.

## Do this

1. **Read it as a host-environment fault, not a code fault.** Ryuk, the cleanup
   sidecar, bind-mounts the Docker socket into its own container; Docker
   Desktop's per-user socket path lives on the host, and the VM that runs the
   daemon cannot mount it. The containers under test never started — the
   failure is upstream of every test body.
2. **Pick the fix by what you can change on the host**, in this order:

| Case | Do |
|------|----|
| Docker Desktop settings are yours to change | Settings › Advanced › enable **"Allow the default Docker socket to be used"** — it "Creates `/var/run/docker.sock`", the path Ryuk mounts by default; restart Docker Desktop and rerun with Ryuk on |
| The setting cannot be enabled (managed machine) | `export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock` — the socket path *inside the VM*, which is where the mount is resolved; the same override the Rancher Desktop and Colima guides prescribe. Ryuk stays on |
| Neither is possible | `export TESTCONTAINERS_RYUK_DISABLED=true` on the dev host only, and remove leftover containers/networks/volumes yourself after interrupted runs — the library warns this "will prevent testcontainers from automatically cleaning up resources, which is particularly important in tests which timeout" |
| Linux CI runner (`ubuntu-latest`) | Change nothing — `/var/run/docker.sock` is the real daemon socket there, and the suite already passes |

3. **Keep the workaround out of shared config.** Put the variable in the
   developer's shell profile or an untracked local env file, and document it in
   the README as a macOS Docker Desktop note; committing it into `pytest.ini`,
   `conftest.py`, or the CI workflow disables cleanup on every machine that did
   not have the problem.

## Edge cases

| Case | Then |
|------|------|
| Colima, Rancher Desktop, or OrbStack instead of Docker Desktop | Same override mechanism: the vendor guides set `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock` (Rancher Desktop also sets `TESTCONTAINERS_HOST_OVERRIDE` to the VM's address) |
| A specific container class still mounts the wrong socket after the override | The class binds the socket path before host detection resolves it (testcontainers-java#7678, LocalStack; fixed upstream) — upgrade the library before changing more host settings |
| Ryuk is disabled and a run was interrupted | `docker ps -a --filter label=org.testcontainers` lists what the reaper would have removed; delete those containers and their networks/volumes before the next run |
| The error text names `/host_mnt/Users/...` | Docker Desktop's file-sharing mount of the host socket path — the socket cannot be shared into the VM as a file (testcontainers-java#8170, closed as environment); it is the same fault as the `~/.docker/run/docker.sock` message |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Mock the database or rewrite the suite because "Docker is broken on macOS" | Fix the socket path (Desktop setting or `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE`) | Only Ryuk's mount failed; the containers under test start once the reaper can |
| Commit `TESTCONTAINERS_RYUK_DISABLED=true` into the repo's test or CI config | Scope it to the affected dev host and document it | Ryuk removes containers, networks, volumes and images after a run; disabling it everywhere leaks resources on every machine and on CI |
| Point the override at `~/.docker/run/docker.sock` | Point it at `/var/run/docker.sock` | The override names the path the *daemon* mounts into Ryuk, which resolves inside the VM — the host-side per-user path is the one that fails |

## Sources

- https://github.com/testcontainers/testcontainers-python/blob/main/README.md — configuration table: `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE` (default `/var/run/docker.sock`, "Path to Docker's socket used by ryuk"), `TESTCONTAINERS_RYUK_DISABLED` (default `false`, "Disable ryuk"), runtime equivalent `testcontainers_config.ryuk_docker_socket`
- https://java.testcontainers.org/features/configuration/ — `TESTCONTAINERS_RYUK_DISABLED`: "If your environment already implements automatic cleanup of containers after the execution, but does not allow starting privileged containers, you can turn off the Ryuk container"; `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE`: "Path to Docker's socket. Used by Ryuk, Docker Compose, and a few other containers that need to perform Docker actions"
- https://golang.testcontainers.org/features/configuration/ — disabling Ryuk "will prevent testcontainers from automatically cleaning up resources, which is particularly important in tests which timeout as they don't run test clean up"
- https://golang.testcontainers.org/system_requirements/rancher/ and https://docs.rancherdesktop.io/how-to-guides/using-testcontainers/ — `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock` for a macOS VM-based Docker runtime
- https://docs.docker.com/desktop/settings-and-maintenance/settings/ — "Allow the default Docker socket to be used … Creates /var/run/docker.sock which some third party clients may use to communicate with Docker Desktop"
- https://github.com/testcontainers/testcontainers-java/issues/8170 — `error while creating mount source path '/host_mnt/Users/_user/.docker/run/docker.sock' … operation not supported` on Docker Desktop for Mac; closed as environment
- https://github.com/testcontainers/testcontainers-java/issues/7678 — a container fails to start when "Allow the default Docker socket to be used" is unchecked; the class bound the socket before host detection
- https://github.com/testcontainers/testcontainers-go/issues/399 — the socket override was added for non-standard socket paths on macOS VM runtimes
- Field reproduction 2026-08-30 (linkly, testcontainers-python, macOS Docker Desktop): the suite exited rc=5 with `errors=2, 0 tests` on the `~/.docker/run/docker.sock` mount error twice; with `TESTCONTAINERS_RYUK_DISABLED=true` it ran 27/27 green twice; GitHub Actions `ubuntu-latest` ran the same suite green with no variable set (run 33309041474)
