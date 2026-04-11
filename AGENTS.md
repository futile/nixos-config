# Repository Guidelines

## Project Structure & Module Organization
`flake.nix` is the entrypoint for all systems and exposes the shared formatter. Put machine-specific configuration in `hosts/` (`nixos-home/`, `nixos-work/`, `hm-cf/`). Keep reusable NixOS modules in `modules/` and reusable Home Manager modules in `home-modules/`. Store application config under `dotfiles/`, helper executables in `bin/`, non-PATH automation in `scripts/`, and ad hoc project dev flakes in `project-flakes/`. Use `docs/` for contributor-facing reference material such as [`docs/macos-permissions.md`](docs/macos-permissions.md).

Treat `hosts/hm-cf/` as macOS-only. Do not change `hm-cf` files unless the task is explicitly for a macOS device or macOS-specific behavior.

## Build, Test, and Development Commands
Prefer `just` recipes over ad hoc commands:

- `just check`: run `nix flake check` for repository-level evaluation.
- `just build`: build the current host system to `./result` without switching.
- `just switch`: apply the current NixOS configuration on Linux.
- `just hm-build` / `just hm-switch`: build or switch the standalone Home Manager config.
- `just format`: run `nix fmt` and format the `justfile`.
- `just format-check`: fail if formatting is not clean.

Use `just --list --unsorted` to discover less common workflows such as `dry-activate` or macOS permission setup.

## Coding Style & Naming Conventions
Nix code is formatted with the flake formatter (`nixfmt-tree`); run `just format` before submitting changes. Follow existing naming patterns: host directories use machine names, reusable modules use descriptive kebab-case filenames such as `desktop-common.nix`, and keep related logic grouped by domain instead of by tool. Match the surrounding file’s indentation and comment style. Prefer small, composable modules over host-local duplication.

## Testing Guidelines
There is no standalone unit test suite here; validation is configuration-focused. At minimum, run `just format-check` and `just check`. For host-specific changes, also run the relevant build path: `just build` for the current Linux host or `just hm-build` for `hosts/hm-cf`. When a change affects activation behavior, include the exact command you used to verify it.

## Commit & Pull Request Guidelines
Recent commits follow a scoped style such as `hm-cf: Add touch-id support for sudo` or `docs: Move current AGENTS.md...`. Use `scope: imperative summary`, with multiple scopes when needed (`hm-cf,docs:`). Keep commits narrowly focused. Pull requests should state which host or module is affected, list validation commands run, and include screenshots only for UI-facing dotfile changes (Waybar, Neovim, WezTerm, etc.). Link any relevant issue or setup note when the change depends on manual steps.
