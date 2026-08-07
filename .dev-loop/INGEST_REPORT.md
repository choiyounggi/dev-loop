# Knowledge flush — 5 candidates → 2 ingested, 3 dropped

Queue: `~/.dev-loop/queue/` held 5 pending rows across 2 session files
(`dc029c0c…` — 2 qa rows from the `fix-i55-modeb` worktree; `f1a3ae46…` — 3
infrastructure rows from the `linkly` orchestration session).

## Verified best-practice

### 1. A doc gate over a copied table must resolve the owning code constant → `verified`

**Claim.** When a document's table restates values owned by code (a severity map,
a schema enum, a config default), the gate must compare each cell against the
owning symbol. A gate that asserts the invariant the table itself states ("all
five are warnings") uses the document as both subject and oracle, so it stays
green after the constant moves — the check built to catch drift is what pins the
stale claim.

**How verified — local reproduction, 2026-08-08, `linkly` @ `fix/rerun-gaps`.**
Resolved every row of `docs/ENFORCEMENT-MATRIX.md` §C against
`lnpl.diagnostics.SEVERITY_OF` and printed the pairs:

```
ok       unknown-verb: documented='warning' code='warning'
MISMATCH declared-not-enforced: documented='warning' code='info'
MISMATCH declared-measured-only: documented='warning' code='info'
MISMATCH authorization-not-verified: documented='warning' code='info'
ok       guard-skipped-steps: documented='warning' code='warning'
```

The document's severity column reads `warning` in all five rows and its prose
says so outright ("전부 `warning`이고"), so the self-referential form of the check
passes on exactly this pair; the constant grades three of them `info`. The same
column in the plugin's `references/declarations.md`, which is *generated* from the
constant, agreed — the drift is specific to the hand-maintained copy. The
repo's own `impl/tests/test_plugin_references.py:96` already records the
corrected form ("against `SEVERITY_OF` itself, which is the only comparison
that…"), which is independent confirmation of the directive rather than of my
reproduction alone.

**Sources checked.**
- https://google.github.io/styleguide/docguide/best_practices.html — "Change your
  documentation in the same CL as the code change"; where a fact lives elsewhere,
  "Link to it instead" of restating it. Supports the external-agreement axis as
  the enforcement mechanism when a table restates the fact anyway. (Fetched
  2026-08-08.)
- Already on the target page and re-used, not re-fetched:
  https://testing.googleblog.com/2021/04/mutation-testing.html (a check is
  measured by whether a planted defect makes it fail),
  https://eslint.org/docs/latest/extend/custom-rule-tutorial (a checker needs a
  must-pass and a must-fail case).

### 2. Re-capture CLI transcripts at paste time; give each stream its own block → `verified`

**Claim.** A transcript pasted into a document must be re-captured from the
current tree at paste time, and stdout/stderr must appear as two labelled blocks.
A `2>&1` capture records the environment's flush order, not the program's write
order.

**How verified — local reproduction, 2026-08-08, CPython 3.13 / macOS.** One
program printing `STDOUT-1, STDERR-1, STDOUT-2, STDERR-2` in that order, captured
three ways:

| Capture | Recorded order |
|---------|----------------|
| `python prog.py 2>&1 \| cat` | `STDERR-1, STDERR-2, STDOUT-1, STDOUT-2` — **reversed** |
| `python -u prog.py 2>&1 \| cat` | program order |
| both streams on a pty (`pty.openpty()`) | program order |

One unchanged binary, three environments, two different documented orders — so a
merged block cannot support an ordering claim in either direction.

**Sources checked (all fetched 2026-08-08).**
- https://pubs.opengroup.org/onlinepubs/9799919799/functions/stdin.html — "When
  opened, `stderr` shall not be fully buffered"; "`stdout` shall be fully buffered
  if and only if the file descriptor associated with the stream is determined not
  to be associated with an interactive device." This is the mechanism behind the
  table above.
