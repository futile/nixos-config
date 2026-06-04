# Kitty Noctalia Notification Footers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clear live popups and Noctalia history entries for kitty notifications when the originating kitty tab/window is focused.

**Architecture:** Keep kitty's native notification sending and click-to-focus behavior. Add a kitty `notifications.py` filter script that appends a small source footer to notification bodies before Noctalia stores them, then add a global kitty watcher that closes matching live kitty notifications and clears Noctalia history entries with the same footer when the source kitty window gains focus.

**Tech Stack:** kitty Python config hooks (`notifications.py`, watcher callbacks), shell scripts, freedesktop notification DBus, Noctalia IPC, Home Manager Nix wiring.

---

## Context

Kitty already tracks live notifications by `desktop_notification_id -> NotificationCommand -> channel_id`, and its `notify_on_cmd_finish ... notify focus next` behavior correctly closes live popups when the originating kitty window regains focus. Noctalia history is separate: `getHistory()` exposes only the generated history id, summary, body, appName, urgency, timestamp, and image paths. It does not expose the freedesktop numeric id or kitty's source `channel_id`.

The durable correlation key therefore needs to be stored in a field Noctalia does expose. Use a footer appended to the notification body, similar in spirit to commit-message footers:

```text
Kitty-Source: <instance-key>:<channel-id>
```

The footer should be appended only for notifications that originate inside kitty and should be visually unobtrusive. The watcher closes live kitty notifications by matching kitty's in-process `NotificationCommand.channel_id`; the cleanup script then matches this footer exactly in Noctalia history and removes the matching history entries.

## Files

- Create: `dotfiles/kitty/notifications.py`
  - Mutates outgoing kitty notifications before native delivery.
  - Appends `Kitty-Source: <source-key>` to `cmd.body`.
  - Does not filter notifications out.
- Create: `dotfiles/kitty/codex-noctalia-watcher.py`
  - Global kitty watcher.
  - Closes live kitty notifications for the focused kitty window.
  - Calls the Noctalia history cleanup script when a kitty window gains focus.
  - Also checks active-window changes on tab-bar dirtiness.
- Create: `bin/kitty-clear-noctalia-for-source`
  - Removes Noctalia history entries whose body contains the source footer.
- Modify: `home-modules/kitty.nix`
  - Symlink both kitty Python files into `~/.config/kitty`.
  - Ensure helper runtime dependencies are available where needed.
- Modify: `dotfiles/kitty/kitty.conf`
  - Register the watcher.
  - Keep `notify_on_cmd_finish unfocused 10.0 notify focus next`.
- Optionally modify: `bin/codex-notify-noctalia`
  - Do not change Codex notifications that already pass through kitty; `notifications.py` tags those.
  - If a Codex top-level notify hook should produce kitty notifications, add a kitty-specific branch that emits the same footer instead of exiting when `WEZTERM_PANE` is absent.

## Source Key

Use:

```text
<instance-key>:<channel-id>
```

Where:

- `channel-id` is `cmd.channel_id` in `notifications.py` and `window.id` in watcher callbacks.
- `instance-key` should be stable for one kitty process and short enough for a footer.
- Recommended first implementation:
  - If `KITTY_LISTEN_ON` is available in kitty's process environment, hash it to 12 hex characters.
  - Otherwise use the current kitty process id, hashed or literal.

Footer format:

```text

Kitty-Source: kitty:<instance-short>:<channel-id>
```

The leading blank line keeps the footer visually separated from the real notification body. The cleanup script should match the exact line with a regex like:

```text
(^|\n)Kitty-Source: kitty:<instance-short>:<channel-id>($|\n)
```

## Task 1: Add Kitty Notification Tagging

**Files:**
- Create: `dotfiles/kitty/notifications.py`

- [ ] **Step 1: Create the notification filter script**

Create `dotfiles/kitty/notifications.py` with this behavior:

```python
#!/usr/bin/env python3
import hashlib
import os


def _instance_key() -> str:
    listen_on = os.environ.get("KITTY_LISTEN_ON", "")
    if listen_on:
        return hashlib.sha256(listen_on.encode("utf-8")).hexdigest()[:12]
    return hashlib.sha256(str(os.getpid()).encode("ascii")).hexdigest()[:12]


def _source_footer(channel_id: int) -> str:
    return f"Kitty-Source: kitty:{_instance_key()}:{channel_id}"


def main(cmd) -> bool:
    channel_id = getattr(cmd, "channel_id", 0)
    if not channel_id:
        return False

    footer = _source_footer(channel_id)
    body = getattr(cmd, "body", "") or ""
    if footer not in body:
        cmd.body = body.rstrip() + "\n\n" + footer if body else footer

    return False
```

- [ ] **Step 2: Verify syntax**

Run:

```bash
python3 -m py_compile dotfiles/kitty/notifications.py
```

Expected: command exits 0.

