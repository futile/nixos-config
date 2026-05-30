# Task Completion

- Minimum for config/package changes: run `rtk just format-check` and `rtk just check`.
- For host-specific Linux changes affecting current host: also run `nice -n 19 nixos-rebuild build` or `just build`. If applying live, `sudo -A nixos-rebuild switch` is the path known to work.
- For standalone Home Manager/macOS-ish `hosts/hm-cf` work: run relevant `just hm-build` / `just hm-switch` instead of Linux host build; do not touch `hm-cf` unless task is macOS-specific.
- For package changes: build package directly first, e.g. `nice -n 19 nix build .#<package> --no-link`; use `--print-out-paths` for smoke testing binaries.
- For new flake-visible files: `git add` before relying on Nix evaluation.
- For Codex config/hook changes: validate JSON/TOML shape where applicable, smoke-test commands if possible, run repo checks, switch if requested, and remind that Codex must be restarted before new config is authoritative.
- For activation behavior changes: report exact command used (`sudo -A nixos-rebuild switch`, `just switch`, etc.) and resulting system path when available.
- Before final response: inspect `git status --short --untracked-files=all`; distinguish staged, unstaged, committed, and clean states.
- Do not claim completion/passing without fresh command output from the current turn.