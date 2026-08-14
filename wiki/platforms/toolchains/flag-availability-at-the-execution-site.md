---
id: platforms-toolchains-flag-availability-at-the-execution-site
domain: platforms
category: toolchains
applies_to: [general]
confidence: verified
sources:
  - https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration-changes.html
  - https://semver.org/
  - https://protobuf.dev/programming-guides/proto3/
last_verified: 2026-08-14
related: [platforms-toolchains-version-management, platforms-tools-bsd-vs-gnu-cli, backend-common-integrations-externally-owned-defaults]
---

# A CLI Flag, Subcommand, or API Method That Exists Locally but Not Where It Runs

## When this applies

A change adds a CLI flag, a new subcommand, or a call to a new SDK/API method against
a pinned dependency. Also when reviewing such a diff and the PR does not state the
tool/dependency version installed in CI, on teammates' machines, or in the deploy
image — the author's shell proves the flag exists on the author's shell only.

## Do this

| Case | Do |
|------|----|
| Flag added to a command that runs in CI | Resolve the flag against the CI image's own tool, not the author's shell: run `<tool> --help` inside the same image/container the job uses, and pin the tool's version in that image/lockfile in the same change that adds the flag — one change, not two that can drift apart |
| Flag added to a command that runs on a user's/teammate's machine | State the minimum tool version in the change and add a preflight check that runs `<tool> --version` and fails with a named-version error below the minimum, rather than letting the flag itself be the first thing that fails |
| A new subcommand | Confirm the subcommand appears in `<tool> help`'s own command list at the execution site before merging, not just that it runs on the author's machine — an absent subcommand is the loudest failure in this class (non-zero exit, "unknown command"), so catch it at review instead of at run time |
| A new SDK/API method on a pinned dependency | Check the dependency version the lockfile that the deploy/runtime environment actually installs from resolves to, not the version under the author's local `node_modules`/`site-packages`; bump the pin in the same change that calls the new method |

Version pins exist for exactly this: a new flag, subcommand, or method is new
*functionality*, and semantic versioning's own contract is that new backward-compatible
functionality is a MINOR bump (semver.org, clause 7) — so "pin the version alongside
the flag" and "the flag's presence" are the same fact stated two ways, and checking
one without the other lets them drift.

## Edge cases

| Case | Then |
|------|------|
| The flag/field exists syntactically but is a silent no-op in the older/deployed version | This is the case CLI flag parsers usually don't produce (unknown flags typically hard-error); it shows up instead in structured inputs — a new field on a protobuf-based request, an SDK constructor kwarg, a config-file key. Proto3 "preserves unknown fields... in the serialized output" (protobuf.dev) — but an older server's generated code has no accessor for a field it doesn't know, so the call returns 200 while the intended behavior never happens. Add an explicit assertion (response field present / behavior observed), not just an exit-code check |
| The tool is version-managed, so the authoring shell and the CI shell resolve different binaries | Confirm which binary each shell actually resolves — pin file vs PATH lookup can diverge silently ([platforms-toolchains-version-management]) |
| The same flag name means something different in the execution site's userland | A flag that exists at both sites is not the same guarantee as a flag that *behaves* the same at both — check the other userland's own docs, not just that the name is present ([platforms-tools-bsd-vs-gnu-cli]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust that a flag works because it ran on your machine | Run the same command against the execution site's actual tool version (CI image, deploy image, teammate's pin) before merging | Your shell's version is one instance among several the diff must run under |
| Add the flag and assume a missing one always errors loudly | Check whether the input is structured (protobuf field, SDK kwarg, config key) where unknown values are silently preserved or dropped rather than rejected | Hard-error-on-unknown is a CLI-parser convention, not a universal one |
| Bump only the pin, or only add the flag, in separate changes | Land the version bump and the flag/method that depends on it together | A pin bump that lands later (or not at all) leaves the flag calling a version that doesn't have it |

## Sources

- https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration-changes.html — concrete version-gated CLI surface: the `--copy-props` parameter is new to `aws s3` commands in CLI v2 ("The AWS CLI version 2 adds the `--copy-props` parameter"); `aws ecr get-login-password` is "available in the AWS CLI version 1.17.10 and later, and the AWS CLI version 2" — the same binary name, gated by a specific version
- https://semver.org/ — clause 7: "Minor version Y (x.Y.z | x > 0) MUST be incremented if new, backward compatible functionality is introduced to the public API" — the versioning contract that a new flag/method is a version fact, not just a code fact
- https://protobuf.dev/programming-guides/proto3/ — "Proto3 messages preserve unknown fields and include them during parsing and in the serialized output" — unknown fields survive on the wire but are not exposed to code compiled without them, which is the silent-no-op mechanism for structured (non-CLI) inputs
