---
id: platforms-tools-templater-device-local-settings
domain: platforms
category: tools
applies_to: [obsidian, templater]
confidence: verified
sources:
  - https://raw.githubusercontent.com/SilentVoid13/Templater/master/src/settings/LocalSettings.ts
  - https://raw.githubusercontent.com/SilentVoid13/Templater/master/src/settings/Settings.ts
  - https://raw.githubusercontent.com/SilentVoid13/Templater/master/src/main.ts
  - https://raw.githubusercontent.com/obsidianmd/obsidian-api/master/obsidian.d.ts
last_verified: 2026-11-04
related: []
---

# Configuring the Obsidian Templater Plugin Through Its Settings File

## When this applies

You configure Templater by writing its `data.json` (a scripted vault setup, an
agent editing the vault) so folder templates apply when a note is created, and
the templates do not fire even though the file holds the expected values.

## Do this

1. Write `folder_templates` and `trigger_on_file_creation_mode` to `data.json`.
2. Ask the user to turn on "Trigger on file creation" in the Templater settings
   screen, on each device and for each vault.

| Setting | Stored in |
|---------|-----------|
| `folder_templates`, `trigger_on_file_creation_mode` and other plugin settings | `data.json` |
| `trigger_on_file_creation` | Device local storage, key `templater-local-settings` |
| `enable_startup_templates` | Device local storage, same key |
| `enable_system_commands` | Device local storage, same key |

## Edge cases

| Case | Then |
|------|------|
| The vault syncs to a second device | Turn the three local settings on there too: they stay on the device, and they default to `false` |
| An older `data.json` still holds `trigger_on_file_creation: true` | Load migration does not copy it to local storage; Templater shows a notice naming the reset settings, and the user re-enables them in the settings screen |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `trigger_on_file_creation: true` to `data.json` | Ask the user to enable it in the settings screen | Reads for these keys go to `getLocalSettings`, so a value in `data.json` has no effect |

## Sources

- https://raw.githubusercontent.com/SilentVoid13/Templater/master/src/settings/LocalSettings.ts — the three keys, their `false` defaults, and `LOCAL_STORAGE_KEY = "templater-local-settings"`
- https://raw.githubusercontent.com/SilentVoid13/Templater/master/src/settings/Settings.ts — local keys routed to `getLocalSettings`/`saveLocalSetting`, others through `plugin.settings`
- https://raw.githubusercontent.com/SilentVoid13/Templater/master/src/main.ts — `load_settings` shows the notice "reset because they are now device-local"; `test/specs/migration.e2e.ts` asserts these keys are not migrated to localStorage
- https://raw.githubusercontent.com/obsidianmd/obsidian-api/master/obsidian.d.ts — `App.loadLocalStorage`/`saveLocalStorage` hold a vault-specific value in `localStorage`
- Field report: Templater 2.26.0 bundled `main.js` holds the same defaults and key
