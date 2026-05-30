---
name: create-custom-package
description: Use when adding or updating a package under custom-packages in this repository, especially when the work needs flake wiring, overlay wiring, upstream source pinning, nixpkgs-style packaging patterns, or iterative hash and build bring-up.
---

# Create Custom Package

Use this skill when working in this repository on packages under `custom-packages/`.

## Workflow

1. Inspect repository wiring before editing:
   - Read `AGENTS.md`.
   - Read existing files in `custom-packages/`.
   - Read the package exposure points in `flake.nix` and `modules/core.nix`.
2. Match existing repo structure:
   - keep the package expression in `custom-packages/<name>.nix`
   - expose it in `packages.${system}` in `flake.nix`
   - expose it in `pkgs.my-custom-packages` in `modules/core.nix`
3. Use primary sources for the upstream package:
   - inspect the upstream repo's actual build files, lockfiles, manifests, and release/tag state
   - pin a real release tag or commit instead of vaguely following a branch when reproducibility matters
4. Prefer nixpkgs patterns over improvisation:
   - search the local `~/gits/nixpkgs` checkout for packages with the same build system
   - copy the nearest working structure, then adapt it minimally
   - match the correct tooling generation to upstream, such as using the right Tauri major-version hooks
5. Use DeepWiki when it is useful:
   - use the DeepWiki MCP against `nixos/nixpkgs` when you need repository-grounded explanations of existing packaging patterns
   - use it for other upstream repositories too when local file inspection is not enough and you need repository-aware context
   - prefer it as a supplement to primary source reads, not a replacement for checking the actual files you will package against
6. Bring the package up iteratively:
   - start with placeholder hashes where appropriate
   - run a package-only build first
   - replace fixed-output hashes from actual Nix error messages one at a time
   - do not guess hashes or add broad changes before the build tells you what is wrong
7. Make flake-visible files visible to Nix:
   - if a new file is added under `custom-packages/`, ensure it is git-tracked before relying on flake evaluation
8. Patch only what is necessary for packaging:
   - disable upstream updater, signing, release-only, or CI-only behavior when it does not belong in a reproducible source build
   - keep compatibility patches narrow and document why they exist
9. If the package needs repo-level policy exceptions such as insecure-package allowances:
   - do not assume nested `nixpkgs.config` assignments will merge across modules
   - prefer a dedicated mergeable repo option that forwards once into the final nixpkgs config

## Common Patterns

- `fetchFromGitHub` plus fixed `rev` and `hash` for source pinning
- `callPackage ./custom-packages/<name>.nix { }` from both `flake.nix` and `modules/core.nix`
- package-only verification before full host or Home Manager integration
- local compatibility shims when nixpkgs moved ahead of upstream but the package can still be built safely

## Common Mistakes

- Writing the package first without checking how this repo exposes custom packages
- Manually creating a package from scratch instead of checking how `~/gits/nixpkgs` packages similar cases
- Copying a nixpkgs package with the wrong toolchain generation for the upstream app
- Guessing dependency hashes instead of letting Nix report them
- Forgetting that new files in a flake must be tracked by git before evaluation sees them
- Keeping upstream auto-update or release-signing behavior enabled in a Nix source build
- Applying broad refactors instead of a minimal packaging patch
- Assuming `nixpkgs.config` subkeys merge like ordinary NixOS list options

## Validation

1. Build the package directly first, for example `nix build .#<package-name> --no-link`.
2. If the package is consumed by a host or Home Manager config, also build the relevant system or activation path.
3. Run `just format-check`.
4. In the final response, report the exact verification commands used and any policy exceptions or compatibility shims the package requires.
