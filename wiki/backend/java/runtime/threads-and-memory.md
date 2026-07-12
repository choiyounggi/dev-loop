---
id: backend-java-runtime-threads-and-memory
domain: backend
category: runtime
applies_to: [java, kotlin, jvm]
confidence: verified
sources:
  - https://openjdk.org/jeps/444
  - https://openjdk.org/jeps/491
  - https://docs.oracle.com/en/java/javase/21/core/virtual-threads.html
  - https://docs.oracle.com/en/java/javase/21/troubleshoot/troubleshooting-memory-leaks.html
  - https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html
  - https://www.netdata.cloud/guides/docker/docker-jvm-memory-tuning/
last_verified: 2026-07-10
related: [backend-common-concurrency-shared-state-and-pools]
---

# JVM Threading Model Choice and Process-Memory Diagnosis

## When this applies

Choosing between platform threads and virtual threads for a JVM service; a
thread-per-request service hitting thread-pool exhaustion under blocking I/O; heap
rising across GCs; a container OOMKilled with no Java `OutOfMemoryError`.

## Do this

1. Pick the threading model by workload:

| Workload | Model |
|----------|-------|
| Blocking-I/O-heavy, thread-per-request (HTTP handlers awaiting DB/HTTP calls) | Virtual threads (Java 21+, JEP 444): create one per task — creation is cheap and a blocked virtual thread parks, releasing its carrier OS thread |
| CPU-bound work (encoding, scoring, compression) | Platform thread pool sized to core count — virtual threads add no throughput to computation |
| Mixed service | Virtual threads for request handling; hand CPU-bound stages to a bounded, cores-sized platform pool |

2. Create one virtual thread per task (`Executors.newVirtualThreadPerTaskExecutor()`)
   — a virtual thread represents a task, not a pooled resource; to cap concurrency
   against a limited resource, acquire a `Semaphore` inside the task.
3. Prevent carrier pinning on Java 21–23: a virtual thread blocking inside a
   `synchronized` block/method pins its carrier OS thread, and enough pinned carriers
   starve the scheduler.

| Case | Do |
|------|----|
| Your code holds a lock around blocking I/O | Use `ReentrantLock`, not `synchronized`, at those sites |
| Suspected pinning in a dependency | Run with `-Djdk.tracePinnedThreads=full` and read the printed stacks |
| Java 24+ | JEP 491 removes `synchronized` pinning — only native/JNI frames still pin; keep the tracing check for those |

4. Diagnose memory by symptom:

| Symptom | Cause to test | Do |
|---------|---------------|----|
| Old-gen occupancy rises after every full GC until `OutOfMemoryError: Java heap space` | Heap leak (references never released) | Set `-XX:+HeapDumpOnOutOfMemoryError` in prod; capture `jmap -dump:format=b,file=snap.hprof <pid>` (or `jcmd GC.heap_dump`); open the dump in Eclipse MAT and read the dominator tree for the largest retained sets |
| Container OOMKilled, no Java `OutOfMemoryError` in logs | Total process memory (heap + metaspace + code cache + direct buffers + per-thread stacks) exceeded the cgroup limit | Set `-Xmx` to at most 75% of the container limit (or `-XX:MaxRAMPercentage=75` with container support); budget stacks explicitly: thread count × `-Xss` (per-thread stack size) counts against the same limit |
| Heap stable but process RSS grows | Native/off-heap growth: direct `ByteBuffer`s, metaspace, thread creation | Compare `jcmd VM.native_memory summary` (start with `-XX:NativeMemoryTracking=summary`) across time; cap direct memory with `-XX:MaxDirectMemorySize` |
| Backlog invisible until sudden OOM | Unbounded executor queue absorbing submissions | Bound the queue and define the rejection path → [backend-common-concurrency-shared-state-and-pools] |

## Edge cases

| Case | Then |
|------|------|
| Virtual threads adopted but throughput unchanged | Look for pinning (row 3) or a downstream bottleneck (DB pool, semaphore) — virtual threads raise concurrency ceiling, not downstream capacity |
| ThreadLocal-heavy library on virtual threads | Millions of threads × per-thread cached objects multiplies memory — pass state explicitly or scope the library's work to a bounded platform pool |
| OOMKilled recurs after lowering `-Xmx` | Recount non-heap: thread count × `-Xss`, `MaxDirectMemorySize`, metaspace — one of them, not heap, is the consumer; measure with `jcmd VM.native_memory` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pool virtual threads like platform threads | One virtual thread per task; `Semaphore` for concurrency caps | Pooling re-introduces the scarcity virtual threads remove and caps throughput at pool size |
| Fix pool exhaustion on blocking I/O by growing the platform pool | Move the blocking path to virtual threads | Each platform thread costs an OS thread + stack; growth hits memory and scheduler limits |
| Set `-Xmx` equal to the container memory limit | `-Xmx` ≤ 75% of the limit, rest budgeted to non-heap | The kernel kills the container when TOTAL process memory crosses the cgroup limit — heap alone at the limit guarantees OOMKilled |
| Debug an OOM by reading code for leaks | Heap dump + dominator tree in MAT | The dominator tree names the retaining objects directly; code reading guesses |

## Sources

- https://openjdk.org/jeps/444 — virtual threads final in Java 21; thread-per-request scaling model
- https://openjdk.org/jeps/491 — Java 24 removes synchronized-based pinning; native-frame pinning remains
- https://docs.oracle.com/en/java/javase/21/core/virtual-threads.html — never pool virtual threads; synchronized pinning; ReentrantLock replacement; `jdk.tracePinnedThreads`
- https://docs.oracle.com/en/java/javase/21/troubleshoot/troubleshooting-memory-leaks.html — OutOfMemoryError variants, jmap/jcmd heap dumps, `-XX:+HeapDumpOnOutOfMemoryError`
- https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html — `-XX:+UseContainerSupport`, `-Xss`, `-XX:+HeapDumpOnOutOfMemoryError` flags
- https://www.netdata.cloud/guides/docker/docker-jvm-memory-tuning/ — process RSS components vs cgroup limit; kernel kill without JVM error; ≤75% heap sizing
