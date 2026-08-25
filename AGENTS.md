# dev-llm-wiki — Agent Schema

You are the maintainer and consumer of this wiki. This file is the schema: it defines
how the wiki is structured, how you route into it, how you write pages, and how you
keep it healthy. Follow it exactly. When this file and your habits disagree, this file wins.

## What this wiki is

A case-routed knowledge base of development best practices and edge cases, written
**for LLM agents to load as working context**. It is not documentation for humans to
browse (humans are welcome, but every formatting rule below exists to make an agent's
context precise and small).

Three layers (Karpathy LLM-wiki pattern):

| Layer | Path | Mutability |
|-------|------|------------|
| Schema | `AGENTS.md` (this file), `templates/` | Change only with repo owner approval |
| Wiki | `wiki/**` , `INDEX.md`, `log.md` | You create and update via the workflows below |
| Workflows | `skills/` | Change only with repo owner approval |

## Directory layout

```
INDEX.md                     # root map: domain → when to route there
log.md                       # append-only chronological change log
wiki/<domain>/index.md       # domain map: category/page → when to load it
wiki/<domain>/<category>/<page>.md
templates/page.md            # canonical page template
skills/ingest|query|lint/    # the three operations
```

## Routing protocol (how to consume)

Routing takes one of two inputs. **Planning** routes from the *intent* — the task
you are about to do. **Review** routes from the *diff* — what the code in front of
you actually does. Steps 1-6 are the same for both; the review entry then adds
step 7.

1. Read `INDEX.md`. Match your task to a domain by its "route here when" line.
   - **Several domains match**: route to the domain that owns the artifact you will
     change (SQL/schema → databases; application code → backend; a failing system →
     debugging). Reading a second domain's index to check is cheap and sanctioned;
     bulk-loading pages from both is not.
   - **Best match is marked `scaffold`**: it has no pages. Use the cross-pointers in
     its index if any, take the next matching seeded domain, and append a `gap`
     entry to `log.md`.
2. Read that domain's `wiki/<domain>/index.md`. Select pages by their **"load when"
   lines — these are the routing gate**. Load only pages whose line matches your
   situation.
3. After loading, the page's "When this applies" should confirm the match. If it
   contradicts your situation, drop the page and append a `drift` entry to `log.md`
   (index line and page trigger disagree — a lint defect), unless the page content
   demonstrably serves your case anyway, in which case keep it and still log the drift.
4. **Sanctioned extra hops**: when a loaded page routes you onward via an inline
   `[page-id]` reference or a `related:` id, follow it — the citing directive is the
   trigger. This is how constraint/index pages compose.
5. If no page matches anywhere, answer from general knowledge **explicitly labeled
   not wiki-backed**, and append a `gap` entry to `log.md`.
6. Apply the page's directives:
   - If your situation hits a listed edge case, follow the edge-case row, not the
     general rule.
   - Within a Do/decision table, when several rows match, apply the **most specific
     row** (rows are ordered general → specific); when a general row and a
     precondition-bearing row both fit, take the one that preserves the stated
     invariant.
7. **Review entry — route from the diff, then compare the page sets.** When your
   input is a change rather than a task, derive the match from what the diff does,
   not from what its plan said it would do:

   | Signal in the diff | Route on |
   |--------------------|----------|
   | A new or changed CLI flag, subcommand, SDK call, or dependency version | the owning toolchain/platform domain — resolve it against the version present where the code runs |
   | Two or more writes with no transaction around them | the owning data or storage domain — establish what a concurrent reader sees between them |
   | A new lock, queue, pool, background job, or shared file | the concurrency category of the owning domain |
   | A new parameter reaching a query, path, template, or permission check | security, trust-boundary category |
   | A changed schema, index, or migration | databases |
   | A new or changed test file, assertion, or fixture | testing |

   Then compare the page set you reached against the page set the plan named. The
   pages you reached that the plan never named are the change's unplanned risk
   surface; report that list as a review finding in its own right. When the two
   sets match, record "no unplanned pages reached" — a stated null result and an
   omitted one read the same to the next reviewer, so state it.

