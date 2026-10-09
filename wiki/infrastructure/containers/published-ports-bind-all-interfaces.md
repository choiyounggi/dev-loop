---
id: infrastructure-containers-published-ports-bind-all-interfaces
domain: infrastructure
category: containers
applies_to: [docker, docker-compose]
confidence: verified
sources:
  - https://docs.docker.com/reference/compose-file/services/
  - https://docs.docker.com/engine/network/port-publishing/
  - https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/
  - https://docs.docker.com/engine/network/packet-filtering-firewalls/
  - https://docs.docker.com/desktop/features/networking/
last_verified: 2026-10-08
related: [infrastructure-containers-postgres-18-image-data-volume, security-api-exposure-exposing-an-origin-http-api, security-secrets-secrets-in-code]
---

# Published Container Ports for Host-Only Services

## When this applies

Writing or reviewing a Compose `ports:` entry or a `docker run -p` flag for a
service only the local machine uses (a development database, cache, admin UI or
debugger port); a dev database with a placeholder password answers from another
machine on the LAN; a host firewall rule does not block a published container port.

## Do this

| Case | Do |
|------|----|
| The service is used only from the host machine | Put the host IP first: `"127.0.0.1:55432:5432"` in Compose, `-p 127.0.0.1:55432:5432` on `docker run`. A mapping without a host IP binds all interfaces (`0.0.0.0`) |
| A host firewall is expected to filter the port | Bind the port to loopback as above. On Linux, Docker's own firewall rules route a published port's packets before host rules such as ufw apply, so a mapping without a host IP bypasses them |
| A Compose `HOST:CONTAINER` port string | Quote it (`"127.0.0.1:55432:5432"`); YAML can read an unquoted `xx:yy` as a base-60 number |
| The host port must differ per machine (5432 already taken) | Interpolate it: `"127.0.0.1:${DB_PORT:-55432}:5432"`; `${VAR:-default}` yields the default when `VAR` is unset or empty |

## Edge cases

| Case | Then |
|------|------|
| Docker Engine older than 28.0.0 | Hosts on the same L2 segment can reach ports published to localhost; upgrade the engine to 28.0.0 or newer before relying on the loopback binding |
| Docker Desktop (macOS, Windows) | Keep `127.0.0.1` in the mapping as well: Desktop also publishes on `0.0.0.0` by default, its `com.docker.backend` process is what a host firewall can filter, and a Desktop network setting can change the default bind, so the explicit address makes the file mean the same on every engine |
| Another machine must reach the service on purpose | Publish on that interface's address, and give the service real credentials instead of a placeholder password |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Publish a dev database as `"5432:5432"` | Publish it as `"127.0.0.1:5432:5432"` | The short form publishes on every interface; with a placeholder password that is an open database on the LAN, or on the internet when the host has a public IP |

## Sources

- https://docs.docker.com/reference/compose-file/services/ — `ports` short syntax: "If you do not specify a host IP (such as 127.0.0.1), Docker binds to all interfaces (0.0.0.0), bypassing host firewall rules. This can expose the container directly to the internet if the host has a public IP address."; "HOST:CONTAINER should always be specified as a (quoted) string, to avoid conflicts with YAML base-60 float."
- https://docs.docker.com/engine/network/port-publishing/ — "Publishing container ports is insecure by default."; "If you include the localhost IP address (127.0.0.1, or ::1) with the publish flag, only the Docker host can access the published container port."; "In releases older than 28.0.0, hosts within the same L2 segment (for example, hosts connected to the same network switch) can reach ports published to localhost."
- https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/ — "${VAR:-default} -> value of VAR if set and non-empty, otherwise default"
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ — "On Linux, Docker creates firewall rules to implement network isolation, port publishing and filtering."; with ufw, "Packets are routed before the firewall rules can be applied, effectively ignoring your firewall configuration"
- https://docs.docker.com/desktop/features/networking/ — "By default, docker run -p listens on all network interfaces (0.0.0.0), but you can restrict it to a specific address, such as 127.0.0.1 (localhost)"; "This behavior can be modified to bind to localhost by default in Docker Desktop's network settings"; "Host firewalls can permit or deny inbound connections by filtering on com.docker.backend."
