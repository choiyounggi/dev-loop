---
id: qa-document-verification-rationale-prose-after-a-config-value-change
domain: qa
category: document-verification
applies_to: [general]
confidence: verified
sources:
  - https://peps.python.org/pep-0008/#comments
  - https://google.github.io/eng-practices/review/reviewer/looking-for.html
  - https://google.github.io/styleguide/docguide/best_practices.html
  - https://code.claude.com/docs/en/sub-agents
last_verified: 2026-09-17
related: [qa-document-verification-retiring-a-provisional-marker, qa-document-verification-editing-a-gated-document, qa-process-defect-class-resweep-after-review, backend-common-llm-binding-instructions-for-agents]
---

# Rationale Prose Left Behind When a Pinned Config Value Is Removed or Changed

## When this applies

You are removing or changing a pinned config value — a `model:` line in an agent's
frontmatter, a version pin, a flag default, a timeout constant — in a file whose own
body (or a sibling doc, comment block, or test title) narrates why the old value was
chosen. Also when reviewing such a diff, or when an independent audit reports that a
file's prose contradicts its own frontmatter after a green test run.

## Do this

1. **Treat the value and the prose that justifies it as one edit target.** The
   config line and the paragraph explaining it are edited by different habits (a
   one-line frontmatter change vs. a body rewrite), so a diff that touches only the
   line leaves the paragraph asserting the retired behavior with the full authority
   of documentation. PEP 8 states the consequence: "Comments that contradict the
   code are worse than no comments."
2. **After the config edit, grep the whole file for the old value and for the
   vocabulary that narrates it** — the literal (`fable`, `600`, `--strict`), the
   verb of the decision (`pinned`, `locked`, `hardcoded`, `inherit`), and the
   reason words the rationale used (`guard`, `cheaper tier`, `only raise`). Read
   every hit in context; the stale block rarely repeats the literal.
3. **Widen the same grep to the files that quote this one**: sibling agents or
   skills that copy the rationale, README/reference docs, test names and assertion
   messages, CHANGELOG/ADR lines. Google's reviewer guide asks whether a change
   that alters behavior "also updates associated documentation" and, for a
   removal, "whether the documentation should also be deleted".
4. **Decide per hit what the rationale still carries:**

| The stale block… | Do |
|------------------|----|
| Explains only the mechanism of the removed value ("this model is pinned rather than inherit") | Delete it in the same commit — the frontmatter is now the whole truth |
| Names a trade-off the new design still accepts (a self-grading guard now shares the worker's model) | Replace it with one sentence stating the new behavior and the accepted trade-off, so the reason survives the value |
| Is a test title or assertion message that names the old behavior | Rename it in the same diff; a test named for a retired rule reads as coverage of that rule |
| Is a history/ADR line recording that the value was once pinned | Keep it and append the change ([qa-document-verification-retiring-a-provisional-marker]) |

5. **State the prose sweep in the PR or completion report**, with the grep and its
   scope ("`grep -n 'pinned\|inherit' agents/*.md` → 0 hits outside history"), so
   the reviewer checks a claim rather than re-deriving the sweep
   ([qa-document-verification-editing-a-gated-document] for scoping such a count).
6. **Route the diff through a reader that did not write it before calling it
   done.** A green suite proves the tests still pass; it says nothing about prose,
   and the author's self-review reads the rationale as familiar rather than as a
   contradiction.

## Edge cases

| Case | Then |
|------|------|
| The value is inherited or computed after the change (frontmatter `model` omitted → resolved by a precedence order) | Write the new resolution rule where the pin was, naming the precedence source, so the next editor is not left inferring it from an absent line |
| The rationale lives in a blockquote or callout that renders as authoritative guidance | Treat it as the highest-priority hit — a styled block reads as current policy to an agent loading the file |
| Several files carried the same value and the same rationale (copied agents) | Sweep all of them in one diff; a fix landing in one sibling leaves the class open in the other ([qa-process-defect-class-resweep-after-review]) |
| The removal is behind a gate that asserts the old prose (a bats test grepping for "pinned") | Update the gate and the file in the same commit and say so in the PR ([qa-document-verification-editing-a-gated-document]) |
| An audit flagged the contradiction after your self-review passed | Take the audit's FAIL as the verdict on the diff, not on the tests; fix the prose, re-run the sweep, and record what the self-review missed |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ship the frontmatter change because the suite is green | Grep the body and sibling docs for the old value's narration first | Tests assert behavior; nothing asserts that the explanatory prose still matches |
| Delete the rationale block wholesale | Keep the trade-off it names as one sentence about the new behavior | The value changed; the design tension it described is a separate fact the change did not remove |
| Leave the paragraph because it is only a comment | Rewrite or remove it in the same commit | A reviewer or agent trusts the documented rationale over the config line it now contradicts |

## Sources

- https://peps.python.org/pep-0008/#comments — "Comments that contradict the code are worse than no comments. Always make a priority of keeping the comments up-to-date when the code changes!"
- https://google.github.io/eng-practices/review/reviewer/looking-for.html — Documentation: when a CL changes how users build, test, interact with, or release code, check that the developer "also updates associated documentation, including READMEs, g3doc pages, and any generated reference docs"; for a removal or deprecation, ask "whether the documentation should also be deleted"
- https://google.github.io/styleguide/docguide/best_practices.html — "Dead docs are bad. They misinform, they slow down, they incite despair in engineers and laziness in team leads"; "Change your documentation in the same CL as the code change"
- https://code.claude.com/docs/en/sub-agents — a subagent definition's `model` frontmatter accepts an alias (`sonnet`, `opus`, `haiku`, `fable`), a full model id, or `inherit`; when omitted, Claude Code resolves the model in order: the per-invocation `model` parameter, the frontmatter, `CLAUDE_CODE_SUBAGENT_MODEL`, then the main conversation's model — the rule the replacement sentence names once the pin is gone
- Field evidence 2026-09-16 (dev-loop, task t3-agent-pin, issue #200): `model: fable` was removed from two review-agent definitions; both files kept a blockquote explaining that the model was "**pinned** rather than `inherit`" and should only ever be raised. Self-review and a 35/35 green bats run passed it; an independent test-quality-auditor call returned FAIL on the contradiction. The fix deleted both blockquotes, and the review recorded the trade-off the deleted rationale had named (a self-grading guard now sharing the worker's model) as an accepted design decision
