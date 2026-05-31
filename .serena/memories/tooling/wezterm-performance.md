# WezTerm GUI Callback Performance

When editing WezTerm config or Lua integrations, keep GUI-thread callbacks extremely cheap, especially `format-tab-title`.

Do not do filesystem I/O, IPC, process spawning, `wezterm cli`, Noctalia calls, JSON parsing, or other blocking/CPU-heavy work inside `format-tab-title` or similar hot callbacks.

Context: Codex updates the terminal title at about 10 Hz while working, and its animated `Working` status schedules frames around 31 FPS. WezTerm can call tab-title formatting repeatedly during those updates. Past synchronous marker-file checks in `format-tab-title` contributed to poor responsiveness.

Use cached/in-memory state in `format-tab-title`; refresh external state from lower-frequency callbacks such as `update-status` or external scripts. See `docs/wezterm-codex-notification-performance.md`.