Hard rule: never load a whole domain "for background". The index lines exist so you
can decide relevance without opening pages.

## Page format (how to write)

Every page uses `templates/page.md`. Non-negotiable rules:

1. **One case per page.** A page answers one situation. If you are writing "and also…",
   split the page and cross-link under `related`.
2. **≤ 120 lines of body.** Precision beats coverage. Link, don't inline.
3. **Positive guidance; a prohibition must pair.** Every directive is "In situation X,
   do Y". A prohibition (`don't` / `do not` / `never` / `avoid` / `must not`) may
   appear anywhere in a page, as long as the same directive item also carries its
   replacement action or the mechanism that makes the prohibition true. The
   `Instead of` table remains the place for anti-pattern/replacement pairs; each row
   there MUST still pair the anti-pattern with its replacement action. The unit of
   pairing is the directive item — a table cell or a bullet — not the page as a
   whole. A bare prohibition, alone in its item, is a lint failure: a prohibition
   with no replacement invites the reader to improvise, which is how hallucinations
   happen. Enforced by `node scripts/wiki-lint-prohibitions.js`.
4. **No vague qualifiers.** Words like "usually", "consider", "might want to",
   "generally", "as appropriate" are banned in directive sentences. State the
   condition that decides it: "When X, do A. When Y, do B." If you cannot state the
   condition, the knowledge is not ready for a page — file it in the ingest queue.
5. **Sources are mandatory.** Frontmatter `sources:` lists the evidence
   (official docs, measured benchmarks, published post-mortems). Claims you cannot
   source get `confidence: unverified` and are surfaced by lint until sourced or removed.
6. **Case branches are tables.** When behavior differs by situation, use a
   `| Case | Do |` table, not prose. Tables are what agents parse most reliably.

### Frontmatter

```yaml
---
id: <domain>-<category>-<slug>        # globally unique
domain: databases
category: indexing
applies_to: [postgresql, mysql]       # or [general]
confidence: verified | field-tested | unverified
sources:
  - <url or citation>
last_verified: YYYY-MM-DD
related: [<page id>, ...]
---
```

`confidence` meanings — `verified`: backed by cited official docs or reproducible
measurement. `field-tested`: worked in real production use; context described in the
page. `unverified`: candidate knowledge; lint reports it until upgraded or removed.

### Section skeleton

```markdown
# <Title — the situation, stated as a noun phrase>
## When this applies      # trigger conditions, 1-4 lines, matchable without reading further
## Do this                # directives; decision table if branching
## Edge cases             # | Case | Then | table
## Instead of             # | If you are about to | Do this instead | Why | (optional section)
## Sources
```

## Operations

Run these via the skill files, which contain the full step-by-step workflows:

- **Ingest** (`skills/wiki-ingest/SKILL.md`) — add new knowledge: route it to domain/category,
  merge into existing pages before creating new ones, cite sources, update indexes and `log.md`.
- **Query** (`skills/wiki-query/SKILL.md`) — answer a question from the wiki with citations;
  if the answer required synthesis across pages and is re-askable, file it as a new page.
- **Lint** (`skills/wiki-lint/SKILL.md`) — health check: unsourced claims, unpaired
  prohibitions, banned vague qualifiers, orphan pages, broken links, stale `last_verified`.

Two further skills use the wiki to run development work (rather than maintain the wiki):

- **Plan** (`skills/wiki-plan/SKILL.md`) — for a capable model: make every design decision
  (wiki-grounded), then decompose the work into ordered task files sized for execution
  (≤3 files, ≤4 wiki pages, verifiable, self-contained), each mapping the exact
  wiki pages that govern it.
- **Implement** (`skills/loop-implement/SKILL.md`) — the single implementation loop:
  execute the plan's tasks in order, loading each task's named wiki pages, applying their
  directives (no improvisation — missing decisions go back to the plan, never guessed),
  writing tests first and judging each task against done. The wiki-executor discipline
  is folded in here; there is no separate implement skill.

