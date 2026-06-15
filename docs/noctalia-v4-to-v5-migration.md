# Noctalia v4 to v5 migration notes

Last investigated: 2026-06-15.

This document records the migration impact of moving from Noctalia v4 to v5.
It is intentionally split into general upstream facts first, then facts specific
to this repo and the `nixos-work` host.

## 1. Upstream v4 to v5 changes

### What changed

Noctalia v5 is not a normal v4 point upgrade. It is a ground-up rewrite.

| Area            | v4                                                                                                     | v5                                                                      | Migration impact                                               |
| --------------- | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- | -------------------------------------------------------------- |
| Implementation  | Quickshell / Qt / QML shell                                                                            | Native C++ Wayland/OpenGL shell                                         | Old QML assumptions and plugin code do not carry over.         |
| Binary          | `noctalia-shell`                                                                                       | `noctalia`                                                              | Launch commands and IPC calls must be updated.                 |
| Config format   | JSON-centered config: `settings.json`, `plugins.json`, plugin `settings.json`; TOML for user templates | TOML config: all `~/.config/noctalia/*.toml`, plus state overrides      | Existing JSON files are ignored by v5.                         |
| Config layering | Mostly config-dir files written by the app/module                                                      | Built-in defaults, then config-dir TOML, then state-dir `settings.toml` | GUI changes can override declarative config via state.         |
| IPC             | `noctalia-shell ipc call ...`                                                                          | `noctalia msg ...`                                                      | Existing scripts/keybinds need command-by-command replacement. |
| Plugins         | v4 QML plugin ecosystem                                                                                | Experimental Luau plugin system                                         | v4 plugins must be replaced/ported; many may not exist yet.    |
| Nix module      | `programs.noctalia-shell` / `services.noctalia-shell`                                                  | `programs.noctalia`; no NixOS module in the new source snapshot         | Home Manager wiring changes.                                   |

Upstream explicitly marks v5 alpha/work-in-progress in the docs and README.
Expect more breaking changes while v5 stabilizes.

### Config model in v5

The v5 config stack is:

1. Built-in defaults.
2. Every `*.toml` file in the resolved config directory, sorted alphabetically.
3. GUI/runtime overrides from the resolved state directory's `settings.toml`.

Resolved config dirs:

- `$NOCTALIA_CONFIG_HOME/noctalia/`
- `$XDG_CONFIG_HOME/noctalia/`
- `~/.config/noctalia/`

Resolved state dirs:

- `$NOCTALIA_STATE_HOME/noctalia/settings.toml`
- `$XDG_STATE_HOME/noctalia/settings.toml`
- `~/.local/state/noctalia/settings.toml`

Important consequence: if a hand-written config value appears ignored, inspect
or move `~/.local/state/noctalia/settings.toml`; it wins over declarative config.

### Useful v5 command surface

Known v5 IPC command names from the locked source include:

- Panels and settings: `panel-toggle`, `panel-open`, `panel-close`,
  `settings-open`, `settings-close`, `settings-toggle`.
- Session/lock: `session <lock|suspend|lock-and-suspend|logout|reboot|shutdown>`.
- Notifications/clipboard: `notification-clear-active`,
  `notification-clear-history`, `notification-dnd-*`, `clipboard-clear`.
- System controls: `volume-*`, `mic-*`, `brightness-*`, `wifi-*`,
  `bluetooth-*`, `power-*`, `caffeine-*`, `nightlight-*`, `dpms-*`.
- Shell surfaces: `bar-*`, `dock-*`, `desktop-widgets-*`,
  `lockscreen-widgets-*`, `wallpaper-*`, `window-switcher`.
- Theme/templates/plugins: `theme-mode-*`, `color-scheme-*`,
  `templates-apply`, `plugin`, `plugins`.

Examples relevant to the old local bindings:

```sh
noctalia msg panel-toggle launcher
noctalia msg session lock
noctalia msg notification-clear-history
```

### Migration strategy

