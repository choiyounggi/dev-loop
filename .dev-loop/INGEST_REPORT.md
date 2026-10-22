# Knowledge flush — 1 insight(s)

Headless autoflush run. 16 queue rows were claimed. 4 were found and judged: 1 ingested, 3 released as pending duplicates of open PRs. The other 12 were released untouched, because this run could not find them (see the Open-PR check).

## Verified best-practice

**Candidate `85e196ab8171f1d5` — when a JS/TS script inserts text it did not write with `String.prototype.replace`, pass that text through a replacer function.**

- Claim: a replacement *string* is a template even when `from` is a plain string. `$$` becomes `$`. `$&`, `` $` `` and `$'` insert the match, the text before it and the text after it. `$n` and `$<name>` insert capture groups (regex patterns only). The value a replacer function returns is inserted as-is. `replaceAll` and regex replacements follow the same rules.
- Sources checked:
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replace
    - The replacement-patterns table.
    - "Specifying a function as the replacement": the return value is used as the replacement, and the special replacement patterns do not apply to strings it returns.
    - Confirmed through two web searches. One of them also turned up the same note in OpenJDK JDK-8016542 (https://bugs.openjdk.org/browse/JDK-8016542), where `"abc".replace("c", "$&")` with a function replacement must keep the literal `$&`.
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replaceAll
    - The replacement has the same semantics as `replace()`.
  - https://tc39.es/ecma262/#sec-getsubstitution
    - The spec operation behind both `replace` and `RegExp.prototype[Symbol.replace]`. A WebKit changeset in the search results cites it.
- Field evidence from the candidate's session: a plpgsql `AS $$ … $$` fixture was spliced in with `str.replace(from, to)`. Postgres then failed with 42601 `syntax error at or near "$"`. Redoing the splice so the text went in verbatim made the suite pass 6/6.
- This headless run has no Node execution tool, so no new local repro was run. The page leans on the MDN text and the session's field evidence.
- Confidence: **verified**.

## Existing-layer check

- `wiki_search` was run with the candidate's trigger and with a paraphrase (k=8 each). Top hits:
  - testing-quality-anchor-cases-for-allowlist-regexes
  - platforms-shells-escapes-in-shell-string-literals
  - testing-quality-schema-additions-under-a-golden-gate
  - platforms-shells-unset-versus-empty-parameters
  - infrastructure-config-config-values-emitted-as-source-text
  - frontend-security-xss-safe-rendering
  - testing-quality-json-manifest-edit-gates
  - testing-quality-ci-workflow-step-behavior-tests
- Opened and compared "When this applies":
  - anchor-cases: regex `^`/`$` anchors in allowlist tests. Different trigger.
  - escapes-in-shell-string-literals: backslash escapes in shell literals. Different trigger.
  - config-values-emitted-as-source-text: escaping a value a build step writes into generated source. This is the adjacent case, and it now has a `related:` link both ways.
- No existing page covers JS `replace` replacement patterns, so this is a **new page**. No conflicts were flagged.
- `wiki/backend/node/index.md` had no `language` category. `wiki/backend/python/index.md` does have one, and it served as the model.

Pages read: infrastructure-config-config-values-emitted-as-source-text, platforms-shells-escapes-in-shell-string-literals, testing-quality-anchor-cases-for-allowlist-regexes, infrastructure-agent-orchestration-worktree-isolated-workers

## Open-PR check

Open `knowledge/*` heads: #280, #279, #275, #274, #273, #272, #271, #270, #269, #268, #266, #265. This run cannot git-diff them, so overlap was judged from each PR's title and file list (`gh pr list … --json number,title,files`).

| Candidate | Overlapping open PR(s) | Verdict |
|-----------|------------------------|---------|
| `85e196ab8171f1d5` JS `String.replace` `$` patterns | None. No open PR touches `backend/node/language/` or a JS string-replacement topic. | **new**, ingested |
| `12aa086463fd4e2a` macOS BSD grep: `$` in a BRE with `\|` alternation is literal | #273 (`platforms/tools/bsd-vs-gnu-cli.md`, `platforms/shells/portable-shell-scripts.md`) and #265 (wrapped grep) | pending duplicate, claim **released** |
| `66f97671dfa1b324` Prisma 7 driver adapter: COMMIT-time errors arrive as `DriverAdapterError` and slip past an `instanceof Prisma.*Error` wrapper | #280 (a wrapper's own error label pinned by a boundary fault) and #269 (`backend/common/orm/prisma-7-…`) | pending duplicate, claim **released** |
| `447c9601617b87ca` Assertion-count detector misses unittest `self.assert*` | #270, #274 (`testing/quality/checks-that-cannot-pass.md`, `harness-reverse-controls.md`) | pending duplicate, claim **released** |

The 12 other claimed ids could not be located:

```
97c37473b53e63c2, 51b969b2ddf1a0e4, eb432a16d29c7f6b, 059bcdc4893c6cb6,
9308b554babe5a27, a8587555b58e7c6e, 3c9c55ed8769b312, 3e9ce6cd2ed89d38,
96c6e1721a7f2aaf, a2ca98b37ab9ef8f, 7ec41d4bae57db6e, 056027e7c9098793
```

- Cause: this headless run's permissions do not allow listing `~/.dev-loop/queue/`, and the session files holding these rows could not be found from session ids.
- They were **released** (set back to pending), not retired, so the next manual `/dev-loop:knowledge-flush` will process them.

## Routing decision

- `85e196ab8171f1d5` → `backend/node/language/string-replace-replacement-patterns.md`, id `backend-node-language-string-replace-replacement-patterns`.
  - The candidate's `domain: testing` hint was not followed. The lesson is a JavaScript language rule that applies to any script splicing text, not a test-design rule.
  - This adds a **new category `language`** to the `backend/node` subtree. Why: the node subtree only has `runtime` (process/runtime environment), `async` and `boundaries` (validating external data). None of them covers built-in language semantics. The python subtree already keeps its equivalent traps under `language/`.
- Plumbing:
  - `wiki/backend/node/index.md` gets a new `## language` section at the end of the file. It goes at the end so it does not sit next to rows that open PRs #266 and #268 add to that index.
  - `log.md` gets an ingest line.
  - `related:` link added both ways with infrastructure-config-config-values-emitted-as-source-text.
- `INDEX.md` and `wiki/backend/index.md` were left unchanged. Their node rows already send any Node.js/TypeScript code question to the node subtree. Open PRs #265/#274/#279 (INDEX.md) and #265/#266/#268/#269/#272 (backend/index.md) edit those files.

## Local-layer candidates

none
