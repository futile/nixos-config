# Codex CLI, WezTerm, and Noctalia Notifications

## Summary

Codex CLI notifications currently work well at the terminal layer: when a Codex session is in an unfocused WezTerm tab, Codex emits a terminal notification and WezTerm turns it into a desktop notification. The remaining problem is Noctalia's notification history: those notifications stay "unread" even after returning to the relevant WezTerm tab.

The core finding is that Noctalia does not track read state per notification. Its bar notification widget computes unread count by comparing each history entry's timestamp with `NotificationService.lastSeenTs`. That timestamp is updated when the Noctalia notification-history panel opens, not when the source application or source terminal tab regains focus.

For multiple Codex agent tabs, exact per-tab cleanup requires a per-tab identifier in the Noctalia history entry. Built-in Codex TUI notifications emitted through WezTerm currently do not appear to carry such an identifier into Noctalia. A robust implementation therefore needs either a tagged notification path or a change to the notification content/metadata.

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

Use the tagged `notify` hook for `agent-turn-complete` notifications and disable duplicate built-in TUI notifications for that event if necessary. Keep built-in TUI notifications for prompt/approval events until Codex exposes them through `notify` or another hook path.

For exact per-tab clearing:

1. Ensure each notification saved by Noctalia contains a pane-specific marker, ideally derived from `WEZTERM_PANE`.
2. On WezTerm focus, call a cleanup script with `pane:pane_id()`.
3. The cleanup script removes only Noctalia history entries with the matching marker.

Do not rely on generic `appName == "Wezterm"` cleanup when multiple Codex tabs are open, because Noctalia's current history entries do not include enough metadata to distinguish tabs.

## Validation Plan

1. Configure a test `notify` hook that sends a notification with `--app-name="Codex pane $WEZTERM_PANE"`.
2. Start two Codex sessions in separate WezTerm tabs.
3. Trigger a completed-turn notification from each tab while it is unfocused.
4. Confirm `noctalia-shell ipc call notifications getHistory` contains separate `appName` values per pane.
5. Focus one tab and run the cleanup script with that pane id.
6. Confirm only that pane's notification was removed from Noctalia history.
7. Confirm the other Codex tab's notification remains unread.
8. Confirm unrelated WezTerm notifications are not removed.

## Sources

- Codex advanced notifications config: <https://developers.openai.com/codex/config-advanced>
- Codex config reference for TUI notification keys: <https://developers.openai.com/codex/config-reference>
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
