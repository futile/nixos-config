# Codex CLI, WezTerm, and Noctalia Notifications

## Summary

Codex CLI notifications currently work well at the terminal layer: when a Codex session is in an unfocused WezTerm tab, Codex emits a terminal notification and WezTerm turns it into a desktop notification. The remaining problem is Noctalia's notification history: those notifications stay "unread" even after returning to the relevant WezTerm tab.

The core finding is that Noctalia does not track read state per notification. Its bar notification widget computes unread count by comparing each history entry's timestamp with `NotificationService.lastSeenTs`. That timestamp is updated when the Noctalia notification-history panel opens, not when the source application or source terminal tab regains focus.

For multiple Codex agent tabs, exact per-tab cleanup requires a per-tab identifier in the Noctalia history entry. Built-in Codex TUI notifications emitted through WezTerm currently do not appear to carry such an identifier into Noctalia. A robust implementation therefore needs either a tagged notification path or a change to the notification content/metadata.

The implemented hybrid setup uses the tagged notification path for Codex `agent-turn-complete` events and leaves Codex TUI notifications for other events on the existing WezTerm/OSC path. Tagged notifications can be clicked to activate the correct WezTerm pane, and they are removed from Noctalia history when their pane becomes focused.

## Implemented Flow

The implemented files are:

- `bin/codex-notify-noctalia`
- `bin/codex-clear-noctalia-for-pane`
- `bin/codex-noctalia-action-watch`
- `dotfiles/codex/icons/codex-light.svg`
- `dotfiles/codex/icons/codex-dark.svg`
- `dotfiles/codex/config.toml`
- `dotfiles/wezterm/codex-noctalia.lua`
- `home-modules/wezterm.nix`

Codex is configured with:

```toml
notify = ["/home/felix/nixos/bin/codex-notify-noctalia"]

[tui]
notifications = ["approval-requested"]
notification_method = "osc9"
notification_condition = "unfocused"
```

That split is intentional:

- `agent-turn-complete` goes through the top-level `notify` hook and gets exact pane identity.
- `approval-requested` remains a TUI notification through WezTerm/OSC because that path still covers events not exposed through Codex's top-level `notify` hook.

### Completed-Turn Notification Path

For `agent-turn-complete`, Codex invokes:

```text
/home/felix/nixos/bin/codex-notify-noctalia <json-payload>
```

The hook:

1. Reads the Codex JSON payload.
2. Ignores events whose `.type` is not `agent-turn-complete`.
3. Reads the originating WezTerm pane id from `WEZTERM_PANE`.
4. Skips notification creation if that pane is already focused according to `wezterm cli list-clients --format json`.
5. Sends a freedesktop notification through `org.freedesktop.Notifications.Notify`.
6. Sets the notification app name to `Codex pane <pane-id>`.
7. Adds a default action, `['default', 'Open pane']`, so Noctalia left-clicks invoke an action instead of only focusing by app name.
8. Chooses a local Codex SVG icon based on the current light/dark preference.
9. Stores a local mapping from freedesktop notification id to pane id in:

```text
/tmp/codex-noctalia-$UID/notifications.tsv
```

The mapping file has three tab-separated columns:

```text
notification_id  pane_id  unix_timestamp
```

This file is runtime state only. It is used to translate a clicked notification back into the WezTerm pane that produced it. Mappings are removed when a pane's tagged notifications are cleared and after a click action is handled, so stale notification ids do not keep pointing at panes indefinitely.

The pane id is WezTerm's internal `pane_id`, not the visible tab index. A notification labelled `Codex pane 3` can therefore correspond to a tab that appears in position 1 or 2 in the tab bar.

### Notification Icon

The notification hook passes an absolute SVG path as the freedesktop notification `appIcon` argument. Noctalia accepts absolute paths in `NotificationService.getIcon()`, so this avoids relying on icon theme lookup or desktop entry metadata.

The local icon files are:

```text
dotfiles/codex/icons/codex-light.svg
dotfiles/codex/icons/codex-dark.svg
```

Both are circle/avatar-style SVGs derived from Lobe Icons' static color SVG asset:

