# allow positional arguments to commands

set positional-arguments := true

# List available recipes
_default:
    @just --list --unsorted

# Rebuild system with current configuration (does not update)
switch:
    sudo nixos-rebuild switch

# Update all flake inputs (i.e., package repos, doom-emacs version, etc.)
update:
    nix flake update

# Show available inputs (can be used for `update-input`)
show-inputs:
    nix flake metadata

# Update a single input (see `show-inputs` for available inputs)
update-input input:
    nix flake lock --update-input '{{ input }}'

# Sync doom, sometimes necessary to do manually after updates
sync-doom:
    doom sync

# Update all doom packages and sync
update-doom-packages:
    doom sync -u

# Build and show what changes would be activated (i.e., services)
dry-activate:
    # TODO: maybe use `--download-speed` for throttling?
    # TODO: maybe also limit CPU-usage somewhat, maybe with a switch?
    sudo nixos-rebuild dry-activate

# Build the system configuration to `./result`
build:
    nixos-rebuild build

# Check the flake using `nix flake check`
check:
    nix flake check

# Format everything (using `nixpkgs-fmt` and `just --fmt`).
format:
    nixpkgs-fmt .
    just --unstable --fmt

# Check if everything is formatted correctly.
format-check:
    nixpkgs-fmt . --check
    just --unstable --fmt --check

# Show a diff of changes using `nix-diff`
diff:
    nix-diff /run/current-system ./result

# Nix collect garbage; dry-run
nix-gc:
    nix-collect-garbage --dry-run --delete-older-than 14d

# Nix collect garbage; actual run
nix-gc-force:
    nix-collect-garbage --delete-older-than 14d