There does not appear to be an official automatic v4 JSON to v5 TOML migration.
Treat migration as a manual rewrite using the v5 `example.toml` and docs.

The practical strategy is:

1. Start from v5 defaults or `example.toml`.
2. Port only the settings that matter.
3. Keep GUI-managed state separate from declarative config.
4. Replace v4 IPC calls with `noctalia msg ...`.
5. Re-evaluate plugins one by one.

## 2. Local `nixos-work` impact

### Current lock and package wiring

Current flake input:

- Previous Noctalia lock: `fe6fa125f5ee7881c4ee0cf9c0a4329a8238d3c2`
  from 2026-06-01, v4 Quickshell/QML source.
- Current Noctalia lock: `e3d292656c340e5d766e11c3e4be922a39f7ac51`
  from 2026-06-13, v5 C++ source.
- Current flake input still uses `github:noctalia-dev/noctalia-shell`; upstream
  docs now show `github:noctalia-dev/noctalia`.
- `flake.nix` installs `flake-inputs.noctalia.packages.${system}.default`
  directly in `environment.systemPackages`.
- `calendarSupport` was a v4 package override; v5 package options no longer
  include it.

The repo currently enables several services v5 wants:

- `networking.networkmanager.enable = true`
- `hardware.bluetooth.enable = true`
- `services.upower.enable = true`
- `services.tuned.enable = true`
- `services.gnome.evolution-data-server.enable = true`

### Current local config deployment

`hosts/nixos-work/home.nix` still symlinks v4 files into
`~/.config/noctalia/`:

| Local source                                           | Deployed path                      | v5 status                                                                                    |
| ------------------------------------------------------ | ---------------------------------- | -------------------------------------------------------------------------------------------- |
| `dotfiles/noctalia/nixos-work/settings.json`           | `noctalia/settings.json`           | Ignored by v5. Needs TOML rewrite.                                                           |
| `dotfiles/noctalia/nixos-work/plugins.json`            | `noctalia/plugins.json`            | Ignored by v5. Needs plugin-system rewrite.                                                  |
| `dotfiles/noctalia/nixos-work/notification-rules.json` | `noctalia/notification-rules.json` | Ignored by v5. No confirmed direct v5 equivalent.                                            |
| `dotfiles/noctalia/nixos-work/user-templates.toml`     | `noctalia/user-templates.toml`     | Old location/shape. User templates now live under `[theme.templates.user.*]` in config TOML. |

No v5 `noctalia/config.toml` is currently managed by Home Manager in this repo.

### Current Niri integration

`dotfiles/niri/config.kdl` already starts v5-style Noctalia:

```kdl
spawn-sh-at-startup "noctalia"
```

But several bindings still use v4 IPC:

| Current binding/use | v4 command                                           | Likely v5 equivalent                    |
| ------------------- | ---------------------------------------------------- | --------------------------------------- |
| Launcher            | `noctalia-shell ipc call launcher toggle`            | `noctalia msg panel-toggle launcher`    |
| Lock screen         | `noctalia-shell ipc call lockScreen lock`            | `noctalia msg session lock`             |
| Suspend comment     | `noctalia-shell ipc call sessionMenu lockAndSuspend` | `noctalia msg session lock-and-suspend` |

The Niri compositor settings still link to v4 docs and include v4-era comments,
but the `debug { honor-xdg-activation-with-invalid-serial }` and
Noctalia-related layer rules may still be relevant. Re-check against v5 Niri
docs before changing them.

### Local migration inventory by effort

#### Mostly direct JSON to TOML/value translation

These are present in v5 with similar concepts and straightforward value mapping.
They still need key renames and TOML formatting.

