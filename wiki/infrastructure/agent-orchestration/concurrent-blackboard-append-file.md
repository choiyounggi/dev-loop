---
id: infrastructure-agent-orchestration-concurrent-blackboard-append-file
domain: infrastructure
category: agent-orchestration
applies_to: [general, posix]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/functions/write.html
  - https://man7.org/linux/man-pages/man7/pipe.7.html
last_verified: 2026-09-03
related: [infrastructure-agent-orchestration-shared-run-state, backend-common-storage-multi-object-write-ordering, backend-common-concurrency-distributed-locks, infrastructure-agent-orchestration-worktree-isolated-workers]
---

# One Shared File That Several Workers Append Entries To

## When this applies

A coordination protocol has several worker or agent sessions record entries in one
shared file — a findings log, an escalation ledger, a review blackboard — and the
instruction for how a worker writes its entry reads "open the file and add your
line" or "use your Write/Edit tool". Also when reviewing such a protocol, or when
two workers' entries in a shared log arrive merged into one garbled line or one
entry has vanished after another worker wrote.

## Do this

1. Prescribe one `O_APPEND` write per entry, in the shell: `printf '%s\n' "$entry"
   >> "$file"`. With `O_APPEND`, POSIX sets the file offset to the end of the file
   before each write and lets no other file modification intervene between setting
   the offset and the write — every writer's entry lands at the true end of the file
   regardless of how many other writers appended in between, because there is no
   separate "read the current end, then write there" step to race.
2. Route every write to that path through the append primitive, and state in the
   protocol that a full-file replacing tool (a native Write/Edit tool, a
   read-modify-write script) is out of bounds for it. Such a tool computes "old
   contents + my entry" from a snapshot that is stale by the time it writes back and
   erases any entry another worker appended in between; both tools report success and
   only one entry survives.
3. Emit each entry as one line from one `write(2)` call. The atomicity guarantee is
   per `write()` call, not per shell command: a `printf` that issues one write ending
   in one newline is safe; a helper that writes the body and a separator as two calls
   reopens the interleaving gap between its own two writes.
4. On the reading side, read the whole file (or `tail -f` it) on each poll rather
   than seeking to a remembered byte offset — a stored offset can land inside another
   writer's entry if step 3 is violated anywhere in the protocol.

## Edge cases

| Case | Then |
|------|------|
| Entries are structured (JSON, several fields) | Serialize each entry to one line (JSONL) so the whole entry is one `write()` call; a pretty-printed multi-line entry needs a lock or per-worker files merged by the coordinator, because POSIX gives no atomicity spanning two `write()` calls |
| The file lives on a network filesystem shared across machines | The atomic-append text covers local filesystems; NFS mounts differ in honoring `O_APPEND` across clients — verify on the actual mount or route all appends through one process |
| A worker dies mid-write | `O_APPEND` keeps other writers' bytes out of that entry's span, but the dying worker's own line can be torn; readers skip a line that fails to parse instead of treating the file as corrupt |
| The entries are large | `PIPE_BUF` atomicity is a pipe/FIFO guarantee, not a regular-file one; for a regular file the guarantee is per `write()` call with no documented size ceiling, so keep one entry to one call and one line |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Tell workers to "add your entry with your Write/Edit tool" | Tell them to append with one `printf '%s\n' … >> file` | A file-replacing tool reads, recomputes, and writes the whole file back; two workers doing this concurrently start from the same stale snapshot and the second write erases the first worker's entry with no error from either |
| Rely on "the writes are quick enough not to collide" | Rely on the `O_APPEND` guarantee, which holds regardless of timing | POSIX grants the offset-set-plus-write atomicity unconditionally for `O_APPEND`, not only when writers happen not to overlap |
| Write one entry as a header write and a body write | Format the whole entry as one line and issue one `write()` | The guarantee is per call; a second call reopens the interleaving window between the two |
| Cite a multi-object write-ordering page as the authority for a single shared append file | Cite this page; link the ordering page only for the multi-object case | Ordering two different objects and appending one shared object are different hazards with different fixes |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/functions/write.html — with `O_APPEND` "the file offset shall be set to the end of the file prior to each write and no intervening file modification operation shall occur between changing the file offset and the write operation"; for regular files POSIX "does not specify the behavior of concurrent writes … except that each write is atomic" and "Applications should use some form of concurrency control"
- https://man7.org/linux/man-pages/man7/pipe.7.html — "POSIX.1 says that writes of less than PIPE_BUF bytes must be atomic" is stated for pipes and FIFOs; it is not the source of the regular-file `O_APPEND` guarantee above
- Field reproduction 2026-08-27 (multi-worker review blackboard): a shared findings file updated through each worker's native Write/Edit tool lost one worker's entry when two workers wrote inside the same poll window (`reviews/t2-review-blackboard-r1.md`, finding F3); the fixing commit required one append call per entry and moved Write/Edit off that path. Each worker's own review saw a correct single-writer append; only the coordinator's cross-worktree view saw two of them race
