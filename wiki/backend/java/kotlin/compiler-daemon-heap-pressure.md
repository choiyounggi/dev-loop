---
id: backend-java-kotlin-compiler-daemon-heap-pressure
domain: backend
category: kotlin
applies_to: [kotlin, gradle]
confidence: field-tested
sources:
  - https://docs.gradle.org/current/userguide/build_environment.html
  - https://kotlinlang.org/docs/gradle-compilation-and-caches.html
  - https://kotlinlang.org/docs/kotlin-daemon.html
last_verified: 2026-09-03
related: [backend-java-runtime-threads-and-memory, debugging-signals-reading-error-messages, debugging-methodology-hypothesis-testing]
---

# A Kotlin Build That Crawls and Then Dies With a Compiler-Internal Error

## When this applies

A Kotlin/Gradle compile takes several times longer than usual (minutes becoming
tens of minutes) and ends in a compiler-internal failure (`Backend Internal
error: Exception during IR lowering`, or another `Exception during …` from the
compiler) rather than a source diagnostic; the project's `gradle.properties`
pins a small `-Xmx` in `org.gradle.jvmargs`; you are about to read the failing
file for a bug. Field-tested: the memory-pressure diagnosis rests on one
measured build (Sources); the property mechanics are doc-backed.

## Do this

1. **Rule out heap pressure before reading code.** Slowness plus an internal
   error is the shape of a JVM spending its time in GC near its limit. Two
   daemons compile Kotlin and each takes a heap:

| Daemon | Heap comes from |
|--------|-----------------|
| Gradle daemon | `org.gradle.jvmargs` |
| Kotlin compile daemon | `kotlin.daemon.jvmargs` when set; otherwise it inherits `-Xmx` from the launching Gradle JVM |

2. **Raise both from the user-level file, leaving the repo untouched.** Gradle
   reads `$GRADLE_USER_HOME/gradle.properties` (default `~/.gradle/`) before the
   project's file, and user-level values take precedence, so a local override
   needs no commit:

```
# ~/.gradle/gradle.properties
org.gradle.jvmargs=-Xmx4g
kotlin.daemon.jvmargs=-Xmx4g
```

   The Gradle property key is `kotlin.daemon.jvmargs` (space-separated args).
   The similarly named `kotlin.daemon.jvm.options` is a JVM system property that
   is valid only inside `org.gradle.jvmargs`
   (`-Dkotlin.daemon.jvm.options=-Xmx4g,Xms1g`, comma-separated); as a bare
   `gradle.properties` line it sets nothing.

3. **Stop the running daemons, recompile with `--rerun-tasks`, and compare wall
   time and outcome.** A daemon keeps the JVM args it started with, so
   `./gradlew --stop` first. When the same source now compiles, and faster, the
   failure was memory pressure. When it fails identically at the same phase, it
   is a compiler defect: search the exact message with the Kotlin version and
   reduce the file ([debugging-methodology-hypothesis-testing]).

## Edge cases

| Case | Then |
|------|------|
| CI shows the same failure | CI has no user-level file; raise the project `gradle.properties` value in a commit, sized to the runner's memory — the total-process budget rules in [backend-java-runtime-threads-and-memory] apply to the daemon JVM too |
| The build is fast and the internal error still appears | Not heap: the documented causes of `Exception during IR lowering` are compiler bugs in specific lowering phases; report upstream with a minimal reproducer |
| The project file already sets `kotlin.daemon.jvmargs` | The user-level value still wins (user-level precedence covers every property), so the override applies without editing the project |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Bisect the source for the "bug" behind an IR-lowering error after a 20-minute build | Raise both daemon heaps at user level and rebuild once | One cheap run separates memory pressure from a compiler defect |
| Write `kotlin.daemon.jvm.options=-Xmx4g` as a `gradle.properties` line | Write `kotlin.daemon.jvmargs=-Xmx4g` | The dotted form is a system property, only meaningful inside `org.gradle.jvmargs` |
| Edit the project's `gradle.properties` for a local machine | Set the user-level file | User-level takes precedence and the override stays out of the diff |

## Sources

- https://docs.gradle.org/current/userguide/build_environment.html — "Gradle first looks in the user-level gradle.properties file located in GRADLE_USER_HOME, then in the project-level gradle.properties file, and finally in the gradle.properties file located in GRADLE_HOME, with user-level properties taking precedence over project-level"
- https://kotlinlang.org/docs/gradle-compilation-and-caches.html — `kotlin.daemon.jvmargs=-Xmx1500m -Xms500m` as the Gradle property; `org.gradle.jvmargs=-Dkotlin.daemon.jvm.options=-Xmx1500m,Xms500m` as the system-property form; "By default, the Kotlin daemon inherits a specific set of arguments from the Gradle daemon but overwrites them with any JVM arguments specified directly for the Kotlin daemon"
- https://kotlinlang.org/docs/kotlin-daemon.html — "By default, the Kotlin daemon tries to inherit the heap size (-Xmx) of the launching JVM process"
- Field measurement 2026-09-03 (Kotlin/Gradle project with `-Xmx1024m` in the project file): the same source failed after 19 minutes with `Backend Internal error: Exception during IR lowering`; with only a user-level `-Xmx4g` override and `--rerun-tasks` it built in 4 min 13 s. One observation — the message's documented causes elsewhere are compiler defects, which is why step 3 keeps both hypotheses live
