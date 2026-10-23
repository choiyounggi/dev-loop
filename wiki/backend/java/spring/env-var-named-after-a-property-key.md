---
id: backend-java-spring-env-var-named-after-a-property-key
domain: backend
category: spring
applies_to: [java, kotlin, spring, spring-boot]
confidence: verified
sources:
  - https://docs.spring.io/spring-boot/reference/features/external-config.html
  - https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/core/env/SystemEnvironmentPropertySource.html
  - "Local reproduction 2026-10-23: spring-core 5.3.30 + spring-boot 2.7.16 and spring-core 6.1.14 + spring-boot 3.3.5, JDK 17 (Corretto 17.0.16)"
last_verified: 2026-10-23
related: [infrastructure-config-environment-config, security-secrets-secrets-in-code]
---

# An Environment Variable Named After the Property Key That References It

## When this applies

A Spring/Spring Boot app moves a secret or setting out of `application.yml`
into an environment variable referenced as `${ENV}`, and the env name is the
property path upper-cased (`client.payment-api.key` → `CLIENT_PAYMENT_API_KEY`) —
especially when the yml value composes the variable with other text
(`"Bearer ${CLIENT_PAYMENT_API_KEY}"`, `"${HOST}:${PORT}"`).
Also when an outbound call starts failing with 401/400 right after such a
change while the app boots normally.

## Do this

1. **Name the env variable outside the property's own env forms.** For a
   property `a.b-c.d`, spring-core's `SystemEnvironmentPropertySource` matches
   `A_B_C_D` (dots and dashes → `_`), and Spring Boot's documented env form
   `A_BC_D` (dashes removed) matches once Boot's configuration property sources
   are attached; a Boot app consults both. Pick a name that is neither —
   `PAYMENT_API_TOKEN` for `client.payment-api.key` — and reference it from yml:
   `key: "Bearer ${PAYMENT_API_TOKEN}"`.
2. **Know why the collision wins.** OS environment variables rank above config
   data files in Spring Boot's property-source order, and later sources
   override earlier ones; the env value then replaces the *whole* yml value, so
   the composed prefix disappears with no error.
3. **Add one test that injects the env variable and asserts the resolved
   value** (the final header string, the URL), not merely that the property is
   non-null — the collision produces a non-null value.

| Case | Do |
|------|----|
| The yml value is exactly `${ENV}` with nothing around it | A colliding name is harmless today (both paths yield the same string); rename it anyway when you touch it, so a later edit that adds a prefix does not silently break |
| The yml value composes the variable with a prefix, suffix, default, or a second variable | Rename the env variable per step 1 — this is the case that strips the composition |
| The deployment platform already sets the colliding name and you cannot rename it there | Move the composition into code (build the header from the raw key) and bind the property to the bare key |
| You need the env variable to override the property on purpose | Name it after the property and put the *complete* final value in it (prefix included) |

## Edge cases

| Case | Then |
|------|------|
| Plain spring-core `Environment` without Spring Boot | `SystemEnvironmentPropertySource` matches the underscore form (`CLIENT_PAYMENT_API_KEY`) but not the dash-removed form (`CLIENT_PAYMENTAPI_KEY`); with Boot's configuration property sources attached both forms match. Name the variable outside both forms (step 1) so the rename holds under either setup |
| `@ConfigurationProperties` binding instead of `@Value` | Same relaxed binding applies — the env form of the bound key overrides the yml entry |
| A test passes with the yml value but production fails | The test environment did not set the env variable; inject it in the test (step 3) so the override path runs |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Derive the env name by upper-casing the property path | Choose a name outside the property's env forms | That name is the property itself to Spring, so it overrides the yml expression instead of feeding it |
| Verify the externalization by checking the app boots | Assert the resolved composite value with the env variable set | Boot and bean wiring succeed; only the outbound call sees the stripped value |

## Sources

- https://docs.spring.io/spring-boot/reference/features/external-config.html — "Later property sources can override the values defined in earlier ones"; the source order lists "Config data (such as application.properties files)" before "OS environment variables"; to convert a property name to an env name, "Replace dots (.) with underscores (_). Remove any dashes (-). Convert to uppercase." (`spring.main.log-startup-info` → `SPRING_MAIN_LOGSTARTUPINFO`)
- https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/core/env/SystemEnvironmentPropertySource.html — `getProperty("foo.bar")` also finds `foo_bar`, `FOO.BAR`, `FOO_BAR`; "Any hyphen variant of the above would work as well"
- Local reproduction 2026-10-23, run identically on spring-core 5.3.30 + spring-boot 2.7.16 and on spring-core 6.1.14 + spring-boot 3.3.5 (JDK 17; one `StandardEnvironment` per process, env variable set on the process, `resolvePlaceholders("${feign.kakao-api.key}")`): yml `feign.kakao-api.key = "KakaoAK ${KAKAO_SECRET:unset}"` resolved through `ConfigurationPropertySources.attach(env)`: env `FEIGN_KAKAO_API_KEY=DUMMY` → `DUMMY`; env `FEIGN_KAKAOAPI_KEY=DUMMY` → `DUMMY`; env `KAKAO_SECRET=DUMMY` → `KakaoAK DUMMY`. With spring-core's `PropertySourcesPropertyResolver` alone, `FEIGN_KAKAO_API_KEY` → `DUMMY` and `FEIGN_KAKAOAPI_KEY` → `KakaoAK unset`
- Field context 2026-10 (a Spring Boot 2.7 service, recorded by the originating session): after moving an API key to `FEIGN_KAKAO_API_KEY` referenced as `"KakaoAK ${FEIGN_KAKAO_API_KEY}"`, the service restarted cleanly and the external API returned 401 on every call until the name was changed
