# My NixOS Configurations

This repository contains the configurations for my NixOS-machines.

## General Structure

The general layout of this repository is as follows:

* `flake.nix` entrypoint that defines NixOS-configurations for all my hosts.
* `hosts/` contains per-host configurations. These use other existing `modules/` and `home-modules/` to configure a system.
* `module/` contains NixOS-modules related to individual things, i.e., ZFS or docker configuration. These are meant to be reusable, and are built upon by the hosts in `hosts/`.
* `home-modules/` contains home-manager modules, for things that are not in NixOS, or where home-manager offers more configuration options. Usually more high-level and desktop-y.
* `dotfiles/` contains dotfiles for various programs and editors, which are either symlinked or copied into the built system.
* `bin/` contains binaries/scripts that are added to `$PATH` using home-manager.
* `scripts/` contains scripts that should not be on `$PATH`, but are somehow related to a system.
* `cachix.nix` and `cachix/` contain (boilerplate) cachix configuration.
* `justfile` commands I regularly use for managing my config, bundled up for usage with `just`. Very handy to write down commands I don't want to forget.

## Setting Up a New Host

Instructions for setting up a new host can be found [here](new-system-installation.md).

### Shoutouts

Thanks and shoutouts to good resources:

* https://github.com/pimeys/nixos an awesome configuration with a nice structure, which also served as a guideline for my config.
* https://discourse.nixos.org lots of useful discussions and snippets for everything Nix & NixOS.
* https://nixos.org for existing in general.
* https://github.com/nix-community/home-manager for extending NixOS with lots of more things, and for providing a great way to manage program configurations and dotfiles.
  * https://mipmip.github.io/home-manager-option-search/ for providing a searchable version of home-manager options.

### License

Everything in this repo is licensed as CC0, see [LICENSE](LICENSE) for further information.
Please let me know if you find anything that can't be licensed under CC0 in this repo.

### Contributing

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, shall be licensed under CC0, without any additional terms or conditions.
