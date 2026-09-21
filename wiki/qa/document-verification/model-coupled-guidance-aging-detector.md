---
id: qa-document-verification-model-coupled-guidance-aging-detector
domain: qa
category: document-verification
applies_to: [general, llm-docs, agent-wiki]
confidence: verified
sources:
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
  - https://github.com/choiyounggi/dev-loop/blob/main/scripts/wiki-lint-model-era.js
  - https://github.com/choiyounggi/dev-loop/pull/178
last_verified: 2026-09-06
verified_model: claude-fable-5-1
related: [qa-document-verification-spec-document-gates, qa-document-verification-editing-a-gated-document, testing-quality-guard-shape-vs-consequence, testing-quality-checks-that-cannot-pass, backend-common-llm-binding-instructions-for-agents]
---

# An Aging Detector for Documentation That Describes Model Behavior

## When this applies

You maintain guidance written for LLM agents — steering files (`CLAUDE.md`,
`AGENTS.md`), an agent-facing wiki, a prompt library, model-workaround notes —
and are designing the lint or report that surfaces pages whose advice may have
aged with a model generation; deciding what the detector matches on, how it
scopes the text it scans, and whether its verdict blocks CI.

## Do this

1. **Match on the subject of the prose, not on quirk phrasing.** The aging
   surface is every page *about* model or harness behavior, and most of those
   state directives without hedging:

| Signal | Hit rate on a live 271-page agent wiki | Use it as |
|--------|----------------------------------------|-----------|
| Quirk phrases ("the model tends to…", "may hallucinate", "will over-trigger") | 3 / 271 pages | Nothing — it misses the surface it is meant to find |
| Subject keywords in prose (model names, `llm`, `subagent`, `context window`, `hallucinat`), each preceded by a non-word, non-hyphen boundary | 27 / 271 pages, concentrated where expected (`platforms/tools`, `backend/common/llm`) | The detector |

2. **Scan prose only.** Skip frontmatter, the `## Sources` section, the URL part
   of markdown links, and routing index files. A citation whose URL names a
   model, or a page id such as `backend-common-llm-*`, references model-coupled
   material without teaching from it; measured on the same corpus, a whole-file
   grep for the keywords hits 32 pages where the scoped scan hits 21.
3. **Pair the detector with a frontmatter field that records the generation the
   page was verified against** (`verified_model: <model-id>`), and compute the
   verdict from both: coupled **and** (field absent **or** its value contains no
   current-generation token) → re-verification candidate.
4. **Make the current-generation list overridable** — command flag, then an
   environment variable, then a built-in default — so the checker's own list can
   age without editing every caller.
5. **Ship it report-only**: a distinct exit code for "candidates found" (the
   script uses 3), the summary on stdout (`pages: N, model-coupled: M,
   candidates: K`), one `revalidate:<file>: <reason>` line per candidate on
   stderr, and a CI step that publishes the list without failing the build:

| Case | Do |
|------|----|
| The live corpus already carries candidates on the day the check lands | Report-only, in its own non-blocking step; the semantic judgment (re-verify, rewrite, retire) stays with a human or the lint skill |
| You want a hard gate anyway | Gate a *diff-scoped* rule — a newly added model-coupled page must carry `verified_model` — and leave the corpus-wide count as a report |
| A candidate is re-verified and still correct | Set `verified_model` to the current generation and `last_verified` to today; the guidance did not change, its evidence date did |

6. **Prove the detector on the live corpus before wiring it in**: count phrase
   hits against subject hits, then read the flagged list — concentration in the
   directories that discuss models and harnesses is the evidence it measures
   aging rather than vocabulary ([testing-quality-checks-that-cannot-pass] for
   authoring a check whose target may not exist yet).

## Edge cases

| Case | Then |
|------|------|
| A page mentions a hyphen-joined id containing a keyword (`backend-common-llm-context-window-budget`) and no model behavior | The leading boundary `(?<![A-Za-z0-9-])` excludes it; keep one such page as a negative control in the detector's tests |
| A body sentence quotes a vendor's model-specific text | Coupled, and correctly so — the page teaches from that generation's text; the quote's *URL* in Sources stays excluded |
| The model-coupled statement is a stable-looking fact (a model id string, a context length) | Still coupled: those values change per generation, and the re-verification is a re-read rather than a rewrite |
| The current-generation list is hard-coded in the script | The same aging problem one level up — read flag, then env, then default, and document the precedence in the script header |
| The wiki's own maintainer skill runs the check | Route the exit-3 list into the skill's re-verification step; a candidate is a queue item, not a defect |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Detect aging by "the model tends to…"-style phrase patterns | Match subject keywords in prose | 3 of 271 pages carried the phrasing while 27 discussed model behavior — the pattern misses nine in ten |
| Fail CI when any page lacks `verified_model` | Report candidates; gate only newly added model-coupled pages if a gate is wanted | Blocking on a signal the corpus legitimately carries (27 pages on day one) keeps CI permanently red and trains everyone to ignore it ([testing-quality-guard-shape-vs-consequence]) |
| Grep the whole file for model keywords | Scan prose outside frontmatter, Sources, link URLs, and index files | Citations and page ids carry the vocabulary without carrying guidance that can age (32 vs 21 pages on the same corpus) |

## Sources

- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices — guidance is generation-specific: "Tools that undertriggered in previous models are likely to trigger appropriately now. Instructions like 'If in doubt, use [tool]' will cause overtriggering"; prompts "designed to reduce undertriggering … may now overtrigger" — the mechanism that makes model-coupled pages age
- https://github.com/choiyounggi/dev-loop/blob/main/scripts/wiki-lint-model-era.js — the detector: subject regex with a leading `(?<![A-Za-z0-9-])` boundary, scanning outside frontmatter/Sources/link URLs and skipping `index.md`; candidate = coupled and (`verified_model` absent or no current-generation substring); `--current` > `DEV_LOOP_CURRENT_MODELS` > default; exit 0/3/4, report-only by design
- https://github.com/choiyounggi/dev-loop/pull/178 — design rationale and measurements: "explicit 'model tends/may/will' phrasing appears on 3/271 pages while model-coupled subjects cover ~27/271, concentrated in platforms/tools and backend/common/llm"; live run `pages: 275, model-coupled: 20, candidates: 20`; "Deliberately NOT in the blocking CI wiki-checks step"
- Local reproduction 2026-09-06 (dev-loop `main` at 1.21.0, 276 pages): `node scripts/wiki-lint-model-era.js wiki` → `pages: 276, model-coupled: 21, candidates: 21`, exit 3, flagged pages under `platforms/tools`, `infrastructure/agent-orchestration`, `security/agent-exposure`, `backend/common/llm`; a whole-file `grep -liE` for the same keywords over the same 276 pages hit 32