- https://docs.python.org/3/using/cmdline.html — `-u`: "Force the stdout and
  stderr streams to be unbuffered"; `PYTHONUNBUFFERED` "is equivalent to
  specifying the `-u` option."
- https://docs.python.org/3/library/doctest.html — the executable-transcript
  mechanism ("executes those sessions to verify that they work exactly as
  shown"), and the constraint that makes stream separation matter for gating:
  "Output to stdout is captured, but not output to stderr."
- https://google.github.io/styleguide/docguide/best_practices.html — same-change
  documentation updates, applied to transcripts as capture-at-paste-time.

The staleness half is `field-tested` in origin (RFC-0022's `build --run`
transcript omitted a `validation-sample-derived` block added two tasks after
capture, with no elision mark) and is recorded in the page as a dated field
incident, distinct from the doc-sourced buffering half.

### 3–5. Three orchestration candidates → not verified here, dropped as pending duplicates

See **Open-PR check**. No confidence upgrade was applied to any of them; they were
retired from the queue unchanged because open PRs already carry them in equal or
better form.

## Existing-layer check

Routed via `INDEX.md` → `qa` ("automated verification of document deliverables")
and `infrastructure` ("multi-agent orchestration"), then read both domain indexes
and every page whose "load when" line overlapped.

Pages read: qa-document-verification-spec-document-gates,
qa-document-verification-editing-a-gated-document,
qa-deliverables-generated-artifacts-as-deliverable-source,
testing-quality-tests-that-cannot-fail,
platforms-processes-tool-diagnostics-without-a-failing-exit-code,
platforms-processes-non-interactive-cli-invocation,
infrastructure-agent-orchestration-worktree-isolated-workers,
infrastructure-agent-orchestration-pane-delivery-confirmation,
infrastructure-agent-orchestration-control-signals-vs-primary-artifacts,
infrastructure-agent-orchestration-shared-run-state

**Insight 1 — merged, not created.** `spec-document-gates` already owns the
trigger (automated checks deciding whether a spec document meets its
requirements) and already has a four-axis table. Its `Cross-reference` axis stops
at the document boundary — "assert that a statement in one section implies its
counterpart elsewhere, and recompute a derived value from its inputs" — so a
doc-vs-code comparison had no axis. Added a fifth axis row (`External
agreement`), four edge-case rows (summary invariants over a copied column;
checks that restate the expected values as their own literals; docs-only CI where
the owning code cannot be imported; a row present on one side only), one
`Instead of` row, one source, and the dated reproduction. **No conflict** — the
addition extends the axis table rather than contradicting any existing row.
`confidence` deliberately left at `field-tested`: the page's older four-axis
content is field-distilled, and the page-level field takes the lower of the two
rather than being upgraded on the strength of the new section alone.

**Insight 2 — new page.** No existing page carries the trigger. Closest
neighbours and why each is distinct:
- `generated-artifacts-as-deliverable-source` — hand-writing a document the repo
  already generates. A transcript is captured, not generated; overlaps only in
  the "re-run the generator" edge case, which the new page defers to it.
- `tool-diagnostics-without-a-failing-exit-code` — how a *harness* captures
  stderr from a tool that exits 0. Same streams, different consumer (a gate, not
  a reader), and it does not cover documents.
- `non-interactive-cli-invocation` — a TTY-detecting tool changing its output
  format under automation. The new page cites it from the edge-case table rather
  than restating it.
- `qa-deliverables-quantitative-claims-in-a-published-document` (in open PR #51,
  not merged) — numbers in a published document. Same drift mechanism, different
  claim shape; **flagged here rather than merged into**, because it does not exist
  on `main` and cross-PR edits are what caused the #17–#40 pile-up. If #51 lands
  first, the two pages should gain reciprocal `related:` links; neither
  contradicts the other.

Reciprocal `related:` links added both ways on
`generated-artifacts-as-deliverable-source`,
`tool-diagnostics-without-a-failing-exit-code`, and
`non-interactive-cli-invocation`; the qa index "load when" line for
`spec-document-gates` was widened to name the new axis so index and trigger stay
in agreement.

Lint (changed-page pass): 0 errors, 0 warnings — sources-vs-confidence,
prohibitions outside `Instead of`, related/inline id resolution, index presence
and trigger agreement, vague qualifiers, body length (62 and 85 body lines).

## Open-PR check

Listed with `gh pr list --repo choiyounggi/dev-loop --state open --search
"head:knowledge/"` — 12 open heads (#47, #49, #50, #51, #52, #55, #56, #57, #58,
#61, #62, #64). Fetched and diffed the three whose titles touched orchestration
or document gating.

| Candidate | Overlapping head | Verdict |
|-----------|------------------|---------|
| 1 — doc-as-spec gate vs code constant | none (checked #51, #56, #58, #61 — #51 touches qa/deliverables, not document-verification) | **new** |
| 2 — CLI transcripts, re-capture + split streams | none (#51 adds `quantitative-claims-in-a-published-document`, a different claim shape — see Existing-layer check) | **new** |
| 3 — `worktree_escape` fires `ask` on read-only cross-worktree reads; budget the escalation round trip | #51 `knowledge/dch0202-20260806-183029` | **drop** |
| 4 — Orca dispatch-binding taxonomy (`runtime_unavailable` vs `agent_unconfigured`; pass the worktree with the pane) | #51 same head | **drop** |
| 5 — tmux worker wedged on a numbered in-band chooser | #64 `knowledge/choiyounggi-20260808-004155` | **drop** |

Evidence for the three drops, from `git diff origin/main origin/<head> -- wiki/`:

- #51's `worktree-isolated-workers` hunk already carries the candidate's directive
  nearly verbatim — "Budget the round trip (read the recorded escalation →
  approve → clear `escalations/` → restart the watcher) and state in the worker's
  first brief that reads are approved and only writes outside the worktree are
  refused" — plus three rows my candidate did not have (sibling-worktree path
  survives the strip; a write verb anywhere on the line fires independently of
  what is read; redirect-to-absolute fires regardless), backed by a fuller
  reproduction against guardrails 1.2.0. Nothing unique to push.
- #51's `pane-delivery-confirmation` hunk carries the full taxonomy, including the
  `terminal_worktree_mismatch` resolution and the "a failed unit is replaced, not
  retried in place" consequence. Nothing unique to push.
- #64's new `unattended-worker-questions` page supersedes candidate 5: it adds the
  classify-by-terminal-tail table, the allowlisted-key protocol with the
  selection-then-confirmation caveat, the re-send-the-in-flight-prompt step, and
  the out-of-band question channel the candidate only gestured at. Nothing unique
  to push.

This trio has now re-entered the queue on several consecutive flushes. Merging
#51 and #64 retires it at the source.

## Routing decision

| Insight | Domain / category / page | New category? |
|---------|--------------------------|---------------|
| 1 — doc gate resolves the owning code constant | `qa` / `document-verification` / **merged into** `spec-document-gates.md` (5th axis + 4 edge cases + 1 `Instead of` + source + reproduction) | no — merge-before-create; the page owns the trigger and the addition is a new axis on its existing table |
| 2 — CLI transcripts in a document | `qa` / `deliverables` / **new** `command-transcripts-in-a-document.md` | no new category — `deliverables` already covers "documents produced for a reader, and where their content comes from"; this is the captured-run source alongside the generated-artifact source |

Why `qa/deliverables` and not `platforms/processes` for insight 2: the buffering
mechanism is a platforms fact, but the decision the page governs is what goes into
a document. `platforms` is routed to when code or scripts break across machines;
the transcript rule applies when nothing is broken and a document is being
written. The mechanism is cited from POSIX and the two adjacent `platforms/processes`
pages are cross-linked both ways rather than duplicated.

Nothing was left `unverified`. Both promoted insights carry a dated local
reproduction plus fetched official-doc citations; the staleness half of insight 2
is labelled as a dated field incident inside the page rather than presented as
doc-sourced.
