# WezTerm Codex Notifications And Performance

Date: 2026-05-31

## Current State

Codex completion notifications are integrated with Noctalia through a hybrid path:

- Codex `agent-turn-complete` events use the top-level Codex `notify` hook.
- Approval requests still use Codex TUI OSC9 notifications.
- WezTerm Lua adds a yellow ready marker to inactive tabs whose active pane has a pending Codex completion notification.
- Focusing the relevant pane clears the marker and removes that pane's Noctalia notification history entries.

The current WezTerm-side marker path is optimized to keep `format-tab-title` cheap:

- Notification scripts write ready marker files under `$XDG_RUNTIME_DIR/codex-noctalia/ready-panes`.
- Marker names are keyed as `<window_id>-<pane_id>`.
- `dotfiles/wezterm/codex-noctalia.lua` refreshes an in-memory `ready_panes` cache from those marker files on WezTerm `update-status`.
- `format-tab-title` first checks `has_ready_panes`; when false it immediately returns `nil`.
- When there are ready panes, `format-tab-title` only does table lookups and string formatting. It no longer performs filesystem I/O.
- `dotfiles/wezterm/wezterm.lua` sets `status_update_interval = 500`, so cache refresh is at most every 500ms.

The current host config uses `front_end = "WebGpu"` on `nixos-work` and keeps Codex's spinner title enabled:

```toml
[tui]
terminal_title = ["spinner", "project", "app-name"]
```

## Relevant Files

- `dotfiles/codex/hosts/nixos-work/config.toml`
  - `[tui].terminal_title` controls the Codex title spinner.
  - `notify = ["/home/felix/nixos/bin/codex-notify-noctalia"]`.
- `bin/codex-notify-noctalia`
  - Handles Codex `agent-turn-complete`.
  - Writes ready markers keyed by `<window_id>-<pane_id>`.
- `bin/codex-clear-noctalia-for-pane`
  - Clears ready markers and Noctalia history for a pane.
  - Accepts an optional `window_id` to clear namespaced markers precisely.
- `bin/codex-noctalia-action-watch`
  - Watches notification click actions and activates the mapped WezTerm pane.
- `dotfiles/wezterm/codex-noctalia.lua`
  - Registers `format-tab-title`.
  - Maintains the in-memory ready-pane cache.
- `tests/codex-noctalia-marker-test.sh`
  - Guards the marker key/cache shape.
  - Ensures `format-tab-title` does not use `io.open`.

## Performance Findings

Codex itself animates while it is working:

- Codex terminal title spinner updates every 100ms, about 10 Hz.
- Codex's animated `Working` shimmer schedules frames every 32ms, about 31 FPS.
- Codex does not appear to render the whole TUI at a fixed 60-100 FPS continuously; it schedules frames when animated widgets or state changes request them.
- Frame scheduling is coalesced internally and clamped by a max 120 FPS limiter.

Measured behavior during local testing:

- With WezTerm's Codex/Noctalia Lua integration disabled, `wezterm-gui` still rose to roughly 18-20% CPU while Codex was actively working.
- With the optimized Lua integration re-enabled, CPU still rose above 20%, but the UI remained fluid.
- kitty stayed below roughly 5% CPU rendering the same Codex spinner and `Working` animations.
- This means the notification marker integration is no longer the main explanation for the remaining WezTerm CPU usage. The remaining cost is likely mostly WezTerm rendering/parsing Codex's animated terminal output and title updates.

## Pane ID Collision Regression

The regression test exists because a one-shot WebGpu WezTerm test window exposed a pane-id collision:

- Ready markers were originally keyed only by bare `pane_id`.
- Separate WezTerm GUI/mux processes can reuse pane IDs.
- A Codex completion in the WebGpu test process wrote a marker like `ready-panes/1`.
- The original WezTerm process interpreted that marker as its own pane 1 and marked an unrelated tab ready.

The current marker format fixes this by using `<window_id>-<pane_id>` keys. The test checks that the notify and clear scripts use `pane_key`, that Lua caches ready panes, and that `format-tab-title` does not perform filesystem I/O.

## Maintenance Rule

Do not perform filesystem I/O, IPC, process spawning, Noctalia calls, `wezterm cli` calls, JSON parsing, or any other blocking or CPU-heavy work from WezTerm GUI-thread callbacks such as `format-tab-title`.

Codex updates its terminal title at about 10 Hz while working, and its animated `Working` status schedules frames around 31 FPS. Any extra work in tab formatting is multiplied by those refreshes and can make WezTerm noticeably less responsive.

## Concurrency Notes

WezTerm Lua callbacks run on WezTerm's GUI/event loop, so the in-memory Lua table does not need locking for concurrent readers/writers. External scripts still write marker files concurrently with WezTerm reading them, so the cache refresh should tolerate transient partial state. Marker creation/removal is file-level and the UI can tolerate up to 500ms of staleness.

## Remaining Questions

- Why does WezTerm use substantially more CPU than kitty for the same Codex animations?
- How much of the remaining cost comes from OSC terminal-title updates versus ratatui redraw output?
- Would reducing WezTerm `max_fps`, disabling Codex `animations`, or disabling only Codex terminal-title `spinner` provide an acceptable tradeoff?
- Would upstream Codex render metrics or local `strace` sampling show a specific terminal-output pattern that WezTerm handles poorly?
