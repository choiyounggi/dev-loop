---
id: testing-quality-unchanged-function-gates
domain: testing
category: quality
applies_to: [python, git]
confidence: verified
sources:
  - https://docs.python.org/3/library/ast.html#ast.get_source_segment
  - https://git-scm.com/docs/git-show
last_verified: 2026-10-06
related: [testing-quality-checks-that-cannot-pass, testing-quality-source-text-wiring-assertions, testing-quality-guard-shape-vs-consequence, testing-quality-harness-reverse-controls]
---

# Proving a Named Function Is Unchanged by a Diff

## When this applies

A plan, review, or done-gate has to prove "function X was not touched" while
the same change rewrites code around X: its callers, the function that wraps the
call, or the file it lives in. The gate you are about to write (or are reviewing)
greps the diff for removed lines that name X, e.g. `git diff | grep -c '^-.*X('`
expecting `0`.

## Do this

1. **Compare X's own source text at the base and in the working tree.** Parse
   both versions and pull each named function's segment. In Python, use
   `ast.get_source_segment(src, node)` on every `FunctionDef`/`AsyncFunctionDef`
   whose name is on the list. The gate passes when every segment is identical.
   It reports which names changed.

```python
import ast, subprocess, sys
names, path = sys.argv[2:], sys.argv[1]
def segs(src):
    return {n.name: ast.get_source_segment(src, n) for n in ast.walk(ast.parse(src))
            if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and n.name in names}
base = segs(subprocess.run(["git", "show", f"HEAD:./{path}"], capture_output=True,
                           text=True, check=True).stdout)
work = segs(open(path).read())
missing = [n for n in names if n not in base]
if missing: sys.exit(f"not found at base: {missing}")
changed = [n for n in names if base[n] != work.get(n)]
print("changed:", changed); sys.exit(1 if changed else 0)
```

2. **Run the gate on the real change, then on a copy with one literal changed
   inside X.** Require `changed: []` on the first run. Require X's name and a
   non-zero exit on the second. One run tells you nothing: a gate that never
   reports, or one that always reports, looks the same after a single run
   ([testing-quality-checks-that-cannot-pass]).

3. **Fail when a listed name is not found at the base.** A typo in the name list
   would otherwise compare `None` with `None` and pass on any change; the
   `missing` check turns it into an error. A name present at the base but gone
   from the working tree (renamed, deleted) compares text with `None` and is
   reported as changed. `HEAD:./{path}` resolves `path` from the current
   directory, as `open(path)` does; a bare `HEAD:{path}` is repo-root-relative.

## Edge cases

| Case | Then |
|------|------|
| Two functions share a name (a method on two classes, a nested helper) | Key the segments by qualified path (`Class.method`) built while walking, not by bare `name` — a dict keyed by name keeps only the last one |
| "Unchanged" must also cover decorators | `get_source_segment` on a `FunctionDef` starts at `def`; compare `node.decorator_list` segments too, or slice from the first decorator's line |
| X was moved (dedented out of a class, reindented) but its logic is the same | The segment differs in indentation only. Decide the policy first: compare `ast.dump(node)` to accept moves, or compare text to forbid them |
| The language has no stdlib AST with source positions | Use the language's parser (tree-sitter, TS compiler API `node.getText()`, `javac` tree positions) the same way. Do not fall back to a grep over diff lines |
| The base is not `HEAD` (a branch point, a tag) | Pass the base ref to `git show <base>:<path>` explicitly; gating against `HEAD` after a commit compares the change with itself |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Gate on `git diff \| grep -c '^-.*X('` = 0 | Compare X's AST source segment at base and working tree | Wrapping a call to X in a new `if`/`try` re-indents the call line. The diff then shows a removed line containing `X(` while X's body is identical, so the grep gate fails on correct work |
| Gate on "no hunk falls inside X's line range" | Compare the segments, or intersect X's base-file `lineno..end_lineno` with the old-side ranges of `git diff -U0 <base>` | Range intersection is sound only when both sides use base-file coordinates and zero context; mixing in new-file line numbers or `-U3` context lines reports X as changed when it is not. The segment comparison needs no coordinate bookkeeping |
| Trust the gate after seeing it pass once | Also run it on a deliberately changed copy and require it to name X | A gate that always passes looks the same as a correct one until it is run on a known-bad input |

## Sources

- https://docs.python.org/3/library/ast.html#ast.get_source_segment — `get_source_segment(source, node, *, padded=False)`: "Get source code segment of the source that generated node"; returns `None` if location info is missing; added in 3.8
- https://git-scm.com/docs/git-show — `git show <rev>:<path>` prints the blob at that revision, which gives the base text without touching the working tree
- Local reproduction 2026-10-06 (Python 3.14.6, scratch git repo): wrapping `helper(a)` in `if a:` inside `cmd` made `git diff -U0 | grep -c '^-.*helper('` print `1` while `helper` was unchanged; the AST gate printed `changed: []`, rc=0. After changing `x + 1` to `x + 2` inside `helper`, it printed `changed: ['helper']`, rc=1. A misspelled name (`helpr`) exits with `not found at base: ['helpr']`, rc=1, and run from a subdirectory with a cwd-relative path the gate read the subdirectory's file at `HEAD`
- Field context 2026-10-06 (an orchestration plan's task gate): the planned `grep -c "^-.*_relay_drain_once("` would have returned 1 after the planned rewrite of its caller; the AST gate passed on the real change and printed `changed: ['_relay_post']` when one literal in `_relay_post` was changed