- [ ] **Step 3: Commit**

```bash
git add dotfiles/kitty/notifications.py
git commit -m "kitty: tag notifications with source footers"
```

## Task 2: Add Noctalia History Cleanup Script

**Files:**
- Create: `bin/kitty-clear-noctalia-for-source`

- [ ] **Step 1: Create the cleanup script**

Create `bin/kitty-clear-noctalia-for-source`:

```bash
#!/usr/bin/env bash
set -euo pipefail

source_key="${1:?source key required}"
footer="Kitty-Source: ${source_key}"
noctalia_shell="${NOCTALIA_SHELL:-noctalia-shell}"

"${noctalia_shell}" ipc call notifications getHistory |
	jq -r --arg footer "${footer}" '
		.[]?
		| select((.body // "") | contains($footer))
		| .id
	' |
	while IFS= read -r notification_id; do
		if [[ -n "${notification_id}" ]]; then
			"${noctalia_shell}" ipc call notifications removeFromHistory "${notification_id}" >/dev/null
		fi
	done
```

- [ ] **Step 2: Make it executable**

Run:

```bash
chmod +x bin/kitty-clear-noctalia-for-source
```

- [ ] **Step 3: Verify syntax**

Run:

```bash
bash -n bin/kitty-clear-noctalia-for-source
```

Expected: command exits 0.

- [ ] **Step 4: Verify against current history without deleting**

Run:

```bash
noctalia-shell ipc call notifications getHistory |
  jq -r '.[]? | select((.body // "") | contains("Kitty-Source:")) | [.id, .body] | @tsv'
```

Expected before implementation testing: no output unless tagged test notifications already exist.

- [ ] **Step 5: Commit**

```bash
git add bin/kitty-clear-noctalia-for-source
git commit -m "kitty: add Noctalia source cleanup helper"
```

## Task 3: Add Global Kitty Watcher

**Files:**
- Create: `dotfiles/kitty/codex-noctalia-watcher.py`

- [ ] **Step 1: Create the watcher**

Create `dotfiles/kitty/codex-noctalia-watcher.py`:

```python
#!/usr/bin/env python3
import hashlib
import os
import subprocess
import time


CLEAR_SCRIPT = "/home/felix/nixos/bin/kitty-clear-noctalia-for-source"
_last_clear_by_source = {}
_last_active_by_os_window = {}


def _instance_key() -> str:
    listen_on = os.environ.get("KITTY_LISTEN_ON", "")
    if listen_on:
        return hashlib.sha256(listen_on.encode("utf-8")).hexdigest()[:12]
    return hashlib.sha256(str(os.getpid()).encode("ascii")).hexdigest()[:12]


def _source_key(window) -> str:
    return f"kitty:{_instance_key()}:{window.id}"


def _close_live_notifications(boss, window) -> None:
    notification_manager = getattr(boss, "notification_manager", None)
    if notification_manager is None:
        return

    commands = getattr(notification_manager, "in_progress_notification_commands", {})
    notification_ids = [
        notification_id
        for notification_id, command in list(commands.items())
        if getattr(command, "channel_id", None) == window.id
    ]

    for notification_id in notification_ids:
        notification_manager.close_notification(notification_id)


def _clear_for_window(window) -> None:
    source_key = _source_key(window)
    now = time.monotonic()
    if now - _last_clear_by_source.get(source_key, 0.0) < 0.5:
        return
    _last_clear_by_source[source_key] = now
    subprocess.Popen([CLEAR_SCRIPT, source_key])


def on_focus_change(boss, window, data) -> None:
    if data.get("focused"):
        _close_live_notifications(boss, window)
        _clear_for_window(window)


def on_tab_bar_dirty(boss, window, data) -> None:
    active = getattr(boss, "active_window", None)
    if active is None:
        return
    os_window_id = getattr(active, "os_window_id", None)
    previous = _last_active_by_os_window.get(os_window_id)
    if previous == active.id:
        return
    _last_active_by_os_window[os_window_id] = active.id
    _close_live_notifications(boss, active)
    _clear_for_window(active)
```

- [ ] **Step 2: Verify syntax**

Run:

```bash
python3 -m py_compile dotfiles/kitty/codex-noctalia-watcher.py
```

Expected: command exits 0.

- [ ] **Step 3: Commit**

```bash
git add dotfiles/kitty/codex-noctalia-watcher.py
git commit -m "kitty: clear Noctalia history on focus"
```

## Task 4: Wire Kitty Config And Home Manager

**Files:**
- Modify: `home-modules/kitty.nix`
- Modify: `dotfiles/kitty/kitty.conf`

- [ ] **Step 1: Add Home Manager symlinks**

In `home-modules/kitty.nix`, add:

```nix
configFile."kitty/notifications.py".source =
  config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/kitty/notifications.py";
configFile."kitty/codex-noctalia-watcher.py".source =
  config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/kitty/codex-noctalia-watcher.py";
```