```text
https://lobehub.com/icons/codex
https://github.com/lobehub/lobe-icons
https://unpkg.com/@lobehub/icons-static-svg@latest/icons/codex-color.svg
```

Lobe Icons documents the package as MIT licensed. The SVG package exposes variant types such as `codex.svg`, `codex-color.svg`, and `codex-text.svg`, but does not expose light/dark directories. Lobe's light/dark variants are available for PNG/WebP.

Noctalia displays notification images in a rounded/circular slot. The LobeHub preview's rectangular app-tile variants are therefore a poor fit because their corners or edges may be clipped, similar to how rectangular app icons can be clipped in Noctalia. The local SVGs use a white circular background plus the Codex gradient glyph, matching the preview's avatar/circle shape more closely.

The current light and dark SVG files intentionally have the same visible artwork. Keeping both filenames preserves the theme-selection structure if we later want subtly different light/dark artwork.

The hook picks the icon variant like this:

1. If `gsettings org.gnome.desktop.interface color-scheme` contains `dark`, use `codex-dark.svg`.
2. Otherwise, if Noctalia's repo settings file has `.colorSchemes.darkMode == true`, use `codex-dark.svg`.
3. Otherwise use `codex-light.svg`.

The `gsettings` path is checked first because it reflects the active desktop color-scheme preference. The Noctalia settings file is only a fallback for environments where `gsettings` is unavailable.

### Focus Cleanup

Focused-pane cleanup is handled inside WezTerm, not by a polling service. The top-level `dotfiles/wezterm/wezterm.lua` loads:

```lua
local codex_noctalia_ok, codex_noctalia = pcall(dofile, "/home/felix/nixos/dotfiles/wezterm/codex-noctalia.lua")
if codex_noctalia_ok and codex_noctalia and codex_noctalia.setup then
  codex_noctalia.setup(wezterm)
else
  wezterm.log_error("failed to load codex-noctalia.lua: " .. tostring(codex_noctalia))
end
```

`dotfiles/wezterm/codex-noctalia.lua` registers two WezTerm events:

- `window-focus-changed`: clears notifications for the active pane when the WezTerm window regains focus.
- `update-status`: tracks the active pane while the window is focused and clears notifications when the active pane id changes.

Both paths call:

```sh
/home/felix/nixos/bin/codex-clear-noctalia-for-pane <pane-id>
```

This avoids the previous external polling loop. WezTerm owns pane focus, so it is the better place to notice pane focus changes.

### Action Watcher Service

Click-to-pane activation is still handled by a user service because WezTerm Lua does not provide a native D-Bus signal listener for notification action events.

`bin/codex-noctalia-action-watch` runs `gdbus monitor` for `org.freedesktop.Notifications.ActionInvoked` signals and activates the mapped WezTerm pane when a tagged notification's `default` action is clicked.

The click path is:

1. Noctalia receives a tagged notification such as `appName = "Codex pane 1"`.
2. The user clicks the notification.
3. Noctalia sees the `default` action and emits:

```text
org.freedesktop.Notifications.ActionInvoked (uint32 <notification-id>, 'default')
```

4. The watcher sees the signal.
5. The watcher looks up `<notification-id>` in `/tmp/codex-noctalia-$UID/notifications.tsv`.
6. The watcher runs:

```sh
wezterm cli activate-pane --pane-id <pane-id>
```

7. The watcher clears matching Noctalia history entries for that pane.

The watcher logs each pane activation to its systemd journal:

```text
codex-noctalia-action-watch: notification <notification-id> activates pane <pane-id>
```

If a pane changes unexpectedly, check this log first. If there is no matching line, the pane change came from something other than the custom notification click watcher.

### Cleanup Path

`bin/codex-clear-noctalia-for-pane` removes Noctalia history entries for one pane:

```sh
bin/codex-clear-noctalia-for-pane 1
```

It calls:

```sh
noctalia-shell ipc call notifications getHistory
```

and removes entries where:

```text
appName == "Codex pane <pane-id>"
```

This avoids touching unrelated WezTerm notifications and avoids clearing notifications from other Codex tabs.

