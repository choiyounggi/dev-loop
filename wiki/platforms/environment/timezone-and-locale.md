---
id: platforms-environment-timezone-and-locale
domain: platforms
category: environment
applies_to: [general]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man7/environ.7.html
  - https://man7.org/linux/man-pages/man3/tzset.3.html
  - https://www.iana.org/time-zones
  - https://man7.org/linux/man-pages/man5/crontab.5.html
  - https://man7.org/linux/man-pages/man7/systemd.time.7.html
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/toLocaleLowerCase
  - https://unicode.org/faq/casemap_charprop.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap07.html
last_verified: 2026-07-10
related: [databases-schema-design-column-data-types, platforms-processes-background-services]
---

# Timezone and Locale as Hidden Inputs to Date and Text Code

## When this applies

Date/time or text-processing code behaves differently across machines (passes
locally, fails in CI or vice versa); a scheduled/cron job fires at the wrong hour;
reviewing code that formats, parses, or compares dates or strings.

## Do this

The machine's timezone and locale are hidden inputs: `TZ` and `LANG`/`LC_*` come
from the environment, and every API that reads them behaves per-machine. For each
time or text operation, decide the input explicitly instead of inheriting it.

Time:

| Case | Do |
|------|----|
| Storing or computing with timestamps | Store and compute in UTC; convert only at the presentation edge, always with an explicit IANA-named zone (`Asia/Seoul`, not an offset or abbreviation). Column types for the storage side: [databases-schema-design-column-data-types] |
| Parsing a wall-clock string (`"2026-07-10 09:00"`) | State its zone in the parse call. A zoneless parse binds to the machine's zone, so the same string yields a different instant per machine |
| Tests that touch time | Pin the process zone in the test runner (`TZ=UTC` in its env) AND freeze the clock via injection/fake timers — otherwise the suite passes only in your timezone. Flaky-time-test techniques: wiki/testing/ |
| A test must exercise DST or zone-conversion logic | Pin a named DST zone (`TZ=America/New_York`) — pinning means explicit, not UTC-only |
| Scheduling a cron/launchd/systemd job | The job fires in the DAEMON's zone, not your shell's ([platforms-processes-background-services] owns the minimal-environment rule). Declare the zone in the schedule definition where supported: `CRON_TZ=` in cronie crontabs, a trailing IANA zone in systemd `OnCalendar` |
| Schedule must fire exactly once per day | Schedule in UTC or a zone without DST. A `02:30` local schedule is skipped on spring-forward and can double on fall-back |

Locale:

| Case | Do |
|------|----|
| Case-insensitive comparison of machine-facing strings (protocol tokens, headers, identifiers, map keys) | Use a locale-invariant operation (root/invariant-locale API such as `Locale.ROOT`, `toLowerCase()` per the Unicode default mapping, `CultureInfo.InvariantCulture`) or compare case-sensitively on a form you normalized yourself. Under the Turkish locale, uppercasing `"i"` yields `İ` (U+0130) and lowercasing `"I"` yields `ı` (U+0131), so `upper("id") == "ID"` fails there |
| Case conversion for user-facing display | Use the locale-aware API (`toLocaleLowerCase(locale)` and equivalents) with the user's locale passed explicitly |
| Sorting where machines must agree on order (dedup, diffs, binary search, golden files) | Sort by code point / byte order explicitly; collation order differs per `LC_COLLATE` |
| Parsing or formatting numbers in machine data (CSV, config, wire formats) | Fix the locale to an invariant one in the call. `"1.234,56"` and `"1,234.56"` are the same number in different locales — the ambient locale silently picks a reading |
| Local and CI results differ for a date/string test | Diff the hidden inputs first: run `env | grep -E '^(TZ|LANG|LC_)'` in both. Minimal CI/container images leave `LANG`/`LC_*` unset (→ C/POSIX locale) and carry no regional zone config, while dev machines set both — that gap is the classic "passes locally, fails in CI" |

## Edge cases

| Case | Then |
|------|------|
| Zone given as an abbreviation or bare offset (`KST`, `EST`, `+09:00`) | Replace with the IANA `Area/Location` name — abbreviations are ambiguous and fixed offsets ignore DST history; the IANA database is the source of named zones |
| `TZ` is set but empty or unparseable | glibc uses UTC, not the system zone — a mangled `TZ` export masquerades as "server is on UTC" |
| Scheduler has no zone syntax (plain vixie cron) | Express the schedule in the daemon's zone and record that zone next to the entry, or move the job to a systemd timer where `OnCalendar` takes an IANA zone |
| Legacy data already stored in local wall-clock time | Record the zone it was written in alongside it before converting; UTC-converting zoneless rows guesses the source zone — route the schema change through [databases-schema-design-column-data-types] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Fix a timezone-dependent test by editing the assertion to the CI result | Pin `TZ` in the runner env and freeze the clock, then assert the intended instant | The edited assertion encodes one machine's zone; the test breaks again on the next machine |
| `lowercase(userInput)` to build a case-insensitive key | Invariant/root-locale case fold (or normalize + compare case-sensitively) | Locale-sensitive lowering changes per runtime locale — Turkish `İ`/`ı` breaks key equality |
| Schedule a nightly job at `02:30` machine-local | Schedule in UTC (or a no-DST zone), or attach the zone in the schedule syntax | `02:30` local does not exist on spring-forward day and recurs on fall-back day |

## Sources

- https://man7.org/linux/man-pages/man7/environ.7.html — `TZ` and `LANG`/`LC_*` are environment inputs to time and locale functions
- https://man7.org/linux/man-pages/man3/tzset.3.html — unset `TZ` → system zone `/etc/localtime`; empty/unparseable `TZ` → UTC
- https://www.iana.org/time-zones — IANA tz database: named zones, offsets, DST history
- https://man7.org/linux/man-pages/man5/crontab.5.html — `CRON_TZ` per-table zone; daemon-set job environment
- https://man7.org/linux/man-pages/man7/systemd.time.7.html — IANA zone suffix in `OnCalendar` calendar specs
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/toLocaleLowerCase — locale-dependent case mapping; Turkish differs from the Unicode default
- https://unicode.org/faq/casemap_charprop.html — Turkish dotted/dotless i mappings (U+0130/U+0131), language-tailored casing
- https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap07.html — POSIX locale categories (`LC_CTYPE` casing, `LC_COLLATE` ordering, `LC_NUMERIC` number format); C/POSIX locale as the conforming default
