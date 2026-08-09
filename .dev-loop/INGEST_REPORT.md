# Knowledge flush — 5 insight(s): 2 ingested, 3 dropped as in-flight duplicates

Queue drained: `~/.dev-loop/queue/` — 5 pending rows across 2 sessions.

## Verified best-practice

### 1. A rejection message emitted from a code path two constructs share → `verified`

**Claim.** When one function is reached by more than one caller and its message
names a construct in literal text, the subject belongs in a caller-supplied
parameter — and the *repair* the message offers ("use `X` instead") must be
executed from each emitting path, because a wrong subject is caught by reading
while an illegal repair reads as a fix and sends the author into a second,
unrelated rejection.

**Sources checked (all fetched this session):**

- <https://rustc-dev-guide.rust-lang.org/diagnostics.html> — confirms the
  confidence-rating half directly: suggestions carry an applicability level and
  "Be conservative when choosing the level"; `MachineApplicable` = "Can be
  applied mechanically", `MaybeIncorrect` = "Cannot be applied mechanically
  because the suggestion may or may not be a good one", `Unspecified` = "we don't
  know which of the above cases it falls into".
- <https://doc.rust-lang.org/stable/nightly-rustc/rustc_errors/enum.Applicability.html>
  — the enum tools read to decide whether a suggestion is auto-applied or shown
  for review. A production compiler encoding "this suggestion may not be valid"
  as a required field is the strongest available corroboration that repair
  validity is a separate property from message correctness.
- <https://www.nngroup.com/articles/error-message-guidelines/> — an error message
  must offer constructive advice describing a solution *sufficient for the user
  to fix the problem*. Advice that is illegal on the reader's path fails that bar.

**How verified.** Both Rust pages were fetched and quoted verbatim (not
paraphrased from memory); the NN/g guideline was retrieved via search and its
"constructive advice / solution sufficient to fix the problem" wording confirmed.
The field incident behind the candidate is reproducible in `linkly`
(`impl/lnpl/lower.py`: `_Scope.check_reference` hardcoded "guard condition" while
serving both the guard and assignment paths; its `set`-target advice recommended
`input.<field>`, which `_derive_assignment` rejects for `set` targets by a
separate rule — suite 1864 → 1872 after parameterizing subject/target, the 8 new
per-path assertions and no other delta).

**Confidence: `verified`** — the general directive is doc-backed, the incident is
the reproduction.

### 2. An exclusivity or absence claim in a document → `verified`

**Claim.** "The only way is Y" / "this cannot be expressed" / "exactly N forms"
must be *falsified* before publication, not confirmed — and the document should
carry the rule that generates the forms rather than an enumeration of them.

**Sources checked (all fetched this session):**

- <https://www.cs.utexas.edu/~EWD/transcriptions/EWD03xx/EWD303.html> — Dijkstra,
  EWD303, fetched and quoted: "program testing can be used very effectively to
  show the presence of bugs but never to show their absence", and on sampling:
  "hopelessly inadequate to convince ourselves of the correctness … whole classes
  of in some sense critical cases can and will be missed". This is exactly the
  asymmetry an absence claim runs into.
- <https://plato.stanford.edu/entries/popper/> — fetched and quoted: "It is
  logically impossible to verify a universal proposition by reference to
  experience …, but a single genuine counter-instance falsifies the corresponding
  universal law"; "an exception, far from 'proving' a rule, conclusively refutes
  it". Supplies the logic for "supported by a failed refutation, never by
  confirmations".
- <https://google.github.io/styleguide/docguide/best_practices.html> — dead docs
  misinform; documentation changes in the same change as the code it describes.
  Supports the re-check directive (an exclusivity claim is invalidated by
  additions elsewhere).

**How verified.** EWD303 and the SEP entry were both fetched and the sentences
quoted verbatim from the retrieved text. The Google docguide URL is the same one
already cited by the merged wiki, so it resolves in this repo's existing
citation set. The field incident is a recorded run: `lnpl spec --run` on
`find order` + `create order` returned `failed` with
`failure_reason='repository create conflicts: entity.order already exists'`,
falsifying the published "only two `create`s conflict" sentence.

