---
id: security-data-commit-identity-in-public-repos
domain: security
category: data
applies_to: [git, github, general]
confidence: verified
sources:
  - https://git-scm.com/docs/git-commit
  - https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-email-preferences/setting-your-commit-email-address
  - https://git-scm.com/docs/git-log
  - https://github.com/newren/git-filter-repo/blob/main/Documentation/git-filter-repo.txt
  - https://github.blog/changelog/2019-12-19-improved-attribution-when-squashing-commits/
last_verified: 2026-09-08
related: [security-secrets-secrets-in-code, security-data-pii-handling, qa-process-session-identity-leak-in-plugin-prose]
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

6. **Audit every public repo under the account before remediating a single
   commit** — identity leaks are config-level: the same ambient `user.email`
   that leaked in the commit you noticed was in force for every commit you made
   from that machine, in every repo, so the leak is wider than the one commit
   you saw.

   ```sh
   git -C <each-public-repo> log --format='%ae%n%ce' | sort -u
   git -C <each-public-repo> log --format='%B' | grep -iE '<leaked-address>|co-authored-by'
   ```

   Check `%ce` (committer email) as well as `%ae` (author email) — a rebase,
   cherry-pick, or a forge-performed merge sets the committer independently of
   the author, so an author-only check misses it. Grep the message body too:
   GitHub credits "every commit author in the pull request as a co-author on
   the squash commit", so a leaked address can appear only in a
   `Co-authored-by:` trailer, on a commit whose `%ae`/`%ce` never shows it.

7. **Rewrite with `git filter-repo --mailmap <file> --replace-message <file>`
   when the leak spans more than the one commit you already amended**, rather
   than an amend/`rebase -i` loop over each affected commit — `--mailmap`
   rewrites author, committer, and tagger names/emails from one mapping file
   across full history in a single pass; `--replace-message` replaces matched
   text in commit/tag message bodies, which is what reaches `Co-authored-by:`
   trailers, since `--mailmap` only touches the structured identity fields.
   Before force-pushing the rewritten branch, confirm both: a repeat of the
   audit in item 6 returns zero matches, and `git diff <old-tip> <new-tip>` is
   empty (the rewrite changed identity metadata and message text, not file
   contents).

## Edge cases

| Case | Then |
|------|------|
| The wrong address is already pushed to a public repository | Treat it as disclosed: the address is served by the forge API, present in every clone, and in downloadable archives. Fix the identity going forward and, when the address must not be associated with the project, rewrite history and force-push before it is mirrored — the window is short and closes on the first fork or archive |
| The repository is public and the commit is old | Rewriting shared history breaks every existing clone; correct forward and accept the historical entry unless the exposure is material |
| Only the committer differs from the author (rebase, cherry-pick, a merge you performed) | Both identities are published; set both with `GIT_COMMITTER_EMAIL`/`-c user.email`, which feeds both unless the `GIT_*` variables are set |
| GitHub squash-merged a pull request whose commits carried the leaked address | The squash commit's message carries a `Co-authored-by:` trailer per original commit author even when the squash commit's own `%ae`/`%ce` is clean — grep message bodies (`git log --format=%B`), not only `%ae`/`%ce`, before treating a repo as clear |
| The leak spans many commits, multiple repos, or committer/trailer fields rather than one author field | Use `git filter-repo --mailmap --replace-message` (Do this, item 7) instead of amending commits one at a time — it rewrites author/committer/tagger fields and message text across full history in one pass, and its output is verifiable against the pre-rewrite tree |
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
- https://git-scm.com/docs/git-log — pretty formats: `%ae` is the author email, `%ce` the committer email — two distinct fields, both published
- https://github.com/newren/git-filter-repo/blob/main/Documentation/git-filter-repo.txt — `--mailmap`: "Use specified mailmap file ... when rewriting author, committer, and tagger names and emails"; `--replace-message`: "A file with expressions that, if found in commit or tag messages, will be replaced"
- https://github.blog/changelog/2019-12-19-improved-attribution-when-squashing-commits/ — "we will automatically credit every commit author in the pull request as a co-author on the squash commit"
- Field incident 2026-09 (two public repos under one account): one noticed author-field leak turned out to be 12 committer-field + 4 trailer leaks in one repo and 16 + 3 + trailers in the other (plus a second employer's address); all purged via `git filter-repo --mailmap` + `--replace-message` with byte-identical trees, verified by zero-match greps on the rewritten remotes
- Field incident 2026-08-06 (`groundwork`, public repository, macOS): `git config user.email` resolved to an employer address while `git log -1 --format=%ae` showed the repository's history authored under a GitHub no-reply address — the mismatch was silent and would have been published by the next commit
