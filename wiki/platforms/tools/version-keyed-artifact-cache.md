---
id: platforms-tools-version-keyed-artifact-cache
domain: platforms
category: tools
applies_to: [claude-code, general]
confidence: verified
sources:
  - https://code.claude.com/docs/en/plugin-marketplaces
  - https://github.com/anthropics/claude-code/issues/45542
  - https://github.com/anthropics/claude-code/issues/17361
  - https://github.com/anthropics/claude-code/issues/61954
  - https://github.com/mattpocock/skills/blob/main/scripts/sync-plugin-version.mjs
last_verified: 2026-09-04
related: [platforms-toolchains-version-management, platforms-tools-plugin-mcp-server-registration, platforms-tools-unpacked-extension-source-reload]
---

# Shipping New Code Through a Version-Keyed Artifact Cache

## When this applies

You pushed code to a distribution system that caches artifacts in a directory
keyed by a version string — a Claude Code marketplace plugin (files under
`plugins/*/` or a plugin repo), or any tag-pinned cache — and expect the
consumer's "update" to deliver the new code. The update runs, reports success or
"already up to date", but the old behavior persists.

## Do this

1. **Bump the version in the same change as the code.** For a Claude Code plugin,
   raise `.claude-plugin/plugin.json` `version` **and** the matching
   `marketplace.json` entry in the commit that ships the code. The updater keys on
   the version string: an unchanged version is treated as already-installed, so
   the version-keyed cache dir is never refreshed and the new code never runs.

2. **Know where the cache lives so you can confirm the refresh.** Claude Code
   stores each version in its own sibling directory:
   `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. Multiple versions
   coexist there. After an update, check that a directory for the **new** version
   exists — its absence means the bump did not take.

3. **Refresh the marketplace index before the plugin update.** A directory-source
   marketplace caches its `marketplace.json`; run `claude plugin marketplace
   update` (or reinstall the marketplace) so the new version is even visible, then
   update the plugin.

4. **If the cache is still stale after a correct bump, clear it explicitly.**
   Remove the stale entry from `~/.claude/plugins/installed_plugins.json` and
   `rm -rf ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, then
   reinstall. Known updater bugs leave the cache stale even after a version bump;
   a manual clear is the reliable fallback.

5. **Prefer one manifest as the version's source of truth; gate the pair with
   CI only if you keep both.** Claude Code reads `plugin.json`'s version and
   ignores `marketplace.json`'s when both are set, so declaring it in one
   place removes the drift risk entirely. If you keep both anyway — for
   example so the marketplace listing shows a version without an install —
   add a script with a `--check` mode that compares the two, matched by
   plugin **name** (a self-referential marketplace's own entry has a git-URL
   `source`, not a local path, so a path-keyed comparison resolves nothing),
   and run it in CI on every push and before any automated release bump.

| Case | Do |
|------|----|
| You control only `plugin.json` | Leave `version` unset in the marketplace entry; there is nothing left to drift |
| You need both fields populated (display, tooling) | Add a `--check`-mode sync/compare script and run it in CI; treat a mismatch or a missing matching entry as a build failure, not a warning |

## Edge cases

| Case | Then |
|------|------|
| Plugin has no version field | The cache dir is keyed `…/<plugin>/unknown/` and every push collides in one dir — add a version to get per-version isolation and detectable updates |
| Testing a local edit fast | Edit the resolved cache dir directly for a throwaway check, but land the fix by version bump — cache edits are overwritten on the next real install |
| `/plugin update` reports "at latest" yet behavior is old | You shipped under an unchanged version; bump it, or clear the cache (step 4) |
| The plugin runs from a hook/subagent (headless) | It executes the cached `<version>/` copy, not your working tree — an unbumped change is invisible there too |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Push plugin code and re-run `/plugin update` under the same version | Bump `plugin.json` + `marketplace.json` version in the same commit | The updater compares version strings; same version → up-to-date → the version-keyed cache dir is not rewritten |
| Uninstall/reinstall to force fresh code without changing the version | Bump the version (and clear the cache dir if a bug persists) | Uninstall/install keyed to the same version can reuse the stale cache; only a new version guarantees a new dir |

## Sources

- https://code.claude.com/docs/en/plugin-marketplaces — plugin/marketplace manifests carry a `version`; installs are cached per marketplace/plugin
- https://github.com/anthropics/claude-code/issues/45542 — "Plugin cache not refreshed when version number is unchanged after uninstall/install"
- https://github.com/anthropics/claude-code/issues/17361 — cache never refreshes; Claude reads the stale cached copy even with autoUpdate
- https://github.com/anthropics/claude-code/issues/61954 — `plugin update` reports "at latest" while the cache stays stale vs. a refreshed marketplace
- Observed 2026-08-04: `~/.claude/plugins/cache/` holds per-version sibling dirs (`figma/2.2.81`, `2.2.87`, `2.2.88`; `dev-loop/0.8.0`…`0.11.0`), confirming the cache is keyed by version string
- https://code.claude.com/docs/en/plugin-marketplaces — "Avoid setting `version` in both `plugin.json` and the marketplace entry. Claude Code always uses the `plugin.json` value without warning, so a stale manifest version can mask a version you set in `marketplace.json`" — the single-source-of-truth alternative to gating
- https://github.com/mattpocock/skills/blob/main/scripts/sync-plugin-version.mjs — public reference implementation: `--check` mode compares `plugin.json`'s version against `package.json`'s and exits 1 with a fix-it message on drift, wired as `npm run check-plugin-version`
- Local observation 2026-09-04 (this repo, dev-loop): `scripts/check-versions.sh` implements this gate — matches `marketplace.json` entries to `plugin.json` by plugin name (not source path, since this marketplace's one entry is self-referential with a git-URL source), fails the build on any mismatch or on zero matching entries, and runs as a named "Version gate" step in `.github/workflows/test.yml` and inside `auto-release.yml`'s automated bump; the workflow step's comment records that "this pair has drifted unenforced before (a real release incident)"
