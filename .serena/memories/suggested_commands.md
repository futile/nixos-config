# Suggested Commands

- Discover recipes: `just --list --unsorted`.
- Format: `just format`.
- Format check: `just format-check` or preferred noisy wrapper `rtk just format-check`.
- Repo evaluation check: `just check` or preferred noisy wrapper `rtk just check`.
- Build current Linux host to `./result`: `just build`; direct equivalent is `nice -n 19 nixos-rebuild build`.
- Switch current Linux host: `sudo -A nixos-rebuild switch` works in this repo; `sudo -A just switch` may fail under root/libgit2 safe-directory handling.
- Standalone Home Manager build/switch: `just hm-build`, `just hm-switch`.
- Dry activation: `just dry-activate`.
- Update all flake inputs: `just update`; update one input: `just update-input <input>`.
- Build a package directly: `nice -n 19 nix build .#<package> --no-link`; use `--print-out-paths` when path is needed.
- Evaluate Nix values: `nix eval ...`; use source/eval over CBM for exact Nix options, module wiring, paths, and config values.
- Prefer `rtk <command>` for noisy shell commands when exact raw output is not needed: `rtk git status`, `rtk git diff --cached`, `rtk just check`, `rtk journalctl --user --since "10 min ago"`.
- Use raw commands when exact output matters, interactive commands, or debugging RTK.
- CBM CLI examples: `codebase-memory-mcp cli list_projects '{}'`, `codebase-memory-mcp cli index_status '{"project":"home-felix-nixos"}'`, `codebase-memory-mcp cli get_architecture '{"project":"home-felix-nixos","aspects":["all"]}'`.
- Compress Codex global instructions: `just compress-codex-agents`.
- Serena sanity checks: `serena --version`, `serena start-mcp-server --help`, `serena-hooks --help`, `serena memories check`.