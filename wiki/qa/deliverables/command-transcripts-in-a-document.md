---
id: qa-deliverables-command-transcripts-in-a-document
domain: qa
category: deliverables
applies_to: [general]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9799919799/functions/stdin.html
  - https://docs.python.org/3/using/cmdline.html
  - https://docs.python.org/3/library/doctest.html
  - https://google.github.io/styleguide/docguide/best_practices.html
  - https://github.com/npm/cli/blob/latest/docs/lib/content/configuring-npm/package-json.md
  - https://docs.npmjs.com/policies/unpublish
  - https://www.rfc-editor.org/rfc/rfc5737.txt
  - https://tailscale.com/docs/reference/ip-pool
last_verified: 2026-11-04
related:
  [
    qa-deliverables-generated-artifacts-as-deliverable-source,
    qa-document-verification-spec-document-gates,
    platforms-processes-tool-diagnostics-without-a-failing-exit-code,
    platforms-processes-non-interactive-cli-invocation,
    security-data-commit-identity-in-public-repos,
    qa-process-session-identity-leak-in-plugin-prose,
  ]
---

# A Pasted CLI Transcript Inside a Document

## When this applies

You are putting a captured command run — an RFC's worked example, a README
quickstart, a design doc's "here is what it prints" — into a document, and the
transcript shows both the program's output and its diagnostics. Also when a
reviewer re-runs a documented example and gets a different order or extra lines,
and when the captured run printed values from your own environment (server or
tailnet addresses, hostnames, account names, keys) and the document will be
published — a public repository, or a README that ships in a package.

## Do this

1. **Re-capture the transcript from the current tree immediately before the
   paste lands.** A transcript captured earlier in the work describes the build
   at capture time; anything added since is missing from a block presented as a
   measurement. Capture and paste in the same step, and record the commit and
   the exact command line above the block.
2. **Give each stream its own block, labelled.** Capture them separately —
   `cmd >out.txt 2>err.txt` — and paste `out.txt` and `err.txt` as two blocks.
   The document then states what the program produced on each stream, which is a
   property of the program.
3. **When the document's point is the ordering** (a diagnostic must appear
   before/after a result), state the ordering as a sentence about the streams
   and show the two blocks, rather than showing one merged block as the proof.
4. **Force unbuffered output for any transcript you do capture merged**
   (`python -u`, `PYTHONUNBUFFERED=1`, `stdbuf -o0 -e0`) and say in the document
   that it was captured that way, so a reader who re-runs it plainly and sees a
   different order knows why.
5. **Make the transcript executable where the toolchain has a mechanism for it**
   — `doctest`, rustdoc doctests, a snippet-extraction test. An executed
   transcript cannot go stale silently. Note that `doctest` checks stdout only:
   "Output to stdout is captured, but not output to stderr", so a merged block
   is not checkable by it either.
6. **Replace every environment value in the transcript with a documentation
   value before the commit, then search for the real ones.** Addresses become
   RFC 5737 documentation addresses (`192.0.2.10`, `198.51.100.0/24`,
   `203.0.113.0/24`); accounts and hosts become obvious stand-ins (`account-a`,
   `router.example`). Then run `git grep -n -F '<real value>'` once per real
   address, hostname, and account name you replaced, and require zero hits
   across the whole tree before committing — a transcript is often pasted into
   more than one file (README, docs page, changelog).

## Edge cases

