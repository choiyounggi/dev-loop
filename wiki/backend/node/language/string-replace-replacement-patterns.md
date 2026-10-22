---
id: backend-node-language-string-replace-replacement-patterns
domain: backend
category: language
applies_to: [node, javascript, typescript]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replace
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replaceAll
  - https://tc39.es/ecma262/#sec-getsubstitution
last_verified: 2026-10-15
related: [infrastructure-config-config-values-emitted-as-source-text]
---

# Inserting Text You Did Not Write With `String.prototype.replace`

## When this applies

A JavaScript/TypeScript script (a codemod, a fixture or snippet paster, a
template filler, a build step) splices a piece of text it did not author —
SQL, shell, a test fixture, user input, file contents — into a file or string
with `str.replace(from, to)`, `str.replaceAll(from, to)`, or a regex pattern.

## Do this

1. **Pass the inserted text through a replacer function:**
   `str.replace(from, () => to)`. The function's return value is inserted as-is;
   MDN states the special replacement patterns do not apply to strings returned
   from the replacer function.
2. **Assert the result contains the inserted text verbatim** before writing it:
   `if (!out.includes(to)) throw new Error('splice changed the text')`.
3. **After writing, compare `$`-sequences in source and output** (`grep -c '\$\$'`
   or the same count for `$&`) when the inserted text is a language that uses
   `$` (plpgsql `$$` bodies, shell, Perl, PHP, jQuery code, regexes).

A replacement **string** is a template, even when `from` is a plain string with
no regex meaning (MDN, "Specifying a string as the replacement"; ECMAScript
`GetSubstitution`):

| In the replacement string | Inserts |
|---------------------------|---------|
| `$$` | one `$` |
| `$&` | the matched substring |
| `` $` `` | the text before the match |
| `$'` | the text after the match |
| `$n` / `$<name>` | capture group n / named group (regex patterns only; otherwise left literal) |

## Edge cases

| Case | Then |
|------|------|
| `replaceAll` or a regex with the `g` flag | Same template rules on every match — use the replacer function there too |
| A string `from` (no captures) | `$1` stays literal, but `$$`, `$&`, `` $` ``, `$'` still expand — the failure is silent |
| plpgsql function body `AS $$ ... $$` inserted with a string replacement | Becomes `AS $ ... $`; Postgres rejects it with SQLSTATE 42601 `syntax error at or near "$"`, far from the script that caused it |
| You need every occurrence replaced literally and want no callback | `str.split(from).join(to)` — no template processing; replaces all occurrences, not only the first |
| You must keep a string replacement (an API that only accepts strings) | Escape first: `to.replaceAll('$', '$$$$')` — each `$$` in that replacement emits one `$` — and add the step-2 assertion |
| The inserted text contains no `$` today | Still use the function form: the next fixture or snippet may contain one |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `src.replace(marker, snippet)` with a snippet from a person, a file, or another tool | `src.replace(marker, () => snippet)` | `$$`, `$&`, `` $` ``, `$'` in the snippet are rewritten without an error |
| Trust that a string `from` means "literal mode" | Treat only the replacer function as literal mode | Literal matching applies to `from`; the replacement string is still a template |
| Debug the downstream parse error (SQL, shell) first | Diff the inserted text against its source | The corruption happened at the splice, not in the consumer |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replace — the replacement-patterns table (`$$`, `$&`, `` $` ``, `$'`, `$n`, `$<Name>`); a function replacement is invoked per match and its return value is used as the replacement; the special patterns do not apply to strings returned from the replacer function
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replaceAll — the replacement has the same semantics as `replace()`
- https://tc39.es/ecma262/#sec-getsubstitution — the spec operation that expands the replacement template for `String.prototype.replace` and `RegExp.prototype[Symbol.replace]`
- Field evidence 2026-10-15 (Next.js + Prisma app, orchestrated worker task): a Node script pasted an auditor-supplied test fixture containing a plpgsql `AS $$ ... $$` body with `str.replace(from, to)`; the test failed with Postgres 42601 `syntax error at or near "$"`. Redoing the splice so the text was inserted verbatim made the suite pass 6/6
