---
id: databases-schema-design-column-data-types
domain: databases
category: schema-design
applies_to: [postgresql, mysql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/datatype.html
  - https://wiki.postgresql.org/wiki/Don%27t_Do_This
  - https://dev.mysql.com/doc/refman/8.0/en/data-types.html
last_verified: 2026-07-10
related: [databases-schema-design-primary-key-choice, databases-schema-design-nullability-and-defaults, databases-schema-design-requirements-to-tables]
---

# Choosing Column Data Types

## When this applies

You are declaring columns for a new or changed table and must pick each attribute's
type. (For id columns, route to [databases-schema-design-primary-key-choice].)

## Do this

| Attribute kind | Type | Notes |
|----------------|------|-------|
| Money, single known currency | Integer count of the minor unit (`amount_cents BIGINT`) | Binary floats cannot represent 0.1 exactly; sums drift |
| Money, multiple currencies (or currency set may grow) | `NUMERIC(19,4)` + a currency column — minor-unit exponents differ per currency (JPY=0, KWD=3), so a shared `_cents` integer misstates amounts | Same float rule applies |
| Point in time (created_at, expires_at) | PostgreSQL `TIMESTAMPTZ`; MySQL `TIMESTAMP` (range ends 2038 — use `DATETIME` stored as UTC for far-future dates) | Store UTC; convert at the presentation layer |
| Calendar date with no time component (birth date, billing day) | `DATE` | A midnight timestamp masquerading as a date shifts across timezones |
| Duration | Integer of an explicit unit (`timeout_seconds INT`) or PostgreSQL `INTERVAL` | Unit-in-name prevents ms/s confusion |
| Free text (names, descriptions) | PostgreSQL: `TEXT` + `CHECK (length(col) <= n)` when a business limit exists; MySQL: `VARCHAR(n)` sized to the real limit | In PostgreSQL `VARCHAR(n)` has no performance benefit over `TEXT`; the CHECK is easier to change than a type |
| Fixed small value set (status, role) | `TEXT`/`VARCHAR` + `CHECK (status IN (...))`, or a lookup table when values carry data or change at runtime | Native `ENUM` types make adding/reordering values a DDL migration in MySQL and removal awkward in PostgreSQL — choose them only for sets that are truly closed |
| Flags | `BOOLEAN NOT NULL DEFAULT` ([databases-schema-design-nullability-and-defaults]) | |
| Variable/unknown structure | PostgreSQL `JSONB` (not `JSON`) for one documented-shape column ([databases-schema-design-requirements-to-tables]) | Promote fields you filter/join on to real columns |
| Binary blobs (files, images) | Object storage + a path/key column | Row storage bloats backups and caches; serve files from storage built for it |
| IP addresses / networks | PostgreSQL `INET`/`CIDR`; MySQL `VARBINARY(16)` via `INET6_ATON` | Text IPs sort and match incorrectly |
| Fractional quantities measured, never summed for money (ratios, coordinates) | `DOUBLE PRECISION` | Floats are fine where approximation is inherent |

Pick the narrowest type that fits the domain's real range — but for counters and
quantities that grow with business volume, start at `BIGINT`; widening a hot column
later is an online-migration project ([databases-schema-design-primary-key-choice]).

## Edge cases

| Case | Then |
|------|------|
| Phone numbers, postal codes, national ids | `TEXT`, never numeric — leading zeros, `+`, and separators are data; you never do arithmetic on them |
| Currency codes | ISO 4217 alpha-3 as `TEXT`/`CHAR(3)` with `CHECK (char_length(currency) = 3)`; add a lookup table only when you attach data to currencies (symbol, exponent) |
| Percentages / rates used in billing math | `NUMERIC`, and document whether 0.15 or 15 means fifteen percent |
| MySQL `TIMESTAMP` columns | Auto-initialization defaults (`explicit_defaults_for_timestamp`) vary by version/config — declare defaults explicitly rather than relying on them |
| Precision beyond microseconds, or dates before 4713 BC | Standard timestamp types cannot hold them; store as text/numeric with documented format |
| Changing a column's type on a large live table | Most changes rewrite the table under a lock. Add new column → backfill in batches → swap reads → drop old, same shape as a live rename ([databases-schema-design-naming-conventions]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Store money in `FLOAT`/`DOUBLE` | Minor-unit integer or `NUMERIC` | Binary floats accumulate rounding error in sums |
| Store timestamps as epoch integers or formatted strings | Native timestamp type in UTC | You lose comparison operators, timezone math, and validity checking |
| Add `VARCHAR(255)` as the reflex string type | `TEXT` (PostgreSQL) or a limit from the actual domain (MySQL) | 255 is cargo cult; arbitrary limits reject real data or hide the real rule |

## Sources

- https://www.postgresql.org/docs/current/datatype.html — type semantics
- https://wiki.postgresql.org/wiki/Don%27t_Do_This — community-maintained type pitfalls (money/float, varchar(n), timestamp vs timestamptz)
- https://dev.mysql.com/doc/refman/8.0/en/data-types.html — MySQL type ranges and TIMESTAMP behavior
