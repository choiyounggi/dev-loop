---
id: backend-python-language-iterative-dfs-for-unbounded-graph-depth
domain: backend
category: language
applies_to: [python]
confidence: verified
sources:
  - https://docs.python.org/3/library/sys.html#sys.getrecursionlimit
  - https://docs.python.org/3/library/sys.html#sys.setrecursionlimit
  - https://docs.python.org/3/whatsnew/3.12.html
last_verified: 2026-09-08
related: [backend-python-language-mutable-state-traps, backend-python-language-dict-subclass-attribute-loss-on-copy]
---

# Iterative DFS for Graph Traversal Depth Driven by Input Size

## When this applies

You are implementing a DFS-based algorithm in Python (cycle detection, a
dependency/reference graph, compiler diagnostics walking declared-entity
relationships) where the graph's size is driven by user- or module-supplied
content rather than a small fixed set — the traversal depth is not capped by
anything in the language or the domain.

## Do this

1. **Use an explicit frame stack, not Python's call stack, whenever depth
   scales with input.** `sys.getrecursionlimit()` documents that the limit
   "prevents infinite recursion from causing an overflow of the C stack and
   crashing Python" — a legitimate, non-infinite traversal that happens to be
   deep hits the same wall as a bug would.
2. **Replace the recursive call with a stack of `(node, child_iterator)`
   pairs.** Push a new frame when descending into an unvisited child; when the
   current frame's iterator is exhausted, mark the node done (black) and pop.
   This reproduces the recursive version's visitation order exactly, including
   the point at which a node is finalized.
3. **Keep white/gray/black coloring (or an equivalent visited/in-progress/done
   set) on the explicit stack version** — a gray node reached again is the
   cycle; a black node reached again is safe cross-root memoization. The
   iterative rewrite does not change this logic, only where the "call stack"
   lives.
4. **When you are tempted to raise `sys.setrecursionlimit(N)` instead, rewrite
   iteratively.** The documentation warns raising it "should be done with care,
   because a too-high limit can lead to a crash" — it trades a catchable
   `RecursionError` for an uncatchable interpreter crash once the C stack (a
   separate, platform-dependent limit) is exhausted.

## Edge cases

| Case | Then |
|------|------|
| Target is CPython 3.12+ | The recursion limit "now applies only to Python code" (builtins are protected by a separate mechanism) — a pure-Python recursive DFS is still Python code, so the trap and the fix are unchanged |
| The graph is guaranteed small by a hard schema limit (not by convention) | Recursive DFS is fine — state the limit and why it holds, so a later change to the schema is the trigger to revisit |
| Traversal needs to return a value assembled bottom-up (not just visit/color) | Push return values on a parallel results stack keyed by node, popped and combined when the node's frame pops — the iterative shape still supports post-order aggregation |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write a recursive DFS over a graph whose size is not bounded by the language/domain | An iterative DFS with an explicit `(node, child_iterator)` frame stack | Python's default recursion limit is 1000 frames; a chain of ~500+ nodes reaches it, and the failure mode is a crash on legitimate input, not a bug in the algorithm |
| Raise `sys.setrecursionlimit()` to work around a deep recursive DFS | Rewrite the traversal iteratively | A higher limit only postpones the crash and can turn a catchable `RecursionError` into an interpreter crash when the underlying C stack overflows |

## Sources

- https://docs.python.org/3/library/sys.html#sys.getrecursionlimit — "the maximum depth of the Python interpreter stack. This limit prevents infinite recursion from causing an overflow of the C stack and crashing Python"
- https://docs.python.org/3/library/sys.html#sys.setrecursionlimit — raising the limit "should be done with care, because a too-high limit can lead to a crash"; "If the new limit is too low at the current recursion depth, a RecursionError exception is raised"
- https://docs.python.org/3/whatsnew/3.12.html — "The recursion limit now applies only to Python code. Builtin functions do not use the recursion limit, but are protected by a different mechanism that prevents recursion from causing a virtual machine crash"
- Local reproduction (python3 3.14.6, 2026-09-08): default `sys.getrecursionlimit()` is 1000; a recursive DFS over a 2000-node chain graph raised `RecursionError: maximum recursion depth exceeded`; an iterative version with an explicit frame stack completed the same graph and returned matching cycle-detection output (`True`) against the recursive version on a 500-node cyclic graph within the default limit
- Field application (compiler diagnostics over declared-entity relationships): recursive DFS crashed at ~500 chained nodes; iterative white/gray/black rewrite with an explicit `frames`/`path_stack` list verified correct on synthetic 2000- and 5000-node graphs with `sys.setrecursionlimit(200)` forced low, cross-root memoization preserved, no correctness regression
