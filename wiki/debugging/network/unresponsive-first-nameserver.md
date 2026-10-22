---
id: debugging-network-unresponsive-first-nameserver
domain: debugging
category: network
applies_to: [linux, node, general]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man5/resolv.conf.5.html
  - https://curl.se/docs/manpage.html
  - https://curl.se/libcurl/c/CURLOPT_CONNECTTIMEOUT.html
  - https://curl.se/libcurl/c/CURLOPT_TIMEOUT.html
  - https://nodejs.org/api/dns.html
  - https://man7.org/linux/man-pages/man8/systemd-resolved.service.8.html
  - https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html
  - https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html
  - https://networkmanager.dev/docs/api/latest/nmcli.html
  - https://wiki.musl-libc.org/functional-differences-from-glibc.html
last_verified: 2026-10-10
related: [backend-common-reliability-timeouts-and-retries]
---

# A Fixed Delay on Every Outbound Call From an Unresponsive First Nameserver

## When this applies

Every outbound call from one host (a home server, a Raspberry Pi, a VM) is about
5 s slower whatever the destination, or a client with a short total timeout
(`fetch` with `AbortSignal.timeout(5000)`) fails there while `curl` to the same
URL succeeds slowly. Also when the added delay is a multiple of 5 s or of the
host's `options timeout:` value.

## Do this

1. **Split the request's time into phases before suspecting the route, TLS, or
   the server.** Run
   `curl -s -o /dev/null -w 'namelookup=%{time_namelookup} connect=%{time_connect} appconnect=%{time_appconnect} total=%{time_total}\n' https://<host>/`.
   Each value counts from the start, so a phase costs its value minus the one
   before it.
2. **When `namelookup` carries the delay, probe each `nameserver` line of
   `/etc/resolv.conf` on its own** with a short timeout:
   `dig @<server-ip> <host> +time=2 +tries=1`. A live server prints
   `status: NOERROR` and a query time in ms; an unresponsive one prints
   `connection timed out; no servers could be reached` after 2 s.
3. **Read the result against the resolver's order.** The glibc resolver queries
   the servers in the order listed and waits `timeout` (default 5 s) on each
   before trying the next, so a dead first server adds about 5 s to every lookup
   while a live later server still answers — the lookup succeeds, late.
4. **Change the server list in the component that writes `/etc/resolv.conf`,
   then re-run step 1 and require `namelookup` in milliseconds.** When
   NetworkManager writes the file (`rc-manager` `symlink` or `file`), run
   `nmcli connection modify <conn> ipv4.dns <ip> ipv4.ignore-auto-dns yes`, then
   `nmcli device reapply <ifname>` — `ignore-auto-dns` drops the DHCP-supplied
   servers, the dead one included.

| Phase split | Conclusion |
|-------------|------------|
| `namelookup` ≈ 5 s (or a multiple), later phases small | A resolver is not answering — steps 2-4 |
| `namelookup` small, `connect − namelookup` large | TCP connect is slow — this page does not apply |
| `connect` small, `appconnect − connect` large | The TLS handshake is slow — this page does not apply |

## Edge cases

| Case | Then |
|------|------|
| You need relief before the server list can change | `options timeout:1` in the file, or `RES_OPTIONS="timeout:1"` for one process, cuts the wait to about 1 s per lookup (measured 1021 ms); the delay shrinks and stays until the dead server is gone |
| `dig` is not installed (minimal images) | Probe one server with Node: `new (require('node:dns').promises.Resolver)({timeout: 2000, tries: 1})`, `setServers(['<server-ip>'])`, `resolve4('<host>')` — a dead server returns `ETIMEOUT` after about 3 s (measured 2995 ms), a live one answers in ms |
| `/etc/resolv.conf` lists only `127.0.0.53` | systemd-resolved answers through its stub — probe the servers listed in `/run/systemd/resolve/resolv.conf` with step 2; resolved keeps talking to one server until it sees an error and then switches to the next, so the delay hits lookups until that switch rather than every lookup |
| The host is macOS | Most processes there do not read `/etc/resolv.conf`; read the servers from `scutil --dns` and probe those |
| The slow process runs on musl (Alpine-based images) | musl queries every listed server in parallel and takes the first answer, so one dead server adds no delay (measured 54 ms against 55 ms without it) — this cause does not apply; probe every server with step 2 to see whether all of them are slow |
| A Node.js service is the slow caller | Node's networking APIs resolve through `dns.lookup()` — `getaddrinfo(3)`, which follows `resolv.conf`; `dns.resolve*()` queries the network directly, so a probe written with it can return fast while every `fetch` stays slow — time `dns.lookup()` to reproduce the app's path |
| The app's total timeout is at or below the resolver's per-server wait | The request aborts while the lookup is still waiting, before any connection opens, and the error names the timeout (`TimeoutError`), not DNS — take the step-1 split before touching the timeout |
| `options rotate` is set | Lookups start at a different server each time, so only the ones that start at the dead server are slow — an intermittent delay that step 2 still finds |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Raise the app's request timeout because the API is slow from this host | Run the step-1 phase split first | A fixed 5 s in `namelookup` is the resolver waiting on one dead server; a longer timeout hides it on every call |
| Blame TLS or the remote API because only the client with a short timeout fails | Compare `namelookup` with `connect` and `appconnect` | curl's connection phase, DNS included, defaults to a 300 s limit and its whole transfer to none, so curl waits the lookup out and succeeds where a 5 s client gives up |
| Hand-edit an `/etc/resolv.conf` that a network manager writes | Change the servers in that manager (step 4) | The manager rewrites the file on its next DNS update and the dead server returns |