| v4 local area                                                   | v5 area                                                                    | Notes                                                                                    |
| --------------------------------------------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `audio.volumeOverdrive`                                         | `[audio].enable_overdrive`                                                 | Boolean.                                                                                 |
| `audio.mprisBlacklist`                                          | `[shell.mpris].blacklist`                                                  | List of player tokens.                                                                   |
| `brightness.enableDdcSupport`                                   | `[brightness].enable_ddcutil`                                              | Boolean.                                                                                 |
| `colorSchemes.darkMode`                                         | `[theme].mode = "dark"` or `"light"`                                       | v5 also supports `"auto"`.                                                               |
| `colorSchemes.predefinedScheme`                                 | `[theme].builtin`                                                          | Scheme names may differ; v5 examples include `Noctalia`, `Catppuccin`, `Rosé Pine`, etc. |
| `colorSchemes.useWallpaperColors` + `generationMethod`          | `[theme].source = "wallpaper"` + `wallpaper_scheme`                        | v5 names are different.                                                                  |
| `general.animationDisabled`, `general.animationSpeed`           | `[shell.animation].enabled`, `.speed`                                      | Invert disabled flag.                                                                    |
| `general.avatarImage`                                           | `[shell].avatar_path`                                                      | Path string.                                                                             |
| `general.language`                                              | `[shell].lang`                                                             | Optional in example config.                                                              |
| `general.radiusRatio`, `boxRadiusRatio`, `screenRadiusRatio`    | `[shell].corner_radius_scale`, bar/dock radius fields                      | Not one-to-one; pick important visual behavior.                                          |
| `general.shadowDirection`                                       | `[shell.shadow].direction`                                                 | Similar enum, verify names.                                                              |
| `nightLight.enabled`, `forced`, `dayTemp`, `nightTemp`          | `[nightlight].enabled`, `.force`, `.temperature_day`, `.temperature_night` | Direct concept mapping.                                                                  |
| `notifications.enabled`                                         | `[notification].enable_daemon`                                             | v5 daemon toggle.                                                                        |
| `notifications.backgroundOpacity`, `location`, `monitors`       | `[notification].background_opacity`, offsets/monitors                      | Position model changed; verify visual outcome.                                           |
| `osd.backgroundOpacity`, `location`, `enabledTypes`, `monitors` | `[osd]`, `[osd.kinds]`                                                     | Similar concepts, renamed values.                                                        |
| `systemMonitor.*Threshold`                                      | `[system.monitor]` plus widget/settings support                            | Polling exists; threshold options may not all exist.                                     |
| `wallpaper.directory`, `automationEnabled`                      | `[wallpaper].directory`, `[wallpaper.automation].enabled`                  | Direct concepts.                                                                         |

#### Exists in v5, but as different options/model

These should be redesigned using v5 docs instead of mechanically translated.

| v4 local area                                  | v5 area                                                                       | Reason                                                                 |
| ---------------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `appLauncher.*`                                | `panel-toggle launcher`, launcher config/search behavior                      | v5 launcher exists, but many old UX toggles may be renamed or removed. |
| `bar.*`, especially `widgets`                  | `[bar.<name>]` with `start`, `center`, `end` arrays and `[widget.*]` settings | v5 bar schema is different and simpler.                                |
| `controlCenter.cards`, `shortcuts`, `position` | `[[control_center.shortcuts]]`, panel placement under `[shell.panel]`         | Same concept, different schema.                                        |
| `desktopWidgets.*`                             | `[desktop_widgets]`, `[desktop_widgets.widget.<id>]`                          | Widget model exists but must be recreated.                             |
| `dock.*`                                       | `[dock]`                                                                      | Exists but schema and behavior differ.                                 |
| `general.keybinds`                             | `[keybinds]`                                                                  | v5 keybinds are internal shell navigation, not compositor bindings.    |
| `idle.*`                                       | `[idle.behavior.<name>]`                                                      | v5 uses named behaviors with commands like `noctalia:session lock`.    |
| `sessionMenu.*`                                | `[shell.panel].session_placement`, session IPC/actions                        | Session UI exists, but old layout/countdown options may not.           |
| `templates.activeTemplates`                    | `[theme.templates]`                                                           | Built-in/community/user template model changed.                        |
| `ui.*`                                         | `[shell]`, `[shell.panel]`, component-specific opacity/radius fields          | Split across multiple v5 sections.                                     |