| Case | Then |
|------|------|
| The tool writes everything to one stream by design | Say so in the document and show one block; the rule is about not *merging* two streams, not about splitting one |
| The tool changes its output when it is not attached to a terminal (colour, progress bars, plain-vs-rich format) | Capture the form your reader will get, name which one it is, and keep the capture command in the document ([platforms-processes-non-interactive-cli-invocation]) |
| The transcript is long and you abridge it | Mark the elision (`…`) at the point it happens; an unmarked cut reads as complete output and is what makes a later-added block go unnoticed |
| The output contains timings, temp paths, or ids that change per run | Replace them with a stable placeholder and say the substitution was made, so a re-runner diffs the shape rather than the values |
| The document is generated from the run | Re-run the generator instead of editing the block ([qa-deliverables-generated-artifacts-as-deliverable-source]) |
| A gate greps the transcript block | Anchor it on the stream label and the command line, not on line adjacency between the two streams ([qa-document-verification-spec-document-gates]) |
| The example needs an address that looks like a Tailscale/CGNAT one (`100.x.y.z`) | Use an RFC 5737 address and say it stands in for a tailnet address. Tailscale gives devices addresses from all of 100.64.0.0/10, so a "made-up" `100.64.0.10` is an address a real device can hold |
| The README belongs to an npm package | Run the step 6 search before `npm publish` as well as before the commit. npm always packs `README` "regardless of settings", even when `files` leaves it out, and a published `name@version` cannot be changed or reused — a leaked value stays in that version until it is unpublished |
| A real value is already in a pushed commit, a tag, or a published package | Treat it as disclosed: fix the current tree, then decide on history rewrite or unpublish ([security-data-commit-identity-in-public-repos]). To find every copy, search each tag (`git grep -F '<value>' <tag>`) and each published tarball, not only the current tree |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Paste a `cmd 2>&1` capture as the record of what the program prints | Capture the two streams separately and paste two labelled blocks | With stdout to a pipe the C runtime makes it fully buffered while stderr is not, so the merged order is the environment's flush order, not the program's write order |
| Reuse a transcript captured earlier in the same piece of work | Re-run and re-capture at paste time | Output added between capture and paste is absent from a block the document presents as measured, and nothing in the block shows the omission |
| Argue an ordering claim ("the diagnostic comes after the result") from a merged block | State the claim about the streams and show them separately | The same binary produces both orders depending on whether stdout is a pipe or a tty — the merged block cannot support either claim |
| Reproduce the transcript once by hand and call it verified | Re-run it under the reader's conditions (piped, unbuffered, and on a tty) and reconcile | A single capture cannot distinguish a program-order claim from a buffering artefact |
| Paste a real run's output into a README as-is because it is "only an example" | Swap in documentation values (step 6) and search the tree for each real value before committing | A README travels further than the repo: every tag archive and every npm version packs it, and none of those copies can be edited afterwards |

## Sources

- https://pubs.opengroup.org/onlinepubs/9799919799/functions/stdin.html — "When opened, `stderr` shall not be fully buffered"; "`stdout` shall be fully buffered if and only if the file descriptor associated with the stream is determined not to be associated with an interactive device" — redirecting a transcript into a pipe or file changes stdout's buffering and therefore the interleaving, while stderr's is unchanged
- https://docs.python.org/3/using/cmdline.html — `-u`: "Force the stdout and stderr streams to be unbuffered"; `PYTHONUNBUFFERED` "is equivalent to specifying the `-u` option"
- https://docs.python.org/3/library/doctest.html — doctest "executes those sessions to verify that they work exactly as shown" (the executable-transcript mechanism), and "Output to stdout is captured, but not output to stderr"
- https://google.github.io/styleguide/docguide/best_practices.html — "Change your documentation in the same CL as the code change" — the capture-at-paste-time rule applied to transcripts
- https://github.com/npm/cli/blob/latest/docs/lib/content/configuring-npm/package-json.md — `files`: "Certain files are always included, regardless of settings", listing `package.json`, `README`, `LICENSE / LICENCE`, and the `main` and `bin` files
- https://docs.npmjs.com/policies/unpublish — "Registry data is immutable, meaning once published, a package cannot change"; a name and version cannot be reused even after unpublishing
- https://www.rfc-editor.org/rfc/rfc5737.txt — 192.0.2.0/24, 198.51.100.0/24 and 203.0.113.0/24 "are provided for use in documentation"
- https://tailscale.com/docs/reference/ip-pool — devices get addresses from the RFC 6598 CGNAT range 100.64.0.0/10, so an example in that range can belong to a real device
- Field incident 2026-11 (a proxy CLI's README): an onboarding transcript kept the real router address on 3 lines. `git log -G` and a per-tag `git grep` found it in tags v0.2.0–v0.4.1, and it was also in the npm 0.4.0 and 0.4.1 tarballs. Only the current tree had 0 hits
- Local reproduction 2026-08-08 (CPython 3.13, macOS), one program printing `STDOUT-1, STDERR-1, STDOUT-2, STDERR-2` in that order: through a pipe (`2>&1 | cat`) the merged capture came out `STDERR-1, STDERR-2, STDOUT-1, STDOUT-2` — stdout fully buffered, flushed at exit; the same command with `python -u` gave the program's order; and with both streams on a pty (`pty.openpty()`) it also gave the program's order. Three environments, two different documented orders, one unchanged program
- Field incident 2026-08-07 (`linkly`, RFC-0022 draft): a `build --run` transcript stated the reverse of the real diagnostic/output ordering and omitted a `validation-sample-derived` block added two tasks after the capture, with no elision mark. A reviewer re-running under `python -u` and a pty found both; rewritten with the streams separated, all four transcripts in the RFC then matched their re-runs byte for byte