The cleanup script also removes local notification-id mappings for that pane from `/tmp/codex-noctalia-$UID/notifications.tsv`.

## Local Findings

### Noctalia

`noctalia-shell` is a Quickshell wrapper. The running IPC surface can be inspected with:

```sh
noctalia-shell ipc show
```

The relevant notification IPC target exposes:

```text
target notifications
  function removeFromHistory(id: string): bool
  function toggleHistory(): void
  function removeOldestHistory(): void
  function getHistory(): string
  function getActions(index: string): string
  function enableDND(): void
  function invokeDefault(index: string): bool
  function clear(): void
  function invokeDefaultAndDismiss(index: string): bool
  function dismissOldest(): void
  function dismissAll(): void
  function toggleDND(): void
  function disableDND(): void
  function invokeAction(id: string, actionId: string): bool
```

`getHistory` returns JSON entries with fields such as `id`, `summary`, `body`, `appName`, `urgency`, `timestamp`, `originalImage`, and `cachedImage`. Example entries observed during the investigation:

```json
[
  {
    "id": "40e759046607b4d22540cee89075954389d247f4b6b58a774fc5207fa7edbd2c",
    "summary": "Plan mode prompt: Implement this plan?",
    "body": "",
    "appName": "Wezterm",
    "urgency": 2,
    "timestamp": 1779032012324
  },
  {
    "id": "4a4c533b1fc1cb47141423686ef20350d1db0dbc8cafda0732c039a4a87ff158",
    "summary": "Plan mode prompt: Preferred",
    "body": "",
    "appName": "Wezterm",
    "urgency": 2,
    "timestamp": 1779031944281
  }
]
```

The persisted history file is:

```text
/home/felix/.cache/noctalia/notifications.json
```

The persisted notification state is in:

```text
/home/felix/.cache/noctalia/shell-state.json
```

It contains:

```json
{
  "notificationsState": {
    "lastSeenTs": 1779031788000
  }
}
```

The unread badge behavior comes from Noctalia's bar widget. In the inspected local Noctalia source, `Modules/Bar/Widgets/NotificationHistory.qml` computes unread count by counting history items where `timestamp > NotificationService.lastSeenTs`.

The notification history panel updates `lastSeenTs` on open. In `Modules/Panels/NotificationHistory/NotificationHistoryPanel.qml`:

```qml
onOpened: {
  NotificationService.updateLastSeenTs();
}
```

Notification history removal is supported. In `Services/System/NotificationService.qml`, `removeFromHistory(notificationId)` removes the matching entry from `historyModel` and saves history.

Noctalia notification rules support `block`, `mute`, and `hide`. The rule evaluator joins `appName`, `summary`, and `body` into one haystack and matches literal strings, glob-like patterns, or slash-delimited regexes. The actions mean:

- `block`: drop the notification entirely; no popup and no history.
- `hide`: save to history, but do not show an active popup.
- `mute`: show and save the notification, but skip sound.

There is no stock rule action meaning "show popup but do not save to history".

Current local rule file:

```text
dotfiles/noctalia/nixos-work/notification-rules.json
```

Example rule shape:

```json
{
  "rules": [
    {
      "action": "block",
      "pattern": "/Wezterm Plan mode prompt:.*/"
    }
  ]
}
```

That rule would remove the notification from history, but it would also prevent the popup, which is not the desired flow.

### WezTerm

WezTerm supports terminal notification handling through `notification_handling`. The documented values include:

- `AlwaysShow`
- `NeverShow`
- `SuppressFromFocusedPane`
- `SuppressFromFocusedTab`
- `SuppressFromFocusedWindow`

That explains the already-working part of the flow: desktop notifications can be limited to unfocused panes, tabs, or windows.

WezTerm also has focus events. `window-focus-changed` fires when the GUI window focus state changes and passes the `window` and active `pane`.

WezTerm panes have stable pane ids:

```lua
pane:pane_id()
```

The WezTerm CLI also uses `WEZTERM_PANE` as the default pane target for commands that accept `--pane-id`. This makes pane id a plausible correlation key.

