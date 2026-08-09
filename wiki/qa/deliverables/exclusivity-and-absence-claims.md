---
id: qa-deliverables-exclusivity-and-absence-claims
domain: qa
category: deliverables
applies_to: [general]
confidence: verified
sources:
  - https://www.cs.utexas.edu/~EWD/transcriptions/EWD03xx/EWD303.html
  - https://plato.stanford.edu/entries/popper/
  - https://google.github.io/styleguide/docguide/best_practices.html
last_verified: 2026-08-09
related: [qa-deliverables-generated-artifacts-as-deliverable-source, qa-document-verification-spec-document-gates, debugging-methodology-hypothesis-testing]
---

# An Exclusivity or Absence Claim in a Document

## When this applies

You are about to write a sentence in a spec, RFC, README, or reference doc that
claims exclusivity or absence: "the only way to X is Y", "there are exactly two
ways this conflicts", "this cannot be expressed", "no path produces Z". Also
when reviewing such a sentence someone else wrote, or when a reader reports a
case the document says is impossible.

## Do this

1. **Try to falsify the claim before writing it, and write it only after the
   attempt fails.** Construct inputs designed to break it and run them. A
   positive claim is established by one supporting example; an exclusivity or
   absence claim is destroyed by one counterexample and supported by none, so the
   evidence that makes it publishable is a failed refutation, not a confirmation
   ([debugging-methodology-hypothesis-testing] owns the attempt's structure).
2. **Choose the claim's form by what you can defend:**

| You want to write | Defend it with | If you cannot |
|-------------------|----------------|---------------|
| "The only way is Y" | An enumeration of producing paths derived from the code that produces them, plus a failed attempt at a path outside it | Write the existential claim ("Y produces it"), which one example supports |
| "There are exactly N forms" | The rule that generates the forms, plus N as a consequence of that rule | State the rule and drop the count |
| "This cannot be expressed" | A run of the closest expressible input showing the rejection, naming the rule that rejects it | Write "the vocabulary has no verb for it as of `<commit>`" |
| "No path produces Z" | A sweep of every module that can write Z, listed by name in the document | Write which paths you swept and that others were not checked |

3. **Write the rule that generates the cases instead of the list of cases.** "A
   create conflicts when the row already exists, and rows appear from the seed
   and from an earlier create" stays true when a third row-creating path is
   added; "there are two conflicting shapes" quietly becomes false. An
   enumeration records what the author knew; a generating rule records what the
   system does.
4. **Derive the enumeration by a sweep of the producing code, not from memory.**
   Name the modules swept in the document or its review notes, so the next
   author can re-run the same sweep instead of re-deriving the boundary.
5. **Record the falsification attempt next to the claim** — the command run, the
   input, and the observed result — so a reader can re-run it. Google's docs
   guidance is to keep documentation changing with the code it describes; a
   recorded attempt is what lets the next change re-check the claim instead of
   inheriting it.
6. **Re-run the attempt when the producing paths change.** An exclusivity claim
   is invalidated by additions elsewhere, so it belongs in the re-check list of
   any change that adds a producer ([qa-document-verification-spec-document-gates]
   for turning that re-check into a gate).

## Edge cases

| Case | Then |
|------|------|
| The claim is about your own closed vocabulary (a DSL's verb set, an enum) | Derive it from the table the implementation reads, and cite that table's path; a vocabulary listed in prose drifts from the one that is enforced |
| The falsifying input is expressible but has never been run | Run it — a documented impossibility that no test exercises is the shape most likely to be false |
| The counterexample appears only through a second feature's side effect (a seed, a fixture, an import) | It still falsifies the claim; the claim was about the system, not about one entry point |
| An audit confirms the enumeration is complete | Publish the enumeration with the sweep's scope named, so completeness is re-checkable rather than asserted |
| The claim is about an external system you do not control | State the version you checked and the check you ran; without both it is an absence claim about a moving target |
| The document already carries an unverified exclusivity claim | Attempt the refutation before editing the sentence; a reworded unfalsified claim is the same claim |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Confirm the claim by running the cases you already believe in | Run the cases designed to break it | Confirmations accumulate without ever ruling out the counterexample; a single counter-instance settles it |
| Enumerate the forms you can think of | Write the rule that generates the forms, and derive any count from it | The enumeration is bounded by the author's knowledge and goes stale the next time a producer is added |
| Write "the only way" because no other way came to mind | Write the existential claim you can support | An unfalsified universal claim reads with the same authority as a checked one and is the one readers act on |
| Take the enumeration from an earlier document or session summary | Re-derive it by sweeping the producing code now | The earlier document has the same drift mechanism and no check, so agreement between two documents is not corroboration |

## Sources

- https://www.cs.utexas.edu/~EWD/transcriptions/EWD03xx/EWD303.html — Dijkstra, EWD303: "program testing can be used very effectively to show the presence of bugs but never to show their absence"; sampling "is hopelessly inadequate to convince ourselves of the correctness … whole classes of in some sense critical cases can and will be missed"
- https://plato.stanford.edu/entries/popper/ — "It is logically impossible to verify a universal proposition by reference to experience …, but a single genuine counter-instance falsifies the corresponding universal law"; "an exception, far from 'proving' a rule, conclusively refutes it"
- https://google.github.io/styleguide/docguide/best_practices.html — dead docs misinform; change documentation in the same change as the code it describes
- Field incident 2026-08-09 (`linkly`, spec documentation): the sentence "the only conflicting shape is two `create`s" was falsified by `find order` followed by `create order` against a seeded row — `lnpl spec --run` returned `failed` with `failure_reason='repository create conflicts: entity.order already exists'`. The replacement sentence states the generating rule (a create conflicts when the row exists; rows arise from the seed and from an earlier create) and was published only after an independent sweep of the repo-policy, interpreter, backend, CLI, and spec paths found no third row-creating path