Place them next to the existing `kitty/kitty.conf` and `kitty/noctalia.conf.template` symlinks.

- [ ] **Step 2: Register watcher in kitty.conf**

In `dotfiles/kitty/kitty.conf`, add:

```conf
watcher /home/felix/nixos/dotfiles/kitty/codex-noctalia-watcher.py
```

Keep the existing command-finish notification setting:

```conf
notify_on_cmd_finish unfocused 10.0 notify focus next
```

- [ ] **Step 3: Validate Home Manager evaluation**

Run:

```bash
nix eval .#nixosConfigurations.nixos-work.config.home-manager.users.felix.xdg.configFile.\"kitty/notifications.py\".source --raw
```

Expected output:

```text
/home/felix/nixos/dotfiles/kitty/notifications.py
```

- [ ] **Step 4: Commit**

```bash
git add home-modules/kitty.nix dotfiles/kitty/kitty.conf
git commit -m "kitty: wire notification footer hooks"
```

## Task 5: Manual Integration Test

**Files:**
- No file changes expected.

- [ ] **Step 1: Reload/apply Home Manager config**

Run the relevant Home Manager switch for this host:

```bash
just hm-switch
```

Expected: command exits 0.

- [ ] **Step 2: Restart kitty**

Close and reopen kitty so `notifications.py` and the global watcher are loaded.

- [ ] **Step 3: Create a command-finish notification**

In a kitty tab that is not focused or is hidden in an inactive tab, run a command that exceeds the configured threshold:

```bash
sleep 11
```

Expected: Noctalia history contains a `Kitty` entry whose body ends with a `Kitty-Source:` footer.

- [ ] **Step 4: Verify manual focus clears Noctalia history**

Focus the originating kitty tab manually.

Run:

```bash
noctalia-shell ipc call notifications getHistory |
  jq -r '.[]? | select((.body // "") | contains("Kitty-Source:")) | [.id, .summary, .body] | @tsv'
```

Expected: the live popup closes and the entry for the focused tab is gone from Noctalia history.

- [ ] **Step 5: Verify click-to-focus remains native**

Trigger another command-finish notification from an unfocused kitty tab, click the notification, then check history again.

Expected:

- kitty focuses the originating tab/window.
- the watcher runs after focus.
- the live popup closes.
- the matching Noctalia history entry is removed.

## Task 6: Codex Notification Compatibility

**Files:**
- Modify only if needed: `bin/codex-notify-noctalia`, `dotfiles/codex/config.toml`

- [ ] **Step 1: Verify current Codex kitty-routed notifications are tagged**

Run a Codex interaction inside kitty that emits the existing TUI/OSC notification path, such as an approval prompt if that is the currently configured kitty-routed Codex notification.

Expected: Noctalia history stores the notification with a `Kitty-Source:` footer because kitty's `notifications.py` mutates all outgoing kitty notifications.

- [ ] **Step 2: Preserve WezTerm behavior**

Run:

```bash
bash -n bin/codex-notify-noctalia
bash -n bin/codex-clear-noctalia-for-pane
bash -n bin/codex-noctalia-action-watch
```

Expected: all exit 0.

- [ ] **Step 3: Change Codex top-level hook only if that event is required in kitty**

If a Codex `agent-turn-complete` notification is required in kitty and the top-level `notify` hook still exits because `WEZTERM_PANE` is absent, add a kitty branch to `bin/codex-notify-noctalia` that appends the same footer to the body and sends a tagged freedesktop notification. Use `KITTY_WINDOW_ID` only as a fallback identity; prefer the `notifications.py` path for notifications that already pass through kitty.

- [ ] **Step 4: Commit if changes were needed**

```bash
git add bin/codex-notify-noctalia dotfiles/codex/config.toml
git commit -m "codex: align kitty notifications with source footers"
```

Skip this commit if no Codex hook changes were needed.

## Acceptance Criteria

- Native kitty click-to-focus behavior still works.
- Native kitty `notify_on_cmd_finish ... notify focus next` live popup cleanup still works.
- Noctalia history entries created by kitty notifications include a `Kitty-Source:` footer.
- Manually focusing the originating kitty tab/window closes matching live popups and removes matching Noctalia history entries.
- Focusing one kitty tab does not remove footer-tagged history entries from another kitty tab.
- Existing WezTerm Codex notification cleanup remains unchanged.

## Assumptions

- `notifications.py` receives a non-zero `cmd.channel_id` for kitty notifications emitted by terminal clients and for `notify_on_cmd_finish`.
- Kitty watcher callbacks receive `window.id` values matching `cmd.channel_id`.
- A short hash of `KITTY_LISTEN_ON` or the kitty process id is sufficient to avoid collisions across concurrently running kitty instances.
- The source footer being visible at the end of Noctalia history bodies is acceptable.
