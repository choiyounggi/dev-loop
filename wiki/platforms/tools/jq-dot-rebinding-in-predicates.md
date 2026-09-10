---
id: platforms-tools-jq-dot-rebinding-in-predicates
domain: platforms
category: tools
applies_to: [general]
confidence: verified
sources:
  - https://jqlang.org/manual/
  - https://stackoverflow.com/questions/48898983/jq-index-1-not-working-when-element-is-an-array
last_verified: 2026-09-10
related: [platforms-shells-portable-shell-scripts, platforms-shells-escapes-in-shell-string-literals, testing-quality-tests-that-cannot-fail]
---

# A jq Predicate That Pipes an Array Into `index(.)` Inside a Generator

## When this applies

Writing a jq filter that tests "does the current generated element appear in
array `$arr`" — inside `any(gen; cond)`, `map(select(...))`, `reduce`, or any
condition downstream of a generator — and the test is written as
`$arr | index(.)`, `$arr | contains(.)`, or any other `$arr | fn(.)` form where
`.` is meant to still be the generated element.

## Do this

1. **Bind the generated element to a variable before piping into the array.**
   `. as $x | $arr | index($x) != null`. This is the fix, not a stylistic
   preference: once bound, `$x` keeps the generator's element regardless of
   what `.` becomes later in the pipeline.
2. **Or skip `index()` entirely and use `IN($arr[])`.** `IN(s)` tests `.`
   (unchanged, since no pipe sits between the generator and `IN`) against every
   value `s` produces — `any(.[]; IN($arr[]))`.
3. **Know the one rule that causes the bug.** Per the jq manual, "`.` is the
   input value at the particular stage in a pipeline" — `.a | . | .b` is the
   same as `.a.b`, because each `|` re-evaluates what `.` means for everything
   to its right. `$arr | index(.)` pipes `$arr` into `index`, so for the
   duration of that call `.` **is** `$arr`, not the outer generator's element —
   the filter is actually `$arr | index($arr)`.
4. **Know why that produces a false positive instead of an error.** `index(s)`
   on an array input searches for `s` as a **subsequence** (subarray), not
   single-element membership — `[0,1,2,3] | index([1,2])` finds the subarray at
   its start position. Any non-empty array is trivially a subsequence of
   itself at position `0`, so `$arr | index($arr)` returns `0` for every
   non-empty `$arr`, and `0 != null` is `true` — the predicate is
   unconditionally true, not merely wrong for one case.

## Edge cases

| Case | Then |
|------|------|
| `$arr` is empty | `$arr | index($arr)` returns `null`, so `!= null` is `false` — the bug is silent until `$arr` gets its first element, so a test seeded only with an empty array will not catch it |
| You need the position, not just membership | Still bind first: `. as $x | $arr | index($x)` — the position of `$x`, or `null` if absent |
| Testing membership of a whole array (not element) against a list of arrays | `index(.)`'s self-match trap does not apply here — decide the real case (element-in-array vs array-in-list-of-arrays) before choosing `index`/`IN`, since both take different argument shapes |
| Filter is nested two pipes deep from the generator (`$arr | foo | index(.)`) | The same rebinding happens at the last `|` before `index(.)` regardless of how many pipes precede it — bind the element with `as $x` at the generator, not at the final stage |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `$arr | index(.)` (or `contains(.)`) as a generator's condition | `. as $x | $arr | index($x) != null` | The pipe rebinds `.` to `$arr` itself before `index` runs, so the call becomes a self-comparison, not a membership test against the generated element |
| Trust that a wrong `index(.)` predicate will fail loudly | Reproduce the exact filter standalone against a case where the expected answer is `false` (an element known absent from `$arr`) before trusting it in a guard | The bug returns `true` unconditionally once `$arr` is non-empty, so a guard built on it silently accepts every input it was meant to reject — it never throws or returns an obviously wrong shape |

## Sources

- https://jqlang.org/manual/ — "`.` is the input value at the particular stage in a 'pipeline'... `.a | . | .b` is the same as `.a.b`" (pipe rebinding); `index(s)`/`rindex(s)` "Outputs the index of the first/last occurrence of `s` in the input", demonstrated on array input as a subsequence search (`index([1,2])` on `[0,1,2,3,1,4,2,5,1,2,6,7]` → `1`); `IN(s)` "outputs `true` if `.` appears in the given stream"; `any(generator; condition)` applies `condition` to every output of `generator`. Confirmed unchanged between the jq 1.6 and current (1.8) manual pages for `index`/`rindex`.
- https://stackoverflow.com/questions/48898983/jq-index-1-not-working-when-element-is-an-array — "index takes a subsequence of elements to find, with a scalar being a special case equivalent to a one element sequence", explaining why indexing an array by an array differs from indexing by a scalar.
- Local reproduction 2026-09-10 (jq-1.7.1-apple, `jq --version`): `["a","b"] as $arr | ["b","zzz"] | any(.[]; $arr | index(.) != null)` → `true` even though `"zzz"` is not in `$arr` (and `["zzz","yyy"]` alone, with nothing in `$arr`, also → `true`; an empty `$arr` → `false`); `. as $x | $arr | index($x) != null` and `any(.[]; IN($arr[]))` both correctly discriminate (`true` for `"b"`, `false` for `"zzz"`/`"yyy"`); `["a","b"] | index(["a","b"])` → `0` confirms the self-match subsequence mechanics.
- Field context: dev-loop `skills/orchestrate/scripts/graph-drop.sh:67` (plugin v1.21.0) builds a consumers check as `select(any(.consumes[]?; $outs | index(.) != null))` — this exact form, reproduced standalone, named six unrelated tasks as consumers of an output none of them referenced, because the predicate was unconditionally true for any non-empty `$outs`.