However, no documented WezTerm hook was found for "OSC notification generated" that exposes the desktop notification id, original OSC notification content, or generated notification metadata to Lua. Once WezTerm turns the OSC sequence into a desktop notification, that notification is opaque from WezTerm Lua.

### Codex CLI

The local Codex config is:

```text
dotfiles/codex/config.toml
```

It currently sets terminal title information under `[tui]`, but does not explicitly configure TUI notifications.

Codex has two notification paths:

- `tui.notifications`: built-in TUI notifications, optionally filtered by event type.
- `notify`: an external program hook for supported events.

Relevant documented TUI keys:

```toml
[tui]
notifications = ["agent-turn-complete", "approval-requested"]
notification_method = "osc9" # or auto, bel
notification_condition = "unfocused" # or always
```

The top-level `notify` hook is documented as:

```toml
notify = ["python3", "/path/to/notify.py"]
```

The hook receives one JSON argument. Documented common fields include:

- `type`
- `thread-id`
- `turn-id`
- `cwd`
- `input-messages`
- `last-assistant-message`

As of the checked docs, `notify` is documented as supporting `agent-turn-complete`. Built-in TUI notifications support more TUI events, including `approval-requested`; observed Noctalia entries also included `Plan mode prompt: ...` summaries from Codex.

## Options

### Option 1: Tagged Codex Notify Hook

This is the most robust design for completed-turn notifications.

Use Codex's top-level `notify` hook for `agent-turn-complete`. Because it runs from the Codex process inside the WezTerm pane, the hook should be able to inherit `WEZTERM_PANE`. The hook sends the desktop notification itself with the pane id included in Noctalia-visible metadata, such as `appName` or `summary`.

Sender sketch:

```bash
#!/usr/bin/env bash
set -euo pipefail

payload="$1"
pane="${WEZTERM_PANE:-unknown}"

summary="$(jq -r '."last-assistant-message" // "Codex turn complete"' <<<"$payload")"

notify-send \
  --app-name="Codex pane ${pane}" \
  "Codex" \
  "${summary}"
```

Then a WezTerm focus hook can remove only entries tagged for the focused pane.

WezTerm hook sketch:

```lua
wezterm.on("window-focus-changed", function(window, pane)
  if not window:is_focused() then
    return
  end

  wezterm.background_child_process({
    "codex-clear-noctalia-for-pane",
    tostring(pane:pane_id()),
  })
end)
```

Cleanup script sketch:

```bash
#!/usr/bin/env bash
set -euo pipefail

pane="${1:?pane id required}"

noctalia-shell ipc call notifications getHistory |
  jq -r --arg app "Codex pane ${pane}" '
    .[]
    | select(.appName == $app)
    | .id
  ' |
  while read -r id; do
    [ -n "$id" ] && noctalia-shell ipc call notifications removeFromHistory "$id" >/dev/null
  done
```

Advantages:

- Exact per-pane clearing for tagged notifications.
- Does not remove unrelated WezTerm notifications.
- Does not clear notifications from other Codex tabs.
- Does not require patching Noctalia.

Limitations:

- Covers only events exposed through top-level `notify`; currently documented as `agent-turn-complete`.
- Does not automatically cover TUI-only prompt notifications such as plan-mode prompts unless Codex exposes those through `notify` or another hook path.
- The hook must avoid duplicate notifications if built-in TUI notifications remain enabled for the same event.

### Option 2: Keep TUI Notifications And Use Heuristics

Keep Codex's built-in TUI notifications and clear Noctalia history entries on WezTerm focus by matching:

- `appName == "Wezterm"`
- summary/body patterns such as `Plan mode prompt:`, `Approval`, `Codex`, or `Agent`
- optionally active pane title, cwd, or project name from `wezterm cli list --format json`

Sketch:

```bash
#!/usr/bin/env bash
set -euo pipefail

project="${1:?project marker required}"

noctalia-shell ipc call notifications getHistory |
  jq -r --arg project "$project" '
    .[]
    | select(.appName == "Wezterm")
    | select((.summary + " " + .body) | test($project; "i"))
    | .id
  ' |
  while read -r id; do
    [ -n "$id" ] && noctalia-shell ipc call notifications removeFromHistory "$id" >/dev/null
  done
```

