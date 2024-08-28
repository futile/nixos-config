{
  description = "Full Flake Panic!";

  inputs = {
    # nixpkgs = { url = "github:nixos/nixpkgs/nixos-23.05"; };
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };

    # disabling this cause cause it's the same as `nixpkgs` atm (and it uses storage/network DL)
    # nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    # nixpkgs-unstable = nixpkgs; # requires `inputs = rec {`. works, but duplicates the input, doesn't reference it

    nixpkgs-pkgs-unstable = { url = "github:nixos/nixpkgs/nixpkgs-unstable"; };

    # disabling this cause I don't need it currently (and it uses storage/network DL)
    # nixpkgs-master = { url = "github:nixos/nixpkgs/master"; };

    # disabling this cause I didn't have a ~/gits/nixpkgs lying around
    # nixpkgs-local = { url = "/home/felix/gits/nixpkgs"; };

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
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
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
      url = "github:IlanCosman/tide";
      flake = false;
    };

    doom-emacs = {
      url = "github:hlissner/doom-emacs";
      flake = false;
    };

    wezterm-embark = {
      url = "github:dmshvetsov/wezterm-embark-theme";
      flake = false;
    };

    wezterm-git.url = "github:wez/wezterm?dir=nix";
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
      packages.${system} = {
        # these are here mostly for debugging, for actual use I base on the `nixpkgs`-instance of a configured system, see overlay in `core.nix`.
        phinger-cursors-extended = nixpkgs.legacyPackages.${system}.callPackage ./custom-packages/phinger-cursors-extended.nix { };
      };

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
          # use wezterm from git, because unstable currently fails to start on wayland
          ({ config, flake-inputs, system, ... }: {
            nixpkgs.overlays =
              [ (final: prev: { wezterm = flake-inputs.wezterm-git.packages.${prev.system}.default; }) ];
          })
        ];
      };
    };
}
