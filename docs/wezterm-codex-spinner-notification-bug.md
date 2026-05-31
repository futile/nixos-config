# WezTerm Codex Spinner Notification Marker Bug

Date: 2026-05-31

## Symptoms

- WezTerm becomes very unresponsive while Codex is actively working.
- The rest of the system remains usable, and kitty remains smooth.
- With Codex `terminal_title = ["spinner", "project", "app-name"]`, `wezterm-gui` CPU rose to roughly 25-30% in a one-shot `front_end = "WebGpu"` test window and around 50% in the existing default window.
- When Codex finishes and the terminal title stops animating, `wezterm-gui` returns to near 0% CPU.
- Removing `spinner` drops the WebGpu test window to roughly 6-7% CPU during a Codex turn, and the UI remains smooth.
- A Codex completion in a separate one-shot WebGpu WezTerm process marked an unrelated first tab in the original WezTerm window with the yellow ready dot.

## Relevant Files

- `dotfiles/codex/hosts/nixos-work/config.toml`
  - `[tui].terminal_title` controls the Codex title spinner.
  - `notify = ["/home/felix/nixos/bin/codex-notify-noctalia"]`.
- `bin/codex-notify-noctalia`
  - Handles Codex `agent-turn-complete`.
  - Writes ready markers under `$XDG_RUNTIME_DIR/codex-noctalia/ready-panes`.
- `bin/codex-clear-noctalia-for-pane`
  - Clears ready markers and Noctalia history for a pane.
- `dotfiles/wezterm/codex-noctalia.lua`
  - Registers `format-tab-title`.
  - Before the fix, `format-tab-title` synchronously checked marker files with `io.open`.

## Root Cause Hypothesis

Two independent issues combine:

1. Codex spinner-driven terminal title changes cause WezTerm to re-run tab title formatting repeatedly while Codex is busy.
2. The notification marker code did synchronous filesystem checks from WezTerm's `format-tab-title` callback, which runs on the GUI path and should be kept trivial.

The unrelated-tab marker bug has a separate but related root cause:

- Ready markers were keyed only by `pane_id`.
- Separate WezTerm GUI/mux processes can reuse pane IDs.
- A Codex completion in the WebGpu test process wrote a ready marker such as `ready-panes/1`, which the original WezTerm process interpreted as its own pane 1.

## Planned Fix

- Keep Codex `notify` as the source of truth for `agent-turn-complete`.
- Namespace marker files with both `window_id` and `pane_id`, using a key like `<window_id>-<pane_id>`.
- In WezTerm Lua, maintain an in-memory `ready_panes` cache keyed by `<window_id>-<pane_id>`.
- Refresh the cache from marker files at most every 500ms from non-format callbacks.
- Make `format-tab-title` a cheap table lookup only.

## Concurrency Notes

WezTerm Lua callbacks run on WezTerm's GUI/event loop, so the in-memory Lua table does not need locking for concurrent readers/writers. External scripts still write marker files concurrently with WezTerm reading them, so the cache refresh should tolerate transient partial state. Marker creation/removal is file-level and the UI can tolerate up to 500ms of staleness.

