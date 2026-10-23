---
id: testing-quality-new-test-outside-a-runner-include-filter
domain: testing
category: quality
applies_to: [general, java, kotlin, gradle]
confidence: verified
sources:
  - https://docs.gradle.org/current/userguide/java_testing.html
  - https://docs.gradle.org/current/javadoc/org/gradle/api/tasks/testing/TestFilter.html
last_verified: 2026-10-24
related: [testing-quality-tests-that-cannot-fail, testing-quality-checks-that-cannot-pass, testing-strategy-failing-test-first]
---

# A New Test File in a Build Whose Test Task Lists Its Tests

## When this applies

You add a test class (or file) to a repo whose test task selects tests through a
build-script list — Gradle `test { filter { includeTestsMatching … } }` is the
common case — and you are about to report the new test as written and passing
because the full `gradle test` run is green.

## Do this

1. **Read the test task's filter before adding the file.** Open `build.gradle`
   (or `build.gradle.kts`) and look for a `filter { includeTestsMatching … }`
   block on the `test` task. When it exists, the list is a whitelist: a class it
   does not match is never run, whatever its path and name.
2. **Register the new class in that list in the same change.**
3. **Prove the new test ran.** Run it by name (`gradle test --tests '<fqcn>'`)
   and read the executed count in the report. Gradle still applies the
   build-script inclusions when `--tests` is given, so an unregistered class
   fails here with "No tests found for given includes" — the failure that tells
   you step 2 is missing.
4. **Make the test fail once.** Break the assertion, confirm the named run goes
   red, restore it ([testing-quality-tests-that-cannot-fail]).

| What you see | What it means |
|--------------|---------------|
| Full `gradle test` green, new class absent from the report | The filter excludes it — it never ran |
| `--tests '<new class>'` → "No tests found for given includes" | Filter exists and does not match the class |
| `--tests '<new class>'` runs N tests, N = cases you wrote | Registered and running |

## Edge cases

| Case | Then |
|------|------|
| The filter uses package wildcards (`kr.co.app.part.*`) | A class in that package is covered; one in a new package is not — check the pattern against the class's full name |
| A filter matches nothing at all | `failOnNoMatchingTests` (default `true`) fails the task; setting it `false` turns the same mistake into a silent pass, so keep the default |
| CI runs a different task (`integrationTest`) with its own filter | Register the class in the filter of the task CI actually runs |
| No build-script filter exists | Steps 1–2 do not apply; step 3 still confirms discovery |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Cite a green full-suite run as proof the new test passes | Run the new class by name and read its executed count | A filtered-out class is excluded silently, so the full run is green without it |
| Set `failOnNoMatchingTests = false` to make a named run pass | Add the class to the filter | The flag hides the exact signal that the class is unregistered |

## Sources

- https://docs.gradle.org/current/userguide/java_testing.html — "You can enable filtering either in the build script or via the `--tests` command-line option"; "When you use `--tests`, be aware that the inclusions declared in the build script are still honored"; "Filtering supersedes the inclusion/exclusion mechanism"
- https://docs.gradle.org/current/javadoc/org/gradle/api/tasks/testing/TestFilter.html — `includeTestsMatching` "Appends a test name pattern to the inclusion filter"; `isFailOnNoMatchingTests` "Returns whether the task should fail if no matching tests where found. The default is true."
- Field reproduction (Gradle multi-module Spring repo with a 21-pattern `includeTestsMatching` list; the message text "No tests found for given includes" comes from this run, not from the docs): three new integration-test classes run with `--tests '<package>.*'` failed with "No tests found for given includes" listing only the 21 existing patterns; after adding the three classes to `build.gradle`, the same command ran 16 tests