Advantages:

- Keeps existing TUI notification behavior.
- Can cover TUI-only events if their text is unique enough.

Limitations:

- Not exact for multiple Codex tabs when notification text is generic.
- Observed summaries like `Plan mode prompt: Preferred` do not include a unique pane, tab, thread, or cwd marker.
- Risk of clearing the wrong Codex tab's unread notification.

### Option 3: Patch Codex Or Noctalia

For exact per-tab handling of all Codex TUI notifications, the Noctalia history entry needs a stable per-session or per-pane marker.

Possible changes:

- Patch Codex TUI notification text to include a stable marker such as thread id, cwd/project, or pane id.
- Extend Codex top-level `notify` support to cover prompt/approval events such as plan-mode prompts.
- Patch Noctalia or Quickshell handling if richer source metadata is available from the notification server, though WezTerm would still need to provide pane/session identity in the notification.
- Add a new Noctalia rule action such as `transient` or `popupOnly` if the desired behavior becomes "show popup but do not save to history".

This is cleanest conceptually, but more invasive than a local notify-hook solution.

## Recommendation

Use the tagged `notify` hook for `agent-turn-complete` notifications and keep built-in TUI notifications for prompt/approval events until Codex exposes them through `notify` or another hook path.

For exact per-tab clearing:

1. Ensure each notification saved by Noctalia contains a pane-specific marker, ideally derived from `WEZTERM_PANE`.
2. Watch the focused WezTerm pane with `wezterm cli list-clients --format json`.
3. The cleanup script removes only Noctalia history entries with the matching marker.
4. Add a notification default action and a watcher for `ActionInvoked` so clicking the notification activates the right pane.

Do not rely on generic `appName == "Wezterm"` cleanup when multiple Codex tabs are open, because Noctalia's current history entries do not include enough metadata to distinguish tabs.

## Testing

### Send A Test Notification For A Pane

To send a tagged notification for pane `1`:

```sh
WEZTERM_PANE=1 bin/codex-notify-noctalia \
  '{"type":"agent-turn-complete","last-assistant-message":"Click should activate WezTerm pane 1"}'
```

Expected behavior:

- If pane `1` is focused, no notification is sent.
- If pane `1` is not focused, Noctalia shows a notification whose app name is `Codex pane 1`.
- Clicking the notification activates pane `1`.
- Focusing pane `1` clears that pane's tagged notification from Noctalia history.

To choose the first pane that is not currently focused:

```sh
focused_pane="$(wezterm cli list-clients --format json | jq -r '.[0].focused_pane_id')"
target_pane="$(
  wezterm cli list --format json |
    jq -r --arg focused "$focused_pane" '[.[] | select((.pane_id|tostring) != $focused)][0].pane_id'
)"

WEZTERM_PANE="$target_pane" bin/codex-notify-noctalia \
  "{\"type\":\"agent-turn-complete\",\"last-assistant-message\":\"Click should activate WezTerm pane ${target_pane}\"}"
```

### Inspect Tagged Notifications In Noctalia

List tagged Codex notifications currently in Noctalia history:

```sh
noctalia-shell ipc call notifications getHistory |
  jq -r '.[] | select(.appName | startswith("Codex pane ")) | [.id, .appName, .summary, .body] | @tsv'
```

Check the notification-id to pane-id map:

```sh
cat "/tmp/codex-noctalia-$UID/notifications.tsv"
```

The map is only needed for click activation. Noctalia history cleanup uses `appName = "Codex pane <pane-id>"`.

Inspect the stored image path for tagged notifications:

```sh
noctalia-shell ipc call notifications getHistory |
  jq -r '.[] | select(.appName | startswith("Codex pane ")) | [.appName, .originalImage, .cachedImage] | @tsv'
```

Expected `originalImage` is one of:

```text
/home/felix/nixos/dotfiles/codex/icons/codex-light.svg
/home/felix/nixos/dotfiles/codex/icons/codex-dark.svg
```

### Clear One Pane Manually

Clear tagged history entries for pane `1`:

```sh
bin/codex-clear-noctalia-for-pane 1
```

Confirm they are gone:

