---
name: create-home-module
description: Create or update a Home Manager module in this repository when the task is to add a new reusable module, wire shared dotfiles into Home Manager, or move app config into repo-managed files.
---

# Create Home Module

Use this skill when working in this repository on Home Manager module changes.

## Workflow

1. Inspect existing patterns before editing:
   - Read `AGENTS.md`.
   - Read a few nearby files in `home-modules/` and the relevant host `home.nix` files.
   - Match the surrounding import style, comments, and symlink conventions.
2. Keep reusable logic in `home-modules/` and host-specific choices in `hosts/*/home.nix`.
3. Put repo-managed application config under `dotfiles/` when it should be shared across hosts.
4. Prefer symlinking to files in `dotfiles/` instead of copying them into the Nix store when the repo already uses direct symlinks for easier iteration.
5. Keep modules narrowly scoped:
   - one module for one tool or concern
   - avoid mixing package installation, config linking, and host-specific policy unless the repo already does that for the same tool
6. When importing a new module, update only the hosts that should actually use it.
7. Do not change `hosts/hm-cf/home.nix` unless the task is explicitly for a macOS device or macOS-specific configuration.

## Conventions

- Prefer descriptive kebab-case module names such as `codex.nix` or `desktop-common.nix`.
- Use `config.lib.file.mkOutOfStoreSymlink` for dotfiles that should stay editable from the repo checkout.
- Add short comments only where intent is not obvious.
- Avoid duplicating host logic; factor shared behavior into a module first.

## Validation

1. Run `just format-check`.
2. Run `just check`.
3. Run the relevant build when the change affects a host or Home Manager activation path.
4. In the final response, mention the commands actually used and any host-specific assumptions.