**Confidence: `verified`.**

### 3–5. The three dev-loop orchestration candidates → not re-verified (dropped)

Guardrail read-only worktree escalation; Orca terminal/dispatch binding taxonomy;
tmux in-band question menu. These were not researched further because the
open-PR check (below) found each already ingested in an open PR in equal or
better form. Nothing was upgraded to `verified` on the strength of this session.

## Existing-layer check

Routed via `INDEX.md` → `backend` (server-side application code, `common/errors`
owns error structure) and `qa` (release-quality process, `deliverables` owns
claims in a published document).

Pages read: backend-common-api-design-error-responses, backend-common-api-design-unenforced-declarations, backend-common-change-impact-call-site-enumeration, backend-common-errors-exception-handling, backend-common-errors-async-failure-handling, debugging-signals-reading-error-messages, debugging-methodology-hypothesis-testing, qa-deliverables-generated-artifacts-as-deliverable-source, qa-document-verification-spec-document-gates, qa-document-verification-editing-a-gated-document, qa-process-scope-purity-checks, qa-exploratory-lowered-declaration-survival, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-pane-delivery-confirmation

Plus a `grep -ril 'diagnostic' wiki/` and `grep -ril 'error message' wiki/` sweep
over the whole wiki, to make sure no page under another domain already owned the
producer side of diagnostics.

**Overlaps found, and why each is adjacent rather than duplicate:**

| Existing page | Relation to insight 1 |
|---|---|
| `backend-common-api-design-error-responses` | Owns the *transport* contract — HTTP status codes and the problem+json body. Says nothing about a message's subject or its repair advice. Adjacent, now cross-linked. |
| `debugging-signals-reading-error-messages` | The **consumer** side — how to read a message you were given, including "compilers often print the fix". The new page is the **producer** side: making that printed fix true on the path it was printed from. Complementary; cross-linked both ways. |
| `backend-common-api-design-unenforced-declarations` | Owns *which* diagnostic to emit for unrecognized vs recognized-but-unenforced input; the new page owns how a shared emitter words one. Cross-linked. |
| `backend-common-change-impact-call-site-enumeration` | Supplies the mechanism for "enumerate the emitting paths"; the new page cites it inline. Cross-linked. |