## Naming

- Domains and categories: lowercase kebab-case nouns (`query-optimization`).
- A domain may nest one subtree level when it splits by stack/environment
  (`backend/common/`, `backend/java/`, `backend/node/`, `backend/python/`); page ids
  then include the subtree: `backend-java-jpa-<slug>`. The domain `index.md` routes
  concern-first (shared subtree) then stack; each stack subtree has its own `index.md`.
- Page files: the situation, not the technology (`composite-index-column-order.md`,
  not `postgres-tips.md`).
- Page ids: `<domain>-<category>-<slug>` matching the file path.

## Maintenance invariants

After any wiki change, all of these must hold (lint checks them):

1. Every page is listed in its domain `index.md` with an accurate "load when" line.
   The line must enumerate the page's **distinct use cases** (including
   constraint/uniqueness/design-time uses), not only its headline framing, and must
   not contradict the page's "When this applies". Decision tables inside pages are
   ordered general → specific.
2. Every domain appears in `INDEX.md`.
3. `log.md` has an appended entry: `## [YYYY-MM-DD] <ingest|revise|lint> | <summary>`.
4. Every `related:` id and inline link resolves to an existing page.
5. No page exceeds 120 body lines.

## Running tests on macOS

macOS ships bash 3.2, which does not honor a mid-test `[[ ]]` assertion's exit
status — only a test function's *last* command decides the verdict, so an
earlier failed `[[ ]]` is silently masked (issue #114). Install a modern bash
before running the suite:

```sh
brew install bash
PATH=/opt/homebrew/bin:$PATH bats tests/
```

`tests/bash-version-guard.bats` refuses to run under bash < 4, and
`tests/canary/mid-test-assertion-canary.bats` (run inverted in CI) proves
mid-test assertion failures are still detectable.

## Releasing (four steps, all four required)

dev-loop is installed as `dev-loop@groundwork`, and groundwork's marketplace
entry is **tag-pinned** (`source: {source: url, url: …dev-loop.git, ref: vX.Y.Z}`).
Claude Code checks out exactly that ref, so a merged PR — even a tagged, published
release — reaches nobody until the pin moves. Every dev-loop release runs all four:

1. Bump the version in **both** `.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json` (a repo-wide grep for the old version finds
   both; `scripts/check-versions.sh` fails the build if they disagree). Merge.
2. Confirm the tag: `auto-tag.yml` cuts `vX.Y.Z` and `release.yml` publishes it —
   verify with `gh release list` that the new tag shows as **Latest**.
3. Move the pin in `choiyounggi/groundwork`: `scripts/sync-dev-loop-pin.sh vX.Y.Z`,
   then merge that PR. groundwork's hourly `sync-dev-loop-pin` workflow opens it
   on its own; `gh workflow run sync-dev-loop-pin.yml --repo choiyounggi/groundwork`
   triggers it immediately instead of waiting.
4. Tell the user to run `/plugin marketplace update groundwork` then
   `/plugin update dev-loop@groundwork`. Nothing before this step changes what a
   running session loads; live orchestrate workers keep their cached copy until
   relaunched.

Step 3 is the one that gets skipped. Symptom: `/plugin` reports the *old* version
as latest right after a successful release — that is a stale pin, not a broken
release. Diagnose by reading the `source.ref` in groundwork's marketplace.json
(`~/.claude/plugins/marketplaces/groundwork/.claude-plugin/marketplace.json` locally,
or the raw file on `main`), never from `gh release list` in this repo. The
`pin-drift` workflow fails every 6 hours while the pin is behind, and
`scripts/check-pin-drift.sh <latest-tag> <pinned-ref>` runs the same check by hand.

A CI-only change (workflows, tests, scripts not shipped to users) does not need a
version bump — step 1 applies to anything a plugin consumer loads: skills, hooks,
wiki pages, templates, references.
