---
id: platforms-environment-unicode-text-matching
domain: platforms
category: environment
applies_to: [general]
confidence: verified
sources:
  - https://unicode.org/reports/tr15/
  - https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-3/
  - https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html
last_verified: 2026-07-30
related: [platforms-environment-timezone-and-locale, platforms-filesystems-paths-case-and-line-endings, qa-document-verification-spec-document-gates]
---

# Matching Non-ASCII Text with grep and Regex

## When this applies

You are writing a grep/regex pattern that must match non-ASCII text (Korean,
Japanese, accented Latin, emoji) in files, log lines, or file names; a pattern that
looks correct returns zero hits on text you can see on screen; a search works on one
machine and misses on another after the file crossed an OS, archive, or editor boundary.

## Do this

| Case | Do |
|------|----|
| Writing a literal pattern | Copy the exact substring out of the file rather than typing a stem you expect to be a prefix. In a precomposed script each syllable is a single code point: `아니` (`U+C544 U+B2C8`) is not contained in `아닌` (`U+C544 U+B2CC`), so a stem-prefix pattern returns 0 hits on a line that plainly contains the word |
| The word occurs in several inflected forms | Enumerate the forms as alternatives — `(아닌\|아니다\|아니라)` — one alternative per surface form present in the text |
| Pattern and data can come from different producers (editor, export, archive, another OS) | Normalize both sides to the same form before comparing (NFC for stored text), because `grep` matches code-unit sequences and applies no canonical equivalence: an NFC pattern scores 0 against the same word stored as NFD |
| The match result gates a build, release, or verification checklist | Assert an expected non-zero count rather than "no error", so a normalization or stem mistake surfaces as a failed count ([qa-document-verification-spec-document-gates]) |
| Comparing file names collected on macOS and Linux | Normalize both name lists in your code before diffing: APFS preserves the normalization it was given and looks up either form, HFS+ stores its own normalized form, and Linux filesystems store the bytes given — so the same name reaches your comparison in different forms |

Measured on macOS 15 / APFS, 2026-07-30 (`grep` 2.6.0-FreeBSD, Python 3.13):

```
grep -c '아니' <NFC file>            → 0     # same line contains 아닌
grep -c '아닌' <NFC file>            → 1
grep -c -f <NFC pattern> <NFD file>  → 0     # no normalization by grep
grep -c -f <NFD pattern> <NFD file>  → 1
len('아닌') NFC = 2 code points, NFD = 5     # jamo L+V+T decomposition
```

## Edge cases

| Case | Then |
|------|------|
| The pattern must survive both normalization forms | Match on a substring that contains no combining sequence (an ASCII token, an id, a number), or normalize the input through a filter before grep |
| A pattern with a character class or quantifier over non-ASCII text | Test the exact pattern against a known-matching line first: BSD and GNU regex engines differ in multi-byte class handling, so a class that works on one userland can misfire on the other ([platforms-tools-bsd-vs-gnu-cli]) |
| Zero hits and the cause is unclear | Print the code points of both the pattern and the target line (`python3 -c "print([hex(ord(c)) for c in open(f).read()])"`) before concluding the text is missing — it separates "word absent" from "different code points" |
| The text is user-supplied and used as a key or a dedup identifier | Normalize to NFC at the trust boundary on write, so later equality and search compare one form |
| The search happens inside a database rather than a file | Normalization is applied by the writer, not the engine — same rule: normalize on write, search the stored form |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write a stem prefix (`아니`) expecting it to match its inflections | Copy the literal form present in the text, or enumerate the alternatives | Precomposed syllables are distinct code points, so the stem is not a substring of the inflected word |
| Read a 0-hit grep as "the requirement is absent from the document" | Compare the code points of the pattern and the line before acting | 0 hits also means "different normalization form" or "different syllable" — an absence conclusion from that is a false negative |
| Compare two file-name lists byte-for-byte across machines | Normalize both lists to NFC in code, then diff | Producers store different forms of the same name; APFS lookup hides this locally but a byte diff does not |

## Sources

- https://unicode.org/reports/tr15/ — normalization forms; Hangul syllables have special full-decomposition rules; canonically equivalent strings have different binary representations unless normalized
- https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-3/ — §3.12 Conjoining Jamo Behavior: 11,172 precomposed Hangul syllables from `SBase = U+AC00` decompose algorithmically into L/V/T jamo
- https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html — APFS preserves the file name's normalization and is normalization-insensitive via hashes of the normalized form; HFS+ stores the normalized form
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html — grep matches patterns against input lines by the specified regular-expression rules; no canonical-equivalence folding is specified
