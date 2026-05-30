# Conventions

- Prefer existing repo patterns over new abstractions. Keep host-specific config in `hosts/<host>`, reusable NixOS logic in `modules/`, reusable HM logic in `home-modules/`.
- Do not edit `hosts/hm-cf/` unless the task is explicitly macOS-specific.
- Nix filenames use descriptive kebab-case. Host directories use machine names.
- Nix formatting is formatter-owned; do not manually bikeshed formatting.
- New/updated custom packages normally go in `custom-packages/<name>.nix`, are exposed in `flake.nix` `packages.${system}`, and in `modules/core.nix` under `pkgs.my-custom-packages`. Exception: parked fallback packages may be exposed but not installed by any host/HM module.
- New files used by flake evaluation must be git-tracked before `nix eval`/`nix build` can see them.
- For Nix build/eval commands, lower CPU priority with `nice -n 19` when running directly. Prefer `just` recipes where available.
- Do not assume nested `nixpkgs.config` list options merge. Repo uses `my.permittedInsecurePackages` as mergeable list forwarded once to `nixpkgs.config.permittedInsecurePackages`.
- `dotfiles/codex/AGENTS.source.md` is readable source; compressed `dotfiles/codex/AGENTS.md` is generated with `just compress-codex-agents`.
- After changing `.codex/config.toml`, restart Codex before relying on new config; existing sessions/subagents may keep stale config.
- Codex host config for nixos-work is repo-managed at `dotfiles/codex/hosts/nixos-work/config.toml`; do not run upstream installers that mutate `~/.codex/config.toml` when a declarative edit is appropriate.
- Use CBM as auxiliary index, not replacement for `rg`. For literals/config/docs/Nix semantics, source reads/eval win.
- Use DeepWiki with exact GitHub owner/repo casing when needed.
- Commit style: `scope: imperative summary`; keep commits narrowly focused. PR notes should include affected host/module and validation commands.