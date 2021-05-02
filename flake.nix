{
  description = "Full Flake Panic!";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-20.09"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };

    # for python-language-server with Python 3.9 support
    nixpkgs-pyls-39 = { url = "github:nixos/nixpkgs/pull/121522/head"; };

    home-manager = { 
      url = "github:nix-community/home-manager/release-20.09"; 
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    fish-foreign-env = {
      url = "github:oh-my-fish/plugin-foreign-env";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-pyls-39, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      nixos-unstable-overlay = final: prev: {
        unstable = import nixpkgs-unstable {
          system = final.system;
          config.allowUnfree = true;
        };
      };
      nixpkgs-pyls-39-overlay = final: prev: {
        pyls-39 = import nixpkgs-pyls-39 {
          system = final.system;
          config.allowUnfree = true;
        };
      };
      lib = {
        mkWrappedWithDeps =
          { pkg, prefix-deps, suffix-deps, pathsToWrap, otherArgs ? { } }:
          let
            prefixBinPath = nixpkgs.lib.makeBinPath prefix-deps;
            suffixBinPath = nixpkgs.lib.makeBinPath suffix-deps;
            pkgs = nixpkgs.legacyPackages.${system};
          in pkgs.symlinkJoin ({
            name = pkg.name + "-wrapped";
            paths = [ pkg ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              cd "$out"
              for p in ${builtins.toString pathsToWrap}
              do
                wrapProgram "$out/$p" --prefix PATH : "${prefixBinPath}" --suffix PATH : "${suffixBinPath}"
              done
            '';
          } // otherArgs);
      };
    in rec {
      nixosConfigurations.nixos-home = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          # add unstable overlay
          ({ nixpkgs.overlays = [ nixos-unstable-overlay nixpkgs-pyls-39-overlay ]; })

          # load system config
          ./system.nix

          # user config
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.felix =
              import ./home.nix { inherit inputs lib; };
          }
        ];
      };
    };
}