#### Plugin-dependent or no confirmed v5 equivalent

| Local item                                                       | Current v4 config                                                     | v5 status                                                                                                                                  |
| ---------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Catwalk                                                          | `plugins.json` enables `catwalk` from `noctalia-dev/noctalia-plugins` | Old plugin will not work. Need a v5 Luau equivalent or replacement.                                                                        |
| Polkit agent plugin                                              | `plugins.json` enables `polkit-agent`                                 | v5 has `[shell].polkit_agent`; use built-in support if sufficient.                                                                         |
| Weekly calendar plugin                                           | `plugins.json` enables `weekly-calendar`                              | Old plugin will not work. Calendar core exists, but weekly plugin behavior needs replacement.                                              |
| Notification block rules                                         | `notification-rules.json` blocks two notification patterns            | No confirmed direct v5 rule-file equivalent found. May require built-in blacklist if enough, a plugin, or an external notification filter. |
| `noctaliaPerformance.disableDesktopWidgets` / `disableWallpaper` | v4 performance toggles                                                | v5 has direct `[desktop_widgets].enabled` and `[wallpaper].enabled`; old performance section is gone.                                      |
| `network.*` detailed panel settings                              | v4 Network/Bluetooth UI preferences                                   | v5 has network/bluetooth services and IPC, but not all old panel-display settings were found.                                              |

### Other local scripts affected

`bin/codex-clear-noctalia-for-pane` is tied to v4 notification IPC:

```sh
NOCTALIA_SHELL=${NOCTALIA_SHELL:-noctalia-shell}
noctalia-shell ipc call notifications getHistory
noctalia-shell ipc call notifications removeFromHistory <id>
```

v5 has `notification-clear-active` and `notification-clear-history`, but no
confirmed `getHistory`/`removeFromHistory` command was found in the v5 command
surface. This script likely needs a design change, not a simple command rename.

`home-modules/wezterm.nix`, `dotfiles/wezterm/codex-noctalia.lua`, and kitty
notification helpers reference the same notification-history workflow and should
be reviewed together.

### Suggested future migration order

1. Decide whether to pin/stay on v4 or continue with v5 alpha.
2. If staying on v5, create a new `dotfiles/noctalia/nixos-work/config.toml`
   from v5 defaults and manage it via Home Manager.
3. Port visual shell basics first: theme, bar, wallpaper, notification daemon,
   OSD, lockscreen.
4. Replace Niri IPC bindings with `noctalia msg ...`.
5. Rebuild template handling under `[theme.templates.user.*]`.
6. Revisit plugins and notification-history scripts separately.
7. Inspect/delete/migrate `~/.local/state/noctalia/settings.toml` as needed so
   GUI state does not mask declarative config.

## Sources

- Noctalia v5 announcement:
  <https://noctalia.dev/blog/announcing-noctalia-v5>
- v5 configuration docs:
  <https://docs.noctalia.dev/v5/configuration/>
- v5 NixOS docs:
  <https://docs.noctalia.dev/v5/getting-started/nixos/>
- v5 running docs:
  <https://docs.noctalia.dev/v5/getting-started/running-the-shell/>
- v5 plugins docs:
  <https://docs.noctalia.dev/v5/plugins/>
- Current locked v5 source during investigation:
  `github:noctalia-dev/noctalia-shell/e3d292656c340e5d766e11c3e4be922a39f7ac51`
- Previous locked v4 source during investigation:
  `github:noctalia-dev/noctalia-shell/fe6fa125f5ee7881c4ee0cf9c0a4329a8238d3c2`
- Local files inspected:
  `flake.nix`, `hosts/nixos-work/home.nix`,
  `dotfiles/niri/config.kdl`, `dotfiles/noctalia/nixos-work/*`,
  `bin/codex-clear-noctalia-for-pane`,
  `home-modules/wezterm.nix`.
