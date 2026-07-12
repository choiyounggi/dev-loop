---
id: security-dependencies-supply-chain
domain: security
category: dependencies
applies_to: [general]
confidence: verified
sources:
  - https://docs.npmjs.com/cli/v10/commands/npm-ci
  - https://docs.npmjs.com/cli/v10/configuring-npm/package-lock-json
  - https://pip.pypa.io/en/stable/topics/secure-installs/
  - https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/
  - https://docs.github.com/en/code-security/dependabot/dependabot-security-updates/about-dependabot-security-updates
last_verified: 2026-07-10
related: [security-secrets-secrets-in-code]
---

# Trusting and Maintaining Third-Party Dependencies

## When this applies

Adding a dependency, updating dependencies, or hardening a project against
malicious or compromised packages.

## Do this

1. **Commit the lockfile and install from it** — `npm ci` / `pnpm install
   --frozen-lockfile` / `pip install` with hash-pinned requirements. Every build
   then resolves byte-identical artifacts; a registry-side swap or floating
   re-resolution fails the install instead of shipping.
2. **Adding a dependency is a permanent trust grant** to its maintainers, and
   their dependencies' maintainers. Decide by:

| Case | Do |
|------|----|
| Stdlib or an already-installed dependency covers the need | Use that; add nothing |
| Small utility (a function, a few dozen lines) | Write it in-repo |
| Genuinely needed (crypto, parsers, protocol clients — code you must not hand-roll) | Vet before adding: recent releases and issue responsiveness, adoption, open advisories, and whether the package ships install scripts |

3. **On first add, verify the exact package name** against the project's official
   repo/docs — typosquats sit one character away from popular names.
4. Applications pin exact versions via the lockfile; run automated vulnerability
   scanning with update PRs (Dependabot-style), gated by the test suite.
5. **Install scripts (postinstall) are arbitrary code execution at install
   time.** Review them on every new dependency; where the ecosystem allows,
   disable by default and allowlist (`npm --ignore-scripts`, pnpm's per-package
   script approval).

## Edge cases

| Case | Then |
|------|------|
| You publish a library, not an app | Declare compatible version ranges in the manifest for consumers; still commit a lockfile so your own CI builds reproducibly |
| CI runs a bare resolving install (`npm install`) | Switch to the frozen-lockfile command — resolution in CI defeats the committed lockfile |
| Urgent CVE in a transitive dependency the direct dep hasn't picked up | Apply a lockfile-level override (`overrides`/`resolutions`); remove it when the direct dependency updates |
| Dependency shows no releases or issue activity across recent versions of its ecosystem | Plan a replacement or vendor the code — future CVEs in it will have no fix |
| Monorepo/internal registry mixing internal and public names | Scope internal packages (`@org/…`) and pin the registry per scope — unscoped internal names invite dependency-confusion substitution from the public registry |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Auto-merge all dependency update PRs | Auto-PR + test gate; human review for majors and for new transitive trees | A compromised release rides auto-merge straight to prod; tests don't judge changed behavior contracts |
| Add a package for a trivial function | Write the function | Each package is a standing trust grant and a future CVE surface |
| Delete the lockfile to escape an install conflict | Resolve the conflicting ranges and update only the packages involved | Regenerating from scratch silently re-resolves every dependency, discarding the vetted state |

## Sources

- https://docs.npmjs.com/cli/v10/commands/npm-ci — clean installs strictly from the lockfile
- https://docs.npmjs.com/cli/v10/configuring-npm/package-lock-json — lockfile purpose: reproducible dependency trees
- https://pip.pypa.io/en/stable/topics/secure-installs/ — hash-checking mode for pinned installs
- https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/ — unmaintained/vulnerable components as a top risk
- https://docs.github.com/en/code-security/dependabot/dependabot-security-updates/about-dependabot-security-updates — automated vulnerability update PRs
