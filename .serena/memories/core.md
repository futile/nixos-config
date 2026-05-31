# Core

- NixOS/Home Manager flake repo. `flake.nix` is root entrypoint for packages, NixOS systems, Home Manager systems, formatter, templates.
- Hosts live under `hosts/`: `nixos-home`, `nixos-work`, `hm-cf`. `hosts/hm-cf/` is macOS-only; do not touch unless task is explicitly macOS-specific.
- Reusable NixOS modules: `modules/`. Reusable Home Manager modules: `home-modules/`.
- App/user config: `dotfiles/`. Helper executables intended for PATH: `bin/`. Non-PATH automation: `scripts/`. Ad hoc dev flakes: `project-flakes/`. Contributor docs: `docs/`.
- Custom package expressions: `custom-packages/<name>.nix`; overlay exposure through `modules/core.nix` as `pkgs.my-custom-packages`; debug flake package exposure through `flake.nix` `packages.${system}`.
- Common base modules in `flake.nix`: `modules/core.nix`, `modules/sccache.nix`, `modules/lib-my.nix`, `cachix.nix`.
- `modules/core.nix` owns custom package overlay, `nixpkgs.config.allowUnfree`, mergeable `my.permittedInsecurePackages`, nix flakes settings, registry entries.
- `modules/lib-my.nix` exposes `pkgs.lib.my.editorTools` from `modules/editor-tools.nix` and `pkgs.lib.my.mkWrappedWithDeps` for PATH-wrapped packages.
- `hosts/nixos-work/home.nix` imports active desktop/Codex/Home Manager modules and sets `my.codex.configToml = "${thisFlakePath}/dotfiles/codex/hosts/nixos-work/config.toml"`.
- Codex token stack lives in `home-modules/codex-token-optimization.nix`: installs `codebase-memory-mcp`, `context-mode`, upstream Serena wrapped with editor tools, and `rtk`; links `dotfiles/codex/hooks.json` to `~/.codex/hooks.json`; Headroom service is present but gated off.
- Read `mem:tech_stack` for language/build/tooling details. Read `mem:conventions` for repo-specific editing rules. Read `mem:tooling/serena` for repo-specific notes on Serena's strengths and limits with Nix modules and Lua plugin specs. Read `mem:tooling/wezterm-performance` before editing WezTerm Lua/config or related integrations. Read `mem:suggested_commands` for commands. Read `mem:task_completion` before claiming task completion.