```sh
noctalia-shell ipc call notifications getHistory |
  jq -r '[.[] | select(.appName == "Codex pane 1")] | length'
```

### Verify Click Activation Manually

Send a notification for an unfocused pane, click it, then check the focused pane:

```sh
wezterm cli list-clients --format json | jq -r '.[0].focused_pane_id'
```

The focused pane should match the pane id in the notification app name.

For lower-level debugging, watch notification action signals:

```sh
gdbus monitor \
  --session \
  --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications
```

Clicking one of the tagged notifications should produce a line like:

```text
/org/freedesktop/Notifications: org.freedesktop.Notifications.ActionInvoked (uint32 76, 'default')
```

### Development Checks

Check shell syntax:

```sh
bash -n bin/codex-clear-noctalia-for-pane
bash -n bin/codex-noctalia-action-watch
bash -n bin/codex-notify-noctalia
```

Check the repo Codex TOML:

```sh
python3 -c 'import pathlib,tomllib; tomllib.loads(pathlib.Path("dotfiles/codex/config.toml").read_text())'
```

Check the live Codex TOML:

```sh
python3 -c 'import pathlib,tomllib; tomllib.loads(pathlib.Path("/home/felix/.codex/config.toml").read_text())'
```

Run normal repository validation:

```sh
just format-check
just check
```

## Service Operations

The persistent action watcher service is declared in `home-modules/wezterm.nix`:

```text
systemd.user.services.codex-noctalia-action-watch
```

It becomes persistent after a Home Manager switch. During development, it can also be started as a transient user service:

```sh
systemd-run \
  --user \
  --unit=codex-noctalia-action-watch \
  --collect \
  --same-dir \
  --setenv=PATH=/etc/profiles/per-user/felix/bin:/run/current-system/sw/bin:/home/felix/.nix-profile/bin \
  /etc/profiles/per-user/felix/bin/bash \
  /home/felix/nixos/bin/codex-noctalia-action-watch
```

Check whether it is active:

```sh
systemctl --user is-active codex-noctalia-action-watch.service
```

Inspect its process tree:

```sh
systemctl --user status codex-noctalia-action-watch.service --no-pager
```

Expected child processes include the main Bash script and a `gdbus monitor` process.

Restart after editing scripts:

```sh
systemctl --user restart codex-noctalia-action-watch.service
```

Stop the transient or persistent service:

```sh
systemctl --user stop codex-noctalia-action-watch.service
```

Read recent logs:

```sh
journalctl --user -u codex-noctalia-action-watch.service --since '10 minutes ago' --no-pager
```

Look for lines like:

```text
codex-noctalia-action-watch: notification 42 activates pane 3
```

The old development service name was `codex-noctalia-focus-watch.service`. If it exists as a stale transient unit, stop it:

```sh
systemctl --user stop codex-noctalia-focus-watch.service
```

After editing `/home/felix/.codex/config.toml`, restart Codex before relying on the new configuration. Existing Codex sessions and subagents may keep the startup config they already loaded.

## Common Development Flows

### Change The Notification Text

Edit `bin/codex-notify-noctalia`, then run:

```sh
bash -n bin/codex-notify-noctalia
systemctl --user restart codex-noctalia-action-watch.service
WEZTERM_PANE=1 bin/codex-notify-noctalia \
  '{"type":"agent-turn-complete","last-assistant-message":"Notification text test"}'
```

Click the test notification and confirm it activates pane `1`.

### Change The Notification Icon

Edit the local SVGs under:

```text
dotfiles/codex/icons/
```

Then run:

```sh
bash -n bin/codex-notify-noctalia
WEZTERM_PANE=1 bin/codex-notify-noctalia \
  '{"type":"agent-turn-complete","last-assistant-message":"Icon test"}'
```

Inspect the saved image path:

```sh
noctalia-shell ipc call notifications getHistory |
  jq -r '.[] | select(.appName == "Codex pane 1") | [.originalImage, .cachedImage] | @tsv'
```

If Noctalia shows its fallback bell icon, check:

