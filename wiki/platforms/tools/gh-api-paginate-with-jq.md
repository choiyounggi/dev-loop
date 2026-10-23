---
id: platforms-tools-gh-api-paginate-with-jq
domain: platforms
category: tools
applies_to: [github, gh-cli, jq]
confidence: verified
sources:
  - https://cli.github.com/manual/gh_api
last_verified: 2026-10-23
related: [platforms-processes-parsing-cli-structured-output, platforms-tools-jq-dot-rebinding-in-predicates]
---

# Counting or Picking the Last Item Across `gh api --paginate` Pages

## When this applies

A script or check reads an array-returning GitHub endpoint (reviews, comments,
commits, check runs) with `gh api --paginate` and computes something over the whole
list — a count (`length`), the newest item (`last`), a sum, a filter-then-count —
with `--jq`.

## Do this

1. **Compute over all pages with `--slurp`, outside gh's `--jq`:**

   ```sh
   gh api "repos/$OWNER/$REPO/pulls/$N/reviews" --paginate --slurp \
     | jq 'add | length'              # count
   gh api "repos/$OWNER/$REPO/pulls/$N/reviews" --paginate --slurp \
     | jq 'add | last | .state'       # newest item
   ```

   `--slurp` wraps every page into one outer array; for REST endpoints whose pages
   are arrays, `add` concatenates them into a single list before the aggregate runs.
2. **Keep `--jq` for per-item projections only** (`--jq '.[].id'`), where running
   once per page gives the same lines as running once over everything.

| Expression | Per page (`--jq`) gives | Over all pages gives |
|------------|-------------------------|----------------------|
| `.[].field` | Same lines | Same lines |
| `length`, `map(select(…)) \| length` | One number per page | One total |
| `last`, `first`, `max_by`, `sort_by(…)[-1]` | One item per page | One item |

## Edge cases

| Case | Then |
|------|------|
| You pipe `--paginate` output (no `--jq`, no `--slurp`) into `jq` | gh 2.87.3 printed the REST array pages as one merged array, so `jq 'length'` gave the total; the manual describes each page as "a separate JSON array or object", so rely on `--slurp` + `add`, which the manual specifies |
| Only one page today (`per_page` larger than the list) | Every form agrees until the list grows past one page — test with `?per_page=1` to force several pages |
| GraphQL pagination | Pages are objects, and `add` merges objects shallowly (the last page wins), so `add \| length` is wrong there. Collect the nodes first: `--paginate --slurp \| jq '[.[].data.<path>.nodes[]] \| length'` — the form gh's manual example uses (`[.[].data.viewer.repositories.nodes[]]`) |
| The endpoint returns an object with an inner array (`check-runs`, `workflow_runs`) | `--slurp` gives an array of page objects; aggregate over `map(.check_runs) \| add` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read `--paginate --jq 'length'` as the total | `--paginate --slurp \| jq 'add \| length'` | `--jq` runs per page; you get one count per page and the first line is a page size |
| Take `--paginate --jq 'last'` as the newest item | `--paginate --slurp \| jq 'add \| last'` | Each page contributes its own last item; the first line is the last item of page 1, not of the list |

## Sources

- https://cli.github.com/manual/gh_api — in `--paginate` mode "Each page is a separate JSON array or object. Pass `--slurp` to wrap all pages of JSON arrays or objects into an outer JSON array"; `--slurp`: "Use with "--paginate" to return an array of all pages of either JSON arrays or objects" (same text in `gh api --help`, gh 2.87.3)
- Reproduction 2026-10-23 (gh 2.87.3): `gh api "repos/cli/cli/pulls/9000/reviews?per_page=1" --paginate --jq 'length'` printed `1`, `1`, `1` on three lines; the same call piped to `jq 'length'` printed `3`; with `--slurp`, `jq 'length, (map(length)|add)'` printed `3` and `3`
