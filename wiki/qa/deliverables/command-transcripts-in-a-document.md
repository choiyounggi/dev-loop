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
last_verified: 2026-08-08
related:
  [
    qa-deliverables-generated-artifacts-as-deliverable-source,
    qa-document-verification-spec-document-gates,
    platforms-processes-tool-diagnostics-without-a-failing-exit-code,
    platforms-processes-non-interactive-cli-invocation,
  ]
---

# A Pasted CLI Transcript Inside a Document

## When this applies

You are putting a captured command run — an RFC's worked example, a README
quickstart, a design doc's "here is what it prints" — into a document, and the
transcript shows both the program's output and its diagnostics. Also when a
reviewer re-runs a documented example and gets a different order or extra lines.

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

## Edge cases

| Case | Then |
|------|------|
| The tool writes everything to one stream by design | Say so in the document and show one block; the rule is about not *merging* two streams, not about splitting one |
| The tool changes its output when it is not attached to a terminal (colour, progress bars, plain-vs-rich format) | Capture the form your reader will get, name which one it is, and keep the capture command in the document ([platforms-processes-non-interactive-cli-invocation]) |
| The transcript is long and you abridge it | Mark the elision (`…`) at the point it happens; an unmarked cut reads as complete output and is what makes a later-added block go unnoticed |
| The output contains timings, temp paths, or ids that change per run | Replace them with a stable placeholder and say the substitution was made, so a re-runner diffs the shape rather than the values |
| The document is generated from the run | Re-run the generator instead of editing the block ([qa-deliverables-generated-artifacts-as-deliverable-source]) |
| A gate greps the transcript block | Anchor it on the stream label and the command line, not on line adjacency between the two streams ([qa-document-verification-spec-document-gates]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Paste a `cmd 2>&1` capture as the record of what the program prints | Capture the two streams separately and paste two labelled blocks | With stdout to a pipe the C runtime makes it fully buffered while stderr is not, so the merged order is the environment's flush order, not the program's write order |
| Reuse a transcript captured earlier in the same piece of work | Re-run and re-capture at paste time | Output added between capture and paste is absent from a block the document presents as measured, and nothing in the block shows the omission |
| Argue an ordering claim ("the diagnostic comes after the result") from a merged block | State the claim about the streams and show them separately | The same binary produces both orders depending on whether stdout is a pipe or a tty — the merged block cannot support either claim |
| Reproduce the transcript once by hand and call it verified | Re-run it under the reader's conditions (piped, unbuffered, and on a tty) and reconcile | A single capture cannot distinguish a program-order claim from a buffering artefact |

## Sources

- https://pubs.opengroup.org/onlinepubs/9799919799/functions/stdin.html — "When opened, `stderr` shall not be fully buffered"; "`stdout` shall be fully buffered if and only if the file descriptor associated with the stream is determined not to be associated with an interactive device" — redirecting a transcript into a pipe or file changes stdout's buffering and therefore the interleaving, while stderr's is unchanged
- https://docs.python.org/3/using/cmdline.html — `-u`: "Force the stdout and stderr streams to be unbuffered"; `PYTHONUNBUFFERED` "is equivalent to specifying the `-u` option"
- https://docs.python.org/3/library/doctest.html — doctest "executes those sessions to verify that they work exactly as shown" (the executable-transcript mechanism), and "Output to stdout is captured, but not output to stderr"
- https://google.github.io/styleguide/docguide/best_practices.html — "Change your documentation in the same CL as the code change" — the capture-at-paste-time rule applied to transcripts
- Local reproduction 2026-08-08 (CPython 3.13, macOS), one program printing `STDOUT-1, STDERR-1, STDOUT-2, STDERR-2` in that order: through a pipe (`2>&1 | cat`) the merged capture came out `STDERR-1, STDERR-2, STDOUT-1, STDOUT-2` — stdout fully buffered, flushed at exit; the same command with `python -u` gave the program's order; and with both streams on a pty (`pty.openpty()`) it also gave the program's order. Three environments, two different documented orders, one unchanged program
- Field incident 2026-08-07 (`linkly`, RFC-0022 draft): a `build --run` transcript stated the reverse of the real diagnostic/output ordering and omitted a `validation-sample-derived` block added two tasks after the capture, with no elision mark. A reviewer re-running under `python -u` and a pty found both; rewritten with the streams separated, all four transcripts in the RFC then matched their re-runs byte for byte