## Sources

- https://man7.org/linux/man-pages/man5/resolv.conf.5.html — "If there are multiple servers, the resolver library queries them in the order listed"; `timeout:n` "the default is RES_TIMEOUT (currently 5, see <resolv.h>)"; `attempts:n` default RES_DFLRETRY (currently 2); `rotate` "causes round-robin selection of name servers"; `RES_OPTIONS` amends the options "on a per-process basis"
- https://curl.se/docs/manpage.html — `--write-out`: `time_namelookup` "from the start until the name resolving was completed"; `time_connect` until "the TCP connect to the remote host (or proxy) was completed"; `time_appconnect` until "the SSL/SSH/etc connect/handshake to the remote host was completed"
- https://curl.se/libcurl/c/CURLOPT_CONNECTTIMEOUT.html — "The connection phase includes the name resolve (DNS) and all protocol handshakes and negotiations"; default 300 s
- https://curl.se/libcurl/c/CURLOPT_TIMEOUT.html — default "0 (zero) which means it never times out during transfer"
- https://nodejs.org/api/dns.html — `dns.lookup()` "is implemented as a synchronous call to `getaddrinfo(3)`" and follows `resolv.conf(5)`; "Various networking APIs will call `dns.lookup()` internally to resolve host names"; `dns.resolve*()` "do not use `getaddrinfo(3)` and they *always* perform a DNS query on the network"
- https://man7.org/linux/man-pages/man8/systemd-resolved.service.8.html — `/run/systemd/resolve/stub-resolv.conf` "lists the 127.0.0.53 DNS stub (see above) as the only DNS server"; `/run/systemd/resolve/resolv.conf` contains "all known DNS servers"; resolved "will continuously talk to the same server for all queries in a particular lookup scope until some form of error is seen", "at which point it will switch to the next server"
- https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html — `rc-manager`: `symlink` "If `/etc/resolv.conf` is a regular file or does not exist, NetworkManager will write the file directly"; `file` "NetworkManager will write `/etc/resolv.conf` as regular file"
- https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html — `ipv4.ignore-auto-dns`: with method `auto`, "automatically configured name servers and search domains are ignored and only name servers and search domains specified in the "dns" and "dns-search" properties, if any, are used"
- https://networkmanager.dev/docs/api/latest/nmcli.html — `device reapply`: "Attempt to update device with changes to the currently active connection made since it was last applied"
- https://wiki.musl-libc.org/functional-differences-from-glibc.html — "Traditional resolvers, including glibc’s, make use of multiple nameserver lines in `resolv.conf` by trying each one in sequence and falling to the next after one times out. musl’s resolver queries them all in parallel and accepts whichever response arrives first."
- Local reproduction 2026-10-10 (Docker Desktop 27.4.0, `python:3-alpine`, musl): the same dead-first `nameserver` order gave `getaddrinfo` in 54 ms against 55 ms with the working resolver alone
- Local reproduction 2026-10-10 (Docker Desktop 27.4.0, `node:22-bookworm-slim`, glibc): with `nameserver 192.0.2.1` (TEST-NET-1, nothing answers) listed before a working resolver, `dns.lookup` took 5031 ms and `fetch` with `AbortSignal.timeout(4000)` failed with `TimeoutError` at 4007 ms; adding `options timeout:1` gave 1021 ms; the working resolver alone gave 12 ms and the fetch returned 200 in 596 ms
- Local check 2026-10-10 (macOS, DiG 9.10.6, Node 26.7.0): `dig @192.0.2.1 example.com +time=2 +tries=1` → "connection timed out; no servers could be reached" after 2 s, a live resolver → `status: NOERROR`; a single-server `Resolver({timeout: 2000, tries: 1})` → `ETIMEOUT` at 2995 ms vs 5 ms; the macOS `/etc/resolv.conf` header reads "This file is not consulted for DNS hostname resolution … used by most processes on this system … use: scutil --dns"
- Field evidence 2026-10-09 (a Raspberry Pi home server): curl reported `namelookup=5.04s`, `connect=5.30s`; the first `nameserver` (the router's DNS) timed out for A and AAAA while a public resolver answered in 38 ms; the Node client failed at 5436 ms
