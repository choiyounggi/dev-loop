# Knowledge flush — 4 insight(s)

4 queued candidates → **3 pages** (2 new platforms pages, 1 new qa page in a new
category). Two qa candidates were merged into a single page because they are the same
case seen twice; nothing was dropped.

Cross-Check: primary-source verification of every directive (man pages, official tool
docs) plus local reproduction of the two mechanism claims against this repo's own hook
source. No independent adversarial agent review was run for this flush — the
verification is documentary and reproducible, not a second opinion.

## Verified best-practice

### 1. A non-interactive flag is not a closed stdin → `confidence: verified`
**Claim.** When invoking a prompt-capable CLI unattended, pass the tool's
non-interactive switch *and* redirect stdin from `/dev/null`; a hang with zero output
is evidence about the client until the far side's log shows the request arrived.

| Source | What it establishes |
|---|---|
| [nohup(1)](https://man7.org/linux/man-pages/man1/nohup.1.html) | "If standard input is a terminal, redirect it from an unreadable file" — detaching includes taking terminal stdin away |
| [ssh(1)](https://man.openbsd.org/ssh.1) | `-n` "Redirects stdin from /dev/null (actually, prevents reading from stdin). This must be used when ssh is run in the background" |
| [ssh_config(5)](https://man.openbsd.org/ssh_config.5) | `BatchMode=yes` disables "password prompts and host key confirmation requests", "useful in scripts and other batch jobs where no user is present" |
| [timeout(1)](https://man7.org/linux/man-pages/man1/timeout.1.html) | "Start COMMAND, and kill it if still running after DURATION"; exit 124 on timeout — a distinguishable "blocked" signal |

Two established tools implement *both* halves (close stdin **and** a fail-fast
interaction switch) as separate mechanisms, which is exactly the candidate's directive.
The client/server split step is field-derived (a gateway access log showed zero
requests from the host during two hangs; `</dev/null` fixed it immediately) and is
labelled as such in the page's Field context rather than presented as documented.

### 2. Command-inspecting gates read pre-expansion text → `confidence: verified`
**Claim.** Write values literally in an argument a gate inspects; create files a gate
reads in a *prior* command.

- [Claude Code hooks docs](https://code.claude.com/docs/en/hooks) — `PreToolUse` runs
  "Before a tool call executes. Can block it"; the hook's stdin JSON carries
  `tool_input.command`, the unexecuted command string. Exit 2 blocks and "stderr text
  is fed back to Claude as an error message."
- [POSIX shell 2.6](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
  — word expansion is performed by the shell as it processes the line, so an external
  reader of the command text sees none of it applied.

**Reproduced locally** against this repo's own extraction pattern
(``--body-file[= ]+[^ '"`]+``, `hooks/pre-flush-pr-gate.sh:56`), 2026-07-30:

| Command text | Extracted | Refusal |
|---|---|---|
| `--body-file "$REPO/…"` | *(empty)* | "no `--body-file` found" |
| `--body-file $REPO/…` | literal `$REPO/…` | "body file does not exist yet" |
| `--body-file "/abs/…"` | *(empty)* | "no `--body-file` found" |
| `--body-file /abs/…` | `/abs/…` | passes |
| `--body-file=/abs/…` | `/abs/…` | passes |

This **corrects the candidate**, which attributed the failure to quoting alone. The run
shows two distinct failure modes with two different error messages — quotes defeat
*extraction*, an unexpanded variable defeats *resolution* — and that a quoted
**literal** path fails too. The page states both; the sharper form is what makes the
error message diagnostic.

### 3+4. Editing a document that text gates check → `confidence: field-tested`
**Claim.** Inventory a file's gate anchors before editing; describe an upstream
contract as an observed shape rather than with definition verbs; scope a check outside
the region that quotes it; record scoped conditions, not global counts.

The *hazards* are documented; the *directives* are field-derived, hence `field-tested`
rather than `verified`:

| Source | What it establishes |
|---|---|
| [Vale `existence`](https://docs.vale.sh/checks/existence) | The check "looks for the 'existence' of particular tokens" as a word-bounded non-capturing group — a lexical gate matches patterns, not intent. This is why a purely descriptive sentence trips a "do not redefine" gate |
| [Vale scopes](https://docs.vale.sh/topics/scopes.md) | Scopes restrict where a rule applies; "Any scope prefaced with `~` is negated" and scopes chain — keeping checks off regions such as code examples is first-class |
| [markdownlint MD013](https://github.com/DavidAnson/markdownlint/blob/main/doc/md013.md) | Rules expose `code_blocks`/`tables`/`headings` booleans (default `true`) so quoted code can be excluded from a prose rule |
| [pgrep(1)](https://man7.org/linux/man-pages/man1/pgrep.1.html) | "The running pgrep, pkill, or pidwait process will never report itself as a match" — self-exclusion is designed in because self-matching is the expected failure |

Field evidence retained in the page: a vague-word audit that matched its own quoted
pattern (1 global hit → 3 after quoting the fix, 0 under an `awk`-scoped run; the same
self-reference observed 3× across two documents), and a vocabulary gate
(`(arena|pool)…(재정의|정의한다|규정한다)`) that failed a true descriptive sentence
until it was rewritten as an observation, restoring the suite 60 → 61.

## Existing-layer check

**Read in full:** `INDEX.md`, `AGENTS.md`, `templates/page.md`,
`wiki/platforms/index.md`, `wiki/qa/index.md`,
`wiki/platforms/processes/background-services.md`,
`wiki/platforms/shells/portable-shell-scripts.md`, `log.md`, plus the two in-flight
pages `wiki/qa/document-verification/spec-document-gates.md` (PR #10) and
`wiki/testing/docs-as-spec/document-conformance-checks.md` (PR #9), fetched from the
fork. **Repo-wide greps** for `grep|self-referen|lexical|doc-as-spec`,
`stdin|/dev/null|non-interactive|tty`, and `PreToolUse|pre-commit|hook`.
**Queue dedup:** all 4 candidate hashes absent from `.processed.jsonl`.

**Open-PR dedup was decisive here.** PRs #6–#10 are open and unmerged, and
#7/#8/#9/#10 all sit in the doc-gate theme, so `main` alone understates coverage.
Overlap verdicts:

| Overlap candidate | Verdict |
|---|---|
| `qa-document-verification-spec-document-gates` (**PR #10, open**) | **Complement, not duplicate.** It owns the *gate author's* side (four axes, controls, fail-closed anchors). The new page owns the *document author's* side: what to do when your prose must survive gates that already exist, including gates whose pattern your text quotes. Neither self-reference scoping nor anchor inventory appears in #10; its nearest row ("Examples section satisfies the check") is a different cause |
| `testing-docs-as-spec-document-conformance-checks` (**PR #9, open**) | No overlap. Positive/negative controls and GFM pipe parsing for checks under construction; says nothing about editing an already-gated document |
| `testing-quality-tests-that-cannot-fail` | Adjacent, linked. Owns proving a *test* can fail. The new qa page routes gate-construction questions to it rather than restating them |
| `qa-process-regression-scope` | Adjacent, linked. Supplies the "re-run the full set, compare the baseline" principle the new page applies to gate suites |
| `platforms-processes-background-services` | Closest neighbour to insight 1 and **already covers `nohup … & disown`** for *lifetime*. It does not cover stdin as a blocking input or the client/server split. Kept separate (its "load when" is persistence), linked **both ways** |
| `platforms-shells-portable-shell-scripts` | Closest neighbour to insight 2, owns quoting *for the shell* — and its rule is "quote every expansion". The new page narrows one argument read by an external gate, so an unqualified reader could see a contradiction; the new page's edge-case table states explicitly that it "narrows one argument, it does not license unquoted expansions elsewhere". Linked both ways |
| `platforms-environment-path-resolution` | Linked only (literal-vs-resolved paths in non-interactive contexts) |

**Conflicts flagged:** one *soft* directive tension (quote-everything vs. write-this-one-
argument-literally), resolved inside the new page rather than by editing the old one. No
factual contradiction found.

**Reciprocal `related:` links added** to `background-services.md` and
`portable-shell-scripts.md` (frontmatter only; `last_verified` deliberately not bumped,
since nothing on those pages was re-verified).

### Merge conflict to expect (please read before merging)
This branch and **PR #10** both introduce the `## document-verification` section in
`wiki/qa/index.md` at the same insertion point, each with its own page row. Whichever
merges second will conflict there. **Resolution: keep one heading and both rows.** To
keep the conflict to that single hunk, this branch deliberately does **not** touch
`INDEX.md` — PR #10's qa route line ("automated verification of document deliverables
(spec/RFC gates)") already covers this new page. If #10 is rejected instead, the qa
route line in `wiki/qa/index.md` should gain a document-verification clause in a
follow-up. No `related:` id in this branch points at #10's page, so nothing here breaks
under either outcome; once both are merged the two pages are worth cross-linking.

## Routing decision

| Insight | Target | New category? |
|---|---|---|
| 1 — non-interactive CLI hang | `platforms/processes/non-interactive-cli-invocation.md` (new page) | No — `processes` already owns process/session lifetime |
| 2 — gate reads command text | `platforms/shells/command-text-inspected-before-execution.md` (new page) | No — `shells`, justified below |
| 3 + 4 — self-reference & lexical gates | `qa/document-verification/editing-a-gated-document.md` (new page) | **Yes** — `document-verification`, the same category PR #10 introduces |

**Insight 1 → platforms, not debugging.** Half the insight is diagnostic, but the
artifact the reader changes is the invocation command, and `AGENTS.md` routes by owned
artifact. `debugging-methodology-reproduce-first` is linked for the isolation half.
Merging into `background-services` was rejected: that page's case is *persistence*, and
adding a blocking-stdin case would drift its "load when".

**Insight 2 → `shells`, not a new category and not `tools`.** The mechanism is expansion
timing — *when* the shell rewrites the line relative to other readers of it — which is
shell semantics, so `shells` holds two coherent pages (portability; expansion timing vs.
external inspectors). `tools` is BSD-vs-GNU userland differences, which this is not. A
dedicated category (e.g. `policy-gates`) was considered and rejected as a one-page
category with no second member in sight.

**Insights 3+4 → one page, not two.** Both are the document author's side of the
doc-gate loop: 3 is "the gate matched the pattern I quoted", 4 is "the gate matched the
verb I used / the anchor I moved". `AGENTS.md` requires one case per page, and the shared
case is "writing prose inside a document that lexical gates run over" — the directives
interleave (scope the check, phrase as observation, record a scoped condition, re-run the
suite), so splitting would have produced two pages that each need the other. **New
category justified:** the existing qa categories are `process` (human release process),
`environments`, `bug-reports`, `exploratory` — none covers automated checks over a
written deliverable. PR #10 reached the same conclusion independently, which is
corroboration rather than duplication.

### Invariants checked on this branch
Body lines 83 / 82 / 93 (limit 120) · all four required sections present on each page ·
every `related:` id and inline `[page-id]` resolves (13 checks, 0 misses) · each new page
listed in its domain index with a multi-use-case "load when" · every index relative link
resolves · no banned vague qualifiers · `log.md` entry appended.
