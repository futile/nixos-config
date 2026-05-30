# Tech Stack

- Primary language: Nix. Formatting via flake formatter (`nixfmt-tree`) and `just --unstable --fmt` for `justfile`.
- Flake inputs include `nixpkgs` on `nixos-unstable`, `nixpkgs-pkgs-unstable`, Home Manager following `nixpkgs`, `nixos-hardware`, `nix-alien`, Noctalia, fish plugins, Caveman, Codebase Memory MCP, ISD, Serena upstream flake on `github:oraios/serena/main`.
- Main system architecture: NixOS systems from `nixpkgs.lib.nixosSystem`; Home Manager integrated into host configs; standalone HM config also present via recipes.
- Custom package patterns: `fetchFromGitHub`, npm/Bun wrappers, Python app packaging, Rust packages with optional sccache wrapper. Expose custom packages in both `flake.nix` packages and `modules/core.nix` overlay unless intentionally parked/debug-only.
- `withRustSccache` in `flake.nix` adds `sccache`, `RUSTC_WRAPPER`, and `/var/cache/ccache/sccache` for selected Rust custom packages on Linux.
- `pkgs.lib.my.editorTools` is shared LSP/formatter/tool bundle for editors and Serena. Includes JSON/Nix/Python/Lua/JS/TS/shell/markdown/etc. tools.
- Codex stack: Codex CLI itself is intentionally kept in `nix profile`, not installed through Nixpkgs/HM. Repo manages Codex instructions, agents, host config TOML, hooks, and token optimization tools.
- Serena active package: upstream flake package wrapped only on `bin/serena` with editor tools. `serena-hooks` intentionally not wrapped. Local fallback package retained as `custom-packages/serena-custom.nix` / `.#serena-custom` / `pkgs.my-custom-packages.serena-custom`, not installed by HM.
- Codebase Memory MCP project name commonly `home-felix-nixos`. Use as auxiliary index, not source of truth for Nix option semantics.
- Mac host `hm-cf` exists but is out of scope unless task says macOS.