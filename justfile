# allow positional arguments to commands
set positional-arguments

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
    nix flake info

# Update a single input (see `show-inputs` for available inputs)
update-input input:
    nix flake lock --update-input '{{input}}'

# Sync doom, sometimes necessary to do manually after updates
sync-doom:
    doom sync

# Update all doom packages and sync
update-doom-packages:
    doom sync -u

# Build and show what changes would be activated (i.e., services)
build:
    sudo nixos-rebuild dry-activate
