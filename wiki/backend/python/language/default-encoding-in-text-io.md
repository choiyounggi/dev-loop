---
id: backend-python-language-default-encoding-in-text-io
domain: backend
category: language
applies_to: [python]
confidence: verified
sources:
  - https://peps.python.org/pep-0597/
  - https://peps.python.org/pep-0686/
  - https://docs.python.org/3/library/functions.html
last_verified: 2026-08-07
related:
  [
    backend-python-language-bytecode-cache-staleness,
    platforms-environment-timezone-and-locale,
    testing-quality-tests-that-cannot-fail,
    testing-quality-minimum-case-set,
  ]
---

# Text I/O Whose Encoding Comes from the Machine's Locale

## When this applies

Python code opens a text file without `encoding=` — `open(p)`, `open(p, "w")`,
`Path.read_text()`, `csv`/`json` wrappers built on them — and you are adding the
argument, or writing the regression test that keeps it there. Also when a
file-writing bug reproduces on one machine (Windows, a `LANG=C` container, a
cp949/cp932 desktop) and not on yours.

Timezone and locale as hidden inputs generally →
[platforms-environment-timezone-and-locale].

## Do this

1. **Pass `encoding=` at every text-mode call site.** The default is the
   machine's: "The default encoding is platform dependent (whatever
   `locale.getencoding()` returns)". Choose the value from what the file is:

| The file is                                                           | Pass                                                                                                                  |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| A format with a defined encoding (JSON, TOML, YAML, Markdown, source) | `encoding="utf-8"`                                                                                                    |
| Written and read only by this program                                 | `encoding="utf-8"`                                                                                                    |
| Produced by a tool bound to the OS console encoding, deliberately     | `encoding=locale.getencoding()`, stated explicitly so the dependency is visible                                       |
| Raw bytes                                                             | Binary mode with no `encoding` — "For reading and writing raw bytes use binary mode and leave _encoding_ unspecified" |

2. **Make the regression test run the real entry point under the interpreter's
   own diagnostic, and assert zero warnings naming the file you fixed:**

   ```sh
   python3 -X warn_default_encoding -W always::EncodingWarning <entrypoint> <args>
   ```

   `EncodingWarning` "is emitted when the `encoding` argument to `open()` is
   omitted and the default locale-specific encoding is used", and the flag (or
   `PYTHONWARNDEFAULTENCODING`) is what enables it. Filter the captured stderr
   to the file under test by name, so unfixed call sites elsewhere in the
   codebase do not redden this test.

3. **Assert on the warning lines, not on the produced bytes.** The warning is
   emitted at the call site regardless of what the locale happens to be, so it
   is the same verdict on your laptop and in CI.

4. **Keep the flag on the test invocation only.** Without `-X
warn_default_encoding` the warning is silent, so a suite that forgets the flag
   passes on the reintroduced defect — assert the flag is present by requiring
   the harness to redden on a deliberately unencoded `open()` before trusting it
   ([testing-quality-tests-that-cannot-fail]).

5. **Enable the flag repo-wide in CI once the call sites are clean**, so a new
   omission is caught where it is written rather than at the next locale change.

## Edge cases

| Case                                                                               | Then                                                                                                                                                            |
| ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The entry point is a library function, not a script                                | Run it through a one-line driver under the same flags; the warning is attributed to the frame that called `open()`, so the driver's own lines do not mask it    |
| A dependency emits `EncodingWarning` from its own files                            | Filter by filename as in step 2 and record the dependency in the test's name, so the filter states what it is excluding                                         |
| The code targets Python 3.15 or later, where UTF-8 mode is on by default (PEP 686) | Keep the explicit `encoding=`: the argument states the file's contract and is what makes the call correct under an inherited `PYTHONUTF8=0` or an older runtime |
| Running under `PYTHONUTF8=1` / UTF-8 mode already                                  | The warning still fires on the omitted argument, so the test keeps working; the mode changes the value used, not whether the argument was passed                |
| `subprocess` output is being decoded                                               | The same default applies to its text mode — pass `encoding="utf-8"` there, and include it in the call-site sweep                                                |
| The harness rewrites the file between runs to seed the missing-`encoding` mutation | Clear the bytecode cache between iterations ([backend-python-language-bytecode-cache-staleness])                                                                |

## Instead of

| If you are about to                                                                     | Do this instead                                                                       | Why                                                                                                                                                                                              |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Prove the fix with a round-trip assertion (write non-ASCII text, read it back, compare) | Assert zero `EncodingWarning` lines naming the file, under `-X warn_default_encoding` | On a UTF-8 locale the encoded bytes are identical with and without the argument, so the round-trip passes on the defect; it can only fail on a machine you are not testing on                    |
| Assert the output file's declared charset (`<meta charset>`, an XML declaration)        | Assert the warning count                                                              | A declaration is a literal in the template — it is written correctly by code that encoded the body wrongly                                                                                       |
| Set `LANG`/`PYTHONUTF8` in the test environment to make the behavior deterministic      | Fix the call sites and assert the warning                                             | Pinning the environment makes the test pass by removing the input the defect depends on, so the defect ships and fails on the machines that do not inherit that environment                      |
| Read "it works on macOS and Linux" as evidence the encoding is right                    | Run the warning check                                                                 | PEP 686: "many Python developers using Unix forget that the default encoding is platform dependent … Inconsistent default encoding causes many bugs"; "this change mostly affects Windows users" |

## Sources

- https://peps.python.org/pep-0597/ — `EncodingWarning` "is emitted when the `encoding` argument to `open()` is omitted and the default locale-specific encoding is used"; "The `-X warn_default_encoding` option and the `PYTHONWARNDEFAULTENCODING` environment variable are added. They are used to enable `EncodingWarning`"; "When the flag is set, `io.TextIOWrapper()`, `open()` and other modules using them will emit `EncodingWarning` when the `encoding` argument is omitted"; "Developers using macOS or Linux may forget that the default encoding is not always UTF-8"
- https://peps.python.org/pep-0686/ — enabling UTF-8 mode by default targets Python 3.15; "many Python developers using Unix forget that the default encoding is platform dependent. They omit to specify `encoding="utf-8"` … Inconsistent default encoding causes many bugs"; "Most Unix systems use UTF-8 locale … So this change mostly affects Windows users"
- https://docs.python.org/3/library/functions.html — `open()`: "The default encoding is platform dependent (whatever `locale.getencoding()` returns)"; "In text mode, if _encoding_ is not specified the encoding used is platform-dependent"; "For reading and writing raw bytes use binary mode and leave _encoding_ unspecified"
- Reproduction 2026-08-07 (CPython 3.14.6, macOS, `locale.getpreferredencoding(False) == 'UTF-8'`): a script with one `open(p, "w")` and one `open(p, "w", encoding="utf-8")` produced byte-identical output — a round-trip assertion cannot distinguish them. `python3 -X warn_default_encoding -W always::EncodingWarning script.py out.txt` emitted exactly one line, naming the unencoded call by file and line number; the same run without the flag emitted nothing