| Existing page | Relation to insight 2 |
|---|---|
| `qa-deliverables-quantitative-claims-in-a-published-document` (**not merged — open in #51**) | Nearest sibling: *numeric* claims in a published document, recomputed by command. The new page covers *exclusivity/absence* claims, which have the opposite logic (a count is verified by recomputation; a universal claim can only survive a failed refutation). Deliberately **not** related-linked, because the id does not exist on `main` and a link to it would dangle until #51 merges. Flagged here so the owner can add the reciprocal link when #51 lands. |
| `qa-deliverables-generated-artifacts-as-deliverable-source` | Owns "regenerate rather than hand-write"; orthogonal, cross-linked. |
| `qa-document-verification-spec-document-gates` | Owns turning a document requirement into an automated check — the new page's step 6 routes there for making the re-check a gate. Cross-linked. |
| `debugging-methodology-hypothesis-testing` | Owns the structure of the refutation attempt itself; cited inline and cross-linked. |

**Conflicts flagged:** none. No existing page states a conflicting directive on
either trigger.

**Merged vs created:** both created new — neither trigger existed anywhere in the
wiki (merge-before-create was checked against every "load when" line in the two
target categories plus the two grep sweeps above).

**Reciprocal `related:` links added to 6 existing pages:**
`error-responses`, `unenforced-declarations`, `call-site-enumeration`,
`reading-error-messages` (→ insight 1); `generated-artifacts-as-deliverable-source`,
`spec-document-gates`, `hypothesis-testing` (→ insight 2). `last_verified` was
**not** bumped on those pages — only a link was added, no claim was re-verified.

## Open-PR check

13 open `knowledge/*` heads listed and each fetched; `git diff origin/main
origin/<head> -- wiki/` inspected for every one:

`#66 choiyounggi-20260808-013406`, `#64 choiyounggi-20260808-004155`,
`#62 choiyounggi-20260807-225916`, `#61 choiyounggi-20260807-213244`,
`#58 choiyounggi-20260807-191239`, `#57 choiyounggi-20260807-163902`,
`#56 choiyounggi-20260807-153857`, `#55 choiyounggi-20260807-144058`,
`#52 dch0202-rsquare-20260807-100149`, `#51 dch0202-20260806-183029`,
`#50 dch0202-20260806-172420`, `#49 dch0202-rsquare-20260806-142309`,
`#47 dch0202-20260806-130040`.

| Candidate | Overlapping head(s) | Verdict |
|-----------|--------------------|---------|
| Shared-code-path rejection message (subject + repair) | none — `#58` touches `backend/common/change-impact/` (corpus sweep before a rejection rule: how to *bound* a new rejection, not how to *word* one from a shared emitter); `#56` touches `unenforced-declarations` frontmatter only | **new** |
| Exclusivity/absence claims in a document | `#51` adds `qa/deliverables/quantitative-claims-in-a-published-document` (numeric claims), `#66` extends `qa/document-verification/spec-document-gates` (gate design) — neither carries the falsification directive or the enumeration-vs-generating-rule rule | **new** |
| Guardrail `worktree_escape` fires on read-only cross-worktree access | `#51` and `#47`, both on `infrastructure/agent-orchestration/worktree-isolated-workers` | **drop** — `#47` carries the identical directive including the escalation round trip and the "reads pre-approved, writes and system-temp still refused" briefing line; `#51` additionally reproduces the rule's mechanism (main-root mention surviving the strip **and** an independent write-verb/absolute-redirect match). Strictly better than the candidate. |
| Orca terminal binding: check idle prompt, branch on `runtime_unavailable` vs `agent_unconfigured`, pass `--worktree` | `#51`, on `infrastructure/agent-orchestration/pane-delivery-confirmation` | **drop** — carries all four rows (bind-after-"done" is a report not a turn end, occupied runtime → wait and rebind, dead agent → replace, pane/worktree mismatch → pass the worktree) plus an `Instead of` row and the three field observations. |
| tmux worker wedged on a numbered in-band question menu | `#64`, new page `infrastructure/agent-orchestration/unattended-worker-questions` | **drop** — supersedes the candidate: it adds the out-of-band question channel, the stall-classification table, the allowlisted key sequence with the selection-then-confirmation step, and the re-send of the interrupted prompt. |

Three drops, no folds — nothing unique in the dropped candidates was missing from
the open heads, so there was nothing to push to those branches. This is the
recurring trio flagged in `#39`; it re-enters the queue on every flush until
`#47`/`#51`/`#64` merge.

## Routing decision

| Insight | Domain | Category | Page | New category? |
|---------|--------|----------|------|---------------|
| Shared-code-path rejection message | `backend` | `common/errors` (existing — owns error structure and where errors are translated) | `wiki/backend/common/errors/diagnostics-from-a-shared-code-path.md` (new) | No |
| Exclusivity/absence claims | `qa` | `deliverables` (existing — owns claims in a document about to be handed out) | `wiki/qa/deliverables/exclusivity-and-absence-claims.md` (new) | No |

No new categories were added. Both candidates were considered against the
alternatives before landing:

- Insight 1 was weighed against `backend/common/api-design/` (where
  `unenforced-declarations` lives) and against `debugging/signals/`. It went to
  `errors` because the artifact being changed is the emitted error, not the API
  contract shape and not the reader's diagnosis workflow.
- Insight 2 was weighed against `qa/document-verification/` (automated gates on a
  document). It went to `deliverables` because the directive governs what an
  author writes, and only routes onward to `document-verification` for turning
  the re-check into a gate.

Plumbing updated: `wiki/backend/index.md` and `wiki/qa/index.md` each gained a
"load when" row; `log.md` gained the dated ingest entry naming both new pages,
the sources verified, and the three drops with their PR numbers.

Mechanical check before commit: both pages are 72 body lines (limit 120), every
`related:` id and inline `[page-id]` reference resolves against `wiki/`, and
neither body contains a banned vague qualifier.
