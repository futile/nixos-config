{
  description = "Full Flake Panic!";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-22.11"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-pkgs-unstable = { url = "github:nixos/nixpkgs/nixpkgs-unstable"; };
    nixpkgs-master = { url = "github:nixos/nixpkgs/master"; };

    nixpkgs-local = { url = "/home/felix/gits/nixpkgs"; };

    # for emacsGcc; see https://gist.github.com/mjlbach/179cf58e1b6f5afcb9a99d4aaf54f549
    emacs-overlay = { url = "github:nix-community/emacs-overlay"; };

    home-manager = {
      url = "github:nix-community/home-manager/release-22.11";
      inputs = { nixpkgs.follows = "nixpkgs"; };
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

    wezterm-everforest = {
      url = "git+https://git.sr.ht/~maksim/wezterm-everforest";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
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
    in {
      nixosConfigurations.nixos-home = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        # forward flake-inputs to module arguments
        specialArgs = { flake-inputs = inputs; };

        modules = baseModules ++ [
          # "draw the rest of the owl"
          ./hosts/nixos-home/system.nix

          # user config
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # forward flake-inputs to module arguments
            home-manager.extraSpecialArgs = { flake-inputs = inputs; };
            home-manager.users.felix = ./hosts/nixos-home/home.nix;
          }
        ];
      };
    };
}
