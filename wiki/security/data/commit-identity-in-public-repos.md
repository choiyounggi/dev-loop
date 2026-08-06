---
id: security-data-commit-identity-in-public-repos
domain: security
category: data
applies_to: [git, github, general]
confidence: verified
sources:
  - https://git-scm.com/docs/git-commit
  - https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-email-preferences/setting-your-commit-email-address
last_verified: 2026-08-06
related: [security-secrets-secrets-in-code, security-data-pii-handling]
---

# The Author Identity a Commit Carries into a Public Repository

## When this applies

You are about to commit to a repository whose history is public (or will be
published) from a machine whose git identity was configured for something else —
a work laptop set to an employer address, a shared build box, a container image.
Also when a repository's existing history was authored under a different address
than the one your git config now holds.

## Do this

1. **Compare the identity in force against the identity the history uses,
   before the commit:**

   ```sh
   git config user.email          # what your next commit will carry
   git log -1 --format=%ae        # what this repository's history carries
   ```

   When they differ, decide which one this repository should have rather than
   letting the ambient one win.

2. **Override per commit, not globally**, when the machine's identity is correct
   for its other repositories:

   ```sh
   git -c user.name="…" -c user.email="…" commit -m "…"
   ```

   Git takes the author from `GIT_AUTHOR_*`, then `user.name`/`user.email`, then
   `EMAIL`, then a hostname-derived guess — so a `-c` override binds the identity
   for exactly this invocation and changes nothing else.

3. **Set it per repository when you will commit here again:**
   `git config user.email "…"` inside the clone. GitHub: "This will override
   your global Git configuration settings in this one repository, but will not
   affect any other repositories."

4. **Use the forge's no-reply address for public work** so the published history
   carries a routable identity that is not a mailbox you must defend.

5. **Verify after the first commit, before pushing** — `git log -1 --format=%ae`
   — because that is the last point at which the fix is a local amend.

## Edge cases

| Case | Then |
|------|------|
| The wrong address is already pushed to a public repository | Treat it as disclosed: the address is served by the forge API, present in every clone, and in downloadable archives. Fix the identity going forward and, when the address must not be associated with the project, rewrite history and force-push before it is mirrored — the window is short and closes on the first fork or archive |
| The repository is public and the commit is old | Rewriting shared history breaks every existing clone; correct forward and accept the historical entry unless the exposure is material |
| Only the committer differs from the author (rebase, cherry-pick, a merge you performed) | Both identities are published; set both with `GIT_COMMITTER_EMAIL`/`-c user.email`, which feeds both unless the `GIT_*` variables are set |
| The commit is produced by CI or a bot | Give it its own dedicated identity in the workflow environment, not a person's — a human address on machine commits misattributes authorship |
| Your git config has no identity at all | Git falls back to the system user name plus a hostname-derived domain, which publishes the machine's hostname; set the identity explicitly rather than relying on the fallback |
| The project requires a real address (DCO sign-off, CLA) | The no-reply form is not acceptable for sign-off; use a personal address you are willing to publish |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Commit and rely on the machine's configured identity being right | Compare `git config user.email` against `git log -1 --format=%ae` first | Git does not warn on a mismatch — it commits silently with whichever identity resolves, so the first signal is the published commit |
| Change the global config so this repository gets the right address | Override per invocation (`git -c`) or per clone (`git config` inside it) | A global change silently re-identifies every other repository on the machine, including the ones the original address was correct for |
| Fix a leaked address by deleting the branch | Rewrite the commits and force-push, and treat the address as already disclosed | Deleting a branch does not remove reachable commit objects from the forge's API or from clones already taken |
| Publish a personal mailbox to keep commits linked to your account | Use the forge's no-reply address | It links commits to the account without publishing a mailbox |

## Sources

- https://git-scm.com/docs/git-commit — "the information is taken from the configuration items `user.name` and `user.email`, or, if not present, the environment variable `EMAIL`, or, if that is not set, system user name and the hostname used for outgoing mail"; `GIT_AUTHOR_*`/`GIT_COMMITTER_*` take precedence over config
- https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-email-preferences/setting-your-commit-email-address — "GitHub uses the email address set in your local Git configuration to associate commits pushed from the command line with your account"; a per-repository address "will override your global Git configuration settings in this one repository, but will not affect any other repositories"
- Field incident 2026-08-06 (`groundwork`, public repository, macOS): `git config user.email` resolved to an employer address while `git log -1 --format=%ae` showed the repository's history authored under a GitHub no-reply address — the mismatch was silent and would have been published by the next commit