- the `originalImage` path exists and is readable;
- the SVG renders in the current image stack;
- `gsettings get org.gnome.desktop.interface color-scheme` returns the expected light/dark preference;
- `dotfiles/noctalia/nixos-work/settings.json` has the expected fallback `.colorSchemes.darkMode` value.

To use upstream light/dark assets without local SVG derivation, switch to PNG or WebP and use Lobe Icons' static light/dark package paths:

```text
https://unpkg.com/@lobehub/icons-static-png@latest/light/codex.png
https://unpkg.com/@lobehub/icons-static-png@latest/dark/codex.png
https://unpkg.com/@lobehub/icons-static-webp@latest/light/codex.webp
https://unpkg.com/@lobehub/icons-static-webp@latest/dark/codex.webp
```

For this setup, SVG is preferred because it is local, small, and scales cleanly in Noctalia's notification UI.

### Change Click Behavior

Edit `bin/codex-noctalia-action-watch`, then run:

```sh
bash -n bin/codex-noctalia-action-watch
systemctl --user restart codex-noctalia-action-watch.service
```

Then send a test notification and click it.

### Change Focus Cleanup Behavior

Edit `dotfiles/wezterm/codex-noctalia.lua` or `bin/codex-clear-noctalia-for-pane`, then run:

```sh
wezterm --config-file dotfiles/wezterm/wezterm.lua show-keys >/tmp/wezterm-config-check.txt
bash -n bin/codex-clear-noctalia-for-pane
```

The WezTerm config is live-linked and auto-reloads, so keep edits small and validate immediately.

### Update The Home Manager Service

Edit `home-modules/wezterm.nix`, then run:

```sh
just format-check
nix eval .#nixosConfigurations.nixos-work.config.home-manager.users.felix.systemd.user.services.codex-noctalia-action-watch.Service.Environment --json
```

Use `just hm-switch` or `just switch` only when you are ready to apply the Home Manager/system changes in the working tree.

### Keep Live Codex Config In Sync

The repository copy is:

```text
dotfiles/codex/config.toml
```

The live file is:

```text
/home/felix/.codex/config.toml
```

The Home Manager module intentionally does not symlink the live file because Codex writes machine-specific trusted project entries there. When changing notification config, update both files or manually merge the relevant lines into the live file.

## Sources

- Codex advanced notifications config: <https://developers.openai.com/codex/config-advanced>
- Codex config reference for TUI notification keys: <https://developers.openai.com/codex/config-reference>
- LobeHub Codex icon page: <https://lobehub.com/icons/codex>
- Lobe Icons repository and license: <https://github.com/lobehub/lobe-icons>
- Lobe Icons agent instructions: <https://lobehub.com/icons/skill.md>
- WezTerm `notification_handling`: <https://wezterm.org/config/lua/config/notification_handling.html>
- WezTerm `window-focus-changed`: <https://wezterm.org/config/lua/window-events/window-focus-changed.html>
- WezTerm `pane:pane_id()`: <https://wezterm.org/config/lua/pane/pane_id.html>
- WezTerm CLI pane targeting through `WEZTERM_PANE`: <https://wezterm.org/cli/cli/activate-pane.html>
- Noctalia notification IPC docs: <https://docs.noctalia.dev/v4/getting-started/keybinds/interface-and-plugins/>

Local source paths inspected:

- `/nix/store/zs85rbhi9xbz14imgqjh51mmq3jv3v1a-noctalia-shell-2026-05-06_eb2b53d/share/noctalia-shell/Services/System/NotificationService.qml`
- `/nix/store/zs85rbhi9xbz14imgqjh51mmq3jv3v1a-noctalia-shell-2026-05-06_eb2b53d/share/noctalia-shell/Services/Control/IPCService.qml`
- `/nix/store/zs85rbhi9xbz14imgqjh51mmq3jv3v1a-noctalia-shell-2026-05-06_eb2b53d/share/noctalia-shell/Modules/Bar/Widgets/NotificationHistory.qml`
- `/nix/store/zs85rbhi9xbz14imgqjh51mmq3jv3v1a-noctalia-shell-2026-05-06_eb2b53d/share/noctalia-shell/Modules/Panels/NotificationHistory/NotificationHistoryPanel.qml`
