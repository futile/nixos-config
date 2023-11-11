{
  description = "Full Flake Panic!";

  inputs = {
    # nixpkgs = { url = "github:nixos/nixpkgs/nixos-23.05"; };
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-pkgs-unstable = { url = "github:nixos/nixpkgs/nixpkgs-unstable"; };
    nixpkgs-master = { url = "github:nixos/nixpkgs/master"; };

    # disabling this cause I didn't have a ~/gits/nixpkgs lying around
    #nixpkgs-local = { url = "/home/felix/gits/nixpkgs"; };
    nixpkgs-local = { url = "github:nixos/nixpkgs/nixos-23.05"; };

    # for emacsGcc; see https://gist.github.com/mjlbach/179cf58e1b6f5afcb9a99d4aaf54f549
    emacs-overlay = { url = "github:nix-community/emacs-overlay"; };

    nixos-hardware = { url = "github:NixOS/nixos-hardware"; };

    home-manager = {
      # url = "github:nix-community/home-manager/release-23.05";
      url = "github:nix-community/home-manager";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    nix-alien = {
      url = "github:thiagokokada/nix-alien";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland";
    };

    fish-foreign-env = {
      url = "github:oh-my-fish/plugin-foreign-env";
      flake = false;
    };

    fish-puffer-fish = {
      url = "github:nickeb96/puffer-fish";
      flake = false;
    };

    fish-tide = {
      url = "github:IlanCosman/tide/7f41dd24d815c16e85560e1e6a28b03203e2bfe";
      flake = false;
    };

    doom-emacs = {
      url = "github:hlissner/doom-emacs";
      flake = false;
    };

    wezterm-everforest = {
      url = "git+https://git.sr.ht/~maksim/wezterm-everforest";
      flake = false;
    };

    wezterm-embark = {
      url = "github:dmshvetsov/wezterm-embark-theme";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      # base modules that will commonly be used by all systems
      baseModules = [
        # core stuff (overlays, nix config, flake registry, nix path, etc.)
        ./modules/core.nix

        # `lib.my`
        ./modules/lib-my.nix

        # load cachix caches; generated through `cachix use -m nixos <cache-name>`
        ./cachix.nix
      ];
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.nixos-home = nixpkgs.lib.nixosSystem {
        inherit system;

        # forward flake-inputs to module arguments
        specialArgs = { flake-inputs = inputs; inherit system; };

        modules = baseModules ++ [
          # "draw the rest of the owl"
          ./hosts/nixos-home
        ];
      };

      nixosConfigurations.nixos-work = nixpkgs.lib.nixosSystem {
        inherit system;

        # forward flake-inputs to module arguments
        specialArgs = { flake-inputs = inputs; inherit system; };

        modules = baseModules ++ [
          # "draw the rest of the owl"
          ./hosts/nixos-work
        ];
      };
    };
}
