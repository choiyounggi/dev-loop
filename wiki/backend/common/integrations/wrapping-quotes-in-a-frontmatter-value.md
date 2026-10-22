---
id: backend-common-integrations-wrapping-quotes-in-a-frontmatter-value
domain: backend
category: integrations
applies_to: [general, javascript, python]
confidence: verified
sources:
  - https://yaml.org/spec/1.2.2/#733-plain-style
  - https://yaml.org/spec/1.2.2/#732-single-quoted-style
  - https://yaml.org/spec/1.2.2/#731-double-quoted-style
  - https://github.com/jonschlinkert/gray-matter
  - "Local reproduction 2026-10-09 (Node v26.7.0, PyYAML 6.0.3 on Python 3.13.1, js-yaml 5.4.3): naive and paired quote-strip regexes vs two YAML parsers on nine values"
  - "Field case 2026-10-09 (a blog-publishing script whose hand-parsed frontmatter titles ended in an unpaired quote)"
last_verified: 2026-10-09
related: [testing-quality-anchor-cases-for-allowlist-regexes]
---

# Removing the Wrapping Quotes From a Frontmatter or Config Value

## When this applies

Code reads a value out of YAML frontmatter or a `key: value` config line by hand
(split on the first `:`, then a regex) and removes the quotes around it — a post
title, a description, a label. Also when a published title or stored value ends
in a stray `"` or `'` that the source file did not seem to have.

## Do this

1. **Read the block with a YAML parser.** gray-matter (Node) uses js-yaml by
   default; in Python use `yaml.safe_load`. The parser removes the quotes and
   applies the escapes: `''` inside single quotes, `\"` inside double quotes.
2. **Turn a parse error into a message that names the file and the key.** A value
   that starts with a quote and keeps going after the closing quote
   (`title: "Quote" — subtitle`) is not valid YAML: a plain scalar cannot begin
   with `"` or `'`, so the parser reads a quoted scalar and then fails on the
   extra text. Fix the source, not the reader: quote the whole value
   (`title: '"Quote" — subtitle'`).
3. **When a parser cannot be added, remove a pair or nothing.** Strip only when
   the value starts and ends with the same quote character:
   `v.replace(/^(["'])(.*)\1$/s, "$2")`. A regex with one alternative per end
   removes each end on its own.
4. **Test the stripper with these values:** a value that starts but does not end
   with a quote, mismatched quotes (`"mixed'`), a lone `"`, the empty string, and
   two quoted parts (`"a" and "b"`).

| Value | Per-end regex `/^["']\|["']$/g` | Paired regex (step 3) | YAML parser |
|-------|------------------------------|-----------------------|-------------|
| `"Quoted"` | `Quoted` | `Quoted` | `Quoted` |
| `"인용구" — 부제` | `인용구" — 부제` (unpaired `"`) | unchanged | parse error |
| `"mixed'` | `mixed` | unchanged | parse error |
| `"a" and "b"` | `a" and "b` | `a" and "b` | parse error |
| `say "hi"` | `say "hi` | unchanged | `say "hi"` |
| `'it''s'` | `it''s` | `it''s` | `it's` |

## Edge cases

| Case | Then |
|------|------|
| The value starts and ends with the same quote but holds two quoted parts (`"a" and "b"`) | The paired regex still removes the outer pair and returns `a" and "b`. Only a parser tells one quoted value from two, so use step 1 wherever such values can occur |
| The value carries YAML escapes (`''`, `\"`, `\n`) | A regex leaves them as typed. Undo them yourself, or use a parser |
| Wrong values were already published or stored | Re-parse each source file with the parser and compare with the stored value; the per-end regex leaves a trailing `"` or `'` with no partner, which you can grep for in the stored copies |
| The line carries a trailing comment (`title: "x" # note`) | The paired regex returns it unchanged, quotes included; a YAML parser drops the comment and returns `x` |
| The frontmatter is TOML (`+++`) or JSON | Use that format's parser. TOML quoting has its own rules and multi-line forms |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `replace(/^["']\|["']$/g, "")` | Read the value with a YAML parser (step 1), or use the paired regex (step 3) | Each alternative is anchored to one end, so a value quoted at only one end loses that quote and keeps the other |
| Make the reader accept `title: "Quote" — subtitle` | Report the parse error and quote the whole value in the source | Other YAML tools reject the same file; a reader that accepts it hides the problem until the file meets one of them |

## Sources

- https://yaml.org/spec/1.2.2/#733-plain-style — "Plain scalars must not begin with most indicators, as this would cause ambiguity with other YAML constructs"; production `[126] ns-plain-first(c)` excludes `c-indicator`, which includes `"` and `'`
- https://yaml.org/spec/1.2.2/#732-single-quoted-style — "within a single-quoted scalar, such characters need to be repeated. This is the only form of escaping performed in single-quoted scalars" (`[117] c-quoted-quote ::= "''"`)
- https://yaml.org/spec/1.2.2/#731-double-quoted-style — "This is the only style capable of expressing arbitrary strings, by using "\" escape sequences"
- https://github.com/jonschlinkert/gray-matter — "By default, gray-matter is capable of parsing YAML, JSON and JavaScript front-matter", with YAML linked to js-yaml
- Local reproduction 2026-10-09: the table above. PyYAML 6.0.3 raised `ParserError` ("expected <block end>, but found '<scalar>'") and js-yaml 5.4.3 raised "bad indentation of a mapping entry" for `title: "인용구" — 부제` and `title: "a" and "b"`; both parsed `title: say "hi"` and `title: 'it''s'` correctly; PyYAML returned `x` for `title: "x" # comment`
- Field case 2026-10-09: a publishing script stripped titles with the per-end regex. All four published posts whose frontmatter title began with `"` had a title ending in an unpaired `"` in the publish log, found by comparing the log with the source files using `jq` and `grep